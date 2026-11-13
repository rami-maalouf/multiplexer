# a framework symlink fails build source identity capture

**Status:** Open
**Systems:** build scripts, source identities
**Severity:** P3
**Author:** Codex (GPT-6 Astra), from an app outside Exact
**Date:** 2026-11-13

## What happens

A fresh app worktree using a framework symlink compiled Rust, then failed with `compiler input has no captured source identity: .../packages/child-process/exact.json`. An absolute EXACT2 environment override alone still failed because generated Cargo paths retained the alias.

About five minutes plus rebuilding.

## What would help

Canonicalize framework paths consistently or name the required update command in the error. Running `exact update` with the canonical EXACT2 path regenerated the local paths and passed that step.

## Evidence

Observed with Exact `6f4917bda` and exact-templates `041917c`. Kept local; not submitted upstream.

## More evidence (2026-11-13, second task)

The same failure came back in the same worktree. After `exact update` with the canonical path,
the next build failed with two `mismatched types` errors between two copies of one framework crate
(`exact_markdown`): an unhashed `libexact_markdown_editor.rlib` built through the symlink path
stayed in the target folder. Deleting that rlib and its two fingerprints fixed it. About fifteen
minutes. Cleaning stale framework crates when `update` changes the framework path would avoid it.
