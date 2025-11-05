#!/bin/bash

set -e
set -u
set -o pipefail

COLOR_RESET='\033[0m'
COLOR_RED='\033[0;31m'
COLOR_GREEN='\033[0;32m'
COLOR_YELLOW='\033[0;33m'
COLOR_BLUE='\033[0;34m'

function print_info() {
  echo -e "${COLOR_BLUE}INFO: $1${COLOR_RESET}"
}

function print_success() {
  echo -e "${COLOR_GREEN}SUCCESS: $1${COLOR_RESET}"
}

function print_warning() {
  echo -e "${COLOR_YELLOW}WARNING: $1${COLOR_RESET}"
}

function print_error() {
  echo -e "${COLOR_RED}ERROR: $1${COLOR_RESET}" >&2
  exit 1
}

function usage() {
  echo "Usage: $0 [source_owner] [repo_name] [target_org]"
  echo "If arguments are omitted, you will be prompted interactively."
  exit 1
}

print_info "Checking for required tools: git and gh..."

if ! command -v git &>/dev/null; then
  print_error "'git' command not found. Please install Git."
fi

if ! command -v gh &>/dev/null; then
  print_error "'gh' command not found. Please install the GitHub CLI (https://cli.github.com/)."
fi

print_success "All required tools are installed."

print_info "Checking GitHub CLI authentication status..."

if ! gh auth status &>/dev/null; then
  print_error "You are not logged into the GitHub CLI. Please run 'gh auth login'."
fi

print_success "Authenticated with GitHub."

SOURCE_OWNER="${1:-}"
REPO_NAME="${2:-}"
TARGET_ORG="${3:-}"

if [[ -z "$SOURCE_OWNER" ]]; then
  read -p "Enter the source username/owner: " SOURCE_OWNER
fi

if [[ -z "$REPO_NAME" ]]; then
  read -p "Enter the repository name to transfer: " REPO_NAME
fi

if [[ -z "$TARGET_ORG" ]]; then
  read -p "Enter the target organization name: " TARGET_ORG
fi

if [[ -z "$SOURCE_OWNER" || -z "$REPO_NAME" || -z "$TARGET_ORG" ]]; then
  print_error "All fields are required."
  usage
fi

FULL_REPO_NAME="${SOURCE_OWNER}/${REPO_NAME}"

print_info "Preparing to transfer '${FULL_REPO_NAME}' to organization '${TARGET_ORG}'."

print_info "Validating repository and organization..."

if ! gh repo view "$FULL_REPO_NAME" >/dev/null 2>&1; then
  print_error "Repository '${FULL_REPO_NAME}' not found or you don't have access."
fi

print_success "Source repository '${FULL_REPO_NAME}' found."

if ! gh org view "$TARGET_ORG" >/dev/null 2>&1; then
  print_error "Organization '${TARGET_ORG}' not found or you don't have access."
fi

print_success "Target organization '${TARGET_ORG}' found."

echo
print_warning "This action is IRREVERSIBLE."
print_warning "Transferring will change the repository's URL and permissions."
read -p "Are you absolutely sure you want to transfer '${FULL_REPO_NAME}' to '${TARGET_ORG}'? [y/N]: " CONFIRMATION
echo

if [[ ! "$CONFIRMATION" =~ ^[yY]$ ]]; then
  print_info "Transfer cancelled by user."
  exit 0
fi

print_info "Initiating transfer..."

if ! gh repo transfer "$FULL_REPO_NAME" --to "$TARGET_ORG"; then
  print_error "Repository transfer failed. Please check your permissions. You must be an owner of the repository and have repository creation permissions in the target organization."
fi

NEW_REPO_URL="https://github.com/${TARGET_ORG}/${REPO_NAME}"

print_success "Repository successfully transferred to '${TARGET_ORG}'."
print_success "New URL: ${NEW_REPO_URL}"
echo

if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  CURRENT_REMOTE_URL=$(git config --get remote.origin.url)
  OLD_SSH_URL="git@github.com:${FULL_REPO_NAME}.git"
  OLD_HTTPS_URL="https://github.com/${FULL_REPO_NAME}.git"

  if [[ "$CURRENT_REMOTE_URL" == "$OLD_SSH_URL" || "$CURRENT_REMOTE_URL" == "$OLD_HTTPS_URL" ]]; then
    print_info "Detected that you are in a local clone of the transferred repository."
    read -p "Would you like to update the 'origin' remote URL? [y/N]: " UPDATE_REMOTE

    if [[ "$UPDATE_REMOTE" =~ ^[yY]$ ]]; then
      if [[ "$CURRENT_REMOTE_URL" == "$OLD_SSH_URL" ]]; then
        NEW_REMOTE_URL="git@github.com:${TARGET_ORG}/${REPO_NAME}.git"
        print_info "Updating remote 'origin' to new SSH URL: ${NEW_REMOTE_URL}"
      else
        NEW_REMOTE_URL="https://github.com/${TARGET_ORG}/${REPO_NAME}.git"
        print_info "Updating remote 'origin' to new HTTPS URL: ${NEW_REMOTE_URL}"
      fi
      git remote set-url origin "$NEW_REMOTE_URL"
      print_success "Local remote 'origin' has been updated."
    fi
  fi
fi

print_info "Finished."
