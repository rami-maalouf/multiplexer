# Install notes (T0.5 and later)

## 2026-10-27: first install, Synapse only

`./server/playbook.sh --tags=install-all,ensure-matrix-users-created,start` with the
playbook at `e3929968b8`: `ok=195 changed=58 failed=0`, about 25 minutes (most of it the
first download of the roles' images and the Docker step).

**Services** (systemd units `matrix-*`, each one container):

| Container | Image | Arch |
|---|---|---|
| `matrix-synapse` | `ghcr.io/element-hq/synapse:v1.164.0` | arm64, pulled |
| `matrix-postgres` | `postgres:18.6-alpine` | arm64, pulled |
| `matrix-traefik` | `traefik:v3.7.16` | arm64, pulled |
| `matrix-traefik-certs-dumper` | `ghcr.io/ldez/traefik-certs-dumper:v2.11.4` | arm64, pulled |
| `matrix-static-files` | `joseluisq/static-web-server:2.44.1-alpine` | arm64, pulled |
| `matrix-container-socket-proxy` | `ghcr.io/tecnativa/docker-socket-proxy:v0.5.0` | arm64, pulled |
| `matrix-exim-relay` | `ghcr.io/devture/exim-relay:4.99.5-r0-2` | arm64, pulled |

Nothing was built on the server (no `localhost/` images).

**Checked from the Mac:**
- `https://matrix.ramimaalouf.com` has a Let's Encrypt certificate (issuer `YR2`, valid to 2027-01-25).
- `/_matrix/client/versions` lists `v1.17` and `org.matrix.simplified_msc3575: true` (the sliding sync of Element X and matrix-rust-sdk).
- `/_matrix/client/v3/login` offers `m.login.password`.
- `@test1:ramimaalouf.com` signs in with its Keychain password and signs out again.

**Users:** `@rami:ramimaalouf.com` (admin), `@test1:ramimaalouf.com`, `@test2:ramimaalouf.com`,
with `./server/register-user.sh`. Passwords: Keychain only (see `server/README.md`).

**Other services still run:** the T3 Code server (127.0.0.1:3773) and Syncthing (22000,
127.0.0.1:8384). Docker is enabled at boot.

**Memory right after the start:** 1.7 GiB of 23 GiB used. The containers: Postgres 198 MiB,
Synapse 119 MiB, Traefik 28 MiB, the rest under 20 MiB each. CPU near 0%.

**Found on the way:** the playbook puts Ketesa's settings (`cc.etke.ketesa`) into
`/.well-known/matrix/client` even when Ketesa is off, so the file differed from the
website's copy. `config.yml` turns that property off; the file is `m.homeserver` only.

**After about one hour** (2026-10-27 22:31 UTC, `free -h` and `sudo docker stats --no-stream`):
1.8 GiB of 23 GiB used, 21 GiB available, no swap. Load average 0.08. Disk 31 of 96 GB.
All 7 `matrix-*` units active; Synapse healthy.

| Container | CPU | Memory |
|---|---|---|
| `matrix-postgres` | 0.01% | 218 MiB |
| `matrix-traefik` | 0.05% | 128 MiB |
| `matrix-synapse` | 2.9% | 126 MiB |
| `matrix-container-socket-proxy` | 0.03% | 18 MiB |
| `matrix-static-files` | 0% | 11 MiB |
| `matrix-exim-relay` | 0% | 4 MiB |
| `matrix-traefik-certs-dumper` | 0% | 4 MiB |

This is far below Oracle's 20% reclaim line (see the M0 checkpoint): one user, no bridges yet.

## 2026-10-27: first clients

- Element Web (app.element.io, Firefox): sign-in with `www.ramimaalouf.com` (not
  `ramimaalouf.com`: the 301 has no CORS header). Exchanged encrypted messages with
  `@rami-m:matrix.org` over federation, both ways.
- Element X (iPhone): sign-in worked (session `Element X iOS`). Verifying it from Element Web
  hung on the iPhone's "Start verification" spinner; Firefox showed no problem. At the two
  times checked, nothing waited in `device_inbox` for either session, so the server had
  delivered the verification messages. Then it worked (Rami, 22:30 UTC); the server holds a
  cross-signing signature for the Element X session. Not known which step fixed it. If it
  hangs again: start the verification from Element Web (Settings > Sessions > the session >
  Verify session) and do not tap Start on the iPhone.

## 2026-10-27: the WhatsApp bridge (T0.6)

`config.yml` turns on `matrix_bridge_mautrix_whatsapp_enabled` and
`matrix_appservice_double_puppet_enabled`. `./server/playbook.sh
--tags=install-all,ensure-matrix-users-created,start`: `ok=218 changed=15 failed=0`.
Synapse restarted to load the two appservice registrations.

| Container | Image | Arch |
|---|---|---|
| `matrix-mautrix-whatsapp` | `dock.mau.dev/mautrix/whatsapp:v0.2610.0` | arm64, pulled |

Appservice Double Puppet has no container: it is only a registration in Synapse. The bridge
backfills history (the playbook's default) and makes a space for the WhatsApp chats. Its rooms
are not end-to-end encrypted (`matrix_bridges_encryption_enabled` stays `false`). The
self-check stays green (`ok=36 failed=0`).

**Linked** (2026-10-27, about 22:42 UTC): Rami linked his WhatsApp account; the bridge holds
1 login. The history sync then made the rooms: 31 of 71 chats had a room at 22:44:07, 48 of
91 at 22:44:25 (the bridge finds more chats as the sync goes on). Rami saw an incoming
WhatsApp message and his history in Element X.

**Load during the history sync** (22:44:25): load average 2.35; 2.4 GiB of 23 GiB used.
Synapse 180% CPU (of 400%) and 375 MiB, Postgres 112% and 301 MiB, the bridge 21% and 84 MiB.

**Bridge log during the sync:** warnings for old messages it cannot place (unknown sender,
group messages without their sender key), and 4 errors in 30 minutes, none for new messages:
old link-preview pictures that WhatsApp no longer serves (HTTP 403), and old reactions with
no emoji that Synapse refuses ("Missing aggregation key"). The bridge log holds phone numbers
and chat IDs: read only counts, or hide the numbers, when you look at it.

## 2026-10-28: a small database backup (M0)

`config.yml` turns on the playbook's `postgres-backup` (7 daily and 2 weekly dumps, no monthly,
`BACKUP_ON_START=TRUE`). Install: `ok=236 changed=6 failed=0`. The first dump ran at the
container's start (01:23 UTC): Synapse 40.5 MB and the WhatsApp bridge 3.1 MB, gzip; `gzip -t`
passes, and the Synapse dump has 174 tables and ends cleanly. The daily, weekly, monthly and
last files are hard links to one dump: 42 MB on disk. Disk: 33 of 96 GB used.

## 2026-10-28: the Instagram bridge, for the spike (T4.1)

With Rami's yes ("please proceed with the setup and let's give it a test"), relayed by the
connectors conversation (proposal: `docs/connectors/instagram.md` on branch
`connectors/instagram`, sections 2 and 4). `config.yml` turns on
`matrix_bridge_mautrix_meta_instagram_enabled`; all other settings stay at the playbook's
defaults (encryption off, backfill, the " (IG)" name suffix, no proxy).

- Install `./server/playbook.sh --tags=install-all,ensure-matrix-users-created,start`:
  `ok=248 changed=13 failed=0`. It restarted Synapse and the WhatsApp bridge; WhatsApp came
  back with its 1 login, no errors and no logout in its log.
- Self-check: `ok=36 failed=0`, all 6 checks working.

| Container | Image | Arch |
|---|---|---|
| `matrix-mautrix-meta-instagram` | `dock.mau.dev/mautrix/meta:ig-v0.2610.0` | arm64, pulled |

Nothing was built on the server (no `localhost/` images).

**Checked from the Mac:**
- Synapse loads the bridge's registration; the bot `@instagrambot:ramimaalouf.com` exists
  ("Instagram bridge bot").
- `https://matrix.ramimaalouf.com/.well-known/matrix/mautrix` lists
  `https://matrix.ramimaalouf.com/bridges/meta-instagram` and `.../bridges/whatsapp`.
- `.../bridges/meta-instagram/_matrix/provision/v3/login/flows` without a token: HTTP 401,
  `M_MISSING_TOKEN`.
- The bridge logged no `ERR` or `FTL` line after its start. Nobody has logged in to Instagram.

**Memory:** before, 4.0 GiB of 23 GiB used (Synapse 1.8 GiB after a day of caching, Postgres
670 MiB, the WhatsApp bridge 95 MiB). After, 2.3 GiB: the restart emptied Synapse's caches
(138 MiB) and the WhatsApp bridge's (13 MiB). The Instagram bridge itself uses 9 MiB idle.
Load 0.39.

**Backup:** the daily backup takes its list from the playbook's managed databases, so it
includes `matrix_mautrix_meta_instagram` with no new setting. The dump at the backup
container's restart (488 bytes) came before the bridge filled its database; the next daily
dump holds it. After a login, that database holds an Instagram session, so the backup is a
secret, like the WhatsApp bridge's (which holds the WhatsApp link). `/matrix/postgres-backup`
and its `data` folder are `drwx------ matrix:matrix`: only the `matrix` user and root can
read the dumps.

## 2026-10-28: our own copy of the Instagram bridge (T4.1)

Rami's decision ("let's also own our own copy"), relayed by the connectors conversation: the
published bridge's `login android` fails, because Instagram answers its first request
(`POST i.instagram.com/api/v1/qe/sync/`) with HTTP 500. The fix is one commit on Rami's
public fork (proposal: `docs/connectors/instagram.md` on branch `connectors/instagram`).

**Checked before the build (read only):** `rami-maalouf/meta@bce18b56` has upstream
`mautrix/meta@0371efa` (2026-10-28) as its only parent and changes one file,
`pkg/instameow/login_mobile.go` (+14 −31). Its hunks equal
`docs/connectors/patches/mautrix-meta-ig-qe-sync-get.patch`. It asks Instagram for the
password key with a GET instead of a POST, to the same address, and adds no new destination.
The build uses upstream's `Dockerfile.ig` (`golang:1-alpine3.24`, then `alpine:3.24`).

**Waited for the dead login:** the bridge held one login of `@rami` from the morning.
The build waited until Rami removed it (`logout`); at 23:14 UTC it held 0 logins, so the
restart did not try the dead session against Instagram.

`config.yml` sets `matrix_bridge_mautrix_meta_instagram_container_image_self_build: true`,
the fork as `..._self_build_repo`, and `..._version: bce18b56e20616a9347450e24062936ba67ade4b`.
To go back to the published image, delete those three lines and install again.

- Install `./server/playbook.sh --tags=install-all,ensure-matrix-users-created,start`:
  `ok=250 changed=6 failed=0`, 300 s in total. The role cloned the fork into
  `/matrix/mautrix-meta-instagram/container-src` (6.6 MB, at `bce18b56`) and built the image
  on the server in about 2 minutes (checkout done 23:16:09, image made 23:18:15 UTC). Only the
  Instagram bridge restarted; Synapse and the WhatsApp bridge did not.
- Self-check: `ok=36 failed=0`, all 6 checks working.

| Container | Image | Arch |
|---|---|---|
| `matrix-mautrix-meta-instagram` | `localhost/mautrix/meta:ig-bce18b56e20616a9347450e24062936ba67ade4b-arm64` (177 MB) | arm64, built on the server |

**After:** the bridge runs, logs no `ERR` or `FTL` line, and holds 0 logins. WhatsApp runs
with its 1 login and no errors. Memory 2.7 GiB of 23 GiB (2.6 before); the bridge uses 9 MiB.
Load 0.74 just after the build. Disk 34 of 96 GB (33 before): the new image, and Docker's
build cache, now 2.6 GB (2.4 GB of it can be freed, for example with the playbook's system
cleanup; that is a deletion, so it waits for Rami). The old published image
`dock.mau.dev/mautrix/meta:ig-v0.2610.0` stays on disk, unused.

## 2026-10-30: Rami's Instagram login on the fork (T4.1)

Rami linked Instagram with `login android` from `@rami`. Read only, after the login: the
bridge holds 1 login, owned by `@rami:ramimaalouf.com`, and 24 of 24 chats have rooms.
During the login it logged 2 `ERR` lines: `GET qe/sync` answered HTTP 405 (expected: the
password key comes with that answer), and one reconnection state update that it could not
send. No `ERR` line after the login.

## 2026-10-31: debug logs for the main account's login (T4.1)

The main account's try (03:36 UTC) logged 2 `ERR` lines at the `warn` level: the expected
405 on `GET qe/sync`, then HTTP 429 on
`POST api/v1/bloks/async_action/com.bloks.www.caa.ar.submit_code.async/`, 68 s later. So
Meta sent the login to its account recovery ("caa.ar") code step, and refused the code
submit with a rate limit. The `warn` level hides the screen names in between.

`config.yml` sets `matrix_bridge_mautrix_meta_instagram_logging_min_level: debug`. Install:
`ok=250 changed=5 failed=0`. The Instagram and WhatsApp bridges restarted at 05:09:55 UTC;
Synapse did not. WhatsApp: 1 login, no `WRN` or `ERR`. Delete the line after the login.
