# `clock until state` takes only `==`; `!=` is refused

**Status:** Open
**Author:** Devin, from an external app friction log
**Systems:** agent drive
**Severity:** P3
**Date:** 2026-11-09

Waiting for a value to become non-empty reads naturally as
`clock until state openRoom != "" within 45000`. The op is refused: only
`== <literal>` parses. Waiting for *absence* of a value needs `clock data` +
`clock +N` and a later `state` read.

Cost: two refused ops across two drives. What would help: `!=` accepted for the
same literal set, or the refusal naming the supported operators.
