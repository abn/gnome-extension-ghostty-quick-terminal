# Ghostty Quick Terminal for GNOME Shell

A drop-down terminal for GNOME on Wayland, rendered by Ghostty.

Ghostty has a quick terminal of its own, but on Linux it needs the
`wlr-layer-shell` protocol, and Mutter does not implement it. On GNOME the
feature is simply disabled. This extension fills that gap from the other
side: the shell launches a dedicated Ghostty process as its own Wayland
client and does what the layer shell would have done, which is placing the
window, keeping it above everything, sticking it to every workspace, hiding
it from the switcher and sliding it in and out. Ghostty does everything a
terminal does, with your own config, fonts, theme and shell integration.

## Requirements

- GNOME Shell 50 on Wayland
- Ghostty 1.3 or later on the path

## Install

```sh
make build
make install
```

Log out and back in, then enable it:

```sh
gnome-extensions enable ghostty-quick-terminal@abn.is
```

Press Control and grave, the key left of 1, to drop the terminal down.
Press it again to put it away. The shortcut can be changed in the preferences.

## Configure

Position, autohide, animation duration and screen come from the Ghostty
config, so one file drives both the quick terminal here and the one Ghostty
would give you on a layer-shell compositor:

```
quick-terminal-position = bottom
quick-terminal-autohide = true
quick-terminal-animation-duration = 0.15
```

Changes apply when the file is saved. The extension keeps only what Ghostty
does not define: the shortcut, the size along the drop axis, and the
Ghostty command. Open them with:

```sh
gnome-extensions prefs ghostty-quick-terminal@abn.is
```

Scripts and other keybinding tools can toggle the terminal over D-Bus:

```sh
gdbus call --session --dest org.gnome.Shell \
  --object-path /org/gnome/Shell/Extensions/GhosttyQuickTerminal \
  --method is.abn.GhosttyQuickTerminal.Toggle
```

## How it works

The extension spawns Ghostty through Mutter's own client API, so it knows
which window is its own without guessing by class or title. Hiding minimises
the window; showing unminimises, activates and animates it. Nothing polls,
and no timer runs while the terminal sits idle. Disabling the extension
ends the terminal, except when the screen locks, where the process is kept
so a running job survives the lock.

The design and its alternatives, including why Ghostty's wasm build and
libghostty were not used, are recorded in [docs/adr](docs/adr/index.md), and
written up at length in [A drop-down Ghostty on
GNOME](https://abn.is/void/a-drop-down-ghostty-on-gnome/).

## Develop

```sh
make check          # lint, schema, metadata and unit tests
make test/headless  # drive the built extension in an isolated headless shell
make help           # everything else
```

The headless harness boots a private GNOME Shell on its own session bus and
config directories, installs the package, toggles the terminal over D-Bus
and checks where the window ends up. See [docs](docs/index.md) for the
full documentation bundle and [AGENTS.md](AGENTS.md) for the working
conventions.

## License

[MIT](LICENSE)
