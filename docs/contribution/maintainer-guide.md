---
type: Guide
title: Maintainer guide
description: Review, verification and release duties for maintainers.
status: draft
---

# Maintainer guide

## Reviewing

Review as a skeptical maintainer: scope, correctness, minimality,
invariants, regression risk, test and doc coverage. Reject opportunistic
changes and ask for a separate change instead.

## Verifying

A change is done only when `make check` passes with real captured output.
Read the output, do not trust the claim.

## Docs

Any behaviour change updates the relevant pages and the log. Keep the log
about the knowledge base, not about releases.
