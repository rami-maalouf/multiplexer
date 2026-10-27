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
