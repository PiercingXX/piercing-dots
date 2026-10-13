# shellcheck shell=bash
# (sourced by bash, never executed)

# Detect interactive shell
case $- in *i*) iatest=1 ;; *) iatest=0 ;; esac

#######################################################
# PiercingXX's .bashrc https://github.com/piercingxx
#######################################################

#######################################################
# Core sourcing and completion
#######################################################

# Source global definitions (Fedora/openSUSE; Arch/Debian auto-source /etc/bash.bashrc)
if [ -f /etc/bashrc ]; then
    . /etc/bashrc
fi

# PATH first, so tools in ~/.local/bin, ~/.cargo/bin, etc. are found below.
# pathmunge only prepends entries that aren't already there (no dupes in
# nested shells / tmux).
pathmunge() {
    case ":$PATH:" in
        *":$1:"*) ;;
        *) PATH="$1:$PATH" ;;
    esac
}
for _p in "$HOME/go/bin" \
          "$HOME/.local/share/flatpak/exports/bin" \
          /var/lib/flatpak/exports/bin \
          "$HOME/.cargo/bin" \
          "$HOME/.local/bin"; do
    [ -d "$_p" ] && pathmunge "$_p"
done
unset _p
export PATH  # ~/.local/bin is first (linux-mod checks for this line)

# Enable bash programmable completion in interactive shells
if [[ $iatest -gt 0 ]] && ! shopt -oq posix; then
    shopt -s progcomp
    if [ -f /usr/share/bash-completion/bash_completion ]; then
        . /usr/share/bash-completion/bash_completion
    elif [ -f /etc/bash_completion ]; then
        . /etc/bash_completion
    fi
fi

#######################################################
# Shell options, history, and line editing
#######################################################

# History and window sizing
export HISTFILESIZE=50000
export HISTSIZE=10000
export HISTCONTROL=ignoreboth:erasedups
shopt -s checkwinsize
shopt -s histappend
export HISTTIMEFORMAT="%F %T "
PROMPT_COMMAND="${PROMPT_COMMAND:+$PROMPT_COMMAND; }history -a"

# Bell and flow control
if [[ $iatest -gt 0 ]]; then bind "set bell-style visible"; fi
if [[ $iatest -gt 0 ]] && [ -t 0 ]; then stty -ixon; fi

# Readline tweaks (interactive only)
if [[ $iatest -gt 0 ]]; then
    bind 'set completion-ignore-case on'
    bind 'set show-all-if-ambiguous on'
    bind 'TAB:menu-complete'
    bind '"\e[A": history-search-backward'
    bind '"\e[B": history-search-forward'
    if command -v zoxide >/dev/null 2>&1; then
        bind '"\C-f":"zi\n"' # Insert zoxide shortcut
    fi
fi

#######################################################
# Editors, colors, and pager
#######################################################

export EDITOR=nvim
export VISUAL=nvim
alias vim='nvim'

export CLICOLOR=1
export LS_COLORS='no=00:fi=00:di=00;34:ln=01;36:pi=40;33:so=01;35:do=01;35:bd=40;33;01:cd=40;33;01:or=40;31;01:ex=01;32:*.tar=01;31:*.tgz=01;31:*.arj=01;31:*.taz=01;31:*.lzh=01;31:*.zip=01;31:*.z=01;31:*.Z=01;31:*.gz=01;31:*.bz2=01;31:*.deb=01;31:*.rpm=01;31:*.jar=01;31:*.jpg=01;35:*.jpeg=01;35:*.gif=01;35:*.bmp=01;35:*.pbm=01;35:*.pgm=01;35:*.ppm=01;35:*.tga=01;35:*.xbm=01;35:*.xpm=01;35:*.tif=01;35:*.tiff=01;35:*.png=01;35:*.mov=01;35:*.mpg=01;35:*.mpeg=01;35:*.avi=01;35:*.fli=01;35:*.gl=01;35:*.dl=01;35:*.xcf=01;35:*.xwd=01;35:*.ogg=01;35:*.mp3=01;35:*.wav=01;35:*.xml=00;31:'
alias grep='grep --color=auto'

