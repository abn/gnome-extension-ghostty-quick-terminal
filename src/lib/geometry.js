// Pure geometry for the drop-down window. No GNOME imports, unit tested.

export const POSITIONS = ['top', 'bottom', 'left', 'right', 'center'];
export const HANDLE_THICKNESS = 8;

function clamp(value, min, max) {
    return Math.min(max, Math.max(min, value));
}

function clampPercent(percent) {
    const n = Number(percent);
    if (!Number.isFinite(n))
        return 40;
    return Math.min(100, Math.max(10, Math.round(n)));
}

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

// Grab strip placed along the open edge of `rect`, clamped inside `workArea`
// so it stays reachable at 10% and 100% sizes.
export function handleRect(workArea, rect, position, thickness = HANDLE_THICKNESS) {
    const half = Math.floor(thickness / 2);
    const minY = workArea.y;
    const maxY = Math.max(minY, workArea.y + workArea.height - thickness);
    const minX = workArea.x;
    const maxX = Math.max(minX, workArea.x + workArea.width - thickness);
    switch (position) {
    case 'bottom':
        return {
            x: rect.x,
            y: clamp(rect.y - half, minY, maxY),
            width: rect.width,
            height: thickness,
            axis: 'vertical',
        };
    case 'left':
        return {
            x: clamp(rect.x + rect.width - half, minX, maxX),
            y: rect.y,
            width: thickness,
            height: rect.height,
            axis: 'horizontal',
        };
    case 'right':
        return {
            x: clamp(rect.x - half, minX, maxX),
            y: rect.y,
            width: thickness,
            height: rect.height,
            axis: 'horizontal',
        };
    case 'center':
    default:
        return {
            x: rect.x,
            y: clamp(rect.y + rect.height - half, minY, maxY),
            width: rect.width,
            height: thickness,
            axis: 'vertical',
        };
    }
}

// Clamped size percentage (10..100) for stage pointer coordinates.
export function sizePercentFromPointer(workArea, position, pointerX, pointerY) {
    if (workArea.width <= 0 || workArea.height <= 0)
        return 40;
    let raw;
    switch (position) {
    case 'bottom':
        raw = ((workArea.y + workArea.height - pointerY) / workArea.height) * 100;
        break;
    case 'left':
        raw = ((pointerX - workArea.x) / workArea.width) * 100;
        break;
    case 'right':
        raw = ((workArea.x + workArea.width - pointerX) / workArea.width) * 100;
        break;
    case 'center':
        raw = ((2 * (pointerY - (workArea.y + workArea.height / 2))) / workArea.height) * 100;
        break;
    default:
        raw = ((pointerY - workArea.y) / workArea.height) * 100;
        break;
    }
    return clampPercent(raw);
}

// Clamped size percentage (10..100) for a window frame rectangle.
export function sizePercentFromRect(workArea, rect, position) {
    if (workArea.width <= 0 || workArea.height <= 0)
        return 40;
    const ratio = position === 'left' || position === 'right'
        ? rect.width / workArea.width
        : rect.height / workArea.height;
    return clampPercent(ratio * 100);
}
