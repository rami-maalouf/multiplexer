# Server

The Matrix server (Synapse) and the bridges run on the Oracle machine (`ssh oracle`).
[matrix-docker-ansible-deploy](https://github.com/spantaleev/matrix-docker-ansible-deploy)
(the playbook) installs them. Ansible runs it from the Mac. Every change on the server
goes through the playbook or a playbook in this folder; manual commands there only read.

| Path | What it is |
|---|---|
| `setup.sh` | Installs Ansible (uv), gets the playbook at its pinned commit and its roles, and writes `vars.yml` from the Keychain. Safe to run again. |
| `playbook.sh` | Runs the playbook's `setup.yml` against our inventory. Takes the usual `ansible-playbook` flags. |
| `register-user.sh` | Registers a Matrix user with a random password that only the Keychain keeps. |
| `inventory/hosts` | The server: `matrix.ramimaalouf.com`, reached through `Host oracle` in `~/.ssh/config`. |
| `inventory/host_vars/matrix.ramimaalouf.com/config.yml` | All settings. In git, no secrets. |
| `inventory/host_vars/matrix.ramimaalouf.com/vars.yml` | The two secrets. Gitignored; `setup.sh` writes it. Its shape: `vars.example.yml`. |
| `vendor/` | The playbook checkout. Gitignored. |
| `notes/` | What we found on the server (`inventory.md`, T0.1). |

## Set up the Mac

```sh
./server/setup.sh
ansible -i server/inventory/hosts all -m ping   # answers "pong"
```

- For a new server only, the first run is `./server/setup.sh --create-secrets`. It makes
  the two secrets in the Keychain. Without the flag, a missing secret stops the script, so
  a server that runs never gets new secrets by mistake.
- Ansible 2.21 cannot ask about an unknown SSH host key. If Ansible says
  `Host key verification failed`, run `ssh oracle` once and accept the key.

## Run the playbook

```sh
./server/playbook.sh --tags=install-all,ensure-matrix-users-created,start   # install or update
./server/playbook.sh --tags=self-check                                      # all green when it works
./server/register-user.sh rami multiplexer-matrix admin                     # a user, password in the Keychain
```

To update the playbook: change `playbook_commit` in `setup.sh`, read the playbook's
`CHANGELOG.md` since the old commit, raise `matrix_playbook_migration_validated_version`
in `config.yml` if it asks, run `./server/setup.sh`, then install.

## Secrets

All in the Mac's login Keychain. Never in git, chat or logs.

| Service | Account | What |
|---|---|---|
| `multiplexer-server` | `matrix_homeserver_generic_secret_key` | The playbook makes most other secrets from it. |
| `multiplexer-server` | `postgres_connection_password` | PostgreSQL's main user. Changing it later needs manual work. |
| `multiplexer-matrix` | `@rami:ramimaalouf.com` | Rami's Matrix password. |
| `multiplexer-test-account` | `@test1:ramimaalouf.com`, `@test2:ramimaalouf.com` | Test users for the app. |

To paste a password on the iPhone (Universal Clipboard):
`security find-generic-password -s multiplexer-matrix -a @rami:ramimaalouf.com -w | pbcopy`.

## Network

- **Names.** User IDs are `@name:ramimaalouf.com`. Synapse runs at `matrix.ramimaalouf.com`.
  This can never change after the first install.
- **DNS** (Cloudflare): `A matrix -> 192.18.154.172`, proxy off ("DNS only"). No `AAAA`:
  the server has no public IPv6. No `element` record: Element Web is off.
- **Delegation.** The website (`~/Documents/code/web/portfolio`, Vercel) serves
  `/.well-known/matrix/server` and `/.well-known/matrix/client` from
  `public/.well-known/matrix/`. They must equal the files that Synapse's side generates
  (`https://matrix.ramimaalouf.com/.well-known/matrix/...`); the self-check compares them.
  `ramimaalouf.com` answers 301 to `www.ramimaalouf.com`. Synapse and matrix-rust-sdk
  (Element X, our app) follow it; a browser client (Element Web, Element Desktop) does not,
  because the 301 has no CORS header. In a browser client, enter `www.ramimaalouf.com` or
  `matrix.ramimaalouf.com` as the server; the user ID stays `@name:ramimaalouf.com`.
- **Registration leaves a session.** `register-user.sh` (the playbook's `register_new_matrix_user`)
  signs the new user in once, so each user starts with one unnamed session that nobody uses.
- **Oracle security list** (the cloud firewall, set by Rami in the console): region
  `ca-toronto-1`, VCN `vcn-20250515-0038` > Security > Default Security List > Security
  rules. Ingress from `0.0.0.0/0`, all stateful: TCP 22, 80, 443 (old, "run n8n publicly"),
  and since 2026-10-27 TCP 8448, UDP 443 and UDP 8448 (Matrix). Also Oracle's default ICMP
  rules. To rebuild on a new VCN, add the same rules.
- **Host firewall:** none is active. `/etc/iptables/rules.v4` has REJECT rules, but
  nothing loads them: `iptables-persistent` was removed on 2025-08-11, so the
  `netfilter-persistent` service has no plugins. The live `INPUT` chain is empty (policy
  ACCEPT). Docker adds only its own `FORWARD` and `nat` rules. So the host needs no change
  for 80, 443 and 8448.
