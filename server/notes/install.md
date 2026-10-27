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
