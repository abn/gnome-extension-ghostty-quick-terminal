---
type: Decision
title: Ghostty draws, the shell owns the window
description: Why the extension launches a real Ghostty process as a Mutter client instead of embedding a terminal in the shell or a companion app.
status: accepted
---

# Ghostty draws, the shell owns the window

## Context

Ghostty has a quick terminal on Linux, but it is built on the
`wlr-layer-shell` protocol through `gtk4-layer-shell`. Mutter does not
implement that protocol and the GNOME maintainers have declined to. Ghostty
checks for layer-shell support before creating a quick terminal, and on GNOME
the `toggle_quick_terminal` action does nothing at all. An extension cannot
add a Wayland protocol to Mutter, so something else has to stand in for the
layer shell.

The goal is a native drop-down terminal on GNOME with Mutter and Wayland that
shares the user's Ghostty configuration, stays light, and is small enough to
maintain.

## Options considered

**Run Ghostty's wasm build inside GNOME Shell.** GJS exposes `WebAssembly`,
so this is possible in principle. The wasm entrypoint exports the terminal
state machine, config parsing and font shaping; the font path rasterises
through a browser `canvas` element, the application exports are commented
out, and there is no renderer or pty. The extension would have to supply a
DOM shim, a Clutter renderer, pty handling and input encoding, all running
inside the shell process where a fault takes the whole session down. That is
neither low footprint nor maintainable. Rejected.

**A companion app embedding libghostty, in the style of ddterm.** The C
embedding API only knows macOS and iOS as platforms; there is no Linux, GTK
or OpenGL platform, and the upstream plan is to ship libghostty as a series
of libraries, with a GTK terminal widget last. The host ships only
`libghostty-vt`, the VT state library. Rejected for now. Revisit when a
libghostty GTK widget ships; at that point a companion app could own the
window and the terminal in one process.

**A companion app with VTE, exactly like ddterm.** Works today, but the
terminal is not Ghostty, so fonts, themes, shell integration and keybinds
would not be shared. Rejected.

**A dedicated Ghostty process launched by the shell as a Mutter client.**
The shell spawns Ghostty through `Meta.WaylandClient`, so Mutter knows which
windows belong to it and the extension never guesses by class or title. The
window is hidden from the window list, kept above, stuck to every workspace,
placed and sized by the extension, and shown or hidden with a slide, which
is the work the layer shell would have done. Ghostty keeps everything else:
rendering, fonts, config, shell integration, its own keybinds. Chosen.

## Decision

Launch Ghostty as a shell-owned Wayland client and have the extension act as
the missing layer shell. The extension owns geometry, stacking, workspace
behaviour, visibility and animation. Ghostty owns the terminal.

## Consequences

- Identification is by ownership, not heuristics. No polling, no class
  matching, no title matching.
- The quick terminal is a separate Ghostty process with single-instance mode
  off, so it does not join the user's daemon and does not disturb regular
  Ghostty windows.
- The window is hidden by minimising it. Ghostty offers no hide action for
  ordinary windows, and a minimised window that is also hidden from the
  window list stays out of the overview and the switcher.
- The Ghostty quick-terminal config keys are honoured where they make sense
  on GNOME. See [0003](0003-ghostty-config-is-the-source-of-truth.md).
- If libghostty ships a GTK widget, the companion-app option becomes worth a
  new decision record.
