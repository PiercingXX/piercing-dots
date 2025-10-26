#!/usr/bin/env bash
# GitHub.com/PiercingXX

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
                paru -Slq | fzf --multi --preview 'paru -Sii {1}' --preview-window=down:50% | xargs -ro paru -S
            elif command -v yay &> /dev/null; then
                yay -Slq | fzf --multi --preview 'yay -Sii {1}' --preview-window=down:50% | xargs -ro yay -S
            else
                pacman -Slq | fzf --multi --preview 'pacman -Si {1}' --preview-window=down:50% | xargs -ro sudo pacman -S
            fi
            ;;
        "debian")
            ( \
                apt-cache pkgnames; \
                if command -v flatpak &>/dev/null; then \
                    flatpak remote-ls --app flathub --columns=name; \
                fi \
            ) | fzf --multi --preview="apt-cache show {} || flatpak remote-info flathub {}" --preview-window=down:50% | xargs -ro -I{} bash -c "
                if apt-cache show \"\$1\" &>/dev/null; then
                    sudo apt-get install \"\$1\"
                elif flatpak remote-info flathub \"\$1\" &>/dev/null; then
                    flatpak install -y flathub \"\$1\"
                fi
            " --
            ;;
        "fedora")
            ( \
                rpm -qa --qf "%{NAME}\n"; \
                if command -v flatpak &>/dev/null; then \
                    flatpak remote-ls --app flathub --columns=name; \
                fi \
            ) | fzf --multi --preview="dnf info {} || flatpak remote-info flathub {}" --preview-window=down:50% | xargs -ro -I{} bash -c "
                if dnf info \"\$1\" &>/dev/null; then
                    sudo dnf install \"\$1\"
                elif flatpak remote-info flathub \"\$1\" &>/dev/null; then
                    flatpak install -y flathub \"\$1\"
                fi
            " --
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
    pkgs=$(eval "$native_list_cmd")
    [ -z "$pkgs" ] && return 0
    selection=$(printf "%s\n" "$pkgs" | fzf --multi --prompt="Uninstall (enter to select): " \
                            --preview 'echo {}' \
                            --preview-window=down:50% --border)
    [[ -z "$selection" ]] && return 0
    while IFS= read -r pkg; do
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
while true; do
    if [ -z "$1" ]; then
        if ! command -v gum &>/dev/null; then
            if command -v paru &>/dev/null; then
                echo "gum not found. Installing gum with paru..."
                paru --noconfirm -S gum
            fi
        fi
        if ! command -v gum &>/dev/null; then
            echo "gum is not installed and could not be installed automatically. Please install gum for a modern menu (https://github.com/charmbracelet/gum)."
            exit 1
        fi
        mode=$(gum choose --header="Software Manager" "📦 Install" "🗑️ Uninstall" "🚪 Quit")
        case $mode in
            "📦 Install") set -- install ;;
            "🗑️ Uninstall") set -- uninstall ;;
            "🚪 Quit"|"") exit 0 ;;
        esac
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
    # Reset $1 so the menu shows again
    set --
done
# ...existing code...