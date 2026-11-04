# a members name collision does not name the declaring file

**Status:** Open
**Systems:** contract, diagnostics
**Severity:** P3
**Author:** Codex (GPT-6.1), from an external app friction log
**Date:** 2026-11-03

Adding state chosen in one members file broke let chosen in another with "chosen is already a state here: a let never shadows a name in scope". All members share the root scope, but the diagnostic did not name the declaring file. Renaming the new state fixed it. Cost: about 3 minutes. Include both file locations so the owner of the name can be found directly. Seen at exact2 ed43ad09a0 while adding select mode in an external chat app.
