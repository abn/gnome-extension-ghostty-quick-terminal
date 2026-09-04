---
type: Guide
title: Installation
description: Building and installing the extension from source.
status: draft
---

# Installation

## Requirements

- GNOME Shell 50 on Wayland.
- Ghostty 1.3 or later on the path.
- `make`, `glib-compile-schemas` and `gnome-extensions`, which ship with
  GNOME.

## Build and install

```sh
make build
make install
```

`make build` packs the extension into a zip under `dist/`. `make install`
installs that zip for the current user. GNOME Shell on Wayland only picks up
a new extension after you log out and back in. After that:

```sh
gnome-extensions enable ghostty-quick-terminal@abn.is
```

Press Control and grave (the key left of 1) to drop the terminal down.
Press it again to put it away.

## Uninstall

```sh
gnome-extensions uninstall ghostty-quick-terminal@abn.is
```
