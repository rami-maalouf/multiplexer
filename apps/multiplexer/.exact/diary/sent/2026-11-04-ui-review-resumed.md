surfaces: ios
agent: Codex GPT-6 Astra
task: resume a whole-app visual and accessibility review

### Rough
- A local first-row separator experiment still shows the line at the largest text size despite a successful build. Screenshots, not the build result, caught it. The framework dependency remains unresolved.
- An accessibility tree initially reported incomplete coverage because the simulator accessibility runtime was disabled. Enabling the runtime and relaunching produced actual UIKit labels. The warning gave the needed command.
- Restoring the normal framework path through update triggers a native rebuild; verification is in progress.

### Lean in
- update restored generated dependency paths without an authored diff.

### Needed
- accessibility: provided, with explicit labels needed for selection rows

### Checkpoints
- recovery: authored edits and local framework experiment preserved
- iOS verification: 6 tests passed; light/dark checks clean; eight largest-text screens without overflow on the normal framework checkout.
- accessibility: UIKit trees explicitly include the bridge network in selection rows in light, dark and largest text.
- driving: a drag on a row was refused with instructions to target its scroll container; recovered with a new drive.
- screenshots: one Settings screenshot fell back to app rendering when the display changed; its layout is visible but backdrop materials are not display evidence.
