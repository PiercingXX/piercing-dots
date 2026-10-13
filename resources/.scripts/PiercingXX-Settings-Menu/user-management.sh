#!/bin/bash
# GitHub.com/PiercingXX
# User Management: add/remove users, passwords, and group membership.

SCRIPT_DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
# shellcheck source=../lib/common.sh
. "$SCRIPT_DIR/../lib/common.sh"
detect_distro

command_exists gum || die "gum is required for this menu."

me="$(id -un)"

# Human accounts: UID 1000-59999 with a real shell
human_users() {
    getent passwd | awk -F: '$3 >= 1000 && $3 < 60000 && $7 !~ /(nologin|false)$/ {print $1}'
}

# Admin group used for sudo on this distro
admin_group() {
    if getent group wheel >/dev/null; then echo wheel
    elif getent group sudo >/dev/null; then echo sudo
    fi
}

valid_username() {
    [[ "$1" =~ ^[a-z_][a-z0-9_-]{0,31}$ ]]
}

pick_user() {
    local header="$1" include_self="${2:-1}" list
    list=$(human_users)
    [ "$include_self" = 1 ] || list=$(printf '%s\n' "$list" | grep -vx "$me")
    [ -n "$list" ] || { warn "No matching users."; return 1; }
    printf '%s\n' "$list" | gum choose --header "$header"
}

add_user() {
    local name shell admin
    name=$(gum input --placeholder "new username (lowercase, a-z 0-9 _ -)")
    [ -n "$name" ] || return 0
    valid_username "$name" || { err "Invalid username: $name"; return 1; }
    getent passwd "$name" >/dev/null && { err "User $name already exists."; return 1; }

    shell=$(grep -E '^/' /etc/shells 2>/dev/null | grep -vE 'nologin|false' | sort -u \
        | gum choose --header "Login shell for $name" --selected /bin/bash) || return 0
    [ -n "$shell" ] || shell=/bin/bash

    admin=$(admin_group)
    local groups=()
    if [ -n "$admin" ] && gum confirm "Give $name admin rights (add to $admin)?" --default=false; then
        groups=("$admin")
    fi

    if command_exists useradd; then
        if [ ${#groups[@]} -gt 0 ]; then
            sudo useradd -m -s "$shell" -G "${groups[0]}" "$name" || return 1
        else
            sudo useradd -m -s "$shell" "$name" || return 1
        fi
    else
        # BusyBox (Alpine/postmarketOS without shadow)
        sudo adduser -D -s "$shell" "$name" || return 1
        [ ${#groups[@]} -gt 0 ] && sudo addgroup "$name" "${groups[0]}"
    fi
    ok "User $name created."
    say "Set a password for $name (the account stays locked until you do):"
    sudo passwd "$name"
}

remove_user() {
    local name uid
    name=$(pick_user "Remove which user?" 0) || return 0
    [ -n "$name" ] || return 0
    uid=$(id -u "$name" 2>/dev/null)
    if [ "$name" = root ] || [ "$name" = "$me" ] || [ -z "$uid" ] || [ "$uid" -lt 1000 ]; then
        err "Refusing to remove $name."
        return 1
    fi
    getent passwd "$name" | awk -F: '{printf "User: %s\nUID: %s\nHome: %s\nShell: %s\n", $1, $3, $6, $7}'
    echo "Groups: $(id -nG "$name" 2>/dev/null)"
    echo

    local mode
    mode=$(gum choose --header "Remove $name how?" "Keep home folder" "Delete home folder too" "Cancel") || return 0
    [ "$mode" = "Cancel" ] || [ -z "$mode" ] && return 0

    local typed
    typed=$(gum input --placeholder "type '$name' to confirm")
    [ "$typed" = "$name" ] || { warn "Names didn't match; nothing removed."; return 0; }

    local flag=()
    [ "$mode" = "Delete home folder too" ] && flag=(-r)
    if command_exists userdel; then
        sudo userdel "${flag[@]}" "$name" && ok "User $name removed."
    else
        if [ ${#flag[@]} -gt 0 ]; then
            sudo deluser --remove-home "$name" && ok "User $name removed."
        else
            sudo deluser "$name" && ok "User $name removed."
        fi
    fi
}

change_password() {
    local name
    name=$(pick_user "Change password for?") || return 0
    [ -n "$name" ] || return 0
    if [ "$name" = "$me" ]; then
        passwd
    else
        sudo passwd "$name"
    fi
}

manage_groups() {
    local name action group
    name=$(pick_user "Manage groups for?") || return 0
    [ -n "$name" ] || return 0
    while true; do
        clear
        echo "User: $name"
        echo "Groups: $(id -nG "$name" 2>/dev/null)"
        echo
        action=$(gum choose --header "Groups for $name" "Add to group" "Remove from group" "Back") || return 0
        case "$action" in
            "Add to group")
                group=$(getent group | cut -d: -f1 | sort | gum filter --placeholder "group to add $name to") || continue
                [ -n "$group" ] || continue
                if command_exists gpasswd; then
                    sudo gpasswd -a "$name" "$group"
                else
                    sudo addgroup "$name" "$group"
                fi
                ;;
            "Remove from group")
                group=$(id -nG "$name" | tr ' ' '\n' | grep -vx "$(id -gn "$name")" \
                    | gum choose --header "Remove $name from") || continue
                [ -n "$group" ] || continue
                if [ "$name" = "$me" ] && [ "$group" = "$(admin_group)" ]; then
                    gum confirm "Remove yourself from $group? You will lose sudo." --default=false || continue
                fi
                if command_exists gpasswd; then
                    sudo gpasswd -d "$name" "$group"
                else
                    sudo delgroup "$name" "$group"
                fi
                ;;
            *) return 0 ;;
        esac
        pause
    done
}

while true; do
    clear
    action=$(gum choose --header="User Management" "Add User" "Remove User" "Change Password" "Manage Groups" "Back")
    case "$action" in
        "Add User")        add_user ;;
        "Remove User")     remove_user ;;
        "Change Password") change_password ;;
        "Manage Groups")   manage_groups; continue ;;
        "Back"|"")         break ;;
    esac
    pause
done
