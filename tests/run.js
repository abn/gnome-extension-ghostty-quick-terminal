// Unit tests for the pure modules. Run with: gjs -m tests/run.js
import System from 'system';
import {
    clampFraction,
    handleRect,
    hiddenState,
    sameRect,
    sizePercentFromPointer,
    sizePercentFromRect,
    targetRect,
} from '../src/lib/geometry.js';
import {parseShowConfig, quickTerminalSettings, DEFAULT_CONFIG} from '../src/lib/ghosttyConfig.js';

let failures = 0;
function eq(actual, expected, name) {
    const a = JSON.stringify(actual);
    const e = JSON.stringify(expected);
    if (a === e) {
        print(`ok   ${name}`);
    } else {
        failures++;
        print(`FAIL ${name}\n     expected ${e}\n     got      ${a}`);
    }
}

const wa = {x: 0, y: 32, width: 1280, height: 768};

eq(clampFraction(40), 0.4, 'fraction from percent');
eq(clampFraction(5), 0.1, 'fraction clamps low');
eq(clampFraction(250), 1, 'fraction clamps high');
eq(clampFraction('x'), 0.4, 'fraction falls back on garbage');

eq(targetRect(wa, 'top', 0.4), {x: 0, y: 32, width: 1280, height: 307}, 'top rect');
eq(targetRect(wa, 'bottom', 0.4), {x: 0, y: 493, width: 1280, height: 307}, 'bottom rect');
eq(targetRect(wa, 'left', 0.5), {x: 0, y: 32, width: 640, height: 768}, 'left rect');
eq(targetRect(wa, 'right', 0.5), {x: 640, y: 32, width: 640, height: 768}, 'right rect');
eq(targetRect(wa, 'center', 0.5), {x: 320, y: 224, width: 640, height: 384}, 'center rect');
eq(targetRect(wa, 'bogus', 0.4), targetRect(wa, 'top', 0.4), 'unknown position acts as top');

const rect = {x: 0, y: 32, width: 1280, height: 307};
eq(hiddenState('top', rect), {x: 0, y: -307, opacity: 255}, 'hidden above the top');
eq(hiddenState('bottom', rect), {x: 0, y: 307, opacity: 255}, 'hidden below the bottom');
eq(hiddenState('left', rect), {x: -1280, y: 0, opacity: 255}, 'hidden left');
eq(hiddenState('right', rect), {x: 1280, y: 0, opacity: 255}, 'hidden right');
eq(hiddenState('center', rect), {x: 0, y: 0, opacity: 0}, 'center fades');

eq(sameRect(rect, {...rect}), true, 'same rect');
eq(sameRect(rect, {...rect, height: 1}), false, 'different rect');

eq(handleRect(wa, targetRect(wa, 'top', 0.4), 'top'), {x: 0, y: 335, width: 1280, height: 8, axis: 'vertical'}, 'top handle rect');
eq(handleRect(wa, targetRect(wa, 'bottom', 0.4), 'bottom'), {x: 0, y: 489, width: 1280, height: 8, axis: 'vertical'}, 'bottom handle rect');
eq(handleRect(wa, targetRect(wa, 'left', 0.5), 'left'), {x: 636, y: 32, width: 8, height: 768, axis: 'horizontal'}, 'left handle rect');
eq(handleRect(wa, targetRect(wa, 'right', 0.5), 'right'), {x: 636, y: 32, width: 8, height: 768, axis: 'horizontal'}, 'right handle rect');
eq(handleRect(wa, targetRect(wa, 'center', 0.5), 'center'), {x: 320, y: 604, width: 640, height: 8, axis: 'vertical'}, 'center handle rect');
eq(handleRect(wa, targetRect(wa, 'top', 1), 'top'), {x: 0, y: 792, width: 1280, height: 8, axis: 'vertical'}, 'top handle clamps inside work area at 100%');
eq(handleRect(wa, targetRect(wa, 'bottom', 1), 'bottom'), {x: 0, y: 32, width: 1280, height: 8, axis: 'vertical'}, 'bottom handle clamps inside work area at 100%');

eq(sizePercentFromPointer(wa, 'top', 100, 32 + 384), 50, 'pointer percent top');
eq(sizePercentFromPointer(wa, 'bottom', 100, 32 + 384), 50, 'pointer percent bottom');
eq(sizePercentFromPointer(wa, 'left', 320, 100), 25, 'pointer percent left');
eq(sizePercentFromPointer(wa, 'right', 960, 100), 25, 'pointer percent right');
eq(sizePercentFromPointer(wa, 'center', 640, 32 + 384 + 192), 50, 'pointer percent center');
eq(sizePercentFromPointer(wa, 'top', 100, 0), 10, 'pointer percent clamps low');
eq(sizePercentFromPointer(wa, 'top', 100, 999), 100, 'pointer percent clamps high');

eq(sizePercentFromRect(wa, {x: 0, y: 32, width: 1280, height: 384}, 'top'), 50, 'rect percent top');
eq(sizePercentFromRect(wa, {x: 0, y: 32, width: 320, height: 768}, 'left'), 25, 'rect percent left');
eq(sizePercentFromRect(wa, {x: 0, y: 32, width: 1280, height: 10}, 'top'), 10, 'rect percent clamps low');

const sample = `
# comment
font-family = JetBrains Mono
keybind = ctrl+shift+t=new_tab
keybind = super+grave=toggle_quick_terminal
quick-terminal-position = bottom
quick-terminal-autohide = true
quick-terminal-animation-duration = 0.35
quick-terminal-screen = mouse
title =
`;
const map = parseShowConfig(sample);
eq(map.get('keybind'), ['ctrl+shift+t=new_tab', 'super+grave=toggle_quick_terminal'], 'repeated keys accumulate');
eq(map.get('title'), [''], 'empty value parses');
eq(map.has('# comment'), false, 'comments skipped');
eq(quickTerminalSettings(map), {position: 'bottom', autohide: true, animationMs: 350, screen: 'pointer'}, 'quick terminal settings');
eq(quickTerminalSettings(new Map()), DEFAULT_CONFIG, 'defaults when keys are absent');
eq(quickTerminalSettings(parseShowConfig('quick-terminal-position = diagonal\nquick-terminal-animation-duration = -1')),
    DEFAULT_CONFIG, 'invalid values fall back');
eq(quickTerminalSettings(parseShowConfig('quick-terminal-animation-duration = 0')).animationMs, 0, 'zero disables animation');
eq(quickTerminalSettings(parseShowConfig('quick-terminal-animation-duration = 9')).animationMs, 2000, 'duration is capped');

print(failures === 0 ? 'all tests passed' : `${failures} failure(s)`);
System.exit(failures === 0 ? 0 : 1);
