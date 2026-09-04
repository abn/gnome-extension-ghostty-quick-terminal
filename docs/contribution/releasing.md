---
type: Guide
title: Releasing
description: How a tagged release is checked, packed, published on GitHub and uploaded to extensions.gnome.org.
status: draft
---

# Releasing

Releases are driven by tags. Pushing `vX.Y.Z` runs the release workflow,
which checks, packs, publishes a GitHub release and, after a human
approves, uploads the package to extensions.gnome.org with the
`gnome-extensions upload` command that ships with GNOME Shell 49 and later.

## Before tagging

1. Set `version-name` in `src/metadata.json` to `X.Y.Z`. The tag must be
   `vX.Y.Z`; `make release/check TAG=vX.Y.Z` verifies the match.
2. Never add a `version` field. extensions.gnome.org assigns it, and a
   shipped value makes GNOME Shell upgrade or downgrade the extension on its
   own. `make check` refuses a metadata file that carries one.
3. Keep `shell-version` to stable releases plus at most one development
   release.
4. Run `make check` and `make test/headless` locally. The headless harness
   needs a GPU render node, so it does not run in CI.

## Tagging

```sh
git tag -a v0.1.0 -m 'v0.1.0'
git push origin v0.1.0
```

## What the workflow does

- Job `pack`: installs the toolchain in a Fedora 44 container (GNOME Shell
  50), runs `make check`, verifies the tag, packs the extension, keeps the
  zip as a workflow artifact and creates a GitHub release with it.
- Job `publish`: waits for approval on the `extensions.gnome.org`
  environment, then uploads the zip with the account in the environment
  secrets.

## One-time repository setup

1. Create the `extensions.gnome.org` environment under Settings, then
   Environments, and add yourself as a required reviewer. Every upload then
   pauses for a manual approval.
2. Add `EGO_USERNAME` and `EGO_PASSWORD` as secrets on that environment.
   Use a dedicated account if you can; the password is used as is by the
   upload command.
3. Point `url` in `src/metadata.json` at the repository so reviewers and
   users can find it.

## After uploading

Every version goes through manual review on extensions.gnome.org before it
is listed. Watch the review page for feedback. Two things in this extension
deserve an explanation to reviewers when asked:

- The extension spawns a Ghostty process as a Wayland client. It is an
  ordinary user process, not privileged, and it is ended on disable.
- Across a screen lock the Ghostty client is kept in module scope so a
  running terminal survives the lock. The guidelines want dynamic state
  freed on disable; if a reviewer objects, the fallback is to drop the
  client on every disable and re-adopt the window by its application id on
  the next enable.
