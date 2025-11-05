#!/bin/bash

set -e
set -u
set -o pipefail

if tput setaf 1 >/dev/null 2>&1; then
	RED=$(tput setaf 1)
	GREEN=$(tput setaf 2)
	YELLOW=$(tput setaf 3)
	BLUE=$(tput setaf 4)
	BOLD=$(tput bold)
	RESET=$(tput sgr0)
else
	RED='\033[0;31m'
	GREEN='\033[0;32m'
	YELLOW='\033[0;33m'
	BLUE='\033[0;34m'
	BOLD='\033[1m'
	RESET='\033[0m'
fi

declare -a clean_repos
declare -a needs_push_repos
declare -a needs_pull_repos
declare -a diverged_repos
declare -a uncommitted_changes_repos
declare -a untracked_branch_repos
declare -a error_repos

SEARCH_DIR="${1:-.}"

if [ ! -d "$SEARCH_DIR" ]; then
	echo -e "${RED}Error: Directory '$SEARCH_DIR' not found.${RESET}" >&2
	exit 1
fi

echo -e "${BLUE}${BOLD}🔍 Starting scan for Git repositories in: $(
	realpath "$SEARCH_DIR"
)${RESET}\n"

repo_count=0

while IFS= read -r -d '' git_dir; do
	repo_count=$((repo_count + 1))
	repo_path=$(dirname "$git_dir")
	repo_name=$(basename "$repo_path")

	echo -e "--- Checking ${BOLD}${YELLOW}${repo_name}${RESET} (${repo_path}) ---"

	status_line=$(
		(
			cd "$repo_path" || {
				echo "ERROR:Could not cd into directory"
				exit 0
			}

			if ! git fetch --all --prune >/dev/null 2>&1; then
				echo -e "${RED}  -> Could not fetch remote. Check connection or remote config.${RESET}" >&2
				echo "ERROR:Fetch failed"
				exit 0
			fi

			if [ -n "$(git status --porcelain)" ]; then
				echo -e "${YELLOW}  -> Has uncommitted changes.${RESET}" >&2
				echo "UNCOMMITTED"
				exit 0
			fi

			status=$(git status -sb)
			if [[ "$status" == *"no tracking information"* ]]; then
				echo -e "${BLUE}  -> Current branch has no upstream tracking info.${RESET}" >&2
				echo "UNTRACKED_BRANCH"
			elif [[ "$status" == *"[ahead "* ]]; then
				echo -e "${GREEN}  -> Needs push.${RESET}" >&2
				echo "NEEDS_PUSH"
			elif [[ "$status" == *"[behind "* ]]; then
				echo -e "${RED}  -> Needs pull.${RESET}" >&2
				echo "NEEDS_PULL"
			elif [[ "$status" == *"[diverged "* ]]; then
				echo -e "${RED}  -> Diverged from remote. Needs pull and push.${RESET}" >&2
				echo "DIVERGED"
			else
				echo -e "${GREEN}  -> Clean and up-to-date.${RESET}" >&2
				echo "CLEAN"
			fi
		)
	)

	case "$status_line" in
	UNCOMMITTED) uncommitted_changes_repos+=("$repo_path") ;;
	NEEDS_PUSH) needs_push_repos+=("$repo_path") ;;
	NEEDS_PULL) needs_pull_repos+=("$repo_path") ;;
	DIVERGED) diverged_repos+=("$repo_path") ;;
	UNTRACKED_BRANCH) untracked_branch_repos+=("$repo_path") ;;
	CLEAN) clean_repos+=("$repo_path") ;;
	ERROR:*) error_repos+=("$repo_path: ${status_line#*:}") ;;
	*) error_repos+=("$repo_path: Unknown status") ;;
	esac

done < <(find "$SEARCH_DIR" -type d -name ".git" -print0)

echo -e "\n${BLUE}${BOLD}==================== SUMMARY ====================${RESET}"
echo -e "Scan complete. Found ${BOLD}${repo_count}${RESET} repositories.\n"

print_summary_section() {
	local title=$1
	local color=$2
	shift 2
	local repos=("$@")
	local count=${#repos[@]}

	if [ "$count" -gt 0 ]; then
		echo -e "${color}${BOLD}${title} (Count: ${count})${RESET}"
		for repo in "${repos[@]}"; do
			echo "  - ${repo}"
		done
		echo ""
	fi
}

print_summary_section "🔴 Repositories with UNCOMMITTED CHANGES" "$RED" "${uncommitted_changes_repos[@]}"
print_summary_section "🟠 Repositories that have DIVERGED" "$YELLOW" "${diverged_repos[@]}"
print_summary_section "🟡 Repositories that NEED TO BE PUSHED" "$YELLOW" "${needs_push_repos[@]}"
print_summary_section "🔵 Repositories that NEED TO BE PULLED" "$BLUE" "${needs_pull_repos[@]}"
print_summary_section "⚪ Repositories with UNTRACKED BRANCHES" "$RESET" "${untracked_branch_repos[@]}"
print_summary_section "🟢 Clean and up-to-date repositories" "$GREEN" "${clean_repos[@]}"
print_summary_section "❌ Repositories with errors" "$RED" "${error_repos[@]}"

echo -e "${BLUE}${BOLD}=================================================${RESET}"
