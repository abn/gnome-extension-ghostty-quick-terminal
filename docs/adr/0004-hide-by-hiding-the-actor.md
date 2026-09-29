---
type: Decision
title: Hide by hiding the actor, not by minimising
description: Why the quick terminal is hidden by hiding its compositor actor instead of minimising, and what that reverses from 0002.
status: accepted
---

# Hide by hiding the actor, not by minimising

## Context

The window is hidden from the window list and kept above. Mutter refuses to
minimise a window that is hidden from the window list, so the extension lifted
that restriction, minimised, and set it again on every hide. That flip makes
the overview rebuild its window list. After the overview has been opened once,
its workspace objects can already be disposed while the window-list code still
runs, and the flip then throws inside `workspace.js`. The same stack appeared
about 53k times in the session that aborted on 2026-09-29, each one through
the extension's hide completion.

[0002](0002-ghostty-draws-the-shell-owns-the-window.md) recorded the window
hidden by minimising as a consequence. This record supersedes that one line.

## Options considered

**Guard the flip.** Skip or defer `show_in_window_list` while the overview is
visible, and stop if the window went away mid-slide. Cheap, but it keeps the
flip. The headless harness reproduces the error on ordinary hides after an
overview visit, deferred or not, so this does not fix the crash.

**Find another visibility API.** No Mutter API hides a window without
minimising it.

**Hide the compositor actor.** Keep the window mapped and above, set
`skip-taskbar` once at adoption, and hide the window by hiding its actor. No
minimise, so no flip, so the trigger is gone. Reverses the hidden by
minimising consequence: hidden no longer means minimised.

## Decision

Hide and show the window by hiding and showing its compositor actor. Focus
returns to the window that had it before the terminal was shown, unless it
already moved on its own, which is what autohide does. Re-adoption after a
lock derives visibility from the actor, not from `window.minimized`.

## Consequences

- `skip-taskbar` is set once and never flipped, so a toggle gives the
  overview nothing to rebuild.
- The hidden window stays mapped and can hold keyboard focus, so the focus
  handoff on hide is part of the behaviour, not a detail.
- A hidden actor leaves the accessibility tree and the composited frame, but
  a mapped window can still be chosen as a per-window screencast source. That
  is unchecked.
- `_adoptOwnedWindow` reads actor visibility instead of `window.minimized`.
- The headless harness opens the overview, toggles around it, and fails on
  any window-list error, so the regression is covered.
