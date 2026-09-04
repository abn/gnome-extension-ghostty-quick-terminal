// Mirrors the rules GNOME Shell applies to its own extensions, as the
// extensions.gnome.org review guidelines recommend.
import {defineConfig} from '@eslint/config-helpers';
import gnome from 'eslint-config-gnome';

export default defineConfig([
    {
        ignores: ['dist/', 'build/', 'node_modules/'],
    },
    gnome.configs.recommended,
    {
        rules: {
            camelcase: ['error', {properties: 'never'}],
            'consistent-return': 'error',
            'eqeqeq': ['error', 'smart'],
            'key-spacing': ['error', {mode: 'minimum', beforeColon: false, afterColon: true}],
            'prefer-arrow-callback': 'error',
            'prefer-const': ['error', {destructuring: 'all'}],
        },
    },
    {
        files: ['src/**/*.js'],
        languageOptions: {
            globals: {
                global: 'readonly',
            },
        },
    },
]);
