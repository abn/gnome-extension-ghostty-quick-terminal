---
type: Decision
title: Launch Ghostty as a plain subprocess
description: Why the quick terminal is started with Gio.Subprocess and identified by pid and class instead of as a Meta.WaylandClient.
status: accepted
---

# Launch Ghostty as a plain subprocess

## Context

[0002](0002-ghostty-draws-the-shell-owns-the-window.md) launched Ghostty
through `Meta.WaylandClient.new_subprocess()` so that Mutter would report
which windows belonged to it. Ghostty 1.4.0 crashes on startup in that
arrangement: started as a Wayland client of the shell it takes a SIGSEGV
before it creates a surface, so no window ever appears and the toggle looks
dead with nothing in the journal to show for it.

The same binary with the same arguments, in the shell's own environment minus
that client connection, runs normally, and Ghostty 1.3.1 works in the same
harness. The fault is in the 1.4 client path, not in the configuration. Ghostty
main (1.4.1-dev) still crashes, so waiting upstream is not a plan for a user
whose keybinding stopped working after an update.

## Options considered

**Keep `Meta.WaylandClient` and wait for Ghostty.** Ownership stays exact, but
the extension does nothing on the version users are being updated to, and it
fails silently. Rejected.

**Launch as a `Meta.WaylandClient`, and fall back to a plain subprocess when
that client dies without a window.** Recovers either way, at the cost of two
launch paths, a crash-shaped branch in the window state machine and a retry on
every toggle until Ghostty is fixed. Rejected as more moving parts than the
problem needs.

**Launch with `Gio.Subprocess` and identify the window by pid and class.**
Mutter reads a Wayland client's pid from its socket credentials, so the pid
still names the process this extension spawned. The class is set by the
extension itself in `launchArgs`, so `--class=is.abn.GhosttyQuickTerminal`
identifies the window even when the pid is not reported, as with a wrapper
script or a snap that re-execs. Chosen.

## Decision

Start Ghostty with `Gio.SubprocessLauncher` and keep ownership a fact about the
window: the pid Mutter reports for the client, or the class the extension asked
Ghostty to use.

## Consequences

- A window belongs to the extension by process identity, not by title and not
  by where it happened to be placed. The "no polling, no title matching"
  consequence of 0002 still holds. Class matching is limited to the name the
  extension sets itself in `launchArgs`.
- The child inherits the shell's environment, which carries no
  `WAYLAND_DISPLAY`. The variable is passed on when the shell has one, and GDK
  otherwise connects to its default socket name, which is the one Mutter binds
  in a session.
- Windows are no longer tracked by Mutter on the extension's behalf, so nothing
  depends on the client connection surviving: the extension looks at the
  windows Mutter creates and decides by pid and class.
- Ghostty 1.4 works again and 1.3 keeps working. Placement, stacking, workspace
  behaviour, hiding and the animation are unchanged, because none of them used
  the client object.
- If Ghostty stops honouring `--class`, the pid remains the primary signal, so
  a lost class is not a lost window.
