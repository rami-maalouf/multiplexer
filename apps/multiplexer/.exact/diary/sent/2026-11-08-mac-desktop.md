surfaces: macos
agent: codex gpt-6.1-sol
task: implement native desktop input, layout and live notification behavior

### Rough

- keyboard and shortcut vocabulary did not resolve by ordinary topic names; the keyboard-and-focus recipe only covers input submit, while textarea key handling was found in compiler diagnostics. About 4 minutes searching docs/source. KeyEvent vocabulary supplies isComposing; an Enter-to-send composer example would help. Existing docs feedback applies.

- text-field appearance must be a literal and outline only admits none, so a conditional platform field style needed two field declarations with the same state/actions; the parent glass supplies a rounded focus border on desktop. About 3 minutes adapting the compiler refusal. A conditional native appearance would avoid the duplicated declaration.

- a small lifecycle observer edit recompiles the generated SDK bindings. The host packages finish quickly, followed by minutes in the binding compiler on a busy machine. Existing finding 1 applies.

### Lean in

- keycapture, keyboard event modifiers, and native file-drop events already exist.
- keepRunning is a manifest setting on the existing Mac window host.

### Needed

- desktop keyboard: provided, app bindings needed
- file drops: provided, app staging needed
- local notifications: provided, app live-message policy needed

### Checkpoints

- baseline drive reproduced Enter inserting a newline; keyboard drive now shows Enter clearing the composer after Send, Shift+Enter retaining a newline, and both conversation shortcuts opening search.
- actual file drop staged a text file in the composer, then the file and caption appeared in the test conversation after Send.
- native Mac authored tests pass. Pure TypeScript tests pass 38/38. Native core tests pass 27/27 without a Simulator.
- light/dark 900x700 and narrow 700x600 screenshots inspected. Phone-only offsets are disabled on Mac; the desktop header and bottom controls stay in flow.
- independent review found notification delivery cancellation, missing merged-network controls, and mixed mute behavior. All have local fixes and targeted checks.
- hidden-window drive received a new message and recorded one delivered local notification plus the unread badge. Notification click opened its room signed in; the same entry opened no room signed out. No actual system banner or distribution claim.
- final chooser icons and close control are visible in both appearances; a desktop merged-network selector changes the open room. Test account signed out, badge cleared.

- normal macOS bundle rebuilt and relaunched; actual native inbox window inspected read-only.
