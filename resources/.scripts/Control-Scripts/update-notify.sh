#!/bin/bash
# GitHub.com/PiercingXX
# One-shot update availability notification (run once at login).

# shellcheck disable=SC1091
. "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../lib/common.sh"

COUNTER="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/update-count.sh"
STATE_TIMEOUT=4000

# Stay quiet while update-system.sh is mid-upgrade (it holds this lock)
update_lock="${XDG_RUNTIME_DIR:-/tmp}/piercingxx-update-system.lock"
if [ -e "$update_lock" ] && ! flock -n "$update_lock" true 2>/dev/null; then
    exit 0
fi

[ -x "$COUNTER" ] || exit 0
read -r repo aur total < <("$COUNTER" --refresh)

[[ "$total" =~ ^[0-9]+$ ]] && (( total > 0 )) || exit 0

body="$total packages can be updated"
if (( aur > 0 )); then
    body="$repo from repos, $aur from the AUR"
fi
notify_replace update-notify low "$STATE_TIMEOUT" software-update-available "Updates available" "$body"
