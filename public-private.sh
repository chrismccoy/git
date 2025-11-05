#!/bin/bash

set -euo pipefail

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
  ensure_command_exists "gh"
  ensure_command_exists "jq"

  printf "Creating destination directories...\n"
  mkdir -p public private

  printf "Fetching repository list from GitHub...\n"

  local repo_list

  repo_list=$(gh repo list --limit 1000 --json name,visibility \
    --jq '.[] | [.name, .visibility] | @tsv')

  if [ -z "$repo_list" ]; then
    printf "No repositories found.\n"
    exit 0
  fi

  printf "Processing repositories...\n\n"

  local total_cloned=0
  local total_failed=0

  while IFS=$'\t' read -r name visibility; do
    local dest_dir
    case "${visibility^^}" in
      PUBLIC)
        dest_dir="public"
        ;;
      PRIVATE)
        dest_dir="private"
        ;;
      *)
        printf "⚠️  Skipping '%s': Unknown visibility '%s'\n" "$name" "$visibility"
        continue
        ;;
    esac

    local clone_path="${dest_dir}/${name}"
    printf "Cloning %s repo '%s' into '%s'...\n" "$visibility" "$name" "$clone_path"

    if [ -d "$clone_path" ]; then
      printf "  ⚪ Skipped: Directory '%s' already exists.\n\n" "$clone_path"
      continue
    fi

    if gh repo clone "$name" "$clone_path" -- --quiet; then
      printf "  ✅ Successfully cloned.\n\n"
      ((total_cloned++))
    else
      printf "  ❌ Failed to clone '%s'.\n\n" "$name" >&2
      ((total_failed++))
    fi
  done <<< "$repo_list"

  printf -- "-----------------------------------------------------------------\n"
  printf "Clone process complete.\n"
  printf "Successfully cloned: %d\n" "$total_cloned"
  printf "Failed to clone:     %d\n" "$total_failed"

  if [ "$total_failed" -gt 0 ]; then
    return 1
  fi
}

main "$@"
