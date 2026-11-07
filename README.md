<p align="center">
  <img src="website/src/img/mux-hero.jpg" width="112" height="112" alt="The Mux logo: a glass paper plane of three folded paths that meet at one nose">
</p>

<h1 align="center">Mux</h1>

<p align="center"><b>All your chats. One inbox you own.</b></p>

<p align="center">
  <a href="https://mux.orbitlabs.studio">Website</a> ·
  <a href="#why-we-built-it">Why</a> ·
  <a href="#how-it-works">How it works</a> ·
  <a href="#how-we-built-it">How we built it</a>
</p>

Mux is an iPhone app that puts WhatsApp, Instagram, LinkedIn and other chat networks in one
inbox. Every message goes through a [Matrix](https://matrix.org) server that you run, not
through a company's cloud. The name is short for multiplexer: several streams combined into
one.

> **Status:** Mux has one user today: its author, on his iPhone, against his own server. A guide to run Mux on your own server comes next. Until then, this repository is
> a record of how it was built, not an installer.

## Why we built it

Mux is a self-hosted, all-in-one messenger. All-in-one inboxes exist, but they are other
companies' products: the company decides what it costs, which features you get, and where
your messages pass. Messages are the most personal data most of us have. We wanted one inbox
for every network without renting it.

- **Your server, your messages.** The bridges and the Matrix server run on a machine you
  control. You can back it up, move it to another host, or turn it off.
- **No plan, no paywall.** No feature waits behind a subscription, and no company can take one
  away. If Mux lacks something, you can build it.
- **An open protocol.** Mux speaks Matrix, an open standard for chat. Any Matrix app, such as
  Element X, can open the same chats from the same server.

## What it does

Mux has the features an all-in-one inbox needs every day, with the feel of Apple's Messages.

- **One inbox:** every chat in one list, with its network's logo on the picture.
- **Filters:** one network, unread chats, people or groups. Communities and message requests
  have their own rows.
- **Organize:** pin, archive, Low Priority, and your own labels. Select many chats at once.
- **Merge chats:** one person on WhatsApp and Instagram becomes one chat, with a tab for each
  network.
- **Send Later:** hold Send and pick a time. The server sends it, even when the phone is off.
- **Remind me:** a reminder to answer a chat, which ends by itself when you reply.
- **Media:** voice notes (record, play at your speed, transcribe), photos, videos, files, and
  GIFs.
- **Search:** every chat at once, or inside one chat. Bookmarks for messages to find again.
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
4. **Mux on your iPhone** talks only to your server, with Matrix. It never talks to a chat
   network. (One exception: GIF search asks [KLIPY](https://klipy.com) directly. KLIPY sees
   the search words and the phone's address, never a chat.)

Inside the app there are two layers:

- **MatrixCore** (`matrix-core/`) is a Swift package around
  [matrix-rust-sdk](https://github.com/matrix-org/matrix-rust-sdk), the engine behind Element X.
  It signs in, syncs, sends and encrypts. It is the only code that touches the SDK, and its API
  uses plain types (strings, numbers, records), so the screens never depend on Matrix details.
- **The app** (`apps/multiplexer/`) is built with [Exact](https://github.com/ccheever/exact2): each
  screen is a Contract file that native iOS controls draw. One native module connects the
  screens to MatrixCore. The same code is meant to run on the Mac next.

## How we built it

The first eleven days of Mux (October 27 to November 6, 2026) took more than 500 commits. Rami built it with a team of AI coding agents. Several agents worked
at once, each in its own git worktree, guided by one shared plan
([`tasks/plan.md`](tasks/plan.md)) and one task list with acceptance criteria
([`tasks/todo.md`](tasks/todo.md)).

A few rules held it together:

- **Prove each step before the next.** A task ended with a passing test or a screenshot of the
  real app, never with "it should work". MatrixCore has 125 tests, most of them against a real
  Matrix server.
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
| Next | Push notifications (built and tested on the Simulator; waiting for the Apple setup). |
| Next | Connect a network from inside the app, instead of a chat with a bridge's bot. |
| Later | The Mac app, and a guided setup so anyone with a server can run their own. |

Mux is also a field test of Exact, a new framework for native apps. Each place where Exact
slowed the work became a written finding for its team, in
[`docs/exact-feedback/`](docs/exact-feedback/README.md). Some became fixes in Exact itself.

## The repository

| Folder | What it is |
|---|---|
| [`apps/multiplexer/`](apps/multiplexer/) | The iOS app, built with Exact. `app.contract` is the view, `app.ts` the data, `modules/apple/` the native module. |
| [`matrix-core/`](matrix-core/) | The Swift package that wraps matrix-rust-sdk, with its own tests. `NOTES.md` explains how it links. |
| [`server/`](server/) | The server's playbook inventory, setup and backup scripts. No secrets: they come from the Keychain. |
| [`scripts/`](scripts/) | Setup, test and helper scripts for the Mac. |
| [`website/`](website/) | The website at mux.orbitlabs.studio: static HTML and a Three.js scene, bundled with Bun. |
| [`docs/`](docs/) | The brand ([`brand.md`](docs/brand.md)) and the Exact findings. |
| [`tasks/`](tasks/) | The plan, the decisions and the task list. Read `plan.md` first. |

The app is still named `multiplexer` in folders, the bundle id
(`com.ramimaalouf.multiplexer`) and storage paths. Only the visible name changed to Mux, so
installs, data and tests keep working.

## Run it yourself

Not yet. A setup guide (a server, a domain, the bridges, and the app) is the next document.
The instructions for agents in [`AGENTS.md`](AGENTS.md) show how the app is built and tested
today, on a Mac with Xcode and [Bun](https://bun.sh).
