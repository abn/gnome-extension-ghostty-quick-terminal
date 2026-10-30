// Everything that talks to Ghostty: launching it, reading its config, and
// watching the config directory.

import Gio from 'gi://Gio';
import GLib from 'gi://GLib';

import {parseShowConfig, quickTerminalSettings} from './ghosttyConfig.js';

// Application id of the quick terminal. Distinct from Ghostty's default so
// the window never joins the user's regular Ghostty instance.
export const APP_ID = 'is.abn.GhosttyQuickTerminal';

const DEBOUNCE_MS = 500;

// Ghostty applies config-file imports after command line flags, so the
// keys a drop-down must not lose live in a file passed as one.
export const OVERRIDES_FILE = 'quick-terminal.conf';

export function launchArgs(command, overridesPath, extraArgs = []) {
    return [
        command,
        `--class=${APP_ID}`,
        '--gtk-single-instance=false',
        `--config-file=${overridesPath}`,
        ...extraArgs,
    ];
}

// The shell runs without WAYLAND_DISPLAY in its environment, so a child left
// to inherit it connects to GDK's default socket name, which is the one Mutter
// binds in a session. A shell that inherited the variable, as it does when it
// is started from a session that exported it, hands its own value on instead.
function setDisplayEnvironment(launcher) {
    const display = GLib.getenv('WAYLAND_DISPLAY');
    if (display)
        launcher.setenv('WAYLAND_DISPLAY', display, true);
}

// A Ghostty process the shell launched. Mutter reads the pid of the Wayland
// client behind a window from its socket credentials, so the window still
// belongs to the process spawned here rather than to a guess about its title.
export class GhosttyClient {
    constructor(argv) {
        const launcher = new Gio.SubprocessLauncher({flags: Gio.SubprocessFlags.NONE});
        setDisplayEnvironment(launcher);
        this._subprocess = launcher.spawnv(argv);
        this._pid = Number(this._subprocess.get_identifier());
        this._exited = false;
        this.onExit = null;
        this._subprocess.wait_async(null, () => {
            this._exited = true;
            this.onExit?.();
        });
    }

    get alive() {
        return !this._exited;
    }

    // The class is set by launchArgs, so a window that lost its pid, or a
    // wrapper that re-execs into a new one, is still identified by the name
    // this extension asked Ghostty to use.
    ownsWindow(window) {
        return window.get_pid() === this._pid ||
            window.get_gtk_application_id() === APP_ID;
    }

    terminate() {
        if (this.alive)
            this._subprocess.send_signal(15);
    }
}

export async function loadQuickTerminalConfig(command, cancellable) {
    Gio._promisify(Gio.Subprocess.prototype, 'communicate_utf8_async');
    const proc = Gio.Subprocess.new(
        [command, '+show-config'],
        Gio.SubprocessFlags.STDOUT_PIPE | Gio.SubprocessFlags.STDERR_SILENCE);
    const [stdout] = await proc.communicate_utf8_async(null, cancellable);
    if (!proc.get_successful())
        throw new Error(`${command} +show-config exited with ${proc.get_exit_status()}`);
    return quickTerminalSettings(parseShowConfig(stdout));
}

// Watches the Ghostty config directory and its config.d drop-ins. Changes
// are coalesced into one callback; nothing runs between changes. If the
// directory does not exist yet, its parent is watched until it appears.
export class ConfigWatcher {
    constructor(onChange) {
        this._onChange = onChange;
        this._monitors = [];
        this._pending = null;
        this._dir = Gio.File.new_for_path(
            GLib.build_filenamev([GLib.get_user_config_dir(), 'ghostty']));
        this._arm();
    }

    _arm() {
        for (const monitor of this._monitors)
            monitor.cancel();
        this._monitors = [];
        if (!this._dir.query_exists(null)) {
            this._watch(this._dir.get_parent(), (monitor, file) => {
                if (file.equal(this._dir)) {
                    this._arm();
                    this._schedule();
                }
            });
            return;
        }
        this._watch(this._dir, () => this._schedule());
        this._watch(this._dir.get_child('config.d'), () => this._schedule());
    }

    _watch(file, onChanged) {
        if (!file.query_exists(null))
            return;
        const monitor = file.monitor_directory(Gio.FileMonitorFlags.NONE, null);
        monitor.connect('changed', onChanged);
        this._monitors.push(monitor);
    }

    _schedule() {
        if (this._pending)
            GLib.Source.remove(this._pending);
        this._pending = GLib.timeout_add(GLib.PRIORITY_DEFAULT, DEBOUNCE_MS, () => {
            this._pending = null;
            this._onChange();
            return GLib.SOURCE_REMOVE;
        });
    }

    destroy() {
        if (this._pending)
            GLib.Source.remove(this._pending);
        this._pending = null;
        for (const monitor of this._monitors)
            monitor.cancel();
        this._monitors = [];
    }
}
