# mx: the command line for agents

`mx` reads the Matrix account and acts on it from the Mac, so an agent can use it. It links
the same `MatrixCore` as the iPhone app (`Sources/MatrixCore` is a link to
`../matrix-core/Sources/MatrixCore`), so the CLI and the app share one copy of the chat
logic. Only MatrixCore calls the SDK.

## Build

```sh
./scripts/setup-cli-sdk.sh        # once per sdk version: builds the sdk for macOS (about 5 min)
cd cli && swift build -c release  # then cli/.build/release/mx
```

Element publishes the SDK for iOS only, so `setup-cli-sdk.sh` builds it from source, from the
commit of the app's release (Rust through rustup, toolchain `stable`). The build goes into
`vendor/` and `cli/.sdk/`; neither is in git. An edit in `matrix-core/` needs only
`swift build` again (no copy step, unlike the app).

## Use

```sh
security find-generic-password -s multiplexer-test-account -a @test1:ramimaalouf.com -w \
  | mx login @test1:ramimaalouf.com --password-stdin
mx whoami
mx chats --json --limit 20
mx logout
```

- The password comes only on stdin: never in argv or in the chat.
- `mx` is its own device ("Mux CLI"). The session is in the Keychain (service
  `com.ramimaalouf.multiplexer.cli.session`), the store in
  `~/Library/Application Support/com.ramimaalouf.multiplexer.cli/`. It never touches the app's.
- Hold the `matrixcore` lock for runs as a test user (`scripts/mx-lock.sh matrixcore <lane> -- ...`).
- The test-account rules of `AGENTS.md` apply: on `@rami`, read only, and sign out at the end.

The plan is in `tasks/todo.md`, "Agent CLI".
