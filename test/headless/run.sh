#!/usr/bin/env bash
# Integration check in an isolated headless GNOME Shell.
#
# Boots gnome-shell headless on a private session bus with private XDG
# directories, installs the packed extension there, enables it, drives it
# over D-Bus and checks the window geometry. Nothing touches the real
# session. Requires dbus-run-session, a GPU render node and ghostty.
#
# Usage: test/headless/run.sh <zip> <uuid>
set -euo pipefail

zip=$(realpath "$1")
uuid=$2
root=$(git rev-parse --show-toplevel)
sandbox=$root/build/headless

# The private environment must be in place before the session bus starts,
# because services it activates (dconf in particular) inherit it. Otherwise
# sandbox writes land in the real profile.
export XDG_CONFIG_HOME=$sandbox/config XDG_DATA_HOME=$sandbox/data XDG_CACHE_HOME=$sandbox/cache
export WAYLAND_DISPLAY=wayland-ghostty-test GNOME_SHELL_SESSION_MODE=user
unset DISPLAY XDG_SESSION_ID XDG_SESSION_TYPE

if [[ "${HEADLESS_INNER:-}" != 1 ]]; then
  rm -rf "$sandbox"
  mkdir -p "$sandbox"/{config/ghostty,data,cache}
  ext_dir=$sandbox/data/gnome-shell/extensions/$uuid
  mkdir -p "$ext_dir"
  unzip -q -o "$zip" -d "$ext_dir"
  glib-compile-schemas "$ext_dir/schemas"
  exec env HEADLESS_INNER=1 dbus-run-session -- "$0" "$zip" "$uuid"
fi

# A fresh profile would show the welcome tour over everything, and hot corners
# would open the overview when the virtual pointer initializes at (0, 0).
gsettings set org.gnome.shell welcome-dialog-last-shown-version \
  "$(gnome-shell --version | awk '{print $3}')"
gsettings set org.gnome.desktop.interface enable-hot-corners false

gnome-shell --unsafe-mode --headless --wayland --no-x11 --virtual-monitor 1280x800 \
  --wayland-display "$WAYLAND_DISPLAY" > "$sandbox/shell.log" 2>&1 &
shell_pid=$!
trap 'kill $shell_pid 2>/dev/null; wait $shell_pid 2>/dev/null' EXIT

shell_call() {
  gdbus call --session --dest org.gnome.Shell --object-path /org/gnome/Shell --method "$@"
}
ext_call() {
  gdbus call --session --dest org.gnome.Shell \
    --object-path /org/gnome/Shell/Extensions/GhosttyQuickTerminal \
    --method "is.abn.GhosttyQuickTerminal.$1"
}
# Evaluates JS inside the shell and prints the JSON result.
ev() {
  local out
  out=$(shell_call org.gnome.Shell.Eval "$1")
  [[ "$out" == "(true, "* ]] || { printf 'eval failed: %s\n' "$out" >&2; return 1; }
  python3 -c 'import ast,json,sys; print(json.loads(ast.literal_eval(sys.argv[1][7:-1])))' "$out"
}
ext_settings() {
  local op=$1
  shift
  GSETTINGS_SCHEMA_DIR=$sandbox/data/gnome-shell/extensions/$uuid/schemas \
    gsettings "$op" org.gnome.shell.extensions.ghostty-quick-terminal "$@"
}
fail() {
  printf 'headless: FAIL %s\n' "$1" >&2
  grep -A6 -E "$uuid|GhosttyQuickTerminal" "$sandbox/shell.log" | grep -vE 'dbus-daemon|AddMatch' | head -30 >&2
  exit 1
}
step() { printf 'headless: %s\n' "$1"; }

# Hiding is an actor hide now, not a minimise, so assert on actor visibility.
terminal_shown() {
  ev 'JSON.stringify(global.get_window_actors().filter(a=>a.meta_window.get_gtk_application_id()==="is.abn.GhosttyQuickTerminal").map(a=>a.visible))'
}

for _ in $(seq 1 30); do
  sleep 1
  kill -0 $shell_pid 2>/dev/null || fail 'shell exited during startup (see build/headless/shell.log)'
  shell_call org.gnome.Shell.Extensions.ListExtensions >/dev/null 2>&1 && break
done
step 'shell is up'

