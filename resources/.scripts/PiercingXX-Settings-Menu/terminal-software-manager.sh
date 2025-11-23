#!/bin/bash
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
            ubuntu|debian|pop|mint|pureos)
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
                        *ubuntu*|*debian*|*pop*|*mint*|*pureos*)
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

clear
# Function to search and install software (clean, with conditional brew)
install_software() {
    local dtype
    dtype=$(distribution)
    case "$dtype" in
        "arch")
            (
                if command -v paru &>/dev/null; then
                    paru -Slq | sed 's/^/[repo] /'
                elif command -v yay &>/dev/null; then
                    yay -Slq | sed 's/^/[repo] /'
                else
                    pacman -Slq | sed 's/^/[repo] /'
                fi
                if command -v flatpak &>/dev/null; then
                    flatpak remote-ls --app flathub --columns=application | sed 's/^/[flatpak] /'
                fi
                if command -v brew &>/dev/null; then
                    brew formulae | sed 's/^/[brew] /'
                fi
            ) | fzf --multi \
                --preview='sel={}; n=$(printf "%s" "$sel" | cut -d" " -f2-); if [[ "$sel" == "[flatpak] "* ]]; then flatpak remote-info flathub "$n" 2>/dev/null; elif [[ "$sel" == "[brew] "* ]] && command -v brew &>/dev/null; then brew info "$n" 2>/dev/null; else flatpak remote-info flathub "$n" 2>/dev/null || (command -v paru >/dev/null 2>&1 && (paru -Si --aur "$n" 2>/dev/null || paru -Si "$n" 2>/dev/null)) || pacman -Si "$n" 2>/dev/null; fi' \
                --preview-window=down:50% \
            | xargs -ro -I{} bash -c '
                sel="{}"
                name=$(printf "%s" "$sel" | cut -d" " -f2-)
                if [[ "$sel" == "[flatpak] "* ]]; then
                    if command -v flatpak &>/dev/null; then
                        flatpak install -y flathub "$name"
                    else
                        echo "flatpak not installed; skipping $name" >&2
                    fi
                elif [[ "$sel" == "[brew] "* ]]; then
                    if command -v brew &>/dev/null; then
                        brew install "$name"
                    else
                        echo "brew not installed; run Brew Setup first" >&2
                    fi
                elif command -v paru &>/dev/null; then
                    paru -S --noconfirm --skipreview "$name"
                elif command -v yay &>/dev/null; then
                    yay -S --noconfirm "$name"
                else
                    sudo pacman -S --noconfirm "$name"
                fi
            ;;
        "debian")
            (
                apt-cache pkgnames
                if command -v flatpak &>/dev/null; then
                    flatpak remote-ls --app flathub --columns=application
                fi
                if command -v brew &>/dev/null; then
                    brew formulae | sed 's/^/[brew] /'
                fi
            ) | fzf --multi --preview="apt-cache show {} || flatpak remote-info flathub {} || ( [[ {} == '[brew] '* ]] && command -v brew &>/dev/null && brew info \"\$(echo {} | cut -d' ' -f2-)\" )" --preview-window=down:50% | xargs -ro -I{} bash -c '
                sel="{}";
                if apt-cache show "$sel" &>/dev/null; then
                    sudo apt-get install -y "$sel"
                elif flatpak remote-info flathub "$sel" &>/dev/null; then
                    flatpak install -y flathub "$sel"
                elif [[ "$sel" == "[brew] "* ]]; then
                    name=$(echo "$sel" | cut -d" " -f2-)
                    if command -v brew &>/dev/null; then
                        brew install "$name"
                    fi
                fi'
            ;;
        "fedora")
            (
                rpm -qa --qf "%{NAME}\n"
                if command -v flatpak &>/dev/null; then
                    flatpak remote-ls --app flathub --columns=application
                fi
                if command -v brew &>/dev/null; then
                    brew formulae | sed 's/^/[brew] /'
                fi
            ) | fzf --multi --preview="dnf info {} || flatpak remote-info flathub {} || ( [[ {} == '[brew] '* ]] && command -v brew &>/dev/null && brew info \"\$(echo {} | cut -d' ' -f2-)\" )" --preview-window=down:50% | xargs -ro -I{} bash -c '
                sel="{}";
                if dnf info "$sel" &>/dev/null; then
                    sudo dnf install -y "$sel"
                elif flatpak remote-info flathub "$sel" &>/dev/null; then
                    flatpak install -y flathub "$sel"
                elif [[ "$sel" == "[brew] "* ]]; then
                    name=$(echo "$sel" | cut -d" " -f2-)
                    if command -v brew &>/dev/null; then
                        brew install "$name"
                    fi
                fi'
            ;;
    esac
}

# Function to uninstall software
uninstall_software() {
    local dtype selection
    dtype=$(distribution)
    local native_list_cmd flatpak_list_cmd
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
    # Flatpak list command (if available)
    if command -v flatpak &>/dev/null; then
        flatpak_list_cmd='flatpak list --app --columns=application'
    else
        flatpak_list_cmd='echo'
    fi
    # Brew list command (if available)
    if command -v brew &>/dev/null; then
        brew_list_cmd='brew list --formulae'
    else
        brew_list_cmd='echo'
    fi
    pkgs=$( (eval "$native_list_cmd"; eval "$flatpak_list_cmd"; eval "$brew_list_cmd") )
    [ -z "$pkgs" ] && return 0
    selection=$(printf "%s\n" "$pkgs" | fzf --multi --prompt="Uninstall (enter to select): " \
                            --preview 'echo {}' \
                            --preview-window=down:50% --border)
    [[ -z "$selection" ]] && return 0
    while IFS= read -r pkg; do
        # Try native uninstall first, then flatpak
        if eval "$native_list_cmd" | grep -Fxq "$pkg"; then
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
        elif command -v flatpak &>/dev/null && flatpak list --app --columns=application | grep -Fxq "$pkg"; then
            flatpak uninstall -y "$pkg"
        elif command -v brew &>/dev/null && brew list --formulae | grep -Fxq "$pkg"; then
            brew uninstall "$pkg"
        else
            echo "Unknown or unsupported package for uninstall: $pkg"
        fi
    done <<< "$selection"
}

while true; do
    clear
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
