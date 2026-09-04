---
type: Decision
title: Documentation as an OKF bundle
description: Keep the wiki as an Open Knowledge Format v0.2 bundle from day one.
status: accepted
---

# Documentation as an OKF bundle

## Context

The wiki must stay public-ready and usable by both people and agents. A
plain pile of markdown drifts quickly: pages lose metadata, links break,
and private detail slips in.

## Decision

Keep `docs/` as an Open Knowledge Format v0.2 bundle. The root index
declares the version, concept pages carry typed frontmatter, section indexes
are navigation only, and the log records how the knowledge base evolves.
The `docs/check` target enforces the structure and privacy hygiene.

## Consequences

- Every behaviour change touches `docs/` and the log in the same change.
- Frontmatter is mandatory on concept pages, so adding a page costs a few
  extra lines.
- Software release notes stay out of the log.