# The headless seat has no keyboard, and wl-copy needs one to take focus.
# A RemoteDesktop session with a virtual keyboard gives the seat one.
python3 "$root/test/headless/virtual-keyboard.py" > "$sandbox/keyboard.log" 2>&1 &
keyboard_pid=$!
trap 'kill $keyboard_pid $shell_pid 2>/dev/null; wait $keyboard_pid $shell_pid 2>/dev/null' EXIT
sleep 2
grep -q 'virtual keyboard ready' "$sandbox/keyboard.log" || fail 'virtual keyboard did not come up (see build/headless/keyboard.log)'
step 'virtual keyboard attached'

gnome-extensions enable "$uuid"
sleep 1
[[ -f "$sandbox/config/dconf/user" ]] || fail 'sandbox dconf database missing: writes may be leaking to the real profile'
state=$(gnome-extensions info "$uuid" | awk '/State:/ {print $2}')
[[ "$state" == ACTIVE ]] || fail "extension state is $state"
step 'extension enabled'

ext_call Toggle >/dev/null
sleep 5
json=$(ev 'JSON.stringify(global.get_window_actors().map(a=>{const w=a.meta_window;const r=w.get_frame_rect();return {app:w.get_gtk_application_id(),rect:[r.x,r.y,r.width,r.height],above:w.above,sticky:w.is_on_all_workspaces(),skip:w.skip_taskbar,visible:a.visible,minimized:w.minimized,focus:w.has_focus()}}))')
printf '%s\n' "$json" > "$sandbox/windows-shown.json"
python3 - "$json" <<'PY' || fail 'window is not where it should be'
import json, sys
wins = [w for w in json.loads(sys.argv[1]) if w['app'] == 'is.abn.GhosttyQuickTerminal']
assert len(wins) == 1, f'expected one quick terminal window, got {wins}'
w = wins[0]
# 1280x800 virtual monitor, 40 percent height, top position, below the panel
assert w['rect'][0] == 0 and w['rect'][2] == 1280, w
assert 0 < w['rect'][1] <= 40, w
assert abs(w['rect'][3] - (800 - w['rect'][1]) * 0.4) <= 2, w
assert w['visible'] and w['above'] and w['sticky'] and w['skip'] and not w['minimized'], w
assert w['focus'], w
print('headless: window placed at', w['rect'])
PY
visible=$(gdbus call --session --dest org.gnome.Shell --object-path /org/gnome/Shell/Extensions/GhosttyQuickTerminal \
  --method org.freedesktop.DBus.Properties.Get is.abn.GhosttyQuickTerminal Visible)
[[ "$visible" == "(<true>,)" ]] || fail "Visible property is $visible"
gdbus call --session --dest org.gnome.Shell.Screenshot --object-path /org/gnome/Shell/Screenshot \
  --method org.gnome.Shell.Screenshot.Screenshot false false "$sandbox/shown.png" >/dev/null
step 'screenshot saved to build/headless/shown.png'

ext_call Toggle >/dev/null
sleep 2
shown=$(terminal_shown)
if [[ "$shown" != "[false]" ]]; then
  ev 'JSON.stringify(global.get_window_actors().filter(a=>a.meta_window.get_gtk_application_id()==="is.abn.GhosttyQuickTerminal").map(a=>({ty:a.translation_y,op:a.opacity,visible:a.visible,transitions:a.get_transition("translation-y")!==null,focus:a.meta_window.has_focus(),minimized:a.meta_window.minimized,hidden:a.meta_window.is_hidden(),animations:imports.gi.St.Settings.get().enable_animations})))' >&2
  fail "expected the window actor to be hidden, got $shown"
fi
visible=$(gdbus call --session --dest org.gnome.Shell --object-path /org/gnome/Shell/Extensions/GhosttyQuickTerminal \
  --method org.freedesktop.DBus.Properties.Get is.abn.GhosttyQuickTerminal Visible)
[[ "$visible" == "(<false>,)" ]] || fail "Visible property is $visible after hide"
focused=$(ev 'global.display.focus_window ? global.display.focus_window.get_gtk_application_id() : null')
[[ "$focused" != "is.abn.GhosttyQuickTerminal" ]] || fail 'the hidden terminal kept keyboard focus'
step 'hidden again'

ext_call Show >/dev/null
sleep 2
shown=$(terminal_shown)
[[ "$shown" == "[true]" ]] || fail "expected the window actor to be shown again, got $shown"
step 'shown again'

