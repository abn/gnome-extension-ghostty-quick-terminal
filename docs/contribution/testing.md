---
type: Guide
title: Testing
description: Unit tests for pure modules and the headless integration harness.
status: draft
---

# Testing

## Unit tests

```sh
make test
```

Runs `tests/run.js` under `gjs`. It covers the pure modules: geometry and
Ghostty config parsing. Add a case there whenever those modules change.

## Headless integration

```sh
make test/headless
```

Boots an isolated GNOME Shell in headless mode on a private session bus,
with its own config, data and cache directories so nothing touches your
session. It installs the built extension there, enables it, calls the D-Bus
`Toggle` method, checks that a Ghostty window owned by the extension sits at
the expected rectangle, hides and shows it again, changes the Ghostty config
and checks the terminal moved, turns autohide on and checks that `wl-copy`
completes without hiding the terminal while another window does hide it,
points the command at a missing binary and
checks the failure is logged rather than thrown, and finally disables the
extension and checks the terminal went with it. A screenshot lands under
`build/headless/`.

The private environment is exported before the session bus starts. That
matters: services the bus activates, dconf above all, inherit it, and
without it sandbox writes would land in your real profile.

The harness needs `dbus-run-session`, a GPU render node, Ghostty and
`wl-clipboard` on the path. The headless seat has no keyboard, so the harness
opens a Mutter RemoteDesktop session with a virtual keyboard for the run;
without one `wl-copy` cannot take focus. It runs the shell with `--unsafe-mode` so the test can evaluate
JavaScript inside it; that flag is never used for the real session.

## Manual check in your session

After `make install`, log out and back in, enable the extension and watch
the shell log while toggling:

```sh
journalctl --user -f -o cat /usr/bin/gnome-shell
```
