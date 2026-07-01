#!/usr/bin/env bash
set -euo pipefail

# Generate CLAUDE.md from .cursor/rules/*.mdc
# Usage:
#   ./sync-claude-md.sh
#   ./sync-claude-md.sh <rules_dir> <output_file>

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_RULES_DIR="${SCRIPT_DIR}/.cursor/rules"
DEFAULT_OUTPUT_FILE="${HOME}/.claude/CLAUDE.md"

RULES_DIR="${1:-$DEFAULT_RULES_DIR}"
OUTPUT_FILE="${2:-$DEFAULT_OUTPUT_FILE}"

if [[ ! -d "$RULES_DIR" ]]; then
  echo "Rules directory not found: $RULES_DIR" >&2
  exit 1
fi

shopt -s nullglob
rule_files=( "$RULES_DIR"/*.mdc )
shopt -u nullglob

if (( ${#rule_files[@]} == 0 )); then
  echo "No .mdc rule files found in: $RULES_DIR" >&2
  exit 1
fi

IFS=$'\n' rule_files=( $(printf '%s\n' "${rule_files[@]}" | sort) )

tmp_file="$(mktemp "${TMPDIR:-/tmp}/claude-md.XXXXXX")"
trap 'rm -f "$tmp_file"' EXIT

{
  echo "# CLAUDE.md"
  echo

  for file in "${rule_files[@]}"; do
    base_name="$(basename "$file")"
    body="$(
      awk '
        BEGIN { fm = 0; fm_done = 0 }
        /^---[[:space:]]*$/ {
          if (fm_done == 0) {
            fm++
            if (fm == 2) {
              fm_done = 1
            }
            next
          }
        }
        fm_done == 1 { print }
      ' "$file"
    )"

    echo
    printf '%s\n' "$body"
    echo
  done
} > "$tmp_file"

mkdir -p "$(dirname "$OUTPUT_FILE")"
mv "$tmp_file" "$OUTPUT_FILE"
trap - EXIT

echo "Generated ${OUTPUT_FILE} from ${#rule_files[@]} rule file(s)."
