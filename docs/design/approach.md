---
type: Reference
title: Approach
description: How the extension turns a Ghostty window into a drop-down terminal on GNOME Wayland.
status: draft
---

# Approach

The extension plays the part of the layer shell that Mutter does not offer.
Ghostty stays a normal application; the shell decides where its window goes
and when it is visible.

## Lifecycle

1. On enable the extension registers the toggle keybinding, exports a small
   D-Bus interface, loads the quick-terminal keys from Ghostty's config and
   starts watching the config directory.
2. The first toggle launches Ghostty as a Mutter Wayland client with
   single-instance mode off and a private application id. Decorations,
   saved window state and quitting after the last window are pinned in a
   small config file the extension ships and passes with `--config-file`.
   Ghostty applies such imports after command line flags, so the pin holds
   even when the user's own drop-ins say otherwise.
3. When Mutter reports a window owned by that client, the extension hides
   it from the window list, sticks it to all workspaces, keeps it above,
   places it according to position and size, and slides it in.
4. A further toggle slides it out and minimises it, or focuses it when it is
   visible but not focused.
5. Closing the terminal from inside ends the process. The next toggle
   launches a fresh one. If the process outlives its last window, the next
   toggle replaces it.

## Placement

The target rectangle comes from the work area of the chosen monitor, the
position from Ghostty's config and the size fraction from the extension
settings. Wayland clients own their size, so after asking Mutter to move and
resize the frame the extension keeps re-applying the geometry until the
frame matches, then stops listening.

## Visibility

Showing unminimises and activates the window with the shell's own effect
skipped, then eases the window actor's translation from off-screen to zero.
Hiding eases it back off-screen and minimises with the effect skipped.
Mutter refuses to minimise a window that is hidden from the window list, so
the window is shown in the list for the duration of the minimise call and
hidden from it again right after. Both directions use Clutter transitions on
the actor, so nothing runs when no animation is in flight.

## Focus

With `quick-terminal-autohide` on, the extension listens for focus changes
while the terminal is visible and hides it when focus moves to a window that
is neither the terminal nor one of its transients.

Clipboard tools are the exception. `wl-copy` and `wl-paste` map a surface
titled `wl-clipboard` to obtain a serial, take focus for an instant, and
unmap. When focus lands on such a window the extension reads the process
command line before deciding, and leaves the terminal in place if it is one
of those tools. A window kept above can also starve that surface of focus,
which leaves `wl-copy` hanging, so while the terminal is visible and above
the extension focuses `wl-clipboard` surfaces as they appear.

## Lock and disable

Disabling the extension normally ends the Ghostty process. When the shell
disables extensions because the screen locked, the process is kept and
adopted again on unlock, so running jobs survive a lock.
