// Small D-Bus surface for scripts and other keybinding tools.

import Gio from 'gi://Gio';

export const OBJECT_PATH = '/org/gnome/Shell/Extensions/GhosttyQuickTerminal';

const INTERFACE = `
<node>
  <interface name="is.abn.GhosttyQuickTerminal">
    <method name="Toggle"/>
    <method name="Show"/>
    <method name="Hide"/>
    <method name="ReloadConfig"/>
    <property name="Visible" type="b" access="read"/>
    <property name="HasWindow" type="b" access="read"/>
  </interface>
</node>`;

export class DBusApi {
    constructor(terminal, reloadConfig) {
        this._terminal = terminal;
        this._reloadConfig = reloadConfig;
        this._object = Gio.DBusExportedObject.wrapJSObject(INTERFACE, this);
        this._object.export(Gio.DBus.session, OBJECT_PATH);
    }

    Toggle() {
        this._terminal.toggle();
    }

    Show() {
        this._terminal.show();
    }

    Hide() {
        this._terminal.hide();
    }

    ReloadConfig() {
        this._reloadConfig();
    }

    get Visible() {
        return this._terminal.visible;
    }

    get HasWindow() {
        return this._terminal.hasWindow;
    }

    destroy() {
        this._object.unexport();
        this._object = null;
    }
}
