#!/usr/bin/env bash
# GitHub.com/PiercingXX
# Shared pending-update counter for bars and notifiers.
#
# Usage: update-count.sh            -> "repo aur total"
#        update-count.sh --total    -> "total"
#        update-count.sh --json     -> {"repo":N,"aur":N,"total":N,"packages":N,"updates":N,"text":"N","tooltip":"...","class":"..."}
#        update-count.sh --list     -> one pending package per line
#        add --refresh to bypass the cache
#
# Never runs `pacman -Sy`: Arch uses checkupdates (pacman-contrib, private db
# copy) and falls back to `pacman -Qu` against the last synced db.
# Results are cached for PX_UPDATE_TTL seconds (default 300) so several bars
# polling at once share one check.

mode="plain"
refresh=0
for arg in "$@"; do
    case "$arg" in
        --json)    mode="json" ;;
        --total)   mode="total" ;;
        --list)    mode="list" ;;
        --refresh) refresh=1 ;;
        -h|--help) sed -n '3,14p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    esac
done

command_exists() { command -v "$1" >/dev/null 2>&1; }

cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/piercingxx"
cache_file="$cache_dir/updates"
list_file="$cache_dir/updates.list"
lock_file="$cache_dir/updates.lock"
ttl="${PX_UPDATE_TTL:-300}"
mkdir -p "$cache_dir"

cache_fresh() {
    [ "$refresh" -eq 0 ] || return 1
    [ -s "$cache_file" ] || return 1
    local now mtime
    now=$(date +%s)
    mtime=$(stat -c %Y "$cache_file" 2>/dev/null || echo 0)
    [ $((now - mtime)) -lt "$ttl" ]
}

# repo_updates / aur_updates print one package per line
repo_updates() {
    if command_exists pacman; then
        if command_exists checkupdates; then
            local out rc
            out=$(checkupdates --nocolor 2>/dev/null); rc=$?
            # 0 = updates, 2 = none, anything else = failure (offline, db error)
            if [ "$rc" -eq 0 ] || [ "$rc" -eq 2 ]; then
                [ -n "$out" ] && printf '%s\n' "$out"
                return 0
            fi
        fi
        pacman -Qu 2>/dev/null | grep -v '\[ignored\]'
    elif command_exists apt; then
        apt list --upgradable 2>/dev/null | tail -n +2 | sed '/^$/d'
    elif command_exists dnf; then
        # name.arch  version  repo ; stop before the obsoletes section
        dnf -q check-update 2>/dev/null | awk '/^Obsoleting/{exit} NF==3 && $1 ~ /\./ {print}'
    elif command_exists xbps-install; then
        xbps-install -Mun 2>/dev/null
    elif command_exists zypper; then
        zypper --non-interactive --quiet list-updates 2>/dev/null | awk -F'|' '/^v /{gsub(/ /,"",$3); print $3}'
    elif command_exists apk; then
        apk version -l '<' 2>/dev/null | tail -n +2
    fi
}

aur_updates() {
    command_exists pacman || return 0
    if command_exists paru; then
        paru -Qua 2>/dev/null | grep -v '\[ignored\]'
    elif command_exists yay; then
        yay -Qua 2>/dev/null | grep -v '\[ignored\]'
    fi
}

installed_count() {
    if command_exists pacman; then pacman -Qq 2>/dev/null | wc -l
    elif command_exists dpkg-query; then dpkg-query -f '.\n' -W 2>/dev/null | wc -l
    elif command_exists rpm; then rpm -qa 2>/dev/null | wc -l
    elif command_exists xbps-query; then xbps-query -l 2>/dev/null | wc -l
    elif command_exists apk; then apk info 2>/dev/null | wc -l
    else echo 0
    fi
}

refresh_cache() {
    local repo_list aur_list repo aur
    repo_list=$(repo_updates)
    aur_list=$(aur_updates)
    repo=$(printf '%s' "$repo_list" | grep -c . || true)
    aur=$(printf '%s' "$aur_list" | grep -c . || true)
    {
        [ -n "$repo_list" ] && printf '%s\n' "$repo_list"
        [ -n "$aur_list" ] && printf '%s\n' "$aur_list" | sed 's/^/[aur] /'
    } > "$list_file.tmp"
    mv -f "$list_file.tmp" "$list_file"
    printf '%s %s\n' "${repo:-0}" "${aur:-0}" > "$cache_file.tmp"
    mv -f "$cache_file.tmp" "$cache_file"
}

# One checker at a time; whoever waited re-reads the fresh cache
exec 8>"$lock_file"
if flock -w 120 8; then
    cache_fresh || refresh_cache
    flock -u 8
fi

read -r repo aur < "$cache_file" 2>/dev/null
repo=${repo:-0}
aur=${aur:-0}
total=$((repo + aur))

case "$mode" in
    total) echo "$total" ;;
    list)  cat "$list_file" 2>/dev/null ;;
    json)
        tooltip=$(head -n 40 "$list_file" 2>/dev/null \
            | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' -e 's/\t/ /g' \
            | awk 'BEGIN{ORS=""} {if (NR>1) print "\\n"; print}')
        [ "$total" -gt 40 ] && tooltip="$tooltip\\n…"
        [ "$total" -eq 0 ] && tooltip="System is up to date"
        class="none"
        [ "$total" -gt 0 ] && class="pending"
        printf '{"repo":%d,"aur":%d,"total":%d,"packages":%d,"updates":%d,"text":"%d","tooltip":"%s","class":"%s"}\n' \
            "$repo" "$aur" "$total" "$(installed_count)" "$total" "$total" "$tooltip" "$class"
        ;;
    *) echo "$repo $aur $total" ;;
esac
