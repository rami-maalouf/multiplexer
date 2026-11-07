# How I run my own chat server (and how you can too)

I built Mux coz I wanted one inbox for all my chats, without handing every message to a company. See, to put WhatsApp or Instagram in one inbox, a bridge has to log in as you and read every message in plain text. That's how bridging works. And when someone else hosts the bridges, that someone can read your chats.

So I set up my own server in October and November 2026: a Matrix server with bridges to WhatsApp, Instagram and LinkedIn. This is exactly what I did, including the parts that went wrong, so you can skip them. My raw notes are in `server/` and `tasks/` in this repo if you want the long version.

At the end you get one inbox for your chats. Read it in Element X, or in Mux on your iPhone: https://appdrop.app/d/nb2nfrv68c

A few placeholders I use all the way through:

- `example.com` is your base domain. Your user ID becomes `@alice:example.com`.
- `matrix.example.com` is the name of your server.
- `alice` is your user name.
- `<server-ip>` is your server's public IPv4 address.

## 1. What you're actually building (and who can read your messages)

```
WhatsApp, Instagram, LinkedIn, Signal  <->  bridges  <->  Synapse  <->  Element X or Mux
                                            (all on your server)
```

- **Synapse** is the Matrix server. It stores your chats.
- **A bridge** (mautrix) logs in to one network as you. It copies each message into a Matrix room, and copies your replies back.
- **The playbook** ([matrix-docker-ansible-deploy](https://github.com/spantaleev/matrix-docker-ansible-deploy)) installs all of it with Docker. Ansible runs it from your Mac over SSH.

Look, the bridges hold your login session for each network, and they read every message in plain text coz they have to convert it. So whoever controls the server can read your chats. With a hosted service, that's the company. With this setup, it's only you.

That's the whole reason to self-host.

Three things follow from it:

- The bridged rooms are not end-to-end encrypted. That's the playbook's default (`matrix_bridges_encryption_enabled: false`), and the bridge reads every message anyway.
- The database backups hold your bridge sessions. Treat every backup as a secret.
- A server breach exposes your chats. Use SSH keys only, run as few services as you can, and install updates.

## 2. What you need

1. **A domain** you control, with access to its DNS records.
2. **A Linux server** that's always on, with a public IPv4 address.
   - I use an Oracle Cloud VM: Ubuntu 24.04, aarch64 (ARM), 4 CPUs, 23 GiB memory, 96 GB disk.
   - Any amd64 VPS works too. The playbook fully supports only amd64 and "somewhat supports" ARM. On ARM, every image I used came prebuilt for arm64, so nothing was built on my server. A component without an arm64 image has to build on the server, or it can't run.
   - Use Ubuntu 24.04 like I did. The playbook docs warn that Ubuntu 26.04 ships `sudo-rs`, which doesn't work with Ansible 2.21 and older.
3. **A Mac** (or any computer) with `uv`, `git` and `ssh`. Ansible runs here, not on the server.
4. **Your phone**, with each network's app, to link it.

**How big a server?** I measured mine over 7 days, one user, three bridges: CPU p95 4%, memory p95 14% of 23 GiB. The Matrix containers used about 1.6 GiB. My notes say 2 CPUs and 12 GB would be enough. The peak is the first history sync of a big WhatsApp account: load 2.35 on 4 CPUs.

**What it costs.** Oracle's Always Free page lists 2 OCPUs and 12 GB of its A1 (ARM) shape as free. Two catches:

- Oracle can reclaim an Always Free instance if, over 7 days, its CPU (p95), network and memory use all stay below 20%. A one-user Matrix server is under all three, so a free instance is at risk. My account is Pay As You Go, where this rule shouldn't apply. I haven't confirmed that.
- I haven't confirmed what a bigger instance costs on Pay As You Go either.

## 3. DNS

1. Add an `A` record: `matrix` -> `<server-ip>`.
2. On Cloudflare, set the record to "DNS only" (proxy off). With the proxy on, the server can't get its certificates.
3. Add an `AAAA` record only if your server has a public IPv6 address. Mine has none, so I have no `AAAA` record.
4. Skip the `element` record. This setup turns Element Web off.

Check it from your Mac:

```sh
dig +short matrix.example.com   # prints <server-ip>
```

**Delegation.** Your user IDs are `@alice:example.com`, but the server runs at `matrix.example.com`. So `example.com` has to serve two small files: `/.well-known/matrix/server` and `/.well-known/matrix/client`. Pick one way:

- **Your base domain already has a website** (my way). After the first install (step 8), copy the two files from `https://matrix.example.com/.well-known/matrix/` to your website. Serve `client` with the header `Access-Control-Allow-Origin: *`. My website is on Vercel: the files live in `public/.well-known/matrix/`, and the headers in `vercel.json`.
- **Your base domain has no website.** Point `example.com` at the server too (an `A` record), and add `matrix_static_files_container_labels_base_domain_enabled: true` to the settings. Then the playbook serves the files itself. The playbook docs call this the easiest way. I didn't use it, so I haven't tested it.

**You can never change the domain after the first install.** The playbook docs say a wrong domain needs a full uninstall. Get it right once.

## 4. Ports and firewall

Open these ports to the internet (ingress from `0.0.0.0/0`):

- TCP 22: SSH, for Ansible
- TCP 80: Let's Encrypt and redirects
- TCP 443 and UDP 443: the Matrix client API
- TCP 8448 and UDP 8448: Matrix federation

**On Oracle Cloud**, the cloud firewall is the VCN's security list:

1. Open the console: your VCN > Security > Default Security List > Security rules.
2. Add stateful ingress rules from `0.0.0.0/0` for the ports above.

**The host firewall.** My notes say Oracle's Ubuntu image ships REJECT rules in `/etc/iptables/rules.v4` that block every port except 22. On my server nothing loads that file (its `iptables-persistent` package was removed earlier), so I changed nothing on the host. On a fresh Oracle image those rules may be active, and I didn't write down how to open them. Check before you install.

Then check each port from your Mac before the first install:

```sh
nc -vz matrix.example.com 80
nc -vz matrix.example.com 443
nc -vz matrix.example.com 8448
```

"Connection refused" is good news: the packet reached the server, and nothing listens yet. A timeout means a firewall drops the packet -> fix the security list or the host firewall.

## 5. Get your Mac ready

**SSH.** Add the server to `~/.ssh/config`, so `ssh matrix-server` works:

```
Host matrix-server
  HostName <server-ip>
  User ubuntu
  IdentityFile ~/.ssh/<your-key>
```

Run `ssh matrix-server` once and accept the host key. Ansible 2.21 can't ask about an unknown host key, it just fails with `Host key verification failed`.

**A folder for your settings.** Keep your settings in a git repo, and keep secrets out of it. This is my layout (it's `server/` in this repo):

```
server/
  setup.sh                       # installs ansible, gets the playbook, writes vars.yml
  playbook.sh                    # runs the playbook with your inventory
  inventory/hosts
  inventory/host_vars/matrix.example.com/config.yml   # settings, in git
  inventory/host_vars/matrix.example.com/vars.yml     # secrets, gitignored
  vendor/                        # the playbook checkout, gitignored
```

Ansible reads every file in `host_vars/matrix.example.com/`, so settings and secrets can live in two separate files.

Copy `server/setup.sh` and `server/playbook.sh` from this repo if you want. In `setup.sh`, change the folder name in `host_vars` and the Keychain service name.

**Ansible.** I use Ansible 14.5.0 (ansible-core 2.21.5), installed with `uv`:

```sh
uv tool install --force --with-executables-from ansible-core "ansible==14.5.0"
```

**The playbook, pinned to one commit.** The playbook has no release tags. Pin a commit, so a change upstream never changes your server by surprise. I pin `e3929968b81c9bc87b56c259930f4c5afbc95a96` (master on 2026-10-27). A full clone stalled for me, so fetch only that commit:

```sh
commit=e3929968b81c9bc87b56c259930f4c5afbc95a96
mkdir -p server/vendor && cd server/vendor
git init -q matrix-docker-ansible-deploy && cd matrix-docker-ansible-deploy
git remote add origin https://github.com/spantaleev/matrix-docker-ansible-deploy.git
git fetch -q --depth 1 origin "$commit" && git checkout -q --detach FETCH_HEAD
ansible-galaxy install -r requirements.yml -p roles/galaxy/ --force
```

A newer commit is fine. Then read the playbook's `CHANGELOG.md` and set `matrix_playbook_migration_validated_version` to match (step 6).

You don't need `just`. Every command below calls `ansible-playbook` directly.

**The inventory.** `server/inventory/hosts`:

```ini
[matrix_servers]
matrix.example.com ansible_host=matrix-server ansible_ssh_user=ubuntu ansible_become=true ansible_become_user=root ansible_python_interpreter=/usr/bin/python3
```

`ansible_host=matrix-server` uses the SSH alias, so the key path stays in `~/.ssh/config`.

**A short command for the playbook.** `server/playbook.sh` runs the playbook from its own folder, so the playbook's `ansible.cfg` applies:

```sh
#!/usr/bin/env bash
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
cd "$here/vendor/matrix-docker-ansible-deploy"
exec ansible-playbook -i "$here/inventory/hosts" setup.yml "$@"
```

Check that Ansible reaches the server:

```sh
ansible -i server/inventory/hosts all -m ping   # answers "pong"
```

## 6. The settings file

Put this in `server/inventory/host_vars/matrix.example.com/config.yml`. It's my own file minus the parts only my server needs. Every comment says why the line is there.

```yaml
# breaking changes of the playbook reviewed up to this version (its CHANGELOG.md).
# the value for the commit pinned above.
matrix_playbook_migration_validated_version: v2026.05.18.0

# user ids are @name:example.com. the server runs at matrix.example.com.
# this can never change after the first install.
matrix_domain: example.com

matrix_homeserver_implementation: synapse

# traefik answers on 80, 443 and 8448 and gets let's encrypt certificates.
# let's encrypt needs no e-mail address.
matrix_playbook_reverse_proxy_type: playbook-managed-traefik

# as the playbook's example recommends, also without a public ipv6 address.
devture_systemd_docker_base_ipv6_enabled: true

# no web client: element x and mux are the clients.
matrix_client_element_enabled: false

# the playbook puts ketesa's (an admin web ui) settings in /.well-known/matrix/client even
# when ketesa is off. this keeps the file to m.homeserver only.
matrix_static_files_file_matrix_client_property_cc_etke_ketesa_enabled: false

# only if example.com redirects (for example to www.example.com): the self-check then
# follows the redirect, as synapse, element x and mux do.
# matrix_static_files_self_check_well_known_matrix_client_follow_redirects: safe

# whatsapp. link it with `login qr` to @whatsappbot:example.com (step 11).
matrix_bridge_mautrix_whatsapp_enabled: true

# double puppeting: what you send from the whatsapp app on your phone shows as sent by
# @alice:example.com, not by a stand-in user of the bridge.
matrix_appservice_double_puppet_enabled: true

# instagram (mautrix-meta). read step 11 before you log in.
matrix_bridge_mautrix_meta_instagram_enabled: true

# linkedin (mautrix-linkedin).
matrix_bridge_mautrix_linkedin_enabled: true

# signal. not tested: i don't run it.
# matrix_bridge_mautrix_signal_enabled: true

# a daily dump of each database (synapse and each bridge), on the server: 7 daily, 2 weekly.
# it does not hold media, and it is on the same disk (step 12).
postgres_backup_enabled: true
postgres_backup_keep_days: 7
postgres_backup_keep_weeks: 2
postgres_backup_keep_months: 0
postgres_backup_environment_variables_additional_variables: |
  BACKUP_ON_START=TRUE

# delayed events (msc4140). mux's "send later" needs them: the message waits on your
# server and goes at its time, with the phone off. i chose a 1-year maximum.
matrix_synapse_delayed_events_enabled: true
matrix_synapse_max_event_delay_duration: 365d

# no network suffix in names: "Alex", not "Alex (WA)". mux shows each network as a logo.
matrix_bridge_mautrix_whatsapp_network_displayname_template: '{% raw %}{{or .BusinessName .PushName .Phone}}{% endraw %}'
matrix_bridge_mautrix_meta_instagram_bridge_displayname_suffix: ''
matrix_bridge_mautrix_linkedin_network_displayname_template: "{% raw %}{{ with .Organization }}{{ . }}{{ else }}{{ .FirstName }} {{ .LastName }}{{ end }}{% endraw %}"
```

**Bridge versions.** My own file also pins two bridges to a commit of their `main` branch, coz no release had the login fixes I needed:

```yaml
# instagram: login fixes mautrix/meta#483 and #484 (2026-10-30). no release had them then.
# matrix_bridge_mautrix_meta_instagram_version: "4a7ebd929a549d8dcb4d6c12cd5a94fde66fc42d"
# linkedin: the password login and its 2fa (2026-11-02). the last release had cookies only.
# matrix_bridge_mautrix_linkedin_version: "6cc6a8981941b0ac1d50e4c65cfb210668f8fe7e-arm64"
```

Check the bridges' releases before you copy these. A newer release may already have the fixes, and then the playbook's default is the better choice. And the LinkedIn tag ends in `-arm64`, so don't copy it to an amd64 server.

## 7. Secrets

The playbook needs two secrets. Make each one random and keep it in your password manager or the Keychain. Never put a secret in git or in a chat.

- `matrix_homeserver_generic_secret_key`: the playbook makes most other secrets from it.
- `postgres_connection_password`: PostgreSQL's main user. Changing it later is manual work.

Make them once, for a new server only. A new secret on a server that already runs breaks it.

```sh
openssl rand -hex 32   # run twice, one value for each name
```

Write `server/inventory/host_vars/matrix.example.com/vars.yml` (gitignored):

```yaml
matrix_homeserver_generic_secret_key: "<64 hex characters>"
postgres_connection_password: "<64 hex characters>"
```

Add `vars.yml` and `vendor/` to `.gitignore`. Run `git status` and make sure no secret file shows up.

My `server/setup.sh` does all this from the macOS Keychain: `./server/setup.sh --create-secrets` on the first run, `./server/setup.sh` after that.

## 8. Install

Heads up: the first install changes the server's Docker setup. My notes caught two changes:

- The playbook's Docker role replaces `/etc/apt/sources.list.d/docker.list` with `docker.sources` (same repository).
- It turns Docker on at boot.

If other services already run on your server, check first that nothing uses ports 80, 443 or 8448.

1. Install and start everything:

   ```sh
   ./server/playbook.sh --tags=install-all,ensure-matrix-users-created,start
   ```

   My first install (Synapse only) took about 25 minutes, mostly the first download of the images. Adding one bridge later took 3 to 4 minutes.

2. If your base domain has a website, copy the two files now (step 3):

   ```sh
   curl https://matrix.example.com/.well-known/matrix/server
   curl https://matrix.example.com/.well-known/matrix/client
   ```

   The files on `example.com` must match these exactly. The self-check compares them.

3. Run the self-check:

   ```sh
   ./server/playbook.sh --tags=self-check
   ```

   Every check has to pass. Mine: `ok=36 failed=0`.

4. Optional: check federation at <https://federationtester.matrix.org/> with your base domain (`example.com`, not `matrix.example.com`).

## 9. Register yourself

The playbook registers users. Registration is off for everyone else.

Don't type the password on the command line: it stays in your shell history. My `server/register-user.sh` writes it to a private file and hands the file to Ansible:

```sh
umask 077
vars_file="$(mktemp)"
printf '{"username": "%s", "password": "%s", "admin": "%s"}\n' alice "<password>" yes > "$vars_file"
./server/playbook.sh --extra-vars "@$vars_file" --tags=register-user
rm -f "$vars_file"
```

One gotcha: registering signs the new user in once and leaves that session sitting there unused, with a live token. Sign it out after your first real sign-in. I did mine in Element Web (Settings > Sessions). My `server/remove-unused-sessions.py` does it from the Mac.

## 10. Connect a client

**Element X** (iOS and Android) works with this server from day one.

1. Install Element X.
2. Set the server to `example.com`.
3. Sign in as `alice` with your password.

A note on verification: once, verifying Element X from another session hung on the phone's "Start verification" spinner. Then it just worked, and I honestly don't know which step fixed it. If it hangs for you, start the verification from the other session, and don't tap Start on the phone.

**Mux** (iPhone).

1. Install Mux from https://appdrop.app/d/nb2nfrv68c.
2. Type `example.com` in the server field.
3. Type `alice` and your password, then sign in.

Mux finds the server through the well-known file, same as Element X. Push notifications aren't ready in Mux yet (they wait on my Apple push setup).

**A browser client** (Element Web) doesn't follow a redirect without a CORS header. If `example.com` redirects (for example to `www.example.com`), type `matrix.example.com` in the browser client instead. Your user ID stays `@alice:example.com`.

## 11. Link your networks

For each network, start a direct chat with the bridge's bot and send it a login command. The bot answers with the next step. Do this from a client where you're signed in as yourself.

The bots live on your base domain: `@whatsappbot:example.com`, not on `matrix.example.com`.

### WhatsApp

1. Send `login qr` to `@whatsappbot:example.com`.
2. On your phone: WhatsApp > Linked devices > Link a device. Scan the code.

The bridge then syncs your history and makes a room for each chat. On my account, 265 of 267 chats had rooms after the sync. The server's load went up for a few minutes while it ran.

If your phone is offline for more than 2 weeks, WhatsApp disconnects linked devices. The bridge warns you in its bot chat first.

### Instagram

Read all of this before you log in. My first try got my main account logged out.

- **Don't use the cookie login on your main account.** I pasted cookies from a private browser window (`login instagram`). Within 5 minutes, Instagram "detected suspicious activity" and logged the account out. It also ended my session in another Instagram client. My best guess at why: the session jumped from my home browser to a data-center address and to the bridge's own client identity within a minute.
- **Use `login android`.** It asks for your user name, your password, and maybe a 2FA code or an approval in the Instagram app. I linked my account with it on 2026-10-30, with a bridge build that had the login fixes (step 6, bridge versions).
- **Turn on 2FA first.** The bridge's docs say 2FA lowers the risk of a block.
- **The bot redacts** any message that holds a password or cookies, so it doesn't sit in your chat.
- After failed tries, Instagram sometimes answers with a rate limit ("temporarily limiting login attempts from this network"). Wait before you try again.

The bot: `@instagrambot:example.com`.

### LinkedIn

The bot `@linkedinbot:example.com` offers two flows: `login password` and `login cookies`.

- **`login password`** asks for your email or phone, your password, then a code or an approval in the LinkedIn app. It needs a bridge build from 2026-10-09 or newer. For me it failed (`LinkedIn native login did not complete`), and the bot offered the cookie step.
- **`login cookies`** is what worked for me:
  1. In a Chrome private window, log in to LinkedIn and open the feed.
  2. In the developer tools, copy a `www.linkedin.com` request from after the login as cURL. It has to hold the `li_at` and `JSESSIONID` cookies.
  3. Close the window. Don't log out.
  4. Paste the cURL in the bot chat and add these headers at the end. LinkedIn's site doesn't send them anymore, but the bridge asks for them and uses its own values:

     ```
     -H 'x-li-track: {"clientVersion":""}' -H 'x-li-page-instance: urn:li:page:x'
     ```

The first sync makes rooms only for your 10 most recent chats (the playbook's default `network.sync.create_limit: 10`).

### Signal

I haven't tested this one, I don't run it. The playbook supports it though:

1. Uncomment `matrix_bridge_mautrix_signal_enabled: true` in `config.yml`.
2. Run the install command from step 8 again.
3. Start a chat with `@signalbot:example.com` and follow the bridge's [authentication docs](https://docs.mau.fi/bridges/go/signal/authentication.html).

The playbook docs say Signal has no message history, so the bridge copies no old messages. Only new ones arrive.

### Names without a network suffix

The three name settings in step 6 strip " (WA)", " (IG)" and " (LinkedIn)" from names. If you add them after you linked a network, names don't change right away:

- WhatsApp: send `!wa sync contacts` to the WhatsApp bot. It doesn't answer, but it renames the contacts it knows in the background. The rest change on their next update.
- Instagram and LinkedIn: each name changes on that contact's next update.

## 12. Backups

The settings in step 6 dump each database every day at 00:00 UTC, into `/matrix/postgres-backup/data/` on the server. Three things to know:

- **The dumps are secrets.** They hold your bridge sessions (the WhatsApp link, the Instagram and LinkedIn sessions). Only the `matrix` user and root can read the folder.
- **They're on the same disk as the server.** They save you from a broken database or a mistake, not from losing the server.
- **They don't hold media** (photos, videos).

For a copy off the server, my Mac pulls the dumps, the media store (`/matrix/synapse/storage/media-store/`) and Synapse's signing key every day over SSH. See `server/pull-backup.sh` and `server/install-backup-pull.sh`. Keep that copy out of git and out of synced folders.

I haven't tested a restore yet. The steps I wrote down are in `server/README.md`, under Backups.

## 13. Update the playbook

1. Pick a newer playbook commit.
2. Read the playbook's `CHANGELOG.md` from your old commit to the new one.
3. If it asks, raise `matrix_playbook_migration_validated_version` in `config.yml`.
4. Fetch the new commit and its roles (step 5).
5. Run the install command from step 8, then the self-check.

Each install restarts the services that changed. On my server a bridge restart took 5 to 15 seconds, and the WhatsApp link survived every one.

## 14. When things break

Every one of these happened on my server:

- **Ansible says `Host key verification failed`.** Run `ssh matrix-server` once and accept the key.
- **Let's Encrypt fails.** Cloudflare's proxy is on. Set the record to "DNS only".
- **The self-check fails on `/.well-known/matrix/client`.** The files on `example.com` differ from the server's, or `example.com` redirects. Copy the files again, or set `..._follow_redirects: safe` (step 6).
- **A browser client says the server "does not appear to be a valid Matrix homeserver".** `example.com` redirects without a CORS header. Type `matrix.example.com` in the browser client.
- **Something you edited by hand on the server is gone after an install.** The playbook rewrites its files on every run, Traefik's `provider.yml` for example. Put every change in `config.yml`.
- **You want a bridge's log.** Run `sudo journalctl -u matrix-mautrix-whatsapp` on the server (`docker logs` shows nothing). The log holds phone numbers and chat IDs, so don't paste it anywhere.
- **Disk space runs low.** It's Docker images and build cache. The playbook's `run-docker-prune` tag runs `docker system prune -a -f`, which also deletes other projects' stopped containers and images on the same server. I deleted old images by hand instead.
- **A bridge needs a fix that isn't in a release yet.** Pin its version to a commit of its `main` branch (step 6). Use a tag with a prebuilt image for your CPU, so nothing builds on the server.

The playbook's own docs live in `docs/` of the playbook checkout. Start at `docs/maintenance-and-troubleshooting.md`.

Your chats are yours. Now the server is too :)
