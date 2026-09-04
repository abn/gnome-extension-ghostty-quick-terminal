// Unit tests for the pure modules. Run with: gjs -m tests/run.js
import System from 'system';
import {clampFraction, targetRect, hiddenState, sameRect} from '../src/lib/geometry.js';
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
