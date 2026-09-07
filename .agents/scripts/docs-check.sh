#!/usr/bin/env bash
# Validates the docs wiki as an OKF v0.2 bundle.
#
# Checks:
#   - bundle root index.md carries okf_version: "0.2"
#   - non-root index.md files carry no frontmatter
#   - every other page has frontmatter with a non-empty type field
#
# Privacy and editorial hygiene is not checked here. Those invariants apply
# to the whole tree and live in .pre-commit-config.yaml.
set -euo pipefail

docs=${1:-docs}
status=0

err() { printf 'docs-check: %s\n' "$1" >&2; status=1; }

has_frontmatter() { [[ "$(head -1 "$1")" == '---' ]]; }

frontmatter() {
  awk 'NR==1 && $0!="---" {exit} NR>1 && $0=="---" {exit} NR>1 {print}' "$1"
}

[[ -f "$docs/index.md" ]] || { err "missing $docs/index.md"; exit 1; }
grep -Eq '^okf_version: *"0\.2"' <(frontmatter "$docs/index.md") \
  || err "$docs/index.md must declare okf_version: \"0.2\""

while IFS= read -r -d '' page; do
  rel=${page#"$docs"/}
  case "$rel" in
    index.md|log.md) ;;
    */index.md)
      has_frontmatter "$page" && err "$rel: section index must not carry frontmatter" ;;
    *)
      if ! has_frontmatter "$page"; then
        err "$rel: missing frontmatter"
      elif ! grep -Eq '^type: *[A-Za-z]' <(frontmatter "$page"); then
        err "$rel: frontmatter needs a non-empty type field"
      fi ;;
  esac
done < <(find "$docs" -name '*.md' -print0 | sort -z)

(( status == 0 )) && printf 'docs-check: ok\n'
exit $status
