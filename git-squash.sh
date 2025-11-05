#!/bin/bash

# git reset --soft $(git rev-list --max-parents=0 HEAD) && git commit --amend -m "Initial commit" && git push --force

COMMIT_MESSAGE="Initial commit"
FORCE_PUSH=false

COLOR_RED='\033[0;31m'
COLOR_YELLOW='\033[1;33m'
COLOR_GREEN='\033[0;32m'
COLOR_NC='\033[0m'

function usage() {
  echo "Usage: $0 [--commit \"Your message\"] [--force-push]"
  echo
  echo "  --commit <message>  Specify a custom commit message for the new single commit."
  echo "  --force-push        Automatically force-push to the remote after squashing."
  exit 1
}

while [[ $# -gt 0 ]]; do
  key="$1"
  case $key in
  --commit)
    if [[ -z "$2" || "$2" =~ ^-- ]]; then
      echo -e "${COLOR_RED}Error: --commit flag requires a message argument.${COLOR_NC}"
      usage
    fi
    COMMIT_MESSAGE="$2"
    shift
    shift
    ;;
  --force-push)
    FORCE_PUSH=true
    shift
    ;;
  *)
    echo -e "${COLOR_RED}Error: Unknown option '$1'${COLOR_NC}"
    usage
    ;;
  esac
done

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo -e "${COLOR_RED}Error: This is not a git repository.${COLOR_NC}"
  exit 1
fi

if ! git diff-index --quiet HEAD --; then
  echo -e "${COLOR_RED}Error: You have uncommitted changes. Please commit or stash them first.${COLOR_NC}"
  exit 1
fi

CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)

echo -e "\nThis script will squash the local history of branch '${COLOR_YELLOW}${CURRENT_BRANCH}${COLOR_NC}'."
echo -e "The new commit message will be: ${COLOR_GREEN}\"${COMMIT_MESSAGE}\"${COLOR_NC}"

if [ "$FORCE_PUSH" = true ]; then
  echo -e "${COLOR_YELLOW}The --force-push flag is active and will run after the local squash.${COLOR_NC}"
fi

read -p "Are you sure you want to continue with the local squash? (y/N) " -n 1 -r

echo

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  echo "Operation cancelled."
  exit 1
fi

echo "--> Finding the root commit..."
ROOT_COMMIT=$(git rev-list --max-parents=0 HEAD)

if [ -z "$ROOT_COMMIT" ]; then
  echo -e "${COLOR_RED}Error: Could not find the root commit. Is this an empty repository?${COLOR_NC}"
  exit 1
fi

echo "--> Performing a soft reset to the root commit..."
git reset --soft "$ROOT_COMMIT"

echo "--> Amending the root commit with the new message..."
git commit --amend -m "$COMMIT_MESSAGE"

echo -e "\n${COLOR_GREEN}✅ Success! The local history has been squashed.${COLOR_NC}"

if [ "$FORCE_PUSH" = true ]; then
  echo -e "\n--- Force Push Operation ---"
  REMOTE_NAME=$(git config --get "branch.${CURRENT_BRANCH}.remote")
  if [ -z "$REMOTE_NAME" ]; then
    echo -e "${COLOR_RED}Error: Could not detect a remote for branch '${CURRENT_BRANCH}'.${COLOR_NC}"
    echo "Please set an upstream branch with 'git push -u <remote> <branch>' first."
    exit 1
  fi

  echo -e "${COLOR_RED}!!!!!!!!!!!!!!!!!!!!!!!!!!!!!! WARNING !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!${COLOR_NC}"
  echo -e "${COLOR_RED}You are about to force-push to '${COLOR_YELLOW}${REMOTE_NAME}/${CURRENT_BRANCH}${COLOR_NC}'. This is irreversible.${COLOR_NC}"
  read -p "Proceed with the force push? (y/N) " -n 1 -r
  echo

  if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "--> Force-pushing to '$REMOTE_NAME/$CURRENT_BRANCH'..."
    git push --force "$REMOTE_NAME" "$CURRENT_BRANCH"
    echo -e "\n${COLOR_GREEN}✅ Success! Remote repository history has been overwritten.${COLOR_NC}"
  else
    echo "Force push operation cancelled."
  fi
else
  echo "   The branch '${CURRENT_BRANCH}' now has only one commit."
  echo -e "   To update your remote repository manually, run:"
  echo -e "   ${COLOR_YELLOW}git push --force origin ${CURRENT_BRANCH}${COLOR_NC}"
fi
