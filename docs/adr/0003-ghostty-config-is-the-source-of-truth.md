---
type: Decision
title: Ghostty config is the source of truth
description: Quick-terminal settings that Ghostty defines are read from Ghostty, and the extension only adds what Ghostty lacks.
status: accepted
---

# Ghostty config is the source of truth

## Context

The user configures Ghostty once, in its config files. A drop-down terminal
that duplicates position, autohide and animation settings in GSettings would
drift from that configuration and need two places to change.

## Decision

The extension asks Ghostty for its effective configuration with
`ghostty +show-config` and takes every quick-terminal key it can honour from
there: `quick-terminal-position`, `quick-terminal-autohide`,
`quick-terminal-animation-duration` and `quick-terminal-screen`. A file
monitor on the Ghostty config directory reloads them when they change.

The extension's own settings hold only what Ghostty does not define:

- the toggle keybinding, because Ghostty's global keybinds go through the
  desktop portal and would fight the shell's own binding;
- the size of the terminal along its drop axis, because this Ghostty version
  has no size key;
- the Ghostty command and extra arguments, for people with a custom binary.

## Consequences

- Changing `quick-terminal-position` in the Ghostty config moves the
  drop-down without touching extension settings.
- Loading the config spawns one short-lived Ghostty process at enable time
  and after a config change. There is no periodic re-read.
- Keys Ghostty documents as macOS-only are mapped to their closest GNOME
  meaning: `quick-terminal-screen = mouse` uses the monitor under the
  pointer, anything else uses the primary monitor.
