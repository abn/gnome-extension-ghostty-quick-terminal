import Adw from 'gi://Adw';
import Gdk from 'gi://Gdk';
import Gio from 'gi://Gio';
import GLib from 'gi://GLib';
import Gtk from 'gi://Gtk';

import {ExtensionPreferences} from 'resource:///org/gnome/Shell/Extensions/js/extensions/prefs.js';

const GHOSTTY_REFERENCE = 'https://ghostty.org/docs/config/reference#quick-terminal-position';

export default class GhosttyQuickTerminalPreferences extends ExtensionPreferences {
    fillPreferencesWindow(window) {
        const settings = this.getSettings();
        const page = new Adw.PreferencesPage();
        page.add(this._shortcutGroup(window, settings));
        page.add(this._terminalGroup(settings));
        page.add(this._ghosttyGroup(window));
        window.add(page);
    }

    _shortcutGroup(window, settings) {
        const group = new Adw.PreferencesGroup({title: 'Shortcut'});
        const row = new Adw.ActionRow({
            title: 'Toggle the terminal',
            subtitle: 'Shows, focuses or hides the quick terminal',
            activatable: true,
        });
        const label = new Gtk.ShortcutLabel({disabled_text: 'Not set', valign: Gtk.Align.CENTER});
        const sync = () => label.set_accelerator(settings.get_strv('toggle')[0] ?? '');
        sync();
        settings.connect('changed::toggle', sync);
        row.add_suffix(label);
        row.connect('activated', () => this._captureShortcut(window, settings));
        group.add(row);
        return group;
    }

    _terminalGroup(settings) {
        const group = new Adw.PreferencesGroup({title: 'Terminal'});

        const size = Adw.SpinRow.new_with_range(10, 100, 5);
        size.title = 'Size';
        size.subtitle = 'Percent of the work area along the drop axis';
        settings.bind('size', size, 'value', Gio.SettingsBindFlags.DEFAULT);
        group.add(size);

        const command = new Adw.EntryRow({title: 'Ghostty command'});
        settings.bind('ghostty-command', command, 'text', Gio.SettingsBindFlags.DEFAULT);
        group.add(command);

        const args = new Adw.EntryRow({title: 'Extra arguments', show_apply_button: true});
        args.text = settings.get_strv('extra-args').join(' ');
        args.connect('apply', () => {
            try {
                const [, argv] = GLib.shell_parse_argv(args.text);
                settings.set_strv('extra-args', argv);
            } catch {
                settings.set_strv('extra-args', []);
            }
        });
        group.add(args);
        return group;
    }

    _ghosttyGroup(window) {
        const group = new Adw.PreferencesGroup({
            title: 'From the Ghostty config',
            description: 'Position, autohide, animation duration and screen come from ' +
                'the quick-terminal keys in your Ghostty config and apply when the ' +
                'file is saved.',
        });
        const row = new Adw.ActionRow({
            title: 'Ghostty configuration reference',
            subtitle: 'quick-terminal-position and related keys',
            activatable: true,
        });
        row.add_suffix(new Gtk.Image({icon_name: 'adw-external-link-symbolic', valign: Gtk.Align.CENTER}));
        row.connect('activated', () => {
            new Gtk.UriLauncher({uri: GHOSTTY_REFERENCE}).launch(window, null, null);
        });
        group.add(row);
        return group;
    }

    _captureShortcut(parent, settings) {
        const dialog = new Adw.Dialog({title: 'Set shortcut', content_width: 360});
        const box = new Gtk.Box({
            orientation: Gtk.Orientation.VERTICAL,
            spacing: 12,
            margin_top: 24,
            margin_bottom: 24,
            margin_start: 24,
            margin_end: 24,
        });
        box.append(new Gtk.Label({label: 'Press a key combination.'}));
        box.append(new Gtk.Label({label: 'Backspace clears it. Escape cancels.', css_classes: ['dim-label']}));
        dialog.set_child(box);

        const controller = new Gtk.EventControllerKey();
        controller.connect('key-pressed', (ctrl, keyval, keycode, state) => {
            const mask = state & Gtk.accelerator_get_default_mod_mask();
            if (keyval === Gdk.KEY_Escape) {
                dialog.close();
                return Gdk.EVENT_STOP;
            }
            if (keyval === Gdk.KEY_BackSpace) {
                settings.set_strv('toggle', []);
                dialog.close();
                return Gdk.EVENT_STOP;
            }
            if (!Gtk.accelerator_valid(keyval, mask))
                return Gdk.EVENT_PROPAGATE;
            settings.set_strv('toggle', [Gtk.accelerator_name_with_keycode(null, keyval, keycode, mask)]);
            dialog.close();
            return Gdk.EVENT_STOP;
        });
        dialog.add_controller(controller);
        dialog.present(parent);
    }
}
