---
type: Guide
title: Configuration
description: Which settings live in Ghostty's config and which live in the extension.
status: draft
---

# Configuration

Settings are split by who defines them. Ghostty's own quick-terminal keys
are read from Ghostty. The extension only adds what Ghostty lacks. See the
[decision record](../adr/0003-ghostty-config-is-the-source-of-truth.md).

## In the Ghostty config

Put these in your Ghostty config, for example `~/.config/ghostty/config`.
Changes are picked up when the file is saved.

| Key | Values | Effect |
|-----|--------|--------|
| `quick-terminal-position` | `top`, `bottom`, `left`, `right`, `center` | Which edge the terminal slides in from |
| `quick-terminal-autohide` | `true`, `false` | Hide when focus moves elsewhere. Clipboard tools such as `wl-copy` do not count |
| `quick-terminal-animation-duration` | seconds, `0` disables | Slide duration |
| `quick-terminal-screen` | `mouse` for the monitor under the pointer, anything else for the primary monitor | Which monitor |

Everything else in the Ghostty config applies as usual: font, theme,
shell integration, keybinds inside the terminal. The extension's preferences
window links to the Ghostty configuration reference for these keys rather
than duplicating them as settings.

Do not bind `toggle_quick_terminal` with a `global:` prefix in Ghostty. On
GNOME that action does nothing, and the global shortcut would compete with
the extension's binding.

## In the extension

Open the preferences with `gnome-extensions prefs ghostty-quick-terminal@abn.is`
or from the Extensions app.

| Setting | Default | Effect |
|---------|---------|--------|
| Toggle shortcut | Super and grave | Shows, focuses or hides the terminal |
| Size | 40 percent | Height for top and bottom, width for left and right, both for center |
| Ghostty command | `ghostty` | The binary to launch |
| Extra arguments | none | Appended to the Ghostty command line |

## From the command line

The extension exports a D-Bus interface on the shell bus name for scripts
and other keybinding tools:

```sh
gdbus call --session --dest org.gnome.Shell \
  --object-path /org/gnome/Shell/Extensions/GhosttyQuickTerminal \
  --method is.abn.GhosttyQuickTerminal.Toggle
```

`Show`, `Hide` and `ReloadConfig` are available the same way.
