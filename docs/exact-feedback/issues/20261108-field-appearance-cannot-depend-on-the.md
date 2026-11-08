# Field appearance cannot depend on the platform

**Status:** Open
**Systems:** compiler, fields
**Severity:** P3
**Author:** Codex, from an external app friction log
**Date:** 2026-11-08

A shared field needs the native appearance on one platform and `appearance="none"`
on another. `appearance=(desktop ? "none" : "auto")` is refused because this
attribute requires a literal. A conditional branch must duplicate the textarea,
including its state bindings, event handlers and accessibility name. `outline`
accepts only `none`, so a rounded focus indicator must be drawn by its parent.

Seen at Exact `afac7b1370` while adapting a phone composer to macOS. Cost: about
3 minutes checking compiler diagnostics and duplicating the field declaration.
A platform-dependent appearance, or a documented shared-field pattern, would
avoid the duplicate binding surface.