# The overview rebuilds its window list when skip-taskbar flips. That flip is
# gone now, so toggling around an overview visit must leave the shell's
# window-list code quiet and the terminal out of the list.
ev 'Main.overview.show(); "overview shown"' >/dev/null
sleep 1
overview=$(ev 'JSON.stringify(Main.overview._overview.controls._workspacesDisplay._workspacesViews.flatMap(v=>(v._workspaces??[]).flatMap(w=>w._windows.map(c=>c.metaWindow.get_gtk_application_id()))))')
[[ "$overview" != *GhosttyQuickTerminal* ]] || fail "terminal is in the overview window list: $overview"
for _ in 1 2 3 4 5 6; do
  ext_call Toggle >/dev/null
  sleep 1
done
ev 'Main.overview.hide(); "overview hidden"' >/dev/null
sleep 2
for _ in 1 2 3 4 5 6; do
  ext_call Toggle >/dev/null
  sleep 1
done
overview=$(ev 'JSON.stringify(Main.overview._overview.controls._workspacesDisplay._workspacesViews.flatMap(v=>(v._workspaces??[]).flatMap(w=>w._windows.map(c=>c.metaWindow.get_gtk_application_id()))))')
[[ "$overview" != *GhosttyQuickTerminal* ]] || fail "terminal appeared in the overview window list: $overview"
if grep -qE 'addWindow|layout_manager is null|already disposed' "$sandbox/shell.log"; then
  grep -E 'addWindow|layout_manager is null|already disposed' "$sandbox/shell.log" | head -10 >&2
  fail 'window-list errors while toggling around the overview'
fi
step 'toggling around the overview is clean'

# The workspace switch animation clones the window actors it finds, and a
# clone paints its source without the source's own visibility, transform or
# opacity, so a hidden terminal used to be drawn over the whole transition.
# Only pixels can tell, so screenshot the slowed down transition and measure
# the strip the terminal occupies: dark while it is shown and rides along,
# the bright default wallpaper while it is hidden.
gsettings set org.gnome.mutter dynamic-workspaces false
gsettings set org.gnome.desktop.wm.preferences num-workspaces 2
# Mean luminance of the terminal's strip, well inside it on both axes.
strip_luminance() {
  python3 - "$1" <<'PY'
import sys
import gi
gi.require_version('GdkPixbuf', '2.0')
from gi.repository import GdkPixbuf
pb = GdkPixbuf.Pixbuf.new_from_file(sys.argv[1])
px, stride, channels = pb.get_pixels(), pb.get_rowstride(), pb.get_n_channels()
total = count = 0
for y in range(80, 300, 4):
    for x in range(200, 1080, 4):
        o = y * stride + x * channels
        total += (px[o] + px[o + 1] + px[o + 2]) / 3
        count += 1
print(round(total / count))
PY
}
# Captures the terminal's strip part way through a switch to workspace $1.
switch_shot() {
  ev "imports.gi.St.Settings.get().slow_down_factor = 20; global.workspace_manager.get_workspace_by_index($1).activate(global.get_current_time()); 'switching'" >/dev/null
  gdbus call --session --dest org.gnome.Shell.Screenshot --object-path /org/gnome/Shell/Screenshot \
    --method org.gnome.Shell.Screenshot.Screenshot false false "$sandbox/switch-$2.png" >/dev/null
  live=$(ev 'Main.wm._workspaceAnimation._switchData !== null ? "live" : "over"')
  ev 'imports.gi.St.Settings.get().slow_down_factor = 1; "reset"' >/dev/null
  sleep 2
  [[ "$live" == "live" ]] || fail "the $2 switch was over before the screenshot"
  strip_luminance "$sandbox/switch-$2.png"
}
ext_call Show >/dev/null
sleep 2
lum=$(switch_shot 1 shown)
[[ "$lum" -lt 100 ]] || fail "the shown terminal did not ride along the switch: luminance $lum"
ext_call Hide >/dev/null
sleep 2
lum=$(switch_shot 0 hidden)
[[ "$lum" -gt 100 ]] || fail "the hidden terminal is drawn during a workspace switch: luminance $lum"
ev 'global.workspace_manager.get_workspace_by_index(1).activate(global.get_current_time()); "ws1"' >/dev/null
sleep 1
ev 'global.workspace_manager.get_workspace_by_index(0).activate(global.get_current_time()); "ws0"' >/dev/null
sleep 1
shown=$(terminal_shown)
[[ "$shown" == "[false]" ]] || fail "hidden terminal actor became visible across workspace switch: $shown"
focused=$(ev 'global.display.focus_window ? global.display.focus_window.get_gtk_application_id() : null')
[[ "$focused" != "is.abn.GhosttyQuickTerminal" ]] || fail 'hidden terminal stole focus across workspace switch'
gsettings set org.gnome.mutter dynamic-workspaces true
step 'the hidden terminal stays out of the workspace switch'

