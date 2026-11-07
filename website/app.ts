import type { Answer, Result, Sources } from './app.contract.d.ts';

// the site's words live here, fixed when the site is built: every page renders at build (render=build).
// keep each claim true to the repo: tasks/plan.md, server/README.md and docs/brand.md are the sources.

// the inbox in the hero's phone. made-up people, so no real chat is ever shown.
const CHATS: Result<'loadChats'> = [
  { id: 'c1', name: 'Maya Chen', initials: 'MC', preview: 'Landing at 6. Dinner after?', time: '9:41', network: 'whatsapp', unread: 2, hue: 'linear-gradient(135deg, #57DED4, #519AFF)' },
  { id: 'c2', name: 'Family', initials: 'F', preview: 'Mom: Photos from Sunday', time: '9:12', network: 'whatsapp', unread: 0, hue: 'linear-gradient(135deg, #F7B267, #F25F5C)' },
  { id: 'c3', name: 'Jonas Weber', initials: 'JW', preview: 'Sent a reel', time: '8:57', network: 'instagram', unread: 1, hue: 'linear-gradient(135deg, #B388FF, #519AFF)' },
  { id: 'c4', name: 'Priya Natarajan', initials: 'PN', preview: 'Happy to chat next week', time: 'Yesterday', network: 'linkedin', unread: 0, hue: 'linear-gradient(135deg, #D4F46A, #57DED4)' },
  { id: 'c5', name: 'Climbing crew', initials: 'CC', preview: 'Leo: Same wall, 7pm?', time: 'Yesterday', network: 'whatsapp', unread: 0, hue: 'linear-gradient(135deg, #519AFF, #3B45FD)' },
  { id: 'c6', name: 'Sam Okafor', initials: 'SO', preview: 'haha that is perfect', time: 'Tue', network: 'instagram', unread: 0, hue: 'linear-gradient(135deg, #FF8FAB, #B388FF)' },
];

const REASONS: Result<'loadReasons'> = [
  {
    id: 'own',
    title: 'Your server, your messages',
    body: 'The bridges and the Matrix server run on a machine you control. You can back it up, move it to another host, or turn it off.',
  },
  {
    id: 'paywall',
    title: 'No plan, no paywall',
    body: 'No feature waits behind a subscription, and no company can take one away. If Mux lacks something, you can build it.',
  },
  {
    id: 'open',
    title: 'An open protocol',
    body: 'Mux speaks Matrix, an open standard for chat. Any Matrix app, such as Element X, can open the same chats from the same server.',
  },
];

const FEATURES: Result<'loadFeatures'> = [
  { id: 'inbox', title: 'One inbox', body: 'Every chat in one list, with its network’s logo on the picture. Unread counts, previews and “Seen”, as you expect.' },
  { id: 'filters', title: 'Filters', body: 'Show one network, only unread chats, only people or only groups. Communities and message requests have their own rows.' },
  { id: 'organize', title: 'Pin, archive, label', body: 'Pin the people who matter. Move the rest to Archive or Low Priority, or group chats under your own labels.' },
  { id: 'merge', title: 'Merge chats', body: 'One person on WhatsApp and Instagram becomes one chat. Switch networks with a tap, without losing a feature.' },
  { id: 'later', title: 'Send Later', body: 'Hold Send and pick a time. Your server sends the message, even when your phone is off.' },
  { id: 'remind', title: 'Remind me', body: 'Set a reminder to answer a chat. It ends by itself when you reply, from any of your devices.' },
  { id: 'media', title: 'Voice, photos, GIFs', body: 'Record voice notes, and play them at the speed you choose. Send photos, videos, files and GIFs, with a caption.' },
  { id: 'search', title: 'Search everything', body: 'Search every chat at once, or search inside one chat. Save messages as bookmarks to find them again.' },
  { id: 'feel', title: 'Feels like Messages', body: 'Bubbles, swipe to reply, reactions with every emoji, and liquid glass on iOS. Designed for dark mode first.' },
];

