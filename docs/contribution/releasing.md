---
type: Guide
title: Releasing
description: How Release Please cuts a release from conventional commits, and how the package reaches GitHub and extensions.gnome.org.
status: draft
---

# Releasing

Releases are cut by Release Please from the commit history. Nobody edits a
version or writes a changelog by hand.

## The flow

1. Commits on `main` follow Conventional Commits; the commit-msg hook
   enforces it. `feat` and `fix` commits appear in the changelog and drive
   the version, `feat` bumping the minor and `fix` the patch while the
   project is below 1.0.
2. On every push to `main`, Release Please opens or updates a pull request
   titled `chore(main): release X.Y.Z`. It bumps `version-name` in
   `src/metadata.json`, updates `CHANGELOG.md` and the manifest.
3. Merging that pull request creates the tag `vX.Y.Z` and the GitHub
   release with generated notes.
4. The same workflow run then calls the release workflow: it checks out
   the tag, runs `make check`, verifies the tag against `version-name`,
   packs the extension, attaches the zip to the GitHub release, and waits
   for approval on the `extensions.gnome.org` environment before uploading
   with the `gnome-extensions upload` command that ships with GNOME Shell
   49 and later.

Calling the release workflow from the Release Please run is deliberate. A
tag created with the workflow token does not trigger other workflows, so
the alternative would be a personal access token in the repository.

## Files Release Please owns

- `.release-please-manifest.json`: the last released version. It starts at
  `0.0.0` so the first release is `0.1.0`, the `version-name` the metadata
  already carries.
- `release-please-config.json`: the strategy and the extra file to bump,
  which is `version-name` in `src/metadata.json`.
- `CHANGELOG.md` and `version.txt`: written by the release pull request.

Never add a `version` field to `src/metadata.json`. extensions.gnome.org
assigns it, and a shipped value makes GNOME Shell upgrade or downgrade the
extension on its own. `make check` refuses a metadata file that carries one.

## Before merging a release pull request

- `make check` and `make test/headless` pass locally on `main`. The
  headless harness needs a GPU render node, so it does not run in CI.
- `shell-version` lists stable releases plus at most one development
  release.

## One-time repository setup

1. Create the `extensions.gnome.org` environment under Settings, then
   Environments, and add yourself as a required reviewer. Every upload then
   pauses for a manual approval.
2. Add `EGO_USERNAME` and `EGO_PASSWORD` as secrets on that environment.
   Use a dedicated account if you can; the password is used as is by the
   upload command.
3. Allow GitHub Actions to create pull requests, under Settings, Actions,
   General, Workflow permissions. Release Please needs it.

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
