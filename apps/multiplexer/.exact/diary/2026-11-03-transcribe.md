surfaces: ios
agent: Claude Opus 5.5
task: in a chat app, transcribe a received voice message on the device (from its long-press menu), show the text under it, and keep it across launches

### Rough
- A list of records with `persist` was refused: "`transcripts` is a list of records (`VoiceTranscript`), which is app data: keep app data in a source … `persist` keeps a small setting". Clear; the fix was a load and a save source over a JSON file. About 5 minutes.
- In a drive, the `startSpeechRecognition` mutation never answered: no error, the transcript stayed "Transcribing…". `state pending` showed it waited on `{"capability":"permission","args":{"capability":"speech-recognition"…}}`; the drive needs `--permission speech-recognition=granted`. The package's notes say its on-device engine needs no authorization on iOS 26. About 10 minutes. What would have helped: the drive printing a request held by a permission (as it prints a timer due), naming the `--permission` flag.
- `storage.fs.mkdir('app:/data')` was refused "denied: fs.write" under a grant for the file `app:/data/transcripts.json`; writing the file needs no mkdir. My grant was the mistake; the message was clear.

### Lean in
- `@exact/speech-recognition` transcribes an `app:/` file on the device with `startSpeechRecognition(path=…, processLocally=true)` and a polling `speechRecognitionState` resource: no native code. On this Mac the same Apple engine read a WhatsApp-style Ogg Opus clip and gave its words.

### Needed
- on-device speech to text of a file: provided (`@exact/speech-recognition`)

### Checkpoints
- Drives as a test user: a held voice message offers Transcribe; the result (under a drive, the package hears nothing) shows "No speech in this voice message." under it, kept across launches; `check both` clean on the menu.
- On this Mac, Apple's `SpeechTranscriber` transcribed a spoken Ogg Opus clip correctly (the engine the package uses on iOS 26).
- `verify ios`: clean (5 tests). `bun test`: 7 passed.
