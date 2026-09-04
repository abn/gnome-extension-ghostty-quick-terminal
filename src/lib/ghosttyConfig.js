// Parses `ghostty +show-config` output into the settings the extension
// takes from Ghostty. No GNOME imports, unit tested.

import {POSITIONS} from './geometry.js';

export const DEFAULT_CONFIG = Object.freeze({
    position: 'top',
    autohide: false,
    animationMs: 200,
    screen: 'primary',
});

// Returns a Map from key to the list of values seen, in order. Repeated
// keys such as keybind accumulate; for scalar keys the last value wins.
export function parseShowConfig(text) {
    const map = new Map();
    for (const raw of text.split('\n')) {
        const line = raw.trim();
        if (line === '' || line.startsWith('#'))
            continue;
        const eq = line.indexOf('=');
        if (eq < 0)
            continue;
        const key = line.slice(0, eq).trim();
        const value = line.slice(eq + 1).trim();
        if (!map.has(key))
            map.set(key, []);
        map.get(key).push(value);
    }
    return map;
}

function last(map, key) {
    const values = map.get(key);
    return values ? values[values.length - 1] : undefined;
}

export function quickTerminalSettings(map) {
    const position = last(map, 'quick-terminal-position');
    const autohide = last(map, 'quick-terminal-autohide');
    const duration = Number(last(map, 'quick-terminal-animation-duration'));
    const screen = last(map, 'quick-terminal-screen');
    return {
        position: POSITIONS.includes(position) ? position : DEFAULT_CONFIG.position,
        autohide: autohide === 'true',
        animationMs: Number.isFinite(duration) && duration >= 0
            ? Math.min(2000, Math.round(duration * 1000))
            : DEFAULT_CONFIG.animationMs,
        screen: screen === 'mouse' ? 'pointer' : 'primary',
    };
}
