#!/bin/bash

# Only runs in remote environments
if [ "$CLAUDE_CODE_REMOTE" != "true" ]; then
    exit 0
fi

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR/../../../.."

echo "Installing system dependencies..."
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq 2>/dev/null || true
apt-get install -y -qq jq graphviz poppler-utils libreoffice-calc unzip >/dev/null 2>&1 || true

echo "Installing Python packages..."
uv pip install --system 'markitdown[pptx]' defusedxml semgrep --quiet

echo "Installing Node packages..."
bun install -g agent-browser pptxgenjs playwright react-icons react react-dom sharp --silent
agent-browser install >/dev/null 2>&1 || true
bunx playwright install chromium --quiet >/dev/null 2>&1

echo "Installing CodeQL..."
if ! command -v codeql &>/dev/null; then
    if curl -sL --max-time 10 https://github.com/github/codeql-cli-binaries/releases/latest/download/codeql-linux64.zip -o /tmp/codeql.zip 2>/dev/null; then
        unzip -q /tmp/codeql.zip -d /usr/local/
        ln -sf /usr/local/codeql/codeql /usr/local/bin/codeql
        rm -f /tmp/codeql.zip
    else
        echo "  Skipping CodeQL (download blocked by proxy)"
    fi
fi

if [ -f "$PROJECT_ROOT/package.json" ]; then
    echo "Installing project dependencies..."
    cd "$PROJECT_ROOT"
    bun install
fi

echo "Remote environment setup complete"
