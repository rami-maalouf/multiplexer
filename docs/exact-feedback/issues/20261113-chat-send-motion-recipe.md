# the chat recipe omits the template send handoff

**Status:** Open
**Systems:** docs, chat template
**Severity:** P3
**Author:** Codex (GPT-6 Astra), from an app outside Exact
**Date:** 2026-11-13

## What happens

The chat-thread recipe documents send then scrollIntoView. Reusing the template composer-to-bubble flight required reading its frame loop, bubble geometry and transient phases. The template predicts IDs from a synchronous fake conversation; a network-backed timeline needs its enqueue identity instead.

About twenty minutes of source reading.

## What would help

Document the motion phases and which geometry is sampled, including how an asynchronous local echo hands off to the real row and how to cancel on navigation.

## Evidence

Observed with Exact `6f4917bda` and exact-templates `041917c`. Kept local; not submitted upstream.

## velocity investigation, 2026-11-13

Matching spring parameters and the final landing did not establish matching motion. In a keyboard-toolbar adaptation, a cap below the actual resting bubble made the rise target move by about 24 points during the flight. The row suffix included receipt space and padding. Receipt height transitions also repeatedly restarted animated end-follow.

Temporary native frame probes and recordings isolated the interaction in about thirty minutes. Accounting for the full suffix and settling the receipt spaces before the flight left less than one point of late correction in short and multiline sends. This is an app geometry correction, not a demonstrated framework defect. Documenting the template's stable destination invariant, and exposing target/presentation traces without temporary native code, would reduce this cost. Exact `6f4917bda`; template `041917c`.
