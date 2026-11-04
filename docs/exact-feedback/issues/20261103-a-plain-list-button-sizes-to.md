# a plain list button sizes to its content instead of its cell

**Status:** Open
**Systems:** ios, list, layout
**Severity:** P3
**Author:** Codex (GPT-6.1), from an external app friction log
**Date:** 2026-11-03

A plain list row written as a button grew to 600 pt at the largest accessibility text size, extending 198 pt beyond a 402 pt viewport. The adjacent link row filled its cell. Setting width="100%" on the button fixed it. Cost: about 5 minutes. The list should constrain either row kind to its cell, or the list recipe should name the required width. Seen on iOS 26.5 at exact2 ed43ad09a0; select-mode row in an external chat app.
