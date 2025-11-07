#!/usr/bin/env bash

set -euo pipefail

usage() {
  echo "Usage: $0 <owner/repository>"
  echo "  Checks if a GitHub repository exists."
  echo
  echo "Example: $0 dave/dave"
  exit 1
}

if [[ $# -eq 0 ]]; then
  echo "Error: Missing repository slug argument." >&2
  usage
fi

REPO_SLUG="$1"

if ! command -v gh &>/dev/null; then
  echo "Error: gh-cli is not installed. Please install it to use this script." >&2
  echo "See: https://cli.github.com/" >&2
  exit 1
fi

if ! gh auth status &>/dev/null; then
  echo "Error: Not logged into GitHub. Please run 'gh auth login'." >&2
  exit 1
fi

echo "Checking for repository: $REPO_SLUG..."

if gh repo view "$REPO_SLUG" &>/dev/null; then
  echo "✅ Repository '$REPO_SLUG' exists."
  exit 0
else
  echo "❌ Repository '$REPO_SLUG' does not exist or you lack access."
  exit 1
fi
