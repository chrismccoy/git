#!/bin/bash

set -euo pipefail

readonly REMOTE_NAME="origin"

die() {
  printf "ERROR: %s\n" "$1" >&2
  exit 1
}

ensure_command_exists() {
  if ! command -v "$1" &>/dev/null; then
    die "'$1' command not found. Please install it and ensure it's in your PATH."
  fi
}

main() {
  ensure_command_exists "git"
  ensure_command_exists "find"

  if [ "$#" -ne 2 ]; then
    die "Invalid number of arguments.
Usage: $0 <old_organization> <new_organization>
Example: $0 my-old-org my-new-org"
  fi

  local old_org="$1"
  local new_org="$2"
  local repos_found=0
  local repos_updated=0

  printf "Searching for git repositories to update...\n"
  printf "Will replace '%s' with '%s' in remote '%s' URLs.\n" \
    "$old_org" "$new_org" "$REMOTE_NAME"
  printf -- "-----------------------------------------------------------------\n"

  find . -type d -name ".git" -print0 | {
    while IFS= read -r -d '' git_dir; do
      local repo_dir
      repo_dir=$(dirname "$git_dir")
      ((repos_found++))

      printf "Processing: %s\n" "$repo_dir"

      if ! git -C "$repo_dir" remote get-url "$REMOTE_NAME" &>/dev/null; then
        printf "  🟡 Skipped (Remote '%s' not found)\n\n" "$REMOTE_NAME"
        continue
      fi

      local current_url
      current_url=$(git -C "$repo_dir" remote get-url "$REMOTE_NAME")

      if [[ "$current_url" == *"$old_org"* ]]; then
        local new_url="${current_url/$old_org/$new_org}"
        git -C "$repo_dir" remote set-url "$REMOTE_NAME" "$new_url"

        printf "  ✅ Updated URL\n"
        printf "     - From: %s\n" "$current_url"
        printf "     - To:   %s\n" "$new_url"
        ((repos_updated++))
      else
        printf "  ⚪ Skipped (URL does not contain '%s')\n" "$old_org"
        printf "     - Current URL: %s\n" "$current_url"
      fi
      printf "\n"
    done

    printf -- "-----------------------------------------------------------------\n"
    printf "Scan complete.\n"
    printf "Found %d repositories and updated %d of them.\n" \
      "$repos_found" "$repos_updated"
  }
}

main "$@"
