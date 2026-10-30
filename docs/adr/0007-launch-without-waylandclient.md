---
type: Decision
title: Launch Ghostty as a plain subprocess
description: Why the quick terminal is started with Gio.Subprocess and identified by pid instead of as a Meta.WaylandClient.
status: accepted
---

# Launch Ghostty as a plain subprocess

## Context

[0002](0002-ghostty-draws-the-shell-owns-the-window.md) launched Ghostty
through `Meta.WaylandClient.new_subprocess()` so that Mutter would report which
windows belonged to it. Ghostty 1.4.0 takes a SIGSEGV on startup in that
arrangement, before it creates a surface. No window appears, nothing is logged
as an error, and the toggle looks dead.

The same binary with the same arguments, started as a plain subprocess of the
shell, runs normally, and Ghostty 1.3.1 works through both paths. The fault is
in how 1.4 starts as a shell-owned client, not in the configuration. What
exactly differs between the two launches is not established here.

## Options considered

**Keep `Meta.WaylandClient` and wait for Ghostty.** Ownership stays exact, but
the extension does nothing on the version users are being updated to, and it
fails silently. Rejected.

**Launch as a `Meta.WaylandClient` and fall back to a plain subprocess when it
dies without a window.** Two launch paths and a crash-shaped branch in the
window state machine, retried on every toggle. Rejected as more moving parts
than the problem needs.

**Launch with `Gio.SubprocessLauncher` and identify the window by pid.** Mutter
reads a Wayland client's pid from its socket credentials, so the pid names the
process this extension spawned. Chosen.

## Decision

Start Ghostty with `Gio.SubprocessLauncher` and decide ownership by the pid
Mutter reports for the window.

## Consequences

- A window still belongs to the extension by process identity, not by title or
  class. The "no polling, no class matching, no title matching" consequence of
  0002 holds.
- The command in `ghostty-command` has to run Ghostty directly or `exec` it. A
  wrapper that forks puts the window under another pid, and it is not found.
- Windows are no longer tracked by Mutter on the extension's behalf. The
  extension looks at the windows Mutter creates and compares their pid.
- Ghostty 1.4 works again and 1.3 keeps working. Placement, stacking,
  workspace behaviour, hiding and the animation are unchanged, because none of
  them used the client object.
