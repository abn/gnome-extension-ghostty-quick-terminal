#!/usr/bin/env bash
# Validates the docs wiki as an OKF v0.2 bundle and enforces privacy hygiene.
#
# Checks:
#   - bundle root index.md carries okf_version: "0.2"
#   - non-root index.md files carry no frontmatter
#   - every other page has frontmatter with a non-empty type field
#   - no absolute user paths, file:// URIs, em-dashes or obvious secrets
set -euo pipefail

docs=${1:-docs}
status=0

err() { printf 'docs-check: %s\n' "$1" >&2; status=1; }

# Reports every line in $2 matching regex $3, labelled $4. Empty match is fine.
hygiene() {
  local hits
  hits=$(grep -nE "$3" "$2" || true)
  [[ -z "$hits" ]] || while IFS= read -r hit; do err "$1:$hit: $4"; done <<< "$hits"
}

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

  hygiene "$rel" "$page" '/home/[a-z]|/Users/[A-Za-z]' 'absolute user path'
  hygiene "$rel" "$page" 'file://' 'file:// URI'
  hygiene "$rel" "$page" "$(printf '\xe2\x80\x94')" 'em-dash'
  hygiene "$rel" "$page" '(api[_-]?key|secret|token)[=:] *[A-Za-z0-9_-]{16,}' 'possible secret'
done < <(find "$docs" -name '*.md' -print0 | sort -z)

(( status == 0 )) && printf 'docs-check: ok\n'
exit $status
