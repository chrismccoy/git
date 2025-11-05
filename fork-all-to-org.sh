#!/usr/bin/env bash

# fork all repos into an org

GREEN=$(tput setaf 2)
YELLOW=$(tput setaf 3)
RED=$(tput setaf 1)
NC=$(tput sgr0)

error_exit() {
  echo -e "\n${RED}ERROR: $1${NC}\n" >&2
  exit 1
}

if ! command -v gh &>/dev/null; then
  error_exit "'gh' (GitHub CLI) could not be found. Please install it first. See: https://cli.github.com/"
fi

if ! gh auth status &>/dev/null; then
  error_exit "You are not logged into the GitHub CLI. Please run 'gh auth login' first."
fi

CURRENT_USER=$(gh api user --jq .login)

if [ -z "$CURRENT_USER" ]; then
  error_exit "Could not determine the current authenticated GitHub user."
fi

echo "Authenticated as user: ${GREEN}${CURRENT_USER}${NC}"

read -p "Enter the target GitHub organization name to fork into: " TARGET_ORG

if [ -z "$TARGET_ORG" ]; then
  error_exit "Organization name cannot be empty."
fi

echo -e "\n${YELLOW}This script will attempt to fork all of ${CURRENT_USER}'s repositories into the '${TARGET_ORG}' organization.${NC}"
read -p "Are you absolutely sure you want to proceed? (y/N) " -n 1 -r
echo

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  echo "Operation cancelled by user."
  exit 0
fi

echo -e "\nFetching list of repositories for ${GREEN}${CURRENT_USER}${NC}..."

repo_list=$(gh repo list "$CURRENT_USER" --source --limit 5000 --json name)

if [ -z "$repo_list" ]; then
  echo "${YELLOW}No source repositories found for user ${CURRENT_USER}. Nothing to do.${NC}"
  exit 0
fi

echo "$repo_list" | jq -r '.[].name' | while read -r repo_name; do
  full_repo_name="${CURRENT_USER}/${repo_name}"
  target_repo_name="${TARGET_ORG}/${repo_name}"

  echo -e "\n--- Processing repository: ${GREEN}${full_repo_name}${NC} ---"

  if gh repo view "$target_repo_name" &>/dev/null; then
    echo "${YELLOW}SKIP: Repository '${target_repo_name}' already exists in the organization.${NC}"
    continue
  fi

  echo "Forking '${full_repo_name}' to '${TARGET_ORG}'..."
  if gh repo fork "$full_repo_name" --org "$TARGET_ORG" --clone=false; then
    echo "✅ ${GREEN}SUCCESS: Successfully forked to '${target_repo_name}'.${NC}"
  else
    echo "❌ ${RED}FAILED: Could not fork '${full_repo_name}'. Check your permissions for the '${TARGET_ORG}' organization.${NC}"
  fi
done

echo -e "\n${GREEN}All repositories have been processed. Script finished.${NC}\n"
