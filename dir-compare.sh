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

  printf "Fetching repository list from GitHub...\n"
  local -a all_repos

  mapfile -t all_repos < <(gh repo list --json name -q '.[].name' | sort) || true

  if [ ${#all_repos[@]} -eq 0 ]; then
    printf "No GitHub repositories found or the 'gh' command failed.\n"
    exit 0
  fi

  local -a non_existing_repos
  local repo
  local exists_count=0

  printf "Comparing %d GitHub repositories with local directories...\n\n" "${#all_repos[@]}"

  for repo in "${all_repos[@]}"; do
    if [ -d "${repo}" ]; then
      ((exists_count++))
    else
      non_existing_repos+=("$repo")
    fi
  done

  local not_exists_count=${#non_existing_repos[@]}

  printf "--- Summary ---\n"
  printf "Total repositories on GitHub: %d\n" "${#all_repos[@]}"
  printf "Local directories found:      %d\n" "$exists_count"
  printf "Local directories not found:  %d\n" "$not_exists_count"

  if [ "$not_exists_count" -gt 0 ]; then
    printf "\n--- Repositories not found locally ---\n"
    printf "%s\n" "${non_existing_repos[@]}"
  fi
}

main "$@"
