// wl-copy and wl-paste map a tiny surface titled "wl-clipboard" to obtain
// a serial, take focus for an instant, then unmap. Autohide must not treat
// that as the user leaving, and a window kept above must not starve it of
// the focus it needs. This module answers "is that window one of them".

import Gio from 'gi://Gio';
import GLib from 'gi://GLib';
import Meta from 'gi://Meta';

const TITLE = 'wl-clipboard';
const TOOLS = ['wl-copy', 'wl-paste'];

// Cheap synchronous test used to decide whether the async one is worth it.
export function looksLikeWlClipboard(window) {
    return window.get_client_type() === Meta.WindowClientType.WAYLAND &&
        window.get_title() === TITLE;
}

// Confirms the window's process really is wl-copy or wl-paste by reading
// its command line. Rejects with Gio.IOErrorEnum.CANCELLED on cancel.
export async function isWlClipboard(window, cancellable) {
    if (!looksLikeWlClipboard(window))
        return false;
    Gio._promisify(Gio.File.prototype, 'load_contents_async');
    const file = Gio.File.new_for_path(`/proc/${window.get_pid()}/cmdline`);
    let bytes;
    try {
        [bytes] = await file.load_contents_async(cancellable);
    } catch (e) {
        if (e instanceof GLib.Error && e.matches(Gio.IOErrorEnum, Gio.IOErrorEnum.CANCELLED))
            throw e;
        return false;
    }
    const end = bytes.indexOf(0);
    const argv0 = new TextDecoder().decode(bytes.subarray(0, end < 0 ? bytes.length : end));
    return TOOLS.includes(GLib.path_get_basename(argv0));
}
