#!/usr/bin/env bash

#########################################################
# Software Manager: Install and Uninstall Packages
#########################################################

# Function to determine the current distribution
distribution () {
    local dtype="unknown"
    if [ -r /etc/os-release ]; then
        source /etc/os-release
        case $ID in
            fedora|rhel|centos|bazzite)
                dtype="fedora"
                ;;
            ubuntu|debian|pop|mint)
                dtype="debian"
                ;;
            arch|manjaro|cachyos)
                dtype="arch"
                ;;
            *)
                if [ -n "$ID_LIKE" ]; then
                    case $ID_LIKE in
                        *fedora*|*rhel*|*centos*|*bazzite*)
                            dtype="fedora"
                            ;;
                        *ubuntu*|*debian*|*pop*|*mint*)
                            dtype="debian"
                            ;;
                        *arch*|*manjaro*|*cachyos*)
                            dtype="arch"
                            ;;
                    esac
                fi
                ;;
        esac
    fi
    echo $dtype
}

# Function to search and install software
install_software() {
    local dtype
    dtype=$(distribution)
    case "$dtype" in
        "arch")
            if command -v paru &> /dev/null; then
                paru -Slq | fzf --multi --preview 'paru -Sii {1}' --preview-window=down:75% | xargs -ro paru -S
            elif command -v yay &> /dev/null; then
                yay -Slq | fzf --multi --preview 'yay -Sii {1}' --preview-window=down:75% | xargs -ro yay -S
            else
                pacman -Slq | fzf --multi --preview 'pacman -Si {1}' --preview-window=down:75% | xargs -ro sudo pacman -S
            fi
            ;;
        "debian")
            (
                apt-cache pkgnames
                if command -v flatpak &>/dev/null; then
                    flatpak remote-ls --app flathub --columns=name
                fi
            ) | fzf --multi --preview='apt-cache show {1} || flatpak remote-info flathub {1}' --preview-window=down:75% | xargs -ro -I{} bash -c '
                if apt-cache show "{}" &>/dev/null; then
                    sudo apt-get install "{}"
                elif flatpak remote-info flathub "{}" &>/dev/null; then
                    flatpak install -y flathub "{}"
                fi
            ;;
        "fedora")
            (
                rpm -qa --qf '%{NAME}\n'
                if command -v flatpak &>/dev/null; then
                    flatpak remote-ls --app flathub --columns=name
                fi
            ) | fzf --multi --preview='dnf info {1} || flatpak remote-info flathub {1}' --preview-window=down:75% | xargs -ro -I{} bash -c '
                if dnf info "{}" &>/dev/null; then
                    sudo dnf install "{}"
                elif flatpak remote-info flathub "{}" &>/dev/null; then
                    flatpak install -y flathub "{}"
                fi
            ;;
    esac
}

# Function to uninstall software
uninstall_software() {
    local dtype selection
    dtype=$(distribution)
    local native_list_cmd
    case "$dtype" in
        arch)
            if command -v paru &>/dev/null; then
                native_list_cmd='paru -Qq'
            elif command -v yay &>/dev/null; then
                native_list_cmd='yay -Qq'
            else
                native_list_cmd='pacman -Qq'
            fi
            ;;
        debian)
            native_list_cmd="dpkg-query -W -f='\${binary:Package}\n'"
            ;;
        fedora)
            native_list_cmd="rpm -qa --qf '%{NAME}\n'"
            ;;
        *)
            native_list_cmd='echo'
            ;;
    esac
    selection=$(
        {
            eval "$native_list_cmd" | sed 's/^/[N] /'
        } | fzf --multi --prompt="Uninstall (enter to select): " \
                            --preview 'echo {}' \
                            --preview-window=down:75% --border
    )
    [[ -z "$selection" ]] && return 0
    while IFS= read -r line; do
        pkg=${line#"[N] "}
        case "$dtype" in
            arch)
                sudo pacman -Rns --noconfirm "$pkg"
                ;;
            debian)
                sudo apt-get purge -y "$pkg"
                ;;
            fedora)
                if command -v dnf &>/dev/null; then
                    sudo dnf remove -y "$pkg"
                else
                    sudo yum remove -y "$pkg"
                fi
                ;;
            *)
                echo "Unknown or unsupported distribution for uninstall: $pkg"
                ;;
        esac
    done <<< "$selection"
}

# Main script execution
# ...existing code...
if [ -z "$1" ]; then
    echo "Select mode:"
    select mode in "Install" "Uninstall" "Quit"; do
        case $mode in
            Install) set -- install; break ;;
            Uninstall) set -- uninstall; break ;;
            Quit) exit 0 ;;
        esac
    done
fi

case "$1" in
    install)
        install_software
        ;;
    uninstall)
        uninstall_software
        ;;
    *)
        echo "Usage: $0 {install|uninstall}"
        exit 1
        ;;
esac
# ...existing code...