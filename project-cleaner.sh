#!/usr/bin/env bash

# recursively find and delete node_modules, .git, and package-lock.json

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Searching for items to clean in the current directory...${NC}"

targets=()

while IFS= read -r -d $'\0' file; do
	targets+=("$file")
done < <(find . -maxdepth 10 \( -type d -name "node_modules" -o -type d -name ".git" -o -type f -name "package-lock.json" \) -print0)

if [ ${#targets[@]} -eq 0 ]; then
	echo -e "${GREEN}All clean! No 'node_modules', '.git', or 'package-lock.json' found.${NC}"
	exit 0
fi

echo -e "\nThe following items will be ${RED}PERMANENTLY DELETED:${NC}"
printf " - %s\n" "${targets[@]}"

echo ""
read -p "Are you sure you want to delete all of the above? (y/n): " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
	echo "Operation cancelled."
	exit 1
fi

echo -e "\n${YELLOW}Deleting items...${NC}"

# Iterate over the array and delete each item
for target in "${targets[@]}"; do
	echo "Deleting: $target"
	rm -rf "$target" || true
done

echo -e "\n${GREEN}Cleanup complete!${NC}"