# Screen lock disables extensions and parks the Ghostty client. A hidden
# terminal must stay hidden on unlock; a visible one with autohide off stays
# visible.
ev 'Main.screenShield.lock(false); "locked"' >/dev/null
sleep 1
ev 'Main.screenShield.deactivate(false); "unlocked"' >/dev/null
sleep 1
shown=$(terminal_shown)
[[ "$shown" == "[false]" ]] || fail "hidden terminal reappeared after lock/unlock: $shown"
visible=$(gdbus call --session --dest org.gnome.Shell --object-path /org/gnome/Shell/Extensions/GhosttyQuickTerminal \
  --method org.freedesktop.DBus.Properties.Get is.abn.GhosttyQuickTerminal Visible)
[[ "$visible" == "(<false>,)" ]] || fail "Visible property is $visible after hidden lock/unlock"
has=$(gdbus call --session --dest org.gnome.Shell --object-path /org/gnome/Shell/Extensions/GhosttyQuickTerminal \
  --method org.freedesktop.DBus.Properties.Get is.abn.GhosttyQuickTerminal HasWindow)
[[ "$has" == "(<true>,)" ]] || fail "HasWindow is $has after lock/unlock"
ext_call Show >/dev/null
sleep 2
ev 'Main.screenShield.lock(false); "locked"' >/dev/null
sleep 1
ev 'Main.screenShield.deactivate(false); "unlocked"' >/dev/null
sleep 1
shown=$(terminal_shown)
[[ "$shown" == "[true]" ]] || fail "visible terminal without autohide disappeared after lock/unlock: $shown"
ext_call Hide >/dev/null
sleep 1
step 'lock/unlock preserves hidden and non-autohide visibility'

# Focus returns to the window that had it before the terminal was shown.
ghostty --gtk-single-instance=false --class=is.abn.Bystander > /dev/null 2>&1 &
bystander=$!
sleep 4
ev 'Main.activateWindow(global.get_window_actors().map(a=>a.meta_window).find(w=>w.get_gtk_application_id()==="is.abn.Bystander")); "bystander focused"' >/dev/null
sleep 1
ext_call Show >/dev/null
sleep 2
ext_call Hide >/dev/null
sleep 2
focused=$(ev 'global.display.focus_window ? global.display.focus_window.get_gtk_application_id() : null')
[[ "$focused" == "is.abn.Bystander" ]] || fail "focus did not return to the previous window, got $focused"

# Hiding on another workspace must not pull the active workspace back to where
# the previous window or MRU fallback lives.
gsettings set org.gnome.mutter dynamic-workspaces false
gsettings set org.gnome.desktop.wm.preferences num-workspaces 2
ext_call Show >/dev/null
sleep 2
ev 'global.workspace_manager.get_workspace_by_index(1).activate(global.get_current_time()); "ws1"' >/dev/null
sleep 1
ext_call Hide >/dev/null
sleep 2
ws=$(ev 'global.workspace_manager.get_active_workspace_index()')
[[ "$ws" == "1" ]] || fail "hiding after cross-workspace switch jumped to workspace $ws"
focused=$(ev 'global.display.focus_window ? global.display.focus_window.get_gtk_application_id() : null')
[[ "$focused" != "is.abn.GhosttyQuickTerminal" ]] || fail 'terminal kept focus after cross-workspace hide'

ext_call Show >/dev/null
sleep 2
ext_call Hide >/dev/null
sleep 2
ws=$(ev 'global.workspace_manager.get_active_workspace_index()')
[[ "$ws" == "1" ]] || fail "hiding on empty workspace jumped to workspace $ws"
focused=$(ev 'global.display.focus_window ? global.display.focus_window.get_gtk_application_id() : null')
[[ "$focused" != "is.abn.GhosttyQuickTerminal" ]] || fail 'terminal kept focus after empty-workspace hide'
ev 'global.workspace_manager.get_workspace_by_index(0).activate(global.get_current_time()); "ws0"' >/dev/null
sleep 1
gsettings set org.gnome.mutter dynamic-workspaces true
kill $bystander 2>/dev/null
step 'focus returns to the previous window on the active workspace'

