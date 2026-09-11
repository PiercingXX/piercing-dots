#!/bin/bash
# GitHub.com/PiercingXX

resolve_username() {
    if [ -n "${SUDO_USER:-}" ] && getent passwd "$SUDO_USER" >/dev/null 2>&1; then
        echo "$SUDO_USER"
        return
    fi
    local owner
    owner="$(stat -c '%U' "$(pwd)" 2>/dev/null || true)"
    if [ -n "$owner" ] && getent passwd "$owner" >/dev/null 2>&1; then
        echo "$owner"
        return
    fi
    local u1000
    u1000="$(getent passwd 1000 | cut -d: -f1)"
    if [ -n "$u1000" ]; then
        echo "$u1000"
        return
    fi
    id -un
}

username="$(resolve_username)"
home_dir="$(getent passwd "$username" | cut -d: -f6)"
[ -z "$home_dir" ] && home_dir="/home/$username"
builddir=$(pwd)

# Purge existing GIMP config files
rm -Rf "$home_dir/.var/app/org.gimp.GIMP/config/GIMP/"*
rm -Rf "$home_dir/.config/GIMP/"*

# Copy GIMP dots
mkdir -p "$home_dir/.config/GIMP"
chown -R "$username":"$username" "$home_dir/.config/GIMP"
cp -Rf ../dots/GIMP/* "$home_dir/.config/GIMP/"
chown "$username":"$username" -R "$home_dir/.config/GIMP"
cd "$builddir" || exit
