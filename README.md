<p align="center">
  <img src="website/src/img/mux-hero.jpg" width="112" height="112" alt="The Mux logo: a glass paper plane of three folded paths that meet at one nose">
</p>

<h1 align="center">Mux</h1>

<p align="center"><b>All your chats. One inbox you own.</b></p>

<p align="center">
  <a href="https://mux.orbitlabs.studio">Website</a> ·
  <a href="#get-started">Get started</a> ·
  <a href="#why-we-built-it">Why</a> ·
  <a href="#how-it-works">How it works</a> ·
  <a href="#how-we-built-it">How we built it</a> ·
  <a href="CONTRIBUTING.md">Contribute</a>
</p>

Mux is an iPhone app that puts WhatsApp, Instagram, LinkedIn and your other chat networks in
one inbox. Chats sync through a [Matrix](https://matrix.org) server that you run,
with bridges on that server connecting to each original messaging service. The
name is short for multiplexer: several streams combined into one.

## Get started

1. **Run your server.** [`docs/self-hosting.md`](docs/self-hosting.md) takes you from an empty
   Linux box and a domain to a Matrix server with WhatsApp, Instagram and LinkedIn bridges, and
   it tells you which login traps to skip.
2. **Choose a client.** [Installation and platform status](docs/install.md) covers the
   iPhone preview, experimental Mac app, CLI and other Matrix clients. To build
   an iPhone app for your own server, start with [the iPhone setup guide](docs/iphone-self-hosting.md).
3. **Sign in** with your server's domain, your user name and your password. Your chats are there.

Mux is early software. The iPhone app has development-build push evidence; public
beta availability and push support on re-signed previews are not guaranteed. The
Mac app runs locally but does not yet have a verified notarized public release.

Prefer the browser or Android? Any Matrix client, such as Element Web at
[app.element.io](https://app.element.io) or Element X, opens the same chats from the same server.

## Why we built it

Mux is a self-hosted, all-in-one messenger. All-in-one inboxes exist, but they are other
companies' products: the company decides what it costs, which features you get, and where
your messages pass. Messages are the most personal data most of us have. We wanted one inbox
for every network without renting it.

- **Your server, your messages.** The bridges and the Matrix server run on a machine you
  control. You can back it up, move it to another host, or turn it off.
- **No Mux subscription.** The source is GPL-3.0-only. You pay for your own hosting
  and any services you choose to use; messaging providers still control their APIs.
- **An open protocol.** Mux speaks Matrix, an open standard for chat. Any Matrix app, such as
  Element X, can open the same chats from the same server.

## What it does

Mux has the features an all-in-one inbox needs every day, with the feel of Apple's Messages.

- **One inbox:** every chat in one list, with its network's logo on the picture.
- **Filters:** one network, unread chats, people or groups. Communities and message requests
  have their own rows.
- **Organize:** pin, archive, Low Priority, and your own labels. Swipe a row to archive, mute or
  mark it read. Select many chats at once.
- **Merge chats:** one person on WhatsApp and Instagram becomes one chat, with a tab for each
  network.
- **Send Later:** hold Send and pick a time. In unencrypted rooms on a server with
  delayed events enabled, the server sends it even when the phone is off.
- **Remind me:** a reminder to answer a chat, which ends by itself when you reply.
- **Media:** voice notes (record, play at your speed, transcribe), photos, videos, files, and
  GIFs.
- **Search:** every chat at once, or inside one chat. Bookmarks for messages to find again.
- **Read receipts:** Sent and Seen where receipt evidence is available. Network
  support and sync timing affect what the app can show.
- **Notifications:** a new WhatsApp message lights up a locked iPhone with its sender and its
  text on the tested development build. Packaging, permissions and gateway setup
  determine whether a particular install supports this.
- **The feel of Messages:** bubbles, swipe to reply, reactions with every emoji, liquid glass,
  and dark mode first.

## How it works

```
 Chat networks          Your server                                Your iPhone
 -------------          -----------                                -----------
 WhatsApp   <------->   mautrix bridges (one per network)
 Instagram                     |
 LinkedIn                      v
                        Synapse + PostgreSQL   <---- Matrix ---->  Mux (Exact UI)
                               |                                     |  native module
                        Traefik (TLS)                                v
                                                                   MatrixCore (Swift)
                                                                     |  wraps
                                                                   matrix-rust-sdk
```

1. **Your networks stay where they are.** WhatsApp, Instagram and LinkedIn work today. Each new
   network is one more bridge.
2. **Bridges** from [mautrix](https://github.com/mautrix) log in as you and turn each chat into a
   Matrix room.
3. **Your Matrix server** is [Synapse](https://github.com/element-hq/synapse), with PostgreSQL
   and Traefik. One Ansible playbook,
   [matrix-docker-ansible-deploy](https://github.com/spantaleev/matrix-docker-ansible-deploy),
   installs everything. Every change goes through it, so the whole server can be rebuilt on a
   new machine. The databases are backed up every day, on the server and on a Mac.
4. **Mux** reads and sends chats through your Matrix server. GIF search calls
   [KLIPY](https://klipy.com) directly with search terms and your IP address. iPhone
   notifications use Apple and the push gateway configured for that app build;
   [self-hosted iPhone builds](docs/iphone-self-hosting.md) use your own identity and gateway.

Bridges handle message plaintext, and the sample bridged rooms are unencrypted.
Self-hosting gives you control of that infrastructure; it does not remove the
original networks or their policies. Read [who can access your messages](docs/self-hosting.md#1-what-youre-actually-building-and-who-can-read-your-messages)
before linking accounts.

Inside the app there are two layers:

- **MatrixCore** (`matrix-core/`) is a Swift package around
  [matrix-rust-sdk](https://github.com/matrix-org/matrix-rust-sdk), the engine behind Element X.
  It signs in, syncs, sends and encrypts. It is the only code that touches the SDK, and its API
  uses plain types (strings, numbers, records), so the screens never depend on Matrix details.
- **The app** (`apps/multiplexer/`) is built with [Exact](https://github.com/expo/exact): each
  screen is a Contract file that native iOS controls draw. One native module connects the
  screens to MatrixCore. The same app now also runs through Exact's native Mac host.

## How we built it

The first twelve days of Mux (October 27 to November 7, 2026) took more than 530 commits. Rami built it with a team of AI coding agents. Several agents worked
at once, each in its own git worktree, guided by one shared plan
([`tasks/plan.md`](tasks/plan.md)) and one task list with acceptance criteria
([`tasks/todo.md`](tasks/todo.md)).

A few rules held it together:

- **Prove each step before the next.** A task ended with a passing test or a screenshot of the
  real app, never with "it should work". MatrixCore has both deterministic tests and
  live-server integration tests. Dated records state which checks actually passed.
- **Biggest unknown first.** First the server and one bridge, then one screen, then daily
  reading and sending on a real iPhone, then the inbox's features one by one.
- **Use what exists.** The playbook, the mautrix bridges, Element X and matrix-rust-sdk came
  before any code of our own.
- **No secrets in git.** Passwords and keys live in the Mac's Keychain. Scripts read them from
  there.

The milestones:

| When | Milestone |
|---|---|
| Day 1 | Our own Matrix server sent its first messages, and the app signed in, listed chats and sent a message on a real iPhone. |
| Day 2 | A WhatsApp message reached the iPhone through our own server and bridge, and a reply went back. |
| Day 5 | The feel of Messages: bubbles with tails, swipe to reply, reactions and a long-press menu. |
| Week 2 | The inbox's features: filters, pins, archive, GIFs, voice notes, Send Later, search, merged chats, labels. |
| Day 12 | The Mux name and icon, a self-host guide for anyone with a server, an install link, and push notifications on a locked iPhone, through our own push gateway. |
| Next | Connect a network from inside the app, instead of a chat with a bridge's bot. |
| November 8-9 | Native Mac app and agent CLI implemented and tested in development; Mac distribution gates remain open. |

Mux is also a field test of Exact, a new framework for native apps. Each place where Exact
slowed the work became a written finding for its team, in
[`docs/exact-feedback/`](docs/exact-feedback/README.md). Some became fixes in Exact itself.

## The repository

| Folder | What it is |
|---|---|
| [`apps/multiplexer/`](apps/multiplexer/) | The iOS and Mac app, built with Exact. `app.contract` is the view, `app.ts` the data, `modules/apple/` the native module. |
| [`cli/`](cli/) | `mx`, the Mac command-line client with JSONL reads and policy-controlled writes. |
| [`matrix-core/`](matrix-core/) | The Swift package that wraps matrix-rust-sdk, with its own tests. `NOTES.md` explains how it links. |
| [`server/`](server/) | The server's playbook inventory, setup and backup scripts. No secrets: they come from the Keychain. |
| [`scripts/`](scripts/) | Setup, test and helper scripts for the Mac. |
| [`website/`](website/) | The website at mux.orbitlabs.studio: static HTML and a Three.js scene, bundled with Bun. |
| [`docs/`](docs/) | The self-host guide ([`self-hosting.md`](docs/self-hosting.md)), the brand ([`brand.md`](docs/brand.md)) and the Exact findings. |
| [`tasks/`](tasks/) | The plan, the decisions and the task list. Read `plan.md` first. |

The app is still named `multiplexer` in folders, the bundle id
(`com.ramimaalouf.multiplexer`) and storage paths. Only the visible name changed to Mux, so
installs, data and tests keep working.

## Build it yourself

Start with [CONTRIBUTING.md](CONTRIBUTING.md) for prerequisites, the Exact integration
requirement, build steps and test accounts. The currently validated native build
uses local Exact patches that are not yet reproducible from a plain public
upstream clone. The [CLI](cli/README.md) and [website](website/README.md) have their
own build paths. [All documentation](docs/README.md) is indexed by audience.

## License

Copyright (C) 2026 Rami Maalouf.

Mux's original code is licensed under the GNU General Public License,
version 3 only (`GPL-3.0-only`). You may redistribute and modify it under those
terms. It is provided without any warranty, including the implied warranties of
merchantability or fitness for a particular purpose. See [LICENSE](LICENSE) for
the full terms.

Third-party code, dependencies and assets retain their own licenses and notices.
For network icon attribution, see [the asset sources](apps/multiplexer/assets/networks/SOURCES.md).
