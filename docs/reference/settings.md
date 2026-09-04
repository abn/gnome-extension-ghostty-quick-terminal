---
type: Reference
title: Settings schema
description: Keys in the org.gnome.shell.extensions.ghostty-quick-terminal schema.
status: draft
---

# Settings schema

Schema id: `org.gnome.shell.extensions.ghostty-quick-terminal`.

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `toggle` | `as` | `['<Super>grave']` | Keybinding that shows, focuses or hides the terminal |
| `size` | `i` | `40` | Percentage of the work area along the drop axis, 10 to 100 |
| `ghostty-command` | `s` | `'ghostty'` | Program launched for the terminal |
| `extra-args` | `as` | `[]` | Extra command line arguments for Ghostty |

Keys Ghostty defines are not duplicated here. See
[Configuration](../usage/configuration.md).
