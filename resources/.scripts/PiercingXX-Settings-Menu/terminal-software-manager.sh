#!/bin/bash
# GitHub.com/PiercingXX
#########################################################
# Software Manager: search, install and uninstall packages
# (distro repos, AUR on Arch, and Flathub).
#   terminal-software-manager.sh [install|uninstall]
#########################################################

SCRIPT_DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
# shellcheck source=../lib/common.sh
. "$SCRIPT_DIR/../lib/common.sh"
detect_distro

command_exists fzf || { pkg_install fzf || true; }
command_exists fzf || die "fzf is required for the Software Manager."

AUR_HELPER=$(aur_helper)

# Packages that keep the system bootable/usable; never removed from here
PROTECTED_PKGS=(
    base base-files base-system alpine-base filesystem
    linux linux-lts linux-zen linux-hardened linux-firmware linux-surface
    linux-image-amd64 linux-image-arm64 kernel kernel-core kernel-default
    glibc libc6 musl systemd systemd-sysv openrc runit dinit s6 elogind
    pacman apt dpkg dnf rpm xbps zypper apk-tools
    sudo doas bash coreutils util-linux shadow grub systemd-boot mkinitcpio dracut
)

is_protected() {
    local p
    for p in "${PROTECTED_PKGS[@]}"; do
        [ "$1" = "$p" ] && return 0
    done
    return 1
}

clean_list() {
    grep -v '^$' | LC_ALL=C grep -v '[^[:print:]]' | sort -u
}

# ---------------------------------------------------------------------------
# Candidate list: "[source] name" lines
# ---------------------------------------------------------------------------
list_available() {
    case "$PKG" in
        pacman)
            pacman -Slq 2>/dev/null | clean_list | sed 's/^/[repo] /'
            if [ -n "$AUR_HELPER" ]; then
                # -Sla lists only AUR packages, so nothing appears twice. Some
                # paru builds return a compressed blob here; fall back to the
                # official AUR name list when the helper gives nothing usable.
                local aur_list
                aur_list=$("$AUR_HELPER" -Slqa 2>/dev/null | clean_list)
                if [ -z "$aur_list" ] && command_exists curl; then
                    aur_list=$(curl -fsSL https://aur.archlinux.org/packages.gz 2>/dev/null | gunzip 2>/dev/null | clean_list)
                fi
                [ -n "$aur_list" ] && printf '%s\n' "$aur_list" | sed 's/^/[aur] /'
            fi ;;
        apt)    apt-cache pkgnames 2>/dev/null | clean_list | sed 's/^/[repo] /' ;;
        dnf)    dnf repoquery --available --qf '%{name}\n' 2>/dev/null | clean_list | sed 's/^/[repo] /' ;;
        xbps)   xbps-query -Rs '' 2>/dev/null | awk '{print $2}' | sed -E 's/-[0-9][^ ]*$//' | clean_list | sed 's/^/[repo] /' ;;
        zypper) zypper --quiet --non-interactive search --type package 2>/dev/null \
                    | awk -F'|' 'NF >= 3 && $2 !~ /Name/ {gsub(/^ +| +$/, "", $2); print $2}' | clean_list | sed 's/^/[repo] /' ;;
        apk)    apk search 2>/dev/null | sed -E 's/-[0-9][^-]*-r[0-9]+$//' | clean_list | sed 's/^/[repo] /' ;;
    esac
    if command_exists flatpak; then
        flatpak remote-ls --app flathub --columns=application 2>/dev/null | clean_list | sed 's/^/[flatpak] /'
    fi
}

list_installed() {
    case "$PKG" in
        pacman) pacman -Qq ;;
        apt)    dpkg-query -W -f='${binary:Package}\n' ;;
        dnf)    rpm -qa --qf '%{NAME}\n' ;;
        xbps)   xbps-query -l | awk '{print $2}' | sed -E 's/-[0-9][^ ]*$//' ;;
        zypper) rpm -qa --qf '%{NAME}\n' ;;
        apk)    apk info 2>/dev/null ;;
    esac 2>/dev/null | clean_list | sed 's/^/[repo] /'
    if command_exists flatpak; then
        flatpak list --app --columns=application 2>/dev/null | clean_list | sed 's/^/[flatpak] /'
    fi
}

# Preview command for fzf ({} = "[source] name")
preview_cmd() {
    local info
    case "$PKG" in
        pacman) info='pacman -Si "$n" 2>/dev/null || pacman -Qi "$n" 2>/dev/null' ;;
        apt)    info='apt-cache show "$n" 2>/dev/null | head -n 30' ;;
        dnf)    info='dnf info "$n" 2>/dev/null' ;;
        xbps)   info='xbps-query -RS "$n" 2>/dev/null' ;;
        zypper) info='zypper --quiet info "$n" 2>/dev/null' ;;
        apk)    info='apk info -a "$n" 2>/dev/null | head -n 30' ;;
        *)      info='echo "$n"' ;;
    esac
    local aur='echo'
    [ -n "$AUR_HELPER" ] && aur="$AUR_HELPER -Si --aur \"\$n\" 2>/dev/null"
    printf '%s' "s={}; n=\${s#* }; case \"\$s\" in '[flatpak] '*) flatpak remote-info flathub \"\$n\" 2>/dev/null || flatpak info \"\$n\" 2>/dev/null ;; '[aur] '*) $aur ;; *) $info ;; esac"
}

