#!/bin/bash
set -e

REPO="roderik/mpe"
BRANCH="main"
BASE_URL="https://raw.githubusercontent.com/$REPO/$BRANCH"
ARGS=("$@")

ensure_jq() {
    if command -v jq &>/dev/null; then
        return
    fi

    echo "jq not found. Attempting to install..."

    if command -v brew &>/dev/null; then
        brew install jq
    elif command -v apt-get &>/dev/null; then
        if [[ "$(id -u)" -eq 0 ]]; then
            apt-get update -qq && apt-get install -y jq
        elif command -v sudo &>/dev/null; then
            sudo -n apt-get update -qq && sudo -n apt-get install -y jq
        else
            echo "Error: jq is required. Install jq or run this script with sudo."
            exit 1
        fi
    elif command -v dnf &>/dev/null; then
        if [[ "$(id -u)" -eq 0 ]]; then
            dnf install -y jq
        elif command -v sudo &>/dev/null; then
            sudo -n dnf install -y jq
        else
            echo "Error: jq is required. Install jq or run this script with sudo."
            exit 1
        fi
    elif command -v yum &>/dev/null; then
        if [[ "$(id -u)" -eq 0 ]]; then
            yum install -y jq
        elif command -v sudo &>/dev/null; then
            sudo -n yum install -y jq
        else
            echo "Error: jq is required. Install jq or run this script with sudo."
            exit 1
        fi
    else
        echo "Error: jq is required but no supported package manager was found."
        exit 1
    fi

    if ! command -v jq &>/dev/null; then
        echo "Error: jq install failed. Please install jq manually."
        exit 1
    fi
}

echo "Setting up agent skills..."

# Create .agents directory
mkdir -p .agents

# Download setup files
echo "Downloading configuration..."
curl -sL "$BASE_URL/.agents/setup.json" -o .agents/setup.json
curl -sL "$BASE_URL/.agents/setup.sh" -o .agents/setup.sh
chmod +x .agents/setup.sh

# Run the setup
echo "Installing skills..."
ensure_jq
bash .agents/setup.sh "${ARGS[@]}"

echo "Done! Skills installed to .agents/skills/"
