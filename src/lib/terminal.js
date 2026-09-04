// The window state machine. Owns one Ghostty client and its window, and
// does what a layer shell would: placement, stacking, workspaces, show and
// hide with a slide.

import Clutter from 'gi://Clutter';
import Gio from 'gi://Gio';
import GLib from 'gi://GLib';

import * as Main from 'resource:///org/gnome/shell/ui/main.js';

import {clampFraction, hiddenState, sameRect, targetRect} from './geometry.js';
import {DEFAULT_CONFIG} from './ghosttyConfig.js';
import {isWlClipboard, looksLikeWlClipboard} from './wlclipboard.js';

const FIXUP_LIMIT = 10;

export class QuickTerminal {
    constructor({settings, launch}) {
        this._settings = settings;
        this._launch = launch;
        this._config = DEFAULT_CONFIG;
        this._client = null;
        this._window = null;
        this._actor = null;
        this._target = null;
        this._state = 'hidden';
        this._fixup = null;
        this._unmanagedId = 0;
        this._mapId = 0;
        this._focusCheck = null;
        this._clipboardWatch = new Map();
        this._windowCreatedId = global.display.connect('window-created',
            (display, window) => this._onWindowCreated(window));
        this._focusId = global.display.connect('notify::focus-window',
            () => this._onFocusChanged());
        this._workareasId = global.display.connect('workareas-changed',
            () => this._place());
    }

    get visible() {
        return this._state === 'visible' || this._state === 'showing';
    }

    get hasWindow() {
        return this._window !== null;
    }

    setConfig(config) {
        this._config = config;
        this._place();
    }

    // Re-applies placement after the size setting changed.
    replace() {
        this._place();
    }

    // Adopts a client launched earlier, for instance before a screen lock.
    adopt(client) {
        this._client = client;
        client.onExit = () => this._onClientExit(client);
        this._adoptOwnedWindow();
    }

    // Takes the first window the client owns, if any. Used after a lock and
    // when the current window closes while the process has another one.
    _adoptOwnedWindow() {
        if (!this._client?.alive)
            return;
        for (const actor of global.get_window_actors()) {
            const window = actor.meta_window;
            if (this._client.ownsWindow(window)) {
                this._attach(window);
                this._state = window.minimized ? 'hidden' : 'visible';
                return;
            }
        }
    }

    toggle() {
        if (this.visible && this._window.has_focus())
            this.hide();
        else
            this.show();
    }

    show() {
        if (!this._client?.alive) {
            try {
                this._client = this._launch();
            } catch (e) {
                this._state = 'hidden';
                console.warn(`Ghostty Quick Terminal: could not launch Ghostty: ${e.message}`);
                return;
            }
            this._state = 'launching';
            this._client.onExit = () => this._onClientExit(this._client);
            return;
        }
        if (!this._window) {
            this._state = 'launching';
            return;
        }

        const window = this._window;
        const actor = this._actor;
        this._place();
        actor.remove_all_transitions();
        if (window.minimized) {
            Main.wm.skipNextEffect(actor);
            window.unminimize();
        }
        Main.activateWindow(window);
        if (!this.visible)
            this._setActorState(hiddenState(this._config.position, this._target));
        this._state = 'showing';
        this._ease({x: 0, y: 0, opacity: 255}, Clutter.AnimationMode.EASE_OUT_QUAD,
            () => (this._state = 'visible'));
    }

    hide() {
        if (!this._window || this._state === 'hidden' || this._state === 'hiding')
            return;
        const window = this._window;
        const actor = this._actor;
        this._state = 'hiding';
        actor.remove_all_transitions();
        this._ease(hiddenState(this._config.position, this._target), Clutter.AnimationMode.EASE_IN_QUAD, () => {
            Main.wm.skipNextEffect(actor);
            // Mutter refuses to minimize a window hidden from the window
            // list, so lift that for the duration of the call.
            window.show_in_window_list();
            window.minimize();
            window.hide_from_window_list();
            this._setActorState({x: 0, y: 0, opacity: 255});
            this._state = 'hidden';
        });
    }

    // Releases everything. Returns the client so the caller can decide
    // whether it lives on.
    destroy() {
        global.display.disconnect(this._windowCreatedId);
        global.display.disconnect(this._focusId);
        global.display.disconnect(this._workareasId);
        this._cancelFocusCheck();
        for (const window of [...this._clipboardWatch.keys()])
            this._unwatchClipboard(window);
        if (this._actor) {
            this._actor.remove_all_transitions();
            this._setActorState({x: 0, y: 0, opacity: 255});
        }
        this._detach();
        const client = this._client;
        if (client)
            client.onExit = null;
        this._client = null;
        return client;
    }

    _ease(state, mode, onComplete) {
        const duration = this._config.animationMs;
        if (duration === 0) {
            this._setActorState(state);
            onComplete();
            return;
        }
        this._actor.ease({
            translation_x: state.x,
            translation_y: state.y,
            opacity: state.opacity,
            duration,
            mode,
            onComplete,
        });
    }

    _setActorState({x, y, opacity}) {
        this._actor.translation_x = x;
        this._actor.translation_y = y;
        this._actor.opacity = opacity;
    }

