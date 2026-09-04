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

## Releasing

Tag `vX.Y.Z` after setting `version-name`. The workflow packs, publishes
the GitHub release and waits for your approval before uploading to
extensions.gnome.org. See [Releasing](releasing.md).

## Docs

Any behaviour change updates the relevant pages and the log. Keep the log
about the knowledge base, not about releases.