const STEPS: Result<'loadSteps'> = [
  { id: 's1', step: '1', title: 'Your networks', body: 'WhatsApp, Instagram and LinkedIn today. Each new network is one more bridge.' },
  { id: 's2', step: '2', title: 'Bridges', body: 'Open-source mautrix bridges log in as you and turn each chat into a Matrix room.' },
  { id: 's3', step: '3', title: 'Your Matrix server', body: 'Synapse, on a small server you rent or own. Backed up every day.' },
  { id: 's4', step: '4', title: 'Mux on your iPhone', body: 'A native app that talks only to your server, never to a chat network.' },
];

const LAYERS: Result<'loadLayers'> = [
  {
    id: 'server',
    label: 'The server',
    title: 'Synapse and the bridges',
    body: 'Synapse and PostgreSQL hold the chats. A mautrix bridge for each network connects them, and Traefik serves it all over TLS. One Ansible playbook installs everything, and every change goes through it, so the whole server can be rebuilt on a new machine.',
    detail: 'matrix-docker-ansible-deploy · mautrix · ARM server',
  },
  {
    id: 'core',
    label: 'The core',
    title: 'MatrixCore',
    body: 'A Swift package around matrix-rust-sdk, the engine behind Element X. It signs in, syncs, sends and encrypts. It is the only code that touches the SDK, and its API uses plain types, so the screens never depend on Matrix details.',
    detail: 'matrix-rust-sdk · Swift · 125 tests',
  },
  {
    id: 'app',
    label: 'The app',
    title: 'Built with Exact',
    body: 'Each screen is a Contract file that native iOS controls draw: real lists, real menus, real liquid glass. One native module connects the screens to MatrixCore. The same code is meant to run on the Mac next.',
    detail: 'Exact · Swift · iOS 17 and later',
  },
];

const STATS: Result<'loadStats'> = [
  { id: 'days', value: '11', label: 'days of building, October 27 to November 6, 2026' },
  { id: 'commits', value: '500+', label: 'commits in those 11 days' },
  { id: 'tests', value: '125', label: 'tests for MatrixCore, most against a real server' },
  { id: 'notes', value: '179', label: 'places where Exact was hard, written down for its team' },
];

const MILESTONES: Result<'loadMilestones'> = [
  { id: 'day1', when: 'Day 1', title: 'A first screen, on a real iPhone', body: 'Our own Matrix server sent its first messages, and the app signed in, listed chats and sent a message on a real iPhone.', done: true },
  { id: 'day2', when: 'Day 2', title: 'WhatsApp through our server', body: 'A WhatsApp message reached the iPhone through our own server and bridge, and a reply went back to WhatsApp.', done: true },
  { id: 'day5', when: 'Day 5', title: 'The feel of Messages', body: 'Bubbles with tails, swipe to reply, reactions and a long-press menu.', done: true },
  { id: 'week2', when: 'Week 2', title: 'Beeper’s features', body: 'Filters, pins, archive, GIFs, voice notes, Send Later, search, merged chats, labels and more.', done: true },
  { id: 'push', when: 'Next', title: 'Push notifications', body: 'Built and tested on the Simulator. It waits for the Apple setup to reach a locked iPhone.', done: false },
  { id: 'connect', when: 'Next', title: 'Connect from the app', body: 'Add a network from inside Mux, with a QR code or a sign-in, instead of a chat with a bot.', done: false },
  { id: 'mac', when: 'Later', title: 'The Mac, then you', body: 'Mux on the Mac, and a guided setup so anyone with a server can run their own.', done: false },
];

const sources: Sources = {
  loadChats: async () => CHATS,
  loadReasons: async () => REASONS,
  loadFeatures: async () => FEATURES,
  loadSteps: async () => STEPS,
  loadLayers: async () => LAYERS,
  loadStats: async () => STATS,
  loadMilestones: async () => MILESTONES,
};
export const answer: Answer = (source, args, store, storage, native) => sources[source](args, store, storage, native);

// no api: the site reaches nothing.
export const grants = "";
