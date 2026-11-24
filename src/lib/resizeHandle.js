// Invisible grab strip along the open edge of the quick terminal window.
// Lets the user drag-resize the drop-down even without window decorations.

import Clutter from 'gi://Clutter';

export class ResizeHandle {
    constructor({onResize, onResizeEnd}) {
        this._onResize = onResize;
        this._onResizeEnd = onResizeEnd;
        this._grab = null;
        this._dragging = false;

        this._actor = new Clutter.Actor({
            reactive: true,
            visible: false,
        });
        this._panGesture = new Clutter.PanGesture({
            required_button: Clutter.BUTTON_PRIMARY,
        });
        this._panGesture.set_begin_threshold(0);
        this._recognizeId = this._panGesture.connect('recognize', () => this._onBegin());
        this._updateId = this._panGesture.connect('pan-update', () => this._onUpdate());
        this._endId = this._panGesture.connect('end', () => this._onEnd(false));
        this._cancelId = this._panGesture.connect('cancel', () => this._onEnd(true));
        this._actor.add_action(this._panGesture);
        global.window_group.add_child(this._actor);
    }

    get actor() {
        return this._actor;
    }

    get dragging() {
        return this._dragging;
    }

    update(windowActor, rect) {
        this._actor.set_position(rect.x, rect.y);
        this._actor.set_size(rect.width, rect.height);
        this._actor.set_cursor_type(rect.axis === 'horizontal'
            ? Clutter.CursorType.EW_RESIZE
            : Clutter.CursorType.NS_RESIZE);
        const parent = this._actor.get_parent();
        if (parent && windowActor.get_parent() === parent)
            parent.set_child_above_sibling(this._actor, windowActor);
    }

    show() {
        this._actor.show();
    }

    hide() {
        this._dismissGrab();
        this._actor.hide();
    }

    destroy() {
        this._dismissGrab();
        if (this._panGesture) {
            this._panGesture.disconnect(this._recognizeId);
            this._panGesture.disconnect(this._updateId);
            this._panGesture.disconnect(this._endId);
            this._panGesture.disconnect(this._cancelId);
            this._actor.remove_action(this._panGesture);
            this._panGesture = null;
        }
        this._actor.destroy();
        this._actor = null;
    }

    _onBegin() {
        this._dragging = true;
        this._grab = global.stage.grab(this._actor);
    }

    _onUpdate() {
        if (!this._dragging)
            return;
        const coords = this._panGesture.get_centroid_abs();
        this._onResize(coords.x, coords.y);
    }

    _onEnd(cancelled) {
        if (!this._dragging)
            return;
        this._dismissGrab();
        this._onResizeEnd(cancelled);
    }

    _dismissGrab() {
        if (this._grab) {
            this._grab.dismiss();
            this._grab = null;
        }
        this._dragging = false;
    }
}