# Dragging the open edge resizes the terminal live and persists size.
ext_call Show >/dev/null
sleep 2
handle_info=$(ev '(() => {
  const Clutter = imports.gi.Clutter;
  const wa = global.get_window_actors().find(a => a.meta_window.get_gtk_application_id() === "is.abn.GhosttyQuickTerminal");
  const r = wa.meta_window.get_frame_rect();
  const wg = global.window_group.get_children();
  const handle = wg.find(c => !c.meta_window && c.reactive && c.visible && Math.abs(c.width - r.width) <= 2);
  const picked = handle ? global.stage.get_actor_at_pos(Clutter.PickMode.REACTIVE, r.x + Math.floor(r.width / 2), r.y + r.height) : null;
  const workArea = Main.layoutManager.getWorkAreaForMonitor(wa.meta_window.get_monitor());
  return JSON.stringify({
    found: Boolean(handle),
    above: handle ? wg.indexOf(handle) > wg.indexOf(wa) : false,
    cursor: handle ? handle.get_cursor_type() === Clutter.CursorType.NS_RESIZE : false,
    picked: picked === handle,
    rect: handle ? [handle.x, handle.y, handle.width, handle.height] : null,
    cx: r.x + Math.floor(r.width / 2),
    cy: r.y + r.height,
    y60: Math.round(workArea.y + workArea.height * 0.60),
    h60: Math.floor(workArea.height * 0.60),
    h50: Math.floor(workArea.height * 0.50),
    h40: Math.floor(workArea.height * 0.40),
  });
})()')
python3 - "$handle_info" <<'PY_HANDLE' || fail "resize handle missing or misstacked: $handle_info"
import json, sys
h = json.loads(sys.argv[1])
assert h['found'] and h['above'] and h['cursor'] and h['picked'], h
assert h['rect'][3] == 8 and abs(h['rect'][1] + 4 - h['cy']) <= 2, h
PY_HANDLE
read -r drag_cx drag_cy drag_y60 drag_h60 drag_h50 drag_h40 <<<"$(python3 - "$handle_info" <<'PY_COORDS'
import json, sys
h = json.loads(sys.argv[1])
print(h['cx'], h['cy'], h['y60'], h['h60'], h['h50'], h['h40'])
PY_COORDS
)"
ev 'global.__testPtr = global.stage.get_context().get_backend().get_default_seat().create_virtual_device(imports.gi.Clutter.InputDeviceType.POINTER_DEVICE); "ptr"' >/dev/null
sleep 0.3
ev "global.__testPtr.notify_absolute_motion(imports.gi.GLib.get_monotonic_time(), $drag_cx, $drag_cy); 'warm'" >/dev/null
sleep 0.2
ev "global.__testPtr.notify_absolute_motion(imports.gi.GLib.get_monotonic_time(), $drag_cx, $drag_cy); 'hover'" >/dev/null
sleep 0.2
ev "global.__testPtr.notify_button(imports.gi.GLib.get_monotonic_time(), imports.gi.Clutter.BUTTON_PRIMARY, imports.gi.Clutter.ButtonState.PRESSED); 'press'" >/dev/null
sleep 0.2
ev "global.__testPtr.notify_absolute_motion(imports.gi.GLib.get_monotonic_time(), $drag_cx, $((drag_cy + 40))); 'drag1'" >/dev/null
sleep 0.2
ev "global.__testPtr.notify_absolute_motion(imports.gi.GLib.get_monotonic_time(), $drag_cx, $drag_y60); 'drag2'" >/dev/null
sleep 0.2
ev 'global.__testPtr.notify_button(imports.gi.GLib.get_monotonic_time(), imports.gi.Clutter.BUTTON_PRIMARY, imports.gi.Clutter.ButtonState.RELEASED); "release"' >/dev/null
sleep 1
drag_size=$(ext_settings get size)
[[ "$drag_size" == "60" ]] || fail "edge drag expected size 60, got $drag_size"
drag_frame=$(ev 'JSON.stringify((() => { const wa=global.get_window_actors().find(a=>a.meta_window.get_gtk_application_id()==="is.abn.GhosttyQuickTerminal"); const r=wa.meta_window.get_frame_rect(); const h=global.window_group.get_children().find(c=>!c.meta_window&&c.reactive&&c.visible&&Math.abs(c.width-r.width)<=2); return {frame:[r.x,r.y,r.width,r.height], handleY:h?h.y:null}; })())')
python3 - "$drag_frame" "$drag_h60" <<'PY_DRAG' || fail "edge drag did not resize frame or handle: $drag_frame"
import json, sys
d = json.loads(sys.argv[1])
expected_h = int(sys.argv[2])
r = d['frame']
assert abs(r[3] - expected_h) <= 2, d
assert d['handleY'] is not None and abs(d['handleY'] + 4 - (r[1] + r[3])) <= 2, d
PY_DRAG
ext_call Hide >/dev/null
sleep 1
hidden_handles=$(ev 'global.window_group.get_children().filter(c => !c.meta_window && c.reactive && c.visible && c.width >= 1200).length')
[[ "$hidden_handles" == "0" ]] || fail "resize handle stayed visible after hide: $hidden_handles"
ext_call Show >/dev/null
sleep 1
show_h=$(ev 'global.get_window_actors().find(a=>a.meta_window.get_gtk_application_id()==="is.abn.GhosttyQuickTerminal").meta_window.get_frame_rect().height')
[[ $((show_h - drag_h60)) -ge -2 && $((show_h - drag_h60)) -le 2 ]] || fail "resized height did not persist across hide/show: got $show_h expected $drag_h60"

