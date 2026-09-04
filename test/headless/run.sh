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

# A fresh profile would show the welcome tour over everything.
gsettings set org.gnome.shell welcome-dialog-last-shown-version \
  "$(gnome-shell --version | awk '{print $3}')"

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
json=$(ev 'JSON.stringify(global.get_window_actors().map(a=>{const w=a.meta_window;const r=w.get_frame_rect();return {app:w.get_gtk_application_id(),rect:[r.x,r.y,r.width,r.height],above:w.above,sticky:w.is_on_all_workspaces(),skip:w.skip_taskbar,minimized:w.minimized,focus:w.has_focus()}}))')
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
assert w['above'] and w['sticky'] and w['skip'] and not w['minimized'], w
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
minimized=$(ev 'JSON.stringify(global.get_window_actors().map(a=>a.meta_window).filter(w=>w.get_gtk_application_id()==="is.abn.GhosttyQuickTerminal").map(w=>w.minimized))')
if [[ "$minimized" != "[true]" ]]; then
  ev 'JSON.stringify(global.get_window_actors().filter(a=>a.meta_window.get_gtk_application_id()==="is.abn.GhosttyQuickTerminal").map(a=>({ty:a.translation_y,op:a.opacity,transitions:a.get_transition("translation-y")!==null,canMin:a.meta_window.can_minimize(),focus:a.meta_window.has_focus(),minimized:a.meta_window.minimized,hidden:a.meta_window.is_hidden(),animations:imports.gi.St.Settings.get().enable_animations})))' >&2
  fail "expected the window to be minimized, got $minimized"
fi
visible=$(gdbus call --session --dest org.gnome.Shell --object-path /org/gnome/Shell/Extensions/GhosttyQuickTerminal \
  --method org.freedesktop.DBus.Properties.Get is.abn.GhosttyQuickTerminal Visible)
[[ "$visible" == "(<false>,)" ]] || fail "Visible property is $visible after hide"
step 'hidden again'

ext_call Show >/dev/null
sleep 2
minimized=$(ev 'JSON.stringify(global.get_window_actors().map(a=>a.meta_window).filter(w=>w.get_gtk_application_id()==="is.abn.GhosttyQuickTerminal").map(w=>w.minimized))')
[[ "$minimized" == "[false]" ]] || fail "expected the window to be shown again, got $minimized"
step 'shown again'

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
minimized=$(ev 'JSON.stringify(global.get_window_actors().map(a=>a.meta_window).filter(w=>w.get_gtk_application_id()==="is.abn.GhosttyQuickTerminal").map(w=>w.minimized))')
[[ "$minimized" == "[false]" ]] || fail "wl-copy hid the terminal: $minimized"
[[ "$(timeout 5 wl-paste -n)" == "clipboard" ]] || fail 'clipboard content did not round-trip'
step 'wl-copy left the terminal alone'

# Autohide still hides for a real window.
ghostty --gtk-single-instance=false --class=is.abn.Bystander > /dev/null 2>&1 &
bystander=$!
sleep 4
minimized=$(ev 'JSON.stringify(global.get_window_actors().map(a=>a.meta_window).filter(w=>w.get_gtk_application_id()==="is.abn.GhosttyQuickTerminal").map(w=>w.minimized))')
kill $bystander 2>/dev/null
[[ "$minimized" == "[true]" ]] || fail "another window taking focus did not hide the terminal: $minimized"
sleep 1
step 'autohide still works for other windows'

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
