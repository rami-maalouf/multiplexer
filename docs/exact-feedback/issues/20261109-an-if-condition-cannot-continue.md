# An `if` condition cannot continue on the next line

**Status:** Open
**Author:** Devin, from an external app friction log
**Systems:** contract grammar
**Severity:** P3
**Date:** 2026-11-09

A guard grew to five `and` clauses. Continuing it on the next line with a
leading `and` produced two errors: `syntax-expected-name` ("`and` is reserved in
Contract ... choose another name") and `syntax-bad-dedent`. The condition had to
stay on one 175-char line.

Cost: two failed builds, a few minutes. What would help: a leading `and`/`or`
continuation accepted, or the grammar doc naming the rule (conditions end at the
newline).