# Window manager resize finishes through grab-op-end and also persists size.
ev "(() => { const w = global.get_window_actors().find(a=>a.meta_window.get_gtk_application_id()===\"is.abn.GhosttyQuickTerminal\").meta_window; const wa = Main.layoutManager.getWorkAreaForMonitor(w.get_monitor()); w.move_resize_frame(true, wa.x, wa.y, wa.width, $drag_h50); return 'resized'; })()" >/dev/null
sleep 0.5
ev 'global.display.emit("grab-op-end", global.get_window_actors().find(a=>a.meta_window.get_gtk_application_id()==="is.abn.GhosttyQuickTerminal").meta_window, imports.gi.Meta.GrabOp.RESIZING_S); "grab-end"' >/dev/null
sleep 0.5
wm_size=$(ext_settings get size)
[[ "$wm_size" == "50" ]] || fail "grab-op-end expected size 50, got $wm_size"
ext_settings reset size
sleep 1
reset_h=$(ev 'global.get_window_actors().find(a=>a.meta_window.get_gtk_application_id()==="is.abn.GhosttyQuickTerminal").meta_window.get_frame_rect().height')
[[ $((reset_h - drag_h40)) -ge -2 && $((reset_h - drag_h40)) -le 2 ]] || fail "resetting size did not restore height: got $reset_h expected $drag_h40"
ext_call Hide >/dev/null
sleep 1
step 'dragging the open edge and WM resizes update size'

# Shared config: a change in the Ghostty config moves the terminal.
printf 'quick-terminal-position = bottom\n' > "$sandbox/config/ghostty/config"
sleep 2
rect=$(ev 'JSON.stringify(global.get_window_actors().map(a=>a.meta_window).filter(w=>w.get_gtk_application_id()==="is.abn.GhosttyQuickTerminal").map(w=>{const r=w.get_frame_rect();return [r.x,r.y,r.width,r.height]}))')
python3 - "$rect" <<'PY2' || fail "config change did not move the terminal: $rect"
import json, sys
[r] = json.loads(sys.argv[1])
assert r[0] == 0 and r[2] == 1280, r
assert r[1] + r[3] == 800, r
print('headless: config change moved the terminal to', r)
PY2

# Autohide: a clipboard tool borrowing focus must not hide the terminal,
# and must not hang for lack of focus while the terminal is above.
printf 'quick-terminal-position = top\nquick-terminal-autohide = true\n' > "$sandbox/config/ghostty/config"
sleep 2
ext_call Show >/dev/null
sleep 2
if ! printf 'clipboard' | timeout 5 wl-copy; then fail 'wl-copy hung or failed while the terminal was above'; fi
sleep 1
shown=$(terminal_shown)
[[ "$shown" == "[true]" ]] || fail "wl-copy hid the terminal: $shown"
[[ "$(timeout 5 wl-paste -n)" == "clipboard" ]] || fail 'clipboard content did not round-trip'
step 'wl-copy left the terminal alone'

