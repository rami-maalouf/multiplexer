surfaces: ios
agent: Codex, GPT-6.1 Sol
task: check prerequisites for remote notifications

### Rough

- device builds repeated the known native-module roster diagnostic: a target-only swift package had no mac catalyst, simulator or macos slice. development builds continued with the manifest roster, but understanding that distinction and the signing/profile selection needed framework source reads. about three minutes spent on lookup. the diagnostic should distinguish the development fallback from a terminal failure, and the documented profile/identity overrides should cover the supported path (existing finding 126). unrelated signing and cache-removal costs are tracked outside this diary.
- native cleanup could open a title popover by its authored test id, but could not select an action by its authored test id (`selector did not match`). the same action appeared in native accessibility as a cell labelled settings. about two minutes to inspect the native tree and switch to its visible label. a note about which test ids native menus expose would remove this cost; the framework's own model drive is not evidence of native identifier coverage.

### Lean in

- existing notification preparation separated credential setup from the extension and core implementation.
- the notification permission source presented the native system prompt, and the existing extension build pattern worked on both a simulator and a physical device.

### Needed

- notifications (permission): provided.
- remote notifications and extension: by hand (existing registration callbacks and post-build packaging; delivered plain and encrypted content with the app closed).
- remote notification activation and foreground presentation: missing (the host accepts only its own activation envelope and offers no app-defined remote callback).

### Checkpoints

- feedback status: sent; receipt 5e7c150f-68ad-4741-8bfb-7b211e342146.
- ios device build: rough, known roster diagnostic; signed development app and extension installed.
- ios simulator build: smooth; extension installed and registered.
- native drive: rough for popover identifiers; test account signed out after testing.
- end-to-end delivery: plain and encrypted banners with sender and text; extension peak 17 to 19 mb. physical locked-device fallback banner confirmed by the person. natural whatsapp sender and text on the locked phone also confirmed by the person (m3).
- settings notifications: once granted it only showed "On"; replaced with a messaging-app switch (`messageNotifications` persist) that registers or clears the matrix pusher; Open Settings only when the system permission is denied. reinstalled on the phone.
