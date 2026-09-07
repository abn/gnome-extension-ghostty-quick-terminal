#!/usr/bin/env bash
# Idempotent repository bootstrap. Safe to re-run at any time.
# Installs the pre-commit hooks and writes git-excluded tool shims so the
# committed tree stays free of assistant-specific files.
set -euo pipefail

root=$(git rev-parse --show-toplevel)
cd "$root"

# An earlier layout pointed git at committed hook scripts. pre-commit refuses
# to install while that is set, so clear it.
git config --unset core.hooksPath 2>/dev/null || true
pre-commit install --install-hooks

# Tool shim: only points at AGENTS.md. Listed in .gitignore.
printf 'Read AGENTS.md and follow it.\n' > CLAUDE.md

mkdir -p .agents/brain/inbox .agents/brain/outbox .agents/brain/tasks .agents/brain/assets

printf 'bootstrap: hooks installed, shims written, working area ready\n'