# Autohide still hides for a real window.
ghostty --gtk-single-instance=false --class=is.abn.Bystander > /dev/null 2>&1 &
bystander=$!
sleep 4
shown=$(terminal_shown)
kill $bystander 2>/dev/null
[[ "$shown" == "[false]" ]] || fail "another window taking focus did not hide the terminal: $shown"
sleep 1
step 'autohide still works for other windows'

# With autohide on, locking while visible keeps the terminal hidden on unlock.
ext_call Show >/dev/null
sleep 2
ev 'Main.screenShield.lock(false); "locked"' >/dev/null
sleep 1
ev 'Main.screenShield.deactivate(false); "unlocked"' >/dev/null
sleep 1
shown=$(terminal_shown)
[[ "$shown" == "[false]" ]] || fail "autohide terminal reappeared after lock/unlock: $shown"
focused=$(ev 'global.display.focus_window ? global.display.focus_window.get_gtk_application_id() : null')
[[ "$focused" != "is.abn.GhosttyQuickTerminal" ]] || fail 'autohide terminal kept focus after lock/unlock'
step 'autohide terminal stays hidden after lock/unlock'

# A process that outlives its last window must be replaced, not waited on.
# A config-file passed after the extension's own overrides wins over them.
printf 'quit-after-last-window-closed = false\n' > "$sandbox/linger.conf"
ext_settings set extra-args "['--config-file=$sandbox/linger.conf']"
pid=$(ev 'global.get_window_actors().map(a=>a.meta_window).find(w=>w.get_gtk_application_id()==="is.abn.GhosttyQuickTerminal").get_pid()')
kill "$pid"
sleep 2
ext_call Show >/dev/null
sleep 4
ev 'global.get_window_actors().map(a=>a.meta_window).find(w=>w.get_gtk_application_id()==="is.abn.GhosttyQuickTerminal").delete(global.get_current_time()); "closed"' >/dev/null
sleep 3
pgrep -f -- 'linger.conf' >/dev/null || fail 'lingering Ghostty process expected but not found'
ext_call Toggle >/dev/null
sleep 5
has=$(gdbus call --session --dest org.gnome.Shell --object-path /org/gnome/Shell/Extensions/GhosttyQuickTerminal \
  --method org.freedesktop.DBus.Properties.Get is.abn.GhosttyQuickTerminal HasWindow)
[[ "$has" == "(<true>,)" ]] || fail "toggle after a windowless process did not bring a window back: $has"
ext_settings reset extra-args
step 'windowless process is replaced on toggle'

# A missing Ghostty must be logged, not thrown. End the running terminal
# first so the next toggle has to launch.
pid=$(ev 'global.get_window_actors().map(a=>a.meta_window).find(w=>w.get_gtk_application_id()==="is.abn.GhosttyQuickTerminal").get_pid()')
kill "$pid"
sleep 2
ext_settings set ghostty-command /nonexistent/ghostty
sleep 1
ext_call Toggle >/dev/null
sleep 1
grep -q 'could not launch Ghostty' "$sandbox/shell.log" || fail 'missing Ghostty was not reported'
visible=$(gdbus call --session --dest org.gnome.Shell --object-path /org/gnome/Shell/Extensions/GhosttyQuickTerminal \
  --method org.freedesktop.DBus.Properties.Get is.abn.GhosttyQuickTerminal Visible)
[[ "$visible" == "(<false>,)" ]] || fail "Visible is $visible after a failed launch"
ext_settings reset ghostty-command
step 'missing Ghostty is reported and recovers'

gnome-extensions disable "$uuid"
sleep 2
left=$(ev 'JSON.stringify(global.get_window_actors().map(a=>a.meta_window.get_gtk_application_id()))')
[[ "$left" != *GhosttyQuickTerminal* ]] || fail "window survived disable: $left"
step 'disable ended the terminal'

if grep -A3 -E 'JS ERROR|Gjs-CRITICAL|Shell-CRITICAL' "$sandbox/shell.log" | grep -qE "$uuid|GhosttyQuickTerminal"; then
  grep -A8 -E 'JS ERROR|Gjs-CRITICAL|Shell-CRITICAL' "$sandbox/shell.log" | grep -B2 -A6 -E "$uuid|GhosttyQuickTerminal" >&2
  fail 'shell log has errors from the extension'
fi
step 'no extension errors in the shell log'
printf 'headless: ok\n'
