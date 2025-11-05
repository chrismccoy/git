#!/bin/bash

C_GREEN='\033[0;32m'
C_RED='\033[0;31m'
C_YELLOW='\033[0;33m'
C_BLUE='\033[0;34m'
C_NC='\033[0m' # No Color

if [ "$#" -ne 2 ]; then
  echo -e "${C_RED}Error: Invalid number of arguments.${C_NC}"
  echo "Usage: ./rename-repo.sh <owner/old_repo_name> <new_repo_name>"
  echo "Example: ./rename-repo.sh my-org/old-project my-new-project"
  exit 1
fi

OLD_REPO=$1
NEW_REPO_NAME=$2

echo -e "${C_BLUE}Running prerequisite checks...${C_NC}"

if ! command -v gh &>/dev/null; then
  echo -e "${C_RED}Error: 'gh' (GitHub CLI) is not installed.${C_NC}"
  echo "Please install it from https://cli.github.com/ and authenticate with 'gh auth login'."
  exit 1
fi

if ! gh auth status &>/dev/null; then
  echo -e "${C_RED}Error: Not authenticated with GitHub CLI.${C_NC}"
  echo "Please run 'gh auth login' to authenticate."
  exit 1
fi

if ! git rev-parse --is-inside-work-tree &>/dev/null; then
  echo -e "${C_RED}Error: This script must be run from within a local Git repository.${C_NC}"
  exit 1
fi

echo -e "${C_GREEN}Checks passed.${C_NC}"
echo

echo -e "${C_YELLOW}You are about to rename the GitHub repository:${C_NC}"
echo -e "  From: ${C_BLUE}${OLD_REPO}${C_NC}"
echo -e "  To:   ${C_BLUE}${NEW_REPO_NAME}${C_NC}"
echo -e "${C_YELLOW}This will also update the 'origin' remote in your current local repository.${C_NC}"
read -p "Are you sure you want to continue? (y/N) " confirm

if [[ ! "$confirm" =~ ^[yY]$ ]]; then
  echo -e "${C_RED}Operation cancelled.${C_NC}"
  exit 0
fi

echo

echo -e "${C_BLUE}Step 1: Renaming repository on GitHub...${C_NC}"

gh repo rename "$NEW_REPO_NAME" --repo "$OLD_REPO" --yes

if [ $? -ne 0 ]; then
  echo -e "${C_RED}Error: Failed to rename repository on GitHub.${C_NC}"
  echo "Please check the repository name and your permissions."
  exit 1
fi

echo -e "${C_GREEN}Successfully renamed repository on GitHub.${C_NC}"
echo

echo -e "${C_BLUE}Step 2: Updating local 'origin' remote URL...${C_NC}"

OWNER=$(echo "$OLD_REPO" | cut -d'/' -f1)
NEW_URL="git@github.com:${OWNER}/${NEW_REPO_NAME}.git"
#NEW_URL="https://github.com/${OWNER}/${NEW_REPO_NAME}.git"

git remote set-url origin "$NEW_URL"

if [ $? -ne 0 ]; then
  echo -e "${C_RED}Error: Failed to update the local 'origin' remote URL.${C_NC}"
  echo "You may need to update it manually using: git remote set-url origin ${NEW_URL}"
  exit 1
fi

echo -e "${C_GREEN}Successfully updated local remote URL.${C_NC}"
echo

echo -e "${C_BLUE}Verification: Current remotes are:${C_NC}"

git remote -v

echo
echo -e "${C_GREEN}All done! Your repository has been renamed.${C_NC}"
echo -e "You can test the new remote connection with 'git fetch origin'."
