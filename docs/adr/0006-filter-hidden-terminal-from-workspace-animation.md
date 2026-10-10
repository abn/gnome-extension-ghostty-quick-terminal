---
type: Decision
title: Filter the hidden terminal from workspace animation
description: Why the hidden terminal is filtered out of WorkspaceGroup instead of clipped, avoiding Mutter compositor ghosting and allocation errors.
status: accepted
---

# Filter the hidden terminal from workspace animation

## Context

[0004](0004-hide-by-hiding-the-actor.md) hides the terminal by hiding its
compositor actor. Because the window remains mapped, unminimised and on all
workspaces, GNOME Shell's workspace switch animation clones the window actor
and draws it over the transition.

[0005](0005-clip-the-hidden-actor.md) attempted to suppress this by applying
an empty 0x0 clip (`actor.set_clip(0, 0, 0, 0)`) to the actor while hidden.
In practice, `Clutter.Clone` fails to calculate valid bounding boxes and
projected transforms for an actor with zero dimensions. The calculation
evaluates to `NaN`, failing `clutter_actor_allocate` assertions. Consequently,
Mutter cannot determine stage views or damaged framebuffer regions for the
clone. Dirty framebuffer tiles are never redrawn, causing severe visual
ghosting and stale screen trails across the session.

Additionally, if Ghostty exits or closes its Wayland surface while an
autohide animation is in flight, Mutter immediately disposes
`MetaWindowActorWayland`. Calling methods on the disposed GObject actor in
the ease completion callback threw uncaught exceptions and trapped the
extension state machine in `hiding`.

## Options considered

**Restore 0005 clipping with non-zero subpixel size.** A 1x1 clip still
forces Clutter to allocate a clone and render a transparent pixel on every
workspace switch. It does not eliminate redundant actor cloning or address
underlying damage tracking fragility.

**Park the window off-screen across all workspaces.** Mutter's window
constraint engine snaps sticky windows back onto the visible work area, so
off-screen coordinates cannot be maintained across workspace changes.

**Filter the window out in `WorkspaceGroup._shouldShowWindow`.**
`WorkspaceGroup` in `resource:///org/gnome/shell/ui/workspaceAnimation.js`
builds the clone list by testing each window actor against
`_shouldShowWindow(window)`. Hooking this method allows the extension to
return `false` whenever its owned window is hidden, preventing Clutter from
ever instantiating a clone. When visible, the method retains normal sticky
handling so the terminal rides along the switch.

## Decision

Hook `WorkspaceGroup.prototype._shouldShowWindow` during extension
initialisation and remove the hook on teardown. When the inspected window
belongs to the quick terminal and the terminal is not visible, return `false`.

Completely remove `actor.set_clip(0, 0, 0, 0)` and `actor.remove_clip()`.
Wrap actor operations in `_completeHide` and `destroy` defensively to handle
Wayland client teardown gracefully if the surface disappears mid-slide.

This decision supersedes [0005](0005-clip-the-hidden-actor.md).

## Consequences

- No `Clutter.Clone` is created for the hidden terminal during workspace
  switches.
- Mutter stage view allocation and framebuffer damage tracking remain clean
  without `NaN` calculations or visual ghosting.
- The terminal continues to ride along workspace switches when visible.
- If Ghostty exits while a hide ease is active, the disposed actor does not
  block state reset or focus restoration.
