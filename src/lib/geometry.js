// Pure geometry for the drop-down window. No GNOME imports, unit tested.

export const POSITIONS = ['top', 'bottom', 'left', 'right', 'center'];

// Percent of the work area along the drop axis, clamped to 10..100 and
// returned as a fraction.
export function clampFraction(percent) {
    const n = Number(percent);
    if (!Number.isFinite(n))
        return 0.4;
    return Math.min(100, Math.max(10, n)) / 100;
}

// Target frame rectangle for a window anchored at `position` inside
// `workArea`, taking `fraction` of the axis it drops along.
export function targetRect(workArea, position, fraction) {
    const {x, y, width, height} = workArea;
    const h = Math.floor(height * fraction);
    const w = Math.floor(width * fraction);
    switch (position) {
    case 'bottom':
        return {x, y: y + height - h, width, height: h};
    case 'left':
        return {x, y, width: w, height};
    case 'right':
        return {x: x + width - w, y, width: w, height};
    case 'center':
        return {
            x: x + Math.floor((width - w) / 2),
            y: y + Math.floor((height - h) / 2),
            width: w,
            height: h,
        };
    default:
        return {x, y, width, height: h};
    }
}

// Actor translation and opacity that put a window at `position` out of
// sight. Edge positions slide off their edge; center fades.
export function hiddenState(position, rect) {
    switch (position) {
    case 'bottom':
        return {x: 0, y: rect.height, opacity: 255};
    case 'left':
        return {x: -rect.width, y: 0, opacity: 255};
    case 'right':
        return {x: rect.width, y: 0, opacity: 255};
    case 'center':
        return {x: 0, y: 0, opacity: 0};
    default:
        return {x: 0, y: -rect.height, opacity: 255};
    }
}

export function sameRect(a, b) {
    return a.x === b.x && a.y === b.y && a.width === b.width && a.height === b.height;
}