export LESS_TERMCAP_mb=$'\E[01;31m'
export LESS_TERMCAP_md=$'\E[01;31m'
export LESS_TERMCAP_me=$'\E[0m'
export LESS_TERMCAP_se=$'\E[0m'
export LESS_TERMCAP_so=$'\E[01;44;33m'
export LESS_TERMCAP_ue=$'\E[0m'
export LESS_TERMCAP_us=$'\E[01;32m'
if command -v most >/dev/null 2>&1; then
    export PAGER=most
fi

#######################################################
# Aliases
#######################################################

# Quick helpers
alias xx='$HOME/.scripts/PiercingXX-Settings-Menu/settings-menu.sh'
alias ff='fastfetch'
alias c='clear'
alias cls='clear'
alias da='date "+%Y-%m-%d %A %T %Z"'

# System
alias reboot='sudo reboot'
alias shutdown='sudo shutdown -h now'
alias logout='$HOME/.scripts/Control-Scripts/wm-logout-to-tty.sh'
alias freshclam='$HOME/.scripts/PiercingXX-Settings-Menu/virus-scan.sh --update-db'
alias topcpu="ps -eo pcpu,pid,user,args --sort=-pcpu | head -11"
alias openports='ss -tulpn'
alias mountedinfo='df -hT'
alias docker-clean=' \
    docker container prune -f ; \
    docker image prune -f ; \
    docker network prune -f ; \
    docker volume prune -f '

# Editing and safety
alias cp='cp -i'
alias mv='mv -i'
# rm goes to the trash (trash-cli); `rmd` is the real recursive rm.
if command -v trash >/dev/null 2>&1; then
    alias rm='trash -v'
else
    alias rm='rm -i'
fi
alias mkdir='mkdir -p'
alias vi='nvim'
alias svi='sudoedit'
alias vis='nvim "+set si"'
alias less='less -R'

# Navigation
alias home='cd ~'
alias cd..='cd ..'
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias .....='cd ../../../..'
alias bd='cd "$OLDPWD"'


# Listing and ls variants
if command -v eza &>/dev/null; then
    alias ls='eza -a -F -H --icons --color=always --group-directories-first --git'
else
    alias ls='ls -a -F --color=auto'
fi
alias la='\ls -Alh'
alias lx='\ls -lXBh'
alias lk='\ls -lSrh'
alias lc='\ls -ltcrh'
alias lu='\ls -lturh'
alias lr='\ls -lRh'
alias lt='\ls -ltrh'
alias lm='\ls -alh |more'
alias lw='\ls -xAh'
alias ll='\ls -Fls'
alias labc='\ls -lap'
alias lf="\ls -l | grep -E -v '^d'"
alias ldir="\ls -l | grep -E '^d'"
alias lla='\ls -Al'
alias las='\ls -A'
alias lls='\ls -l'

# Permissions helpers
alias mx='chmod a+x'
alias ux='chmod -R u+x'
alias 000='chmod -R 000'
alias 644='chmod -R 644'
alias 666='chmod -R 666'
alias 755='chmod -R 755'
alias 777='chmod -R 777'

# Searching and system info
alias h="history | grep "
alias p="ps aux | grep "
alias ping='ping -c 10'
command -v multitail >/dev/null 2>&1 && alias multitail='multitail --no-repeat -c'
alias rmd='command rm -rfv'

# Archives and storage
alias mktar='tar -cvf'
alias mkbz2='tar -cvjf'
alias mkgz='tar -cvzf'
alias untar='tar -xvf'
alias unbz2='tar -xvjf'
alias ungz='tar -xvzf'
alias folders='du -h --max-depth=1'
alias folderssort='find . -maxdepth 1 -type d -print0 | xargs -0 du -sk | sort -rn'
alias tree='tree -CAhF --dirsfirst'
alias treed='tree -CAFd'
alias logs='sudo find /var/log -type f -exec file {} \; | grep text | cut -d" " -f1 | sed -e"s/:$//g" | grep -v "[0-9]$" | xargs tail -f'

