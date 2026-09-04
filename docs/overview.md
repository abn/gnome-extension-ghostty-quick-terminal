---
type: Reference
title: Overview
description: What the Ghostty quick terminal extension is and why it exists.
status: draft
---

# Overview

A GNOME Shell extension that gives Ghostty a quick terminal: a window that
drops down from the top of the screen on a keybinding and hides again on the
same key, in the style of Guake or Ghostty's own quick terminal on macOS.

## Why

Ghostty ships a quick terminal, but on Linux it needs the `wlr-layer-shell`
protocol, which Mutter does not implement, so on GNOME the feature is
disabled. GNOME Shell on Wayland also does not let an application position
its own windows. The extension does the window management on the shell side
so Ghostty can stay a plain application.

## Goals

- Works on GNOME Shell with Mutter on Wayland.
- Elegant: one keybinding, no surprises, animations that stay out of the way.
- Low footprint: no polling, no timers left running, nothing blocking the
  shell main loop.
- Maintainable: small surface, settings through a schema, documented
  decisions.

## How

The shell launches a dedicated Ghostty process as a Mutter client and does
the work a layer shell would do: placement, stacking, workspaces, show and
hide. Ghostty does everything a terminal does, with the user's own config.
See the [approach](design/approach.md) and the
[decision record](adr/0002-ghostty-draws-the-shell-owns-the-window.md).

## Status

First working version targeting GNOME Shell 50. See
[installation](usage/installation.md).
