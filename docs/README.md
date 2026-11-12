# Mux documentation

Current entry points, reviewed against repository source on 2026-11-10:

- [Install and platform status](install.md): iPhone preview, experimental Mac app,
  CLI and notification requirements.
- [Self-hosting](self-hosting.md): one-user Matrix server and bridge setup, with
  the maintainer's tested configuration and explicit limits.
- [Build your own iPhone app](iphone-self-hosting.md): your Apple identity,
  push gateway, profiles and installation commands.
- [Contributing](../CONTRIBUTING.md): native prerequisites, Exact integration,
  build commands and test-account setup.
- [CLI](../cli/README.md): `mx`, JSONL output, guarded writes and known limits.
- [MatrixCore](../matrix-core/NOTES.md): SDK linking, storage and protocol behavior.
- [Mac distribution](mac-distribution.md): signing and notarization gates; a public
  notarized release has not been established.
- [Brand](brand.md): Mux name, artwork and stable technical identifiers.
- [License](../LICENSE): GPL v3; third-party notices remain applicable.

## Development records

[The plan](../tasks/plan.md) and [task list](../tasks/todo.md) contain current
status followed by dated development history. Older entries describe what was
known then; they are not current installation instructions.

`releases/`, `reviews/`, `plans/`, `tasks/evidence/`, `server/notes/` and the
[Exact feedback archive](exact-feedback/README.md) retain evidence and decisions
from individual work sessions. A successful archive upload is not a public beta
invitation, and a test result applies only to the platform and state it names.
Local paths in these records may refer to private captures or temporary files
that are intentionally absent from this public repository.