# Applications
if command -v synology-drive >/dev/null 2>&1; then
    alias sd='QT_QPA_PLATFORM=xcb synology-drive > /dev/null 2>&1 &'
fi

#######################################################
# Functions
#######################################################

# Desktop session launchers (alias form for maximum shell compatibility)
# start-* names so the aliases don't shadow the real sway/i3/... binaries
alias hypr='start-hyprland'
alias start-sway='$HOME/.scripts/Control-Scripts/start-sway'
alias start-i3='$HOME/.scripts/Control-Scripts/start-i3'
alias start-bspwm='$HOME/.scripts/Control-Scripts/start-bspwm'
alias start-herbst='$HOME/.scripts/Control-Scripts/start-herbst'
alias start-awesome='$HOME/.scripts/Control-Scripts/start-awesome'
alias start-dwm='$HOME/.scripts/Control-Scripts/start-dwm'
alias start-qtile='$HOME/.scripts/Control-Scripts/start-qtile'
alias start-qtilex='$HOME/.scripts/Control-Scripts/start-qtile --x11'
alias herb='start-herbst'

# Repairs/reconfigures greetd + tuigreet (uses sudo)
alias greetd-fix='$HOME/.scripts/Control-Scripts/start-session.sh'

# ls used after cd/z/cdf: no --git (slow in big repos)
_cd_ls() {
    if command -v eza >/dev/null 2>&1; then
        eza -a -F --icons --color=always --group-directories-first
    else
        command ls -a -F --color=auto
    fi
}

cdf() {
    if ! command -v fzf >/dev/null 2>&1; then
        echo "cdf requires fzf" >&2
        return 1
    fi
    local root="${1:-.}"
    local target
    if command -v fd >/dev/null 2>&1; then
        target=$(fd . -t d "$root" 2>/dev/null | fzf) || return
    else
        target=$(find "$root" -type d 2>/dev/null | fzf) || return
    fi
    [ -n "$target" ] && builtin cd -- "$target" && _cd_ls
}

undotrash() {
    if command -v trash-list >/dev/null 2>&1 && command -v trash-restore >/dev/null 2>&1; then
        trash-list | head -n1 | awk '{print $1}' | xargs -r trash-restore
    else
        echo "trash-cli not available" >&2
        return 1
    fi
}

mkc() { command mkdir -p -- "$1" && { builtin cd -- "$1" || return; }; }

f() {
    find . -type f -iname "*${1:-}*" 2>/dev/null
}

countfiles() {
    local t
    for t in files links directories; do
        echo "$(find . -type "${t:0:1}" | wc -l) $t"
    done 2> /dev/null
}

install_bashrc_support() {
    local dtype
    dtype=$(distribution)
    local common=(tree zoxide trash-cli fzf bash-completion fastfetch bat eza chafa w3m)
    case $dtype in
        "fedora")
            sudo dnf install -y multitail starship "${common[@]}" || sudo dnf install -y multitail "${common[@]}"
            ;;
        "debian")
            local pkg
            for pkg in multitail starship "${common[@]}"; do
                if sudo apt-get install -y "$pkg"; then
                    echo "$pkg installed via apt"
                elif command -v brew >/dev/null 2>&1; then
                    echo "$pkg not available in apt, installing via brew"
                    brew install "$pkg"
                else
                    echo "$pkg not available in apt (and no brew)"
                fi
            done
            ;;
        "arch")
            sudo pacman -S --needed --noconfirm starship "${common[@]}"
            if command -v paru &> /dev/null; then
                paru -S --needed --noconfirm multitail jump-bin
            elif command -v yay &> /dev/null; then
                yay -S --needed --noconfirm multitail jump-bin
            else
                echo "Install paru or yay for multitail and jump."
            fi
            ;;
        "void")
            sudo xbps-install -y multitail starship "${common[@]}"
            ;;
        "suse")
            sudo zypper -n install multitail starship "${common[@]}"
            ;;
        "alpine")
            sudo apk add multitail starship tree zoxide fzf bash-completion fastfetch bat eza chafa w3m
            ;;
        *)
            echo "Unknown distribution"
            ;;
    esac
    # Last resort for starship when the distro has no package
    if ! command -v starship >/dev/null 2>&1; then
        local installer
        installer=$(mktemp) && curl -fsSL https://starship.rs/install.sh -o "$installer" \
            && sh "$installer" -y && rm -f "$installer"
    fi
}

