# Project rules

These extend the global standards. They never replace them.

- The extension must degrade cleanly when Ghostty is not installed: log a
  clear message, do not crash GNOME Shell.
- Never block the GNOME Shell main loop. Anything that can take time is
  asynchronous.
- Keybindings and behaviour are configured through GSettings with a committed
  schema. No hard-coded user preferences.
- Target the GNOME Shell version declared in `metadata.json`. Do not add
  compatibility shims for older versions without an ADR.
- Every user-visible behaviour has a page in `docs/usage/`.
