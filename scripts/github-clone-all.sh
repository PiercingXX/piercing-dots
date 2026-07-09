#!/usr/bin/env bash

set -euo pipefail

TARGET_DIR="${GITHUB_BASE_DIR:-/media/Working-Storage/Github}"
REPO_LIMIT="${GITHUB_REPO_LIMIT:-1000}"

require_cmd() {
    command -v "$1" >/dev/null 2>&1 || {
        echo "Error: required command not found: $1" >&2
        exit 1
    }
}

require_cmd gh
require_cmd git

AUTH_USER="$(gh api user --jq .login)"
OWNER="${1:-${GITHUB_OWNER:-$AUTH_USER}}"

mkdir -p "$TARGET_DIR"

echo "GitHub owner: $OWNER"
echo "Target directory: $TARGET_DIR"

mapfile -t repos < <(gh repo list "$OWNER" --limit "$REPO_LIMIT" --json name --jq '.[].name')

if [ "${#repos[@]}" -eq 0 ]; then
    echo "No repositories found for $OWNER"
    exit 0
fi

cloned_count=0
skipped_count=0

for repo_name in "${repos[@]}"; do
    repo_path="$TARGET_DIR/$repo_name"

    if [ -d "$repo_path/.git" ]; then
        echo "Skipping existing repo: $repo_name"
        skipped_count=$((skipped_count + 1))
        continue
    fi

    if [ -e "$repo_path" ]; then
        echo "Skipping $repo_name because path exists and is not a git repo: $repo_path"
        skipped_count=$((skipped_count + 1))
        continue
    fi

    echo "Cloning $OWNER/$repo_name"
    gh repo clone "$OWNER/$repo_name" "$repo_path"
    cloned_count=$((cloned_count + 1))
done

echo
echo "Clone complete."
echo "Cloned: $cloned_count"
echo "Skipped: $skipped_count"