#!/bin/bash

set -e
set -u
set -o pipefail

# The GitHub organization or user whose repositories you want to target.
# Leave this empty ("") to target the repositories for the currently authenticated user.
OWNER=""

REPO_LIMIT=1000

if ! command -v gh &> /dev/null; then
  echo "Error: 'gh' command not found. Please install the GitHub CLI."
  echo "https://cli.github.com/"
  exit 1
fi
if ! command -v jq &> /dev/null; then
  echo "Error: 'jq' command not found. Please install jq."
  echo "Example: 'sudo apt-get install jq' or 'brew install jq'"
  exit 1
fi

TARGET_ARG=""
TARGET_DESC="your"

if [ -n "$OWNER" ]; then
  TARGET_ARG="$OWNER"
  TARGET_DESC="the '$OWNER' organization/user's"
fi

echo "This script will disable the 'Issues' feature for all of ${TARGET_DESC} repositories."
echo ""
echo "🛑 WARNING: This is a significant change. Please be certain."
echo "It is highly recommended to run this in --dry-run mode first."
echo "Example: ./disable-all-issues.sh --dry-run"
echo ""

DRY_RUN=false

if [[ "${1-}" == "--dry-run" ]]; then
  DRY_RUN=true
  echo "--- DRY RUN MODE ENABLED ---"
  echo "No actual changes will be made."
  echo "--------------------------"
else
  read -p "Are you absolutely sure you want to continue? [y/N] " -r response
  if [[ ! "$response" =~ ^[yY]$ ]]; then
    echo "Operation cancelled."
    exit 1
  fi
fi

echo ""
echo "Fetching repository list..."

repo_list=$(
  gh repo list "$TARGET_ARG" --limit "$REPO_LIMIT" --json nameWithOwner --jq '.[].nameWithOwner'
)

if [ -z "$repo_list" ]; then
  echo "No repositories found for ${TARGET_DESC} account."
  exit 0
fi

while IFS= read -r repo; do
  echo "Processing repository: $repo"
  if [ "$DRY_RUN" = true ]; then
    echo "  [DRY RUN] Would execute: gh repo edit \"$repo\" --enable-issues=false"
  else
    if gh repo edit "$repo" --enable-issues=false; then
      echo "  ✅ Successfully disabled issues for $repo"
    else
      echo "  ❌ Failed to disable issues for $repo"
    fi
  fi
done <<<"$repo_list"

echo ""
echo "Operation completed."