extract() {
    for archive in "$@"; do
        if [ -f "$archive" ]; then
            case $archive in
                *.tar.bz2) tar xvjf "$archive" ;;
                *.tar.gz) tar xvzf "$archive" ;;
                *.tar.xz) tar xvJf "$archive" ;;
                *.tar.zst) tar --zstd -xvf "$archive" ;;
                *.bz2) bunzip2 "$archive" ;;
                *.rar) unrar x "$archive" 2>/dev/null || rar x "$archive" ;;
                *.gz) gunzip "$archive" ;;
                *.xz) unxz "$archive" ;;
                *.tar) tar xvf "$archive" ;;
                *.tbz2) tar xvjf "$archive" ;;
                *.tgz) tar xvzf "$archive" ;;
                *.zip) unzip "$archive" ;;
                *.Z) uncompress "$archive" ;;
                *.7z) 7z x "$archive" ;;
                *) echo "don't know how to extract '$archive'..." ;;
            esac
        else
            echo "'$archive' is not a valid file!"
        fi
    done
}

# cpp SRC DEST : copy with a progress bar
cpp() {
    if command -v rsync >/dev/null 2>&1; then
        rsync -ah --info=progress2 -- "$1" "$2"
        return
    fi
    if ! command -v strace >/dev/null 2>&1; then
        cp -- "$1" "$2"
        return
    fi
    strace -q -ewrite cp -- "${1}" "${2}" 2>&1 |
    awk '{
        count += $NF
        if (count % 10 == 0) {
            percent = count / total_size * 100
            printf "%3d%% [", percent
            for (i=0;i<=percent;i++)
                printf "="
            printf ">"
            for (i=percent;i<100;i++)
                printf " "
            printf "]\r"
        }
    }
    END { print "" }' total_size="$(stat -c '%s' "${1}")" count=0
}

mkdirg() {
    command mkdir -p -- "$1" && { builtin cd -- "$1" || return; }
}

if [[ $iatest -gt 0 ]]; then
    cd () {
        if [ -n "$1" ]; then
            builtin cd "$@" && _cd_ls
        else
            builtin cd ~ && _cd_ls
        fi
    }
fi

pwdtail() {
    pwd | awk -F/ '{nlast = NF -1;print $nlast"/"$NF}'
}

distribution () {
    local dtype="unknown" id="" id_like=""
    if [ -r /etc/os-release ]; then
        # subshell: don't leak NAME/VERSION/... into the interactive shell
        id=$(. /etc/os-release && echo "${ID:-}")
        id_like=$(. /etc/os-release && echo "${ID_LIKE:-}")
        case $id in
            fedora|rhel|centos|bazzite)
                dtype="fedora"
                ;;
            sles|opensuse*)
                dtype="suse"
                ;;
            debian|pop|mint|linuxmint|ubuntu|droidian|mobian|furios|ubuntutouch|ubuntu-touch|pureos|raspbian)
                dtype="debian"
                ;;
            gentoo)
                dtype="gentoo"
                ;;
            arch|artix|manjaro|endeavouros|cachyos|garuda)
                dtype="arch"
                ;;
            void)
                dtype="void"
                ;;
            alpine|postmarketos)
                dtype="alpine"
                ;;
            slackware)
                dtype="slackware"
                ;;
            *)
                case $id_like in
                    *fedora*|*rhel*|*centos*) dtype="fedora" ;;
                    *ubuntu*|*debian*|*pop*|*mint*) dtype="debian" ;;
                    *arch*) dtype="arch" ;;
                    *suse*) dtype="suse" ;;
                    *alpine*) dtype="alpine" ;;
                esac
                ;;
        esac
    fi
    echo "$dtype"
}

