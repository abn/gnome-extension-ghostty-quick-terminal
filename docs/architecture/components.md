---
type: Reference
title: Components
description: The modules that make up the extension and what each one owns.
status: draft
---

# Components

All code lives under `src/`. Pure modules have no GNOME imports and are
covered by unit tests run with `gjs`.

| Module | Owns |
|--------|------|
| `extension.js` | Enable and disable, keybinding, wiring of the parts below |
| `lib/geometry.js` | Target rectangle and off-screen offset from work area, position and size. Pure. |
| `lib/ghosttyConfig.js` | Parsing `ghostty +show-config` output into the quick-terminal settings. Pure. |
| `lib/ghostty.js` | Launching Ghostty as a Mutter client, loading its config, watching the config directory |
| `lib/terminal.js` | The window state machine: adopt, place, show, hide, toggle, autohide |
| `lib/wlclipboard.js` | Recognising `wl-copy` and `wl-paste` surfaces by title and process command line |
| `lib/dbus.js` | The `Toggle`, `Show`, `Hide` and `ReloadConfig` D-Bus methods |
| `prefs.js` | The preferences window |
| `schemas/` | The GSettings schema |
| `quick-terminal.conf` | Ghostty keys pinned for the drop-down, passed with `--config-file` |

## Verification

`tests/` holds unit tests for the pure modules. `test/headless/` holds an
integration harness that boots an isolated headless GNOME Shell on a private
session bus, installs the built extension, drives it over D-Bus and checks
the window geometry. See the [testing guide](../contribution/testing.md).