    _onWindowCreated(window) {
        if (this._window && this.visible && this._window.above)
            this._watchClipboard(window);
        if (this._window || !this._client?.ownsWindow(window))
            return;
        this._attach(window);
        // Take over the first map: skip the shell's zoom and slide instead.
        Main.wm.skipNextEffect(this._actor);
        this._setActorState(hiddenState(this._config.position, this._target));
        this._mapId = global.window_manager.connect('map', (wm, actor) => {
            if (actor !== this._actor)
                return;
            global.window_manager.disconnect(this._mapId);
            this._mapId = 0;
            this._state = 'hidden';
            this.show();
        });
    }

    _attach(window) {
        this._window = window;
        this._actor = window.get_compositor_private();
        window.hide_from_window_list();
        if (!window.is_on_all_workspaces())
            window.stick();
        if (!window.above)
            window.make_above();
        this._unmanagedId = window.connect('unmanaged', () => this._onUnmanaged());
        this._place();
    }

    _onUnmanaged() {
        this._detach();
        this._adoptOwnedWindow();
    }

    _detach() {
        if (this._mapId)
            global.window_manager.disconnect(this._mapId);
        this._mapId = 0;
        this._disarmFixup();
        if (this._window && this._unmanagedId)
            this._window.disconnect(this._unmanagedId);
        this._unmanagedId = 0;
        this._window = null;
        this._actor = null;
        this._target = null;
        this._state = 'hidden';
    }

    _onClientExit(client) {
        if (client !== this._client)
            return;
        this._client = null;
        if (this._state === 'launching')
            this._state = 'hidden';
    }

    _monitorIndex() {
        return this._config.screen === 'pointer'
            ? global.display.get_current_monitor()
            : Main.layoutManager.primaryIndex;
    }

    _place() {
        if (!this._window)
            return;
        const monitor = this._monitorIndex();
        if (this._window.get_monitor() !== monitor)
            this._window.move_to_monitor(monitor);
        const workArea = Main.layoutManager.getWorkAreaForMonitor(monitor);
        this._target = targetRect(workArea, this._config.position,
            clampFraction(this._settings.get_int('size')));
        this._applyGeometry();
    }

    // Wayland clients own their size, so keep asking until the frame
    // matches, then stop listening.
    _applyGeometry() {
        const {x, y, width, height} = this._target;
        this._window.move_resize_frame(false, x, y, width, height);
        if (sameRect(this._window.get_frame_rect(), this._target)) {
            this._disarmFixup();
            return;
        }
        if (this._fixup)
            return;
        this._fixup = {attempts: 0, ids: []};
        for (const signal of ['size-changed', 'position-changed']) {
            this._fixup.ids.push(this._window.connect(signal, () => {
                if (++this._fixup.attempts > FIXUP_LIMIT)
                    this._disarmFixup();
                else
                    this._applyGeometry();
            }));
        }
    }

    _disarmFixup() {
        if (!this._fixup)
            return;
        for (const id of this._fixup.ids)
            this._window.disconnect(id);
        this._fixup = null;
    }

    _onFocusChanged() {
        this._cancelFocusCheck();
        if (!this.visible || !this._config.autohide)
            return;
        const focus = global.display.focus_window;
        if (!focus || focus === this._window || focus.get_transient_for() === this._window)
            return;
        if (!looksLikeWlClipboard(focus)) {
            this.hide();
            return;
        }
        // A clipboard tool borrowing focus for an instant is not the user
        // leaving. Confirm before deciding, and let a newer focus change win.
        const check = new Gio.Cancellable();
        this._focusCheck = check;
        isWlClipboard(focus, check).then(clipboard => {
            if (this._focusCheck !== check)
                return;
            this._focusCheck = null;
            if (!clipboard && this.visible)
                this.hide();
        }).catch(e => {
            if (!(e instanceof GLib.Error && e.matches(Gio.IOErrorEnum, Gio.IOErrorEnum.CANCELLED)))
                console.warn(`Ghostty Quick Terminal: focus check failed: ${e.message}`);
        });
    }

    _cancelFocusCheck() {
        this._focusCheck?.cancel();
        this._focusCheck = null;
    }

    // While the terminal is above, a wl-clipboard surface can map without
    // ever receiving focus, and wl-copy then hangs. Hand it the focus.
    _watchClipboard(window) {
        const watch = {ids: [], cancellable: null};
        const check = () => {
            if (watch.cancellable || !looksLikeWlClipboard(window))
                return;
            watch.cancellable = new Gio.Cancellable();
            isWlClipboard(window, watch.cancellable).then(clipboard => {
                this._unwatchClipboard(window);
                if (clipboard && !window.is_hidden())
                    window.focus(global.get_current_time());
            }).catch(() => {});
        };
        watch.ids.push(window.connect('notify::title', check));
        // Once shown under any other title it is an ordinary window.
        watch.ids.push(window.connect('shown', () => {
            if (looksLikeWlClipboard(window))
                check();
            else if (!watch.cancellable)
                this._unwatchClipboard(window);
        }));
        watch.ids.push(window.connect('unmanaged', () => this._unwatchClipboard(window)));
        this._clipboardWatch.set(window, watch);
        check();
    }

    _unwatchClipboard(window) {
        const watch = this._clipboardWatch.get(window);
        if (!watch)
            return;
        watch.cancellable?.cancel();
        for (const id of watch.ids)
            window.disconnect(id);
        this._clipboardWatch.delete(window);
    }
}
