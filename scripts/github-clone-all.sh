#!/usr/bin/env bash
# GitHub.com/PiercingXX
# Clone every repo of a GitHub owner that isn't already cloned.
# Usage: github-clone-all.sh [owner]
#   GITHUB_OWNER        owner (default: the gh-authenticated user)
#   GITHUB_BASE_DIR     clone target (default: $PIERCINGXX_WORK_ROOT/GitHub)
#   GITHUB_REPO_LIMIT   max repos to list (default: 1000)
#   GITHUB_SKIP_ARCHIVED=1  skip archived repos

set -euo pipefail

TARGET_DIR="${GITHUB_BASE_DIR:-${PIERCINGXX_WORK_ROOT:-/media/Working-Storage}/GitHub}"
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

list_args=(--limit "$REPO_LIMIT" --json name --jq '.[].name')
[ "${GITHUB_SKIP_ARCHIVED:-0}" = 1 ] && list_args+=(--no-archived)
mapfile -t repos < <(gh repo list "$OWNER" "${list_args[@]}")

if [ "${#repos[@]}" -eq 0 ]; then
    echo "No repositories found for $OWNER"
    exit 0
fi

if [ "${#repos[@]}" -ge "$REPO_LIMIT" ]; then
    echo "Warning: listed $REPO_LIMIT repos, the GITHUB_REPO_LIMIT cap; there may be more." >&2
fi

cloned_count=0
skipped_count=0
failed_count=0

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
    if gh repo clone "$OWNER/$repo_name" "$repo_path"; then
        cloned_count=$((cloned_count + 1))
    else
        echo "Failed to clone $OWNER/$repo_name" >&2
        failed_count=$((failed_count + 1))
    fi
done

echo
echo "Clone complete."
echo "Cloned: $cloned_count"
echo "Skipped: $skipped_count"
echo "Failed: $failed_count"