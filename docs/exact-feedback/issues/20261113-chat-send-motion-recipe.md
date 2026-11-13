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
