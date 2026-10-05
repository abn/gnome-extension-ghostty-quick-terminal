---
type: Decision
title: Clip the hidden actor to nothing
description: Why the hidden terminal is clipped away as well as hidden, so the workspace switch animation cannot draw it.
status: accepted
---

# Clip the hidden actor to nothing

## Context

[0004](0004-hide-by-hiding-the-actor.md) hides the terminal by hiding its
compositor actor. The window therefore stays mapped, unminimised and on all
workspaces while hidden, and the rest of the shell still counts it as a
window that is showing.

The workspace switch animation takes that at face value. It builds a group
per workspace plus one for the windows on all workspaces, and fills each with
a `Clutter.Clone` of every window actor whose frame intersects the monitor.
A clone paints its source with the source's own visibility, transform and
opacity overridden, so neither `actor.hide()` nor the off-screen slide reaches
it. Every workspace switch drew the hidden terminal over the transition and
dropped it again at the end. The clone's visibility is synced from
`showing_on_its_workspace()`, which only a minimised window makes false.

## Options considered

**Minimise after all.** Mutter reports `can_minimize() == false` for a window
hidden from the window list and ignores `minimize()`, so this needs the
skip-taskbar flip that 0004 removed, and with it the crash that caused.

**Park the window off every monitor while hidden.** The animation skips
windows whose frame does not intersect the monitor. Mutter's constraint
engine moves the frame straight back onto the work area, so the window never
goes off-screen.

**Patch the shell's workspace animation.** Reaches into private classes of
a module that is free to change between shell versions, for a result the
extension can get on its own.

**Clip the actor to nothing.** A clip is part of the paint rather than a
property the clone overrides, so an empty clip empties the clone too. It uses
the same public Clutter API the extension already uses on that actor for the
slide.

## Decision

While hidden, the window actor carries an empty clip alongside being hidden.
The clip goes on when the hide animation completes and comes off when a show
begins, and a window adopted in the hidden state gets one. The extension
removes it when it releases the window.

## Consequences

- Hidden means invisible to anything that paints the actor, clones included,
  not only to the direct paint.
- Hidden no longer depends on the slide offset being correct, so a stale
  offset after a work area change cannot reveal the terminal.
- Any code that reads the actor's clip sees a hidden terminal as a window
  clipped to nothing; nothing in the shell does.
- The headless harness screenshots a slowed down workspace switch and
  measures the strip the terminal occupies, so the regression is covered in
  pixels rather than in state.
