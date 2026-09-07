# AGENTS.md

Entrypoint for humans and agents working in this repository. Read this before
changing anything. Project-specific detail lives in `docs/`.

## Project

A GNOME Shell extension that provides a quake-style quick terminal backed by
Ghostty on GNOME with Mutter and Wayland. The goal is a working, elegant,
low-footprint and maintainable extension. The design lives in
`docs/design/`, the component breakdown in `docs/architecture/`, and
decisions in `docs/adr/`.
Working notes, drafts and task breakdowns live in `.agents/brain/`, which is
local only and never committed.

## Invariants

- No `sudo` or privilege escalation unless a human explicitly asks for it.
- No AI slop: no em-dashes, no marketing fluff, no filler prose, no comments
  that restate the code. Text reads like a person wrote it.
- Docs move with the change. Any behaviour change updates `docs/` and
  `docs/log.md` in the same change.
- Everything committed is public-ready: no internal codenames, hostnames,
  absolute user paths, tokens or task identifiers.
- Commits are logical units. One concern per commit.
- Parallel work happens in separate worktrees, one per scoped change.
- Automation over manual conformance. If a rule can be enforced by a hook or
  the `check` target, enforce it there rather than by hand.

## Automation and conventions

- `make` is the single automation entrypoint. `make check` is what hooks and
  CI run. `make setup` runs `.agents/bootstrap.sh`, which installs hooks and
  generates git-excluded tool shims.
- Commit messages follow Conventional Commits: summary first, under 50
  characters where practical, 72 as the hard limit, no trailers, no emoji.
  The `commit-msg` hook rejects anything else.
- Stage explicit paths. Never `git add -A`.
- Prefer fixing up or amending the owning commit on an active branch over
  stacking fix commits.
- Branch names carry a conventional prefix: `feat/`, `fix/`, `docs/`,
  `chore/`, `refactor/`.
- State the scope in one sentence before starting: unit of work, target,
  outcome. Anything not needed for that outcome is out of scope.

## Verification

A change is done only when `make check` passes and the relevant tests are
green with real captured output. Do not report completion without it.

## Roles and rules

- `.agents/agents/` holds role cards for subagents (technical writer,
  reviewer).
- `.agents/rules/` holds project rules that extend the global standards.
  Read `.agents/rules/project.md` and `.agents/rules/gnome-extension.md`
  before changing anything under `src/`; the second one is what the
  extensions.gnome.org reviewer will hold the code to.
- A clean reviewer pass (see `.agents/agents/reviewer.md`) gates every push.
  The human holds the final approve-to-push decision.

## Contributing

See `docs/contribution/` for the contributor guide and maintainer notes.