# Split fzf selections into repo / aur / flatpak arrays
split_selection() {
    REPO_PKGS=(); AUR_PKGS=(); FLATPAKS=()
    local line
    while IFS= read -r line; do
        [ -n "$line" ] || continue
        case "$line" in
            "[flatpak] "*) FLATPAKS+=("${line#* }") ;;
            "[aur] "*)     AUR_PKGS+=("${line#* }") ;;
            *)             REPO_PKGS+=("${line#* }") ;;
        esac
    done <<< "$1"
}

install_software() {
    local selection
    selection=$(list_available | fzf --multi --prompt="Install > " \
        --header="Tab to select several, Enter to install" \
        --preview="$(preview_cmd)" --preview-window=down:50%) || return 0
    [ -n "$selection" ] || return 0
    split_selection "$selection"

    if [ ${#REPO_PKGS[@]} -gt 0 ]; then
        say "Installing: ${REPO_PKGS[*]}"
        case "$PKG" in
            pacman) sudo pacman -S --needed "${REPO_PKGS[@]}" ;;
            apt)    sudo apt-get install "${REPO_PKGS[@]}" ;;
            dnf)    sudo dnf install "${REPO_PKGS[@]}" ;;
            xbps)   sudo xbps-install "${REPO_PKGS[@]}" ;;
            zypper) sudo zypper install "${REPO_PKGS[@]}" ;;
            apk)    sudo apk add "${REPO_PKGS[@]}" ;;
        esac
    fi
    if [ ${#AUR_PKGS[@]} -gt 0 ]; then
        # Interactive on purpose: review the PKGBUILD before it builds
        say "Installing from the AUR: ${AUR_PKGS[*]}"
        "$AUR_HELPER" -S --needed "${AUR_PKGS[@]}"
    fi
    if [ ${#FLATPAKS[@]} -gt 0 ]; then
        say "Installing Flatpaks: ${FLATPAKS[*]}"
        flatpak install flathub "${FLATPAKS[@]}"
    fi
}

uninstall_software() {
    local selection p
    selection=$(list_installed | fzf --multi --prompt="Uninstall > " \
        --header="Tab to select several, Enter to review" \
        --preview="$(preview_cmd)" --preview-window=down:50%) || return 0
    [ -n "$selection" ] || return 0
    split_selection "$selection"

    local keep=()
    for p in "${REPO_PKGS[@]}"; do
        if is_protected "$p"; then
            warn "Skipping protected package: $p"
        else
            keep+=("$p")
        fi
    done
    REPO_PKGS=("${keep[@]}")
    [ ${#REPO_PKGS[@]} -gt 0 ] || [ ${#FLATPAKS[@]} -gt 0 ] || return 0

    echo
    [ ${#REPO_PKGS[@]} -gt 0 ] && echo "Packages: ${REPO_PKGS[*]}"
    [ ${#FLATPAKS[@]} -gt 0 ] && echo "Flatpaks: ${FLATPAKS[*]}"
    confirm "Remove these? (the package manager shows the full list before removing)" || return 0

    # No --noconfirm/-y: the package manager prints everything it will remove
    # (including dependencies) and asks once more.
    if [ ${#REPO_PKGS[@]} -gt 0 ]; then
        case "$PKG" in
            pacman) sudo pacman -Rns "${REPO_PKGS[@]}" ;;
            apt)    sudo apt-get purge "${REPO_PKGS[@]}" ;;
            dnf)    sudo dnf remove "${REPO_PKGS[@]}" ;;
            xbps)   sudo xbps-remove -R "${REPO_PKGS[@]}" ;;
            zypper) sudo zypper remove "${REPO_PKGS[@]}" ;;
            apk)    sudo apk del "${REPO_PKGS[@]}" ;;
        esac
    fi
    if [ ${#FLATPAKS[@]} -gt 0 ]; then
        flatpak uninstall "${FLATPAKS[@]}"
    fi
}

choose_mode() {
    local i="📦 Install" u="🗑️ Uninstall" b="🚪 Back"
    if [[ "${PIERCINGXX_ASCII_MENU:-0}" == 1 ]]; then
        i="Install"; u="Uninstall"; b="Back"
    fi
    local pick
    if command_exists gum; then
        pick=$(gum choose --header="Software Manager" "$i" "$u" "$b")
    else
        select pick in "$i" "$u" "$b"; do break; done
    fi
    case "$pick" in
        "$i") echo install ;;
        "$u") echo uninstall ;;
        *)    echo back ;;
    esac
}

[ -n "$PKG" ] || die "Unsupported distribution for the Software Manager."

# Direct mode: terminal-software-manager.sh install|uninstall
case "${1:-}" in
    install)   install_software; exit $? ;;
    uninstall) uninstall_software; exit $? ;;
    "") ;;
    *) echo "Usage: $0 [install|uninstall]"; exit 1 ;;
esac

while true; do
    clear
    case "$(choose_mode)" in
        install)   install_software ;;
        uninstall) uninstall_software ;;
        *)         exit 0 ;;
    esac
    echo
    pause
done
