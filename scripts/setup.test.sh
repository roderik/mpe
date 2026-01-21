#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SETUP_SH="$ROOT_DIR/setup.sh"

if [[ ! -f "$SETUP_SH" ]]; then
  echo "setup.sh not found at $SETUP_SH"
  exit 1
fi

tmp_dir=$(mktemp -d)
cleanup() {
  rm -rf "$tmp_dir"
}
trap cleanup EXIT

(
  cd "$tmp_dir"
  bash "$SETUP_SH" --skip-skills --skip-postinstall --skip-codex-mcp >"$tmp_dir/output.log" 2>&1
)

required_paths=(
  ".agents/setup.sh"
  ".agents/setup.json"
  ".agents/templates/CLAUDE.md"
  ".agents/templates/AGENTS.md"
  ".agents/templates/.claude/settings.json"
  ".agents/skills/test-driven-development/SKILL.md"
  ".claude/settings.json"
  "CLAUDE.md"
  "AGENTS.md"
  ".mcp.json"
)

for path in "${required_paths[@]}"; do
  if [[ ! -e "$tmp_dir/$path" ]]; then
    echo "Missing expected file: $path"
    echo "Setup output:"
    cat "$tmp_dir/output.log"
    exit 1
  fi
done

echo "setup.sh created expected files in $tmp_dir"
