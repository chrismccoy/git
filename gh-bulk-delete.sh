#!/usr/bin/env bash

set -euo pipefail

REPO_LIMIT=1000 # Adjust if you have more than 1000 repos
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

usage() {
  cat << EOF
Usage: $(basename "$0") [OPTIONS]

A script to bulk delete GitHub repositories using the 'gh' CLI.

You MUST specify a scope: --private, --public, or --all.
You MAY specify a mode: --dry-run or --interactive. Default is bulk delete.

Options:
  --private           Only target private repositories for deletion.
  --public            Only target public repositories for deletion.
  --all               Target all repositories (both public and private).
  --dry-run           Show which repositories would be deleted without taking action.
  --interactive       Prompt for confirmation before deleting each repository.
  --help              Display this help and exit.

Examples:
  # Dry run to see which PRIVATE repos would be deleted
  ./$(basename "$0") --private --dry-run

  # Interactively choose which PUBLIC repos to delete
  ./$(basename "$0") --public --interactive

  # Bulk delete ALL private repositories (will ask for a single confirmation)
  ./$(basename "$0") --private
EOF
  exit 1
}

main() {
  DELETE_PRIVATE=false
  DELETE_PUBLIC=false
  DRY_RUN=false
  INTERACTIVE_MODE=false

  if [[ $# -eq 0 ]]; then
    echo -e "${RED}Error: No options provided.${NC}"
    usage
  fi

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --private) DELETE_PRIVATE=true; shift ;;
      --public) DELETE_PUBLIC=true; shift ;;
      --all)
        DELETE_PRIVATE=true
        DELETE_PUBLIC=true
        shift
        ;;
      --dry-run) DRY_RUN=true; shift ;;
      --interactive) INTERACTIVE_MODE=true; shift ;;
      --help) usage ;;
      *)
        echo -e "${RED}Error: Unknown option '$1'${NC}"
        usage
        ;;
    esac
  done

  if ! command -v gh &> /dev/null; then
    echo -e "${RED}Error: 'gh' (GitHub CLI) is not installed.${NC}" && exit 1
  fi
  if ! command -v jq &> /dev/null; then
    echo -e "${RED}Error: 'jq' is not installed.${NC}" && exit 1
  fi
  if ! gh auth status &> /dev/null; then
    echo -e "${RED}Error: Not logged in to GitHub. Run 'gh auth login'.${NC}" && exit 1
  fi
  if [[ "$DELETE_PRIVATE" == false && "$DELETE_PUBLIC" == false ]]; then
    echo -e "${RED}Error: You must specify a scope (--private, --public, or --all).${NC}"
    usage
  fi
  if [[ "$DRY_RUN" == true && "$INTERACTIVE_MODE" == true ]]; then
    echo -e "${RED}Error: --dry-run and --interactive flags cannot be used together.${NC}"
    usage
  fi

  local jq_filter=""
  local scope="ALL"
  if [[ "$DELETE_PRIVATE" == true && "$DELETE_PUBLIC" == false ]]; then
    jq_filter='.[] | select(.isPrivate == true) | .nameWithOwner'
    scope="PRIVATE"
  elif [[ "$DELETE_PRIVATE" == false && "$DELETE_PUBLIC" == true ]]; then
    jq_filter='.[] | select(.isPrivate == false) | .nameWithOwner'
    scope="PUBLIC"
  else
    jq_filter='.[] | .nameWithOwner'
  fi

  echo -e "${BLUE}Fetching your repositories (scope: ${scope})...${NC}"
  mapfile -t repos_to_delete < <(gh repo list --limit "$REPO_LIMIT" --json isPrivate,nameWithOwner | jq -r "$jq_filter")

  if [[ ${#repos_to_delete[@]} -eq 0 ]]; then
    echo -e "${GREEN}No ${scope,,} repositories found to delete.${NC}"
    exit 0
  fi

  echo -e "\nFound ${YELLOW}${#repos_to_delete[@]}${NC} ${scope,,} repository/repositories:"
  printf " - %s\n" "${repos_to_delete[@]}"

  local success_count=0
  local error_count=0

  if [[ "$DRY_RUN" == true ]]; then
    echo -e "\n${GREEN}Dry run complete. No repositories were deleted.${NC}"
    exit 0
  fi

  if [[ "$INTERACTIVE_MODE" == true ]]; then
    echo -e "\n${BLUE}Starting interactive deletion...${NC}"
    for repo in "${repos_to_delete[@]}"; do
      read -p "Delete repository ${YELLOW}${repo}${NC}? [y/N/s/q] " -n 1 -r choice
      echo # Move to a new line
      case "$choice" in
        [yY])
          echo -n "  Deleting ${repo}... "
          if gh repo delete "$repo" --yes; then
            echo -e "${GREEN}SUCCESS${NC}"
            ((success_count++))
          else
            echo -e "${RED}FAILED${NC}"
            ((error_count++))
          fi
          ;;
        [qQ])
          echo -e "\n${YELLOW}Quitting interactive session.${NC}"
          break
          ;;
        *)
          echo -e "  ${YELLOW}Skipping ${repo}${NC}"
          ;;
      esac
    done
  else
    echo -e "\n${RED}!!! DANGER ZONE !!!${NC}"
    echo -e "You are about to permanently delete ${YELLOW}${#repos_to_delete[@]}${NC} repository/repositories."
    echo -e "${RED}This action is irreversible.${NC}"
    read -p "Type 'delete' to confirm: " confirmation

    if [[ "$confirmation" != "delete" ]]; then
      echo -e "\n${YELLOW}Deletion cancelled by user.${NC}"
      exit 1
    fi

    echo -e "\n${BLUE}Starting bulk deletion process...${NC}"
    for repo in "${repos_to_delete[@]}"; do
      echo -n "Deleting ${repo}... "
      if gh repo delete "$repo" --yes; then
        echo -e "${GREEN}SUCCESS${NC}"
        ((success_count++))
      else
        echo -e "${RED}FAILED${NC}"
        ((error_count++))
      fi
    done
  fi

  echo -e "\n${BLUE}--- Deletion Summary ---${NC}"
  echo -e "${GREEN}Successfully deleted: ${success_count}${NC}"
  if [[ "$error_count" -gt 0 ]]; then
    echo -e "${RED}Failed to delete: ${error_count}${NC}"
  fi
  local skipped_count=$(( ${#repos_to_delete[@]} - success_count - error_count ))
  if [[ "$skipped_count" -gt 0 ]]; then
    echo -e "${YELLOW}Skipped: ${skipped_count}${NC}"
  fi
}

main "$@"
