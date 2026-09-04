import GLib from 'gi://GLib';
import Gio from 'gi://Gio';
import Meta from 'gi://Meta';
import Shell from 'gi://Shell';

import * as Main from 'resource:///org/gnome/shell/ui/main.js';
import {Extension} from 'resource:///org/gnome/shell/extensions/extension.js';

import {DBusApi} from './lib/dbus.js';
import {ConfigWatcher, GhosttyClient, launchArgs, loadQuickTerminalConfig} from './lib/ghostty.js';
import {QuickTerminal} from './lib/terminal.js';

// The shell disables extensions when the screen locks. The Ghostty process
// is parked here across that so running jobs survive a lock.
let parkedClient = null;

export default class GhosttyQuickTerminalExtension extends Extension {
    enable() {
        this._settings = this.getSettings();
        this._cancellable = new Gio.Cancellable();
        this._terminal = new QuickTerminal({
            settings: this._settings,
            launch: () => new GhosttyClient(launchArgs(
                this._settings.get_string('ghostty-command'),
                this._settings.get_strv('extra-args'))),
        });
        if (parkedClient?.alive)
            this._terminal.adopt(parkedClient);
        parkedClient = null;

        Main.wm.addKeybinding('toggle', this._settings,
            Meta.KeyBindingFlags.IGNORE_AUTOREPEAT,
            Shell.ActionMode.NORMAL | Shell.ActionMode.OVERVIEW,
            () => this._terminal.toggle());
        this._sizeChangedId = this._settings.connect('changed::size',
            () => this._terminal.replace());
        this._dbus = new DBusApi(this._terminal, () => this._reloadConfig());
        this._watcher = new ConfigWatcher(() => this._reloadConfig());
        this._reloadConfig();
    }

    disable() {
        const locked = Main.sessionMode.isLocked;
        this._cancellable.cancel();
        this._cancellable = null;
        this._watcher.destroy();
        this._watcher = null;
        this._dbus.destroy();
        this._dbus = null;
        Main.wm.removeKeybinding('toggle');
        this._settings.disconnect(this._sizeChangedId);
        const client = this._terminal.destroy();
        this._terminal = null;
        if (locked)
            parkedClient = client;
        else
            client?.terminate();
        this._settings = null;
    }

    async _reloadConfig() {
        const command = this._settings.get_string('ghostty-command');
        try {
            const config = await loadQuickTerminalConfig(command, this._cancellable);
            this._terminal?.setConfig(config);
        } catch (e) {
            const cancelled = e instanceof GLib.Error &&
                e.matches(Gio.IOErrorEnum, Gio.IOErrorEnum.CANCELLED);
            if (!cancelled)
                console.warn(`${this.uuid}: could not read Ghostty config: ${e.message}`);
        }
    }
}
