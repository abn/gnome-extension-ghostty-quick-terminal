#!/usr/bin/env bash
# Idempotent repository bootstrap. Safe to re-run at any time.
# Installs the committed git hooks and writes git-excluded tool shims so the
# committed tree stays free of assistant-specific files.
set -euo pipefail

root=$(git rev-parse --show-toplevel)
cd "$root"

git config core.hooksPath .agents/hooks
chmod +x .agents/hooks/* .agents/scripts/*.sh

# Tool shims: each one only points at AGENTS.md. Listed in .gitignore.
for shim in CLAUDE.md; do
  printf 'Read AGENTS.md and follow it.\n' > "$shim"
done

mkdir -p .scratch/inbox .scratch/outbox .scratch/tasks .scratch/assets

printf 'bootstrap: hooks installed, shims written, scratch area ready\n'
