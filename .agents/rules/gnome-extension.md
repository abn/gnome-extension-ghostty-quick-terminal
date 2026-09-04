# GNOME Shell extension rules

Distilled from the extensions.gnome.org review guidelines and the
accompanying best-practices page, as read on 2026-09-05. These are the rules
a reviewer there applies; a change that breaks one will be rejected at
submission. Sources:

- https://gjs.guide/extensions/review-guidelines/review-guidelines.html
- https://gjs.guide/extensions/review-guidelines/best-practices.html

## Lifecycle

- Do nothing at import time or in the constructor: no objects, no signal
  connections, no main-loop sources, no changes to the shell. Static data
  such as constants, regular expressions and maps is fine. Helpers like
  `Gio._promisify` run at first use, not at module load.
- `enable()` creates; `disable()` undoes all of it: destroy every object,
  disconnect every signal, remove every main-loop source even if its
  callback would have returned `SOURCE_REMOVE`, cancel every cancellable,
  remove every transition, unexport every D-Bus object, remove every
  keybinding.
- Never disable selectively. The one sanctioned survivor in this project
  is the Ghostty client parked across a screen lock; the reason is written
  next to the code, and re-adoption on enable is the recovery path.
- Each class cleans up what it created. Do not spread creation in one
  class and teardown in another.
- Keep timeout removal next to timeout creation. A function that can run
  twice removes the pending source before adding a new one.
- Keep `enable()` and `disable()` adjacent and the entry point small.
  Logic lives in modules under `src/lib/`.

## Process boundaries

- `extension.js` and anything it imports must never import `Gtk`, `Gdk`
  or `Adw`.
- `prefs.js` and anything it imports must never import `Clutter`, `Meta`,
  `St` or `Shell`.
- Modules shared by both sides import none of those. `geometry.js` and
  `ghosttyConfig.js` are the pattern: pure, unit tested.

## Code

- Readable, reviewable JavaScript. No minification, no transpiled
  artefacts, no generated bulk. Lines under 200 characters.
- No optional chaining or type checks on methods that are guaranteed to
  exist. Use `instanceof GLib.Error` before calling `matches`.
- No try-catch around `destroy()`, `disconnect()`, `cancel()` or
  `GLib.Source.remove()`; they do not throw in normal use.
- No `_destroyed` style flags. After destroy, null the reference and never
  reuse the instance.
- No `run_dispose()` unless a comment explains the real situation that
  requires it.
- Log only errors and warnings a user would need. One line per event.
- No deprecated modules: no `ByteArray`, `Lang` or `Mainloop`.
- Icons come from the icon theme, never emoji.
- Comments explain intent that the code cannot; they never restate it.
- Target one GNOME Shell version. Multi-version shims need a decision
  record first.

## Subprocesses

- Spawning is discouraged and needs a reason the description states. This
  extension's reason is that Ghostty is the terminal.
- Argv arrays only, never a shell. The command comes from settings, so it
  is user controlled and unprivileged by construction.
- Never spawn anything privileged. Never install packages without an
  explicit user action.
- Spawned processes exit cleanly on disable, except the lock case above.

## Settings and metadata

- Schema id under `org.gnome.shell.extensions`, path under
  `/org/gnome/shell/extensions/`, file named `<schema-id>.gschema.xml`,
  shipped in the package. `settings-schema` in `metadata.json`, and
  `getSettings()` called without arguments.
- `metadata.json` carries only keys it needs: `uuid`, `name`,
  `description`, `shell-version`, `url`, `settings-schema`,
  `version-name`. Never `version`; the site owns it. No `session-modes`
  unless `unlock-dialog` is genuinely required and justified in
  `disable()`. No `donations` unless used.
- `shell-version` lists stable releases and at most one development
  release. Never a future version.
- `url` points at the public repository.

## Package

- The zip contains only what runs: `extension.js`, `prefs.js`,
  `metadata.json`, `lib/`, `schemas/*.gschema.xml`, and the shipped
  Ghostty override file. No build scripts, tests, docs, `.po` files or
  compiled schemas.
- No binaries, no libraries, no telemetry, no clipboard access without
  saying so in the description.
- MIT is compatible with GNOME Shell's GPL-2.0-or-later. Code taken from
  another extension carries its attribution.

## Submission

- The submitter must be able to maintain the code. Read every file before
  uploading. Remove any comment that reads as a prompt or an AI marker.
- Reviewers may approve without testing, so correctness rests on
  `make check` and `make test/headless`, not on the review.
- Expect to explain the spawned process and the lock-screen parking.
