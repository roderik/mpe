#!/bin/bash
set -e

REPO="roderik/mpe"
BRANCH="main"
BASE_URL="https://raw.githubusercontent.com/$REPO/$BRANCH"

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
bash .agents/setup.sh

echo "Done! Skills installed to .agents/skills/"
