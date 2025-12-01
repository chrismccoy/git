#!/bin/bash

if [ "$#" -ne 2 ]; then
  echo "Usage: $0 <repo-name> <target-organization>"
  exit 1
fi

REPO_NAME="$1"
TARGET_ORG="$2"
CURRENT_USER=$(gh api user --jq .login)
AUTO_UPDATE_REMOTE=false

if [ -z "$CURRENT_USER" ]; then
  echo "Error: Could not determine GitHub user. Please ensure you are logged in with 'gh auth login'."
  exit 1
fi

if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  REMOTE_URL=$(git config --get remote.origin.url)
  if [ -n "$REMOTE_URL" ]; then
    LOCAL_OWNER_REPO=$(echo "$REMOTE_URL" | sed -e 's|https://github.com/||' -e 's|git@github.com:||' -e 's|\.git$||')

    EXPECTED_OWNER_REPO="$CURRENT_USER/$REPO_NAME"

    if [ "$LOCAL_OWNER_REPO" == "$EXPECTED_OWNER_REPO" ]; then
      echo "✅ You are in the correct local repository."
      echo "The 'origin' remote will be updated automatically upon successful transfer."
      AUTO_UPDATE_REMOTE=true
    else
      echo "ℹ️ You are in a git repo, but its remote ('$LOCAL_OWNER_REPO') does not match the target ('$EXPECTED_OWNER_REPO')."
      echo "You will need to update the remote manually if the transfer succeeds."
    fi
  fi
fi
echo ""

echo "You are about to transfer the repository '$CURRENT_USER/$REPO_NAME' to the '$TARGET_ORG' organization."
echo "This is a permanent action."
read -p "Are you sure you want to proceed? (y/n) " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  echo "Transfer cancelled."
  exit 1
fi

echo "Attempting to transfer '$REPO_NAME' to '$TARGET_ORG'..."

gh repo transfer "$REPO_NAME" --org "$TARGET_ORG" --confirm "$REPO_NAME"

if [ $? -eq 0 ]; then
  echo ""
  echo "✅ Repository transfer initiated successfully!"
  echo "GitHub will now process the transfer in the background."
  echo ""

  NEW_REMOTE_URL="git@github.com:$TARGET_ORG/$REPO_NAME.git"

  if [ "$AUTO_UPDATE_REMOTE" = true ]; then
    git remote set-url origin "$NEW_REMOTE_URL"
    if [ $? -eq 0 ]; then
      echo "✅ Automatically updated your local 'origin' remote to:"
      echo "   $NEW_REMOTE_URL"
    else
      echo "❌ Failed to automatically update the local remote. Please run this command manually:"
      echo "   git remote set-url origin $NEW_REMOTE_URL"
    fi
  else
    echo "Update your local repository's remote URL with the following command:"
    echo ""
    echo "  git remote set-url origin $NEW_REMOTE_URL"
  fi
  echo ""
  echo "Inform your collaborators to do the same."
else
  echo ""
  echo "❌ Repository transfer failed."
  echo "Please check permissions and ensure the repository and organization names are correct."
fi
