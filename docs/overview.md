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

Ghostty ships a quick terminal on macOS but has no equivalent on GNOME, and
GNOME Shell on Wayland does not let an application position its own windows.
The extension does the window management on the shell side so Ghostty can
stay a plain application.

## Goals

- Works on GNOME Shell with Mutter on Wayland.
- Elegant: one keybinding, no surprises, animations that stay out of the way.
- Low footprint: no polling, no timers left running, nothing blocking the
  shell main loop.
- Maintainable: small surface, settings through a schema, documented
  decisions.

## Status

No extension code exists yet. This bundle records the intended design so the
implementation has something to be checked against.