alias whatismyip="whatsmyip"
whatsmyip () {
    local dev
    dev=$(ip route get 1.1.1.1 2>/dev/null | awk '/dev/ {for(i=1;i<=NF;i++) if ($i=="dev") {print $(i+1); exit}}')
    echo -n "Internal IP: "
    if command -v ip &> /dev/null; then
        ip -o -4 addr show "${dev:-eth0}" | awk '{print $4}' | cut -d/ -f1 | head -n1
    else
        ifconfig "${dev:-eth0}" | awk '/inet /{print $2}'
    fi
    echo -n "External IP: "
    curl -fsS4 ifconfig.me || curl -fsS ipinfo.io/ip || echo "unavailable"
}

trim() {
    local var=$*
    var="${var#"${var%%[![:space:]]*}"}"
    var="${var%"${var##*[![:space:]]}"}"
    echo -n "$var"
}

#######################################################
# Tools and startup
#######################################################

y() {
    local tmp
    local cwd
    tmp="$(mktemp -t "yazi-cwd.XXXXXX")"
    yazi "$@" --cwd-file="$tmp"
    IFS= read -r -d '' cwd < "$tmp"
    [ -n "$cwd" ] && [ "$cwd" != "$PWD" ] && { builtin cd -- "$cwd" || return; }
    rm -f -- "$tmp"
}

# Cache tool init scripts; regenerate only when the tool binary changes.
# Saves several process spawns on every new shell.
_px_cached_init() {
    local name="$1"; shift
    local bin cache
    bin=$(command -v "$1" 2>/dev/null) || return 1
    cache="${XDG_CACHE_HOME:-$HOME/.cache}/bashrc/$name.bash"
    if [[ ! -s $cache || $bin -nt $cache ]]; then
        command mkdir -p "${cache%/*}"
        "$@" > "$cache" 2>/dev/null || { command rm -f "$cache"; return 1; }
    fi
    # shellcheck source=/dev/null
    . "$cache"
}

_px_cached_init starship starship init bash --print-full-init
if _px_cached_init zoxide zoxide init bash; then
    # zoxide defines z(); wrap it so jumps list the directory like cd does
    if [[ $iatest -gt 0 ]]; then
        z() { __zoxide_z "$@" && _cd_ls; }
    fi
fi
_px_cached_init jump jump shell bash
[[ -r /usr/share/fzf/key-bindings.bash ]] && source /usr/share/fzf/key-bindings.bash
[[ -r /usr/share/fzf/completion.bash ]] && source /usr/share/fzf/completion.bash

# Linuxbrew (Debian fallback for packages apt lacks)
if [ -x /home/linuxbrew/.linuxbrew/bin/brew ]; then
    _px_cached_init brew /home/linuxbrew/.linuxbrew/bin/brew shellenv bash
elif [ -x "$HOME/.linuxbrew/bin/brew" ]; then
    _px_cached_init brew "$HOME/.linuxbrew/bin/brew" shellenv bash
fi

# fastfetch only in the first interactive shell of a terminal, not in tmux,
# nvim's :terminal, or nested shells
if [[ $iatest -gt 0 && ${SHLVL:-1} -le 1 && -z ${TMUX:-} && -z ${NVIM:-} ]] && command -v fastfetch &>/dev/null; then
    fastfetch
fi

# Desktop autostart is disabled by default.
# To opt in on tty1, export PIERCINGXX_AUTOSTART_X=1 before this block runs.
if [[ ${PIERCINGXX_AUTOSTART_X:-0} = 1 ]] && [[ -z ${DISPLAY:-} ]] && [[ $(tty) = /dev/tty1 ]] && command -v startx &>/dev/null; then
    # Don't auto-start if Cosmic is present (Pop!_OS 24.04)
    if ! command -v cosmic-session &>/dev/null && ! command -v cosmic-comp &>/dev/null; then
        exec startx
    fi
fi
