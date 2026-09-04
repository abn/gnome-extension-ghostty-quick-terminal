---
type: Guide
title: Contributing
description: How to propose, implement and land a change.
status: draft
---

# Contributing

## Setup

Run the bootstrap once after cloning. It installs the git hooks and
generates local tool shims.

```sh
make setup
```

## Workflow

1. State the scope in one sentence: what unit of work, what target, what
   outcome.
2. Create a worktree with a conventional branch name (`feat/`, `fix/`,
   `docs/`, `chore/`, `refactor/`), rebased on the latest `main`.
3. Implement the change together with its tests and docs.
4. Run `make check`. The pre-commit hook runs it too.
5. Commit in logical units with Conventional Commits messages.
6. Get a reviewer pass before pushing.

## Commit messages

Summary line first, under 50 characters where practical, 72 as the hard
limit. No trailers, no emoji. Prefer amending or fixing up the owning commit
over stacking fix commits on an active branch.
