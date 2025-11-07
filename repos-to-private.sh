#!/bin/bash

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

if ! command -v gh &> /dev/null; then
    echo -e "${RED}Error: GitHub CLI ('gh') is not installed.${NC}"
    echo "Please install it from https://cli.github.com/ and try again."
    exit 1
fi

if ! gh auth status &> /dev/null; then
    echo -e "${RED}Error: You are not logged into the GitHub CLI.${NC}"
    echo "Please run 'gh auth login' and try again."
    exit 1
fi

echo "Starting repository check..."
echo "----------------------------------------"

for dir in */; do
    if [ -d "${dir}" ] && [ -d "${dir}.git" ]; then
        echo -e "\nProcessing directory: ${YELLOW}${dir}${NC}"

        (
            cd "${dir}" || exit

            repo_info=$(gh repo view --json 'nameWithOwner,visibility' 2>/dev/null)

            if [ -z "$repo_info" ]; then
                echo -e "  ${RED}Could not fetch GitHub repo info. Is it a valid GitHub repo with a remote? Skipping.${NC}"
                continue
            fi

            name=$(echo "$repo_info" | jq -r '.nameWithOwner')
            visibility=$(echo "$repo_info" | jq -r '.visibility')

            echo -e "  Repo: ${GREEN}$name${NC}, Current Visibility: ${YELLOW}$visibility${NC}"

            if [ "$visibility" == "PUBLIC" ]; then
                read -p "  Do you want to change visibility to PRIVATE? (y/n): " confirm

                if [[ "$confirm" =~ ^[Yy]$ ]]; then
                    echo -e "  Changing visibility to private..."

                    if gh repo edit "$name" --visibility private --accept-visibility-change-consequences; then
                        echo -e "  ${GREEN}Success! '$name' is now private.${NC}"
                    else
                        echo -e "  ${RED}Error: Failed to change visibility for '$name'.${NC}"
                    fi
                else
                    echo "  Skipping."
                fi
            else
                echo "  Already private or internal. No action needed."
            fi
        )
    fi
done

echo -e "\n----------------------------------------"
echo "Script finished."
