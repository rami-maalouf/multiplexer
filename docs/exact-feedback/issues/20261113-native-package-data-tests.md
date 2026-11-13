# Data entry tests need native package mocks

**Status:** Open
**Systems:** typescript, native packages, tests
**Severity:** P3
**Author:** Codex (GPT-6 Astra), from an app outside Exact
**Date:** 2026-11-13

## What happens

Importing the data entry point under Bun resolves native package exports to `exact.json` manifests rather than callable JavaScript modules. A pure optimistic-overlay test cannot import the production function until those native packages are mocked. About two minutes to identify the boundary and add mocks.

## What would help

Document a data-source test harness or a supported way to provide native package doubles without testing through a signed-in UI session.

## Evidence

Observed with Exact `6f4917bda`. Four production-overlay tests pass after mocking the native package boundary. The framework checkout no longer contains the previously documented issue generator or issue checker; this generic finding was recorded manually and kept local.
