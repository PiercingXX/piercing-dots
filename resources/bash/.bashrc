#!/usr/bin/env bash

# Detect interactive shell
case $- in *i*) iatest=1 ;; *) iatest=0 ;; esac

#######################################################
# PiercingXX's .bashrc https://github.com/piercingxx
#######################################################

# Source global definitions
if [ -f /etc/bashrc ]; then
	. /etc/bashrc
fi

# Enable bash programmable completion features in interactive shells
if [[ $iatest -gt 0 ]]; then
    if [ -f /usr/share/bash-completion/bash_completion ]; then
        . /usr/share/bash-completion/bash_completion
    elif [ -f /etc/bash_completion ]; then
        . /etc/bash_completion
    fi
fi

#######################################################
# EXPORTS
#######################################################

# Disable the bell
if [[ $iatest -gt 0 ]]; then bind "set bell-style visible"; fi

# Expand the history size
export HISTFILESIZE=10000
export HISTSIZE=500

# Check the window size after each command and, if necessary, update the values of LINES and COLUMNS
shopt -s checkwinsize

# Causes bash to append to history instead of overwriting it so if you start a new terminal, you have old session history
shopt -s histappend
# Append to existing PROMPT_COMMAND safely so other tools keep working
PROMPT_COMMAND="${PROMPT_COMMAND:+$PROMPT_COMMAND; }history -a"

# Allow ctrl-S for history navigation (with ctrl-R)
if [[ $iatest -gt 0 ]]; then stty -ixon; fi

# Interactive line-editing tweaks
if [[ $iatest -gt 0 ]]; then
    # Tab completion settings
    bind 'set completion-ignore-case on'
    bind 'set show-all-if-ambiguous on'
    bind 'TAB:menu-complete'
fi

# Set the default editor
export EDITOR=nvim
export VISUAL=nvim
alias vim='nvim'

# To have colors for ls and all grep commands such as grep, egrep and zgrep
export CLICOLOR=1
export LS_COLORS='no=00:fi=00:di=00;34:ln=01;36:pi=40;33:so=01;35:do=01;35:bd=40;33;01:cd=40;33;01:or=40;31;01:ex=01;32:*.tar=01;31:*.tgz=01;31:*.arj=01;31:*.taz=01;31:*.lzh=01;31:*.zip=01;31:*.z=01;31:*.Z=01;31:*.gz=01;31:*.bz2=01;31:*.deb=01;31:*.rpm=01;31:*.jar=01;31:*.jpg=01;35:*.jpeg=01;35:*.gif=01;35:*.bmp=01;35:*.pbm=01;35:*.pgm=01;35:*.ppm=01;35:*.tga=01;35:*.xbm=01;35:*.xpm=01;35:*.tif=01;35:*.tiff=01;35:*.png=01;35:*.mov=01;35:*.mpg=01;35:*.mpeg=01;35:*.avi=01;35:*.fli=01;35:*.gl=01;35:*.dl=01;35:*.xcf=01;35:*.xwd=01;35:*.ogg=01;35:*.mp3=01;35:*.wav=01;35:*.xml=00;31:'
#export GREP_OPTIONS='--color=auto' #deprecated
alias grep='/usr/bin/grep --color=auto'

# Color for manpages in less makes manpages a little easier to read
export LESS_TERMCAP_mb=$'\E[01;31m'
export LESS_TERMCAP_md=$'\E[01;31m'
export LESS_TERMCAP_me=$'\E[0m'
export LESS_TERMCAP_se=$'\E[0m'
export LESS_TERMCAP_so=$'\E[01;44;33m'
export LESS_TERMCAP_ue=$'\E[0m'
export LESS_TERMCAP_us=$'\E[01;32m'


#######################################################
# GENERAL ALIAS'
#######################################################


# PiercingXX maintenance script can be found at git clone https://github.com/piercingxx/piercing-dots
alias xx='$HOME/maintenance*.sh'
alias ff='fastfetch'
alias c='clear'

# alias to show the date
alias da='date "+%Y-%m-%d %A %T %Z"'

# Alias' to modified commands
alias cp='cp -i'
alias mv='mv -i'
alias rm='trash -v'
alias mkdir='mkdir -p'
alias ps='ps auxf'
alias ping='ping -c 10'
alias less='less -R'
alias cls='clear'
alias multitail='multitail --no-repeat -c'
alias freshclam='sudo freshclam'
alias vi='nvim'
alias svi='sudo vi'
alias vis='nvim "+set si"'

# Change directory aliases
alias home='cd ~'
alias cd..='cd ..'
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias .....='cd ../../../..'

# cd into the old directory
alias bd='cd "$OLDPWD"'

# Remove a directory and all files
alias rmd='/bin/rm  --recursive --force --verbose '

# Alias's for multiple directory listing commands
alias la='\ls -Alh'										# show hidden files
alias ls='eza -a -F -H --icons --color=always --group-directories-first --git'	# add colors and file type extensions
alias lx='\ls -lXBh'										# sort by extension
alias lk='\ls -lSrh'										# sort by size
alias lc='\ls -ltcrh'										# sort by change time
alias lu='\ls -lturh'										# sort by access time
alias lr='\ls -lRh'										# recursive ls
alias lt='\ls -ltrh'										# sort by date
alias lm='\ls -alh |more'									# pipe through 'more'
alias lw='\ls -xAh'										# wide listing format
alias ll='\ls -Fls'										# long listing format
alias labc='\ls -lap'										# alphabetical sort
alias lf="\ls -l | egrep -v '^d'"									# files only
alias ldir="\ls -l | egrep '^d'"									# directories only
alias lla='\ls -Al'										# List and Hidden Files
alias las='\ls -A'										# Hidden Files
alias lls='\ls -l'										# List

# alias chmod commands
alias mx='chmod a+x'
alias ux='chmod -R u+x'
alias 000='chmod -R 000'
alias 644='chmod -R 644'
alias 666='chmod -R 666'
alias 755='chmod -R 755'
alias 777='chmod -R 777'

# Search command line history
alias h="history | grep "

# Search running processes
alias p="ps aux | grep "
alias topcpu="/bin/ps -eo pcpu,pid,user,args | sort -k 1 -r | head -10"

# Search files in the current folder (robust replacement for broken alias)
f() {
    # Usage: f pattern
    sudo find . -type f -iname "*${1:-}*" 2>/dev/null
}

# Count all files (recursively) in the current folder
countfiles() {
    for t in files links directories; do
        echo "$(find . -type ${t:0:1} | wc -l) $t"
    done 2> /dev/null
}

# Show open ports
alias openports='netstat -nape --inet'

# Alias's for safe and forced reboots
alias rebootsafe='sudo shutdown -r now'
alias rebootforce='sudo shutdown -r -n now'

# Alias's to show disk space and space used in a folder
alias folders='du -h --max-depth=1'
alias folderssort='find . -maxdepth 1 -type d -print0 | xargs -0 du -sk | sort -rn'
alias tree='tree -CAhF --dirsfirst'
alias treed='tree -CAFd'
alias mountedinfo='df -hT'

# Alias's for archives
alias mktar='tar -cvf'
alias mkbz2='tar -cvjf'
alias mkgz='tar -cvzf'
alias untar='tar -xvf'
alias unbz2='tar -xvjf'
alias ungz='tar -xvzf'

# Show all logs in /var/log
alias logs="sudo find /var/log -type f -exec file {} \; | grep 'text' | cut -d' ' -f1 | sed -e's/:$//g' | grep -v '[0-9]$' | xargs tail -f"

# alias to cleanup unused docker containers, images, networks, and volumes

alias docker-clean=' \
    docker container prune -f ; \
    docker image prune -f ; \
    docker network prune -f ; \
    docker volume prune -f '

#######################################################
# SPECIAL FUNCTIONS
#######################################################
# Extracts any archive(s) (if unp isn't installed)
extract() {
	for archive in "$@"; do
		if [ -f "$archive" ]; then
			case $archive in
			*.tar.bz2) tar xvjf $archive ;;
			*.tar.gz) tar xvzf $archive ;;
			*.bz2) bunzip2 $archive ;;
			*.rar) rar x $archive ;;
			*.gz) gunzip $archive ;;
			*.tar) tar xvf $archive ;;
			*.tbz2) tar xvjf $archive ;;
			*.tgz) tar xvzf $archive ;;
			*.zip) unzip $archive ;;
			*.Z) uncompress $archive ;;
			*.7z) 7z x $archive ;;
			*) echo "don't know how to extract '$archive'..." ;;
			esac
		else
			echo "'$archive' is not a valid file!"
		fi
	done
}

# Copy file with a progress bar
cpp() {
    set -e
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

# Create and go to the directory
mkdirg() {
	mkdir -p "$1"
	cd "$1"
}

# Automatically do an ls after each cd, or z (interactive only)
if [[ $iatest -gt 0 ]]; then
    cd ()
    {
        if [ -n "$1" ]; then
            builtin cd "$@" && ls
        else
            builtin cd ~ && ls
        fi
    }
    function z() {
        __zoxide_z "$@" && ls
    }
fi


# Returns the last 2 fields of the working directory
pwdtail() {
	pwd | awk -F/ '{nlast = NF -1;print $nlast"/"$NF}'
}

# Show the current distribution
distribution () {
    local dtype="unknown"  # Default to unknown

    # Use /etc/os-release for modern distro identification
    if [ -r /etc/os-release ]; then
        source /etc/os-release
        case $ID in
            fedora|rhel|centos)
                dtype="fedora"   # Fedora, RHEL, CentOS
                ;;
            sles|opensuse*)
                dtype="suse"
                ;;
            ubuntu|debian|pop|mint)
                dtype="debian"
                ;;
            gentoo)
                dtype="gentoo"
                ;;
            arch|manjaro)
                dtype="arch"
                ;;
            slackware)
                dtype="slackware"
                ;;
            *)
                # Check ID_LIKE only if dtype is still unknown
                if [ -n "$ID_LIKE" ]; then
                    case $ID_LIKE in
                        *fedora*|*rhel*|*centos*)
                            dtype="fedora"   # Fedora, RHEL, CentOS
                            ;;
                        *ubuntu*|*debian*|*pop*|*mint*)
                            dtype="debian"
                            ;;
                        *arch*)
                            dtype="arch"
                            ;;
                    esac
                fi
                ;;
        esac
    fi

    echo $dtype
}

# Automatically install the needed support files for this .bashrc file
install_bashrc_support() {
	local dtype
	dtype=$(distribution)
	case $dtype in
        "fedora")
            if command -v dnf &> /dev/null; then
                sudo dnf install multitail tree zoxide trash-cli fzf bash-completion fastfetch bat eza -y
            else
                sudo yum install multitail tree zoxide trash-cli fzf bash-completion fastfetch bat eza -y
            fi
            ;;
		"debian")
			sudo apt install multitail tree zoxide starship bat trash-cli fzf bash-completion fastfetch eza -y
			;;
        "arch")
            if command -v paru &> /dev/null; then
                paru -S multitail tree zoxide trash-cli fzf bash-completion fastfetch starship eza bat --noconfirm
            elif command -v yay &> /dev/null; then
                yay -S multitail tree zoxide trash-cli fzf bash-completion fastfetch starship eza bat --noconfirm
            else
                echo "Install paru or yay."
            fi
            ;;
		*)
			echo "Unknown distribution"
			;;
	esac
}

# IP address lookup
alias whatismyip="whatsmyip"
function whatsmyip () {
    # Determine active interface via routing table
    local dev
    dev=$(ip route get 1.1.1.1 2>/dev/null | awk '/dev/ {for(i=1;i<=NF;i++) if ($i=="dev") {print $(i+1); exit}}')
    echo -n "Internal IP: "
    if command -v ip &> /dev/null; then
        ip -o -4 addr show "${dev:-eth0}" | awk '{print $4}' | cut -d/ -f1 | head -n1
    else
        ifconfig "${dev:-eth0}" | awk '/inet /{print $2}'
    fi

    # External IP Lookup
    echo -n "External IP: "
    curl -fsS4 ifconfig.me || curl -fsS ipinfo.io/ip || echo "unavailable"
}

# Trim leading and trailing spaces (for scripts)
trim() {
	local var=$*
	var="${var#"${var%%[![:space:]]*}"}" # remove leading whitespace characters
	var="${var%"${var##*[![:space:]]}"}" # remove trailing whitespace characters
	echo -n "$var"
}

#########################################################
# Search then install/uninstall packages using fzf
#########################################################

# Software Search
ss() {
    local dtype selection
    dtype=$(distribution)
    local native_list_cmd native_preview_cmd
    case "$dtype" in
        "arch")
            if command -v paru &>/dev/null; then
                native_list_cmd='paru -Slq'
                native_preview_cmd='paru -Sii {1}'
            elif command -v yay &>/dev/null; then
                native_list_cmd='yay -Slq'
                native_preview_cmd='yay -Sii {1}'
            else
                native_list_cmd='pacman -Slq'
                native_preview_cmd='pacman -Si {1}'
            fi
            ;;
        "debian")
            native_list_cmd='apt-cache pkgnames'
            native_preview_cmd='apt-cache show {1}'
            ;;
        "fedora")
            if command -v dnf &>/dev/null; then
                native_list_cmd="dnf list available | awk '{print \$1}'"
                native_preview_cmd='dnf info {1}'
            else
                native_list_cmd="yum list available | awk '{print \$1}'"
                native_preview_cmd='yum info {1}'
            fi
            ;;
        *)
            echo "Unknown or unsupported distribution for ss alias."
            return 1
            ;;
    esac
    # Compose combined menu
    selection=$(
        {
            eval "$native_list_cmd" | sed 's/^/[N] /'
            if command -v flatpak &>/dev/null; then
                flatpak remote-ls --app --columns=application flathub | sed 's/^/[F] /'
            fi
        } | fzf --multi --prompt="Install (enter to select): " \
                --preview='
                    if [[ {} == "[F] "* ]]; then
                        flatpak remote-info flathub "${{ {}#"[F] " }}"
                    else
                        '"$native_preview_cmd"'
                    fi' \
                --preview-window=down:75% --border
    )
    [[ -z "$selection" ]] && return 0
    # Install each selected entry
    while IFS= read -r line; do
        if [[ $line == "[F] "* ]]; then
            app=${line#"[F] "}
            flatpak install -y flathub "$app"
        elif [[ $line == "[N] "* ]]; then
            pkg=${line#"[N] "}
            case "$dtype" in
                arch)
                    if command -v paru &>/dev/null; then paru -S "$pkg";
                    elif command -v yay &>/dev/null; then yay -S "$pkg";
                    else sudo pacman -S "$pkg"; fi
                    ;;
                debian)
                    sudo apt-get install "$pkg"
                    ;;
                fedora)
                    if command -v dnf &>/dev/null; then sudo dnf install "$pkg";
                    else sudo yum install "$pkg"; fi
                    ;;
            esac
        fi
    done <<< "$selection"
}

# Software Search Uninstaller || This took a bit more to get working.
ssu_preview() {
    local line="$*"
    local dtype="${DTYPE:-$(distribution)}"
    if [[ $line == "[F] "* ]]; then
        local app=${line#"[F] "}
        if command -v flatpak &>/dev/null; then
            flatpak info "$app"
        else
            echo "Flatpak not installed"
        fi
    else
        local pkg=${line#"[N] "}
        case "$dtype" in
            arch)
                if command -v paru &>/dev/null; then paru -Qi "$pkg";
                elif command -v yay &>/dev/null; then yay -Qi "$pkg";
                else pacman -Qi "$pkg"; fi
                ;;
            debian)
                apt-cache show "$pkg"
                ;;
            fedora)
                if command -v dnf &>/dev/null; then dnf info "$pkg"; else yum info "$pkg"; fi
                ;;
            *)
                echo "Unknown distro"
                ;;
        esac
    fi
}
ssu() {
    local dtype selection
    dtype=$(distribution)
    # Build native list command per distro
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
    # Compose combined menu
    selection=$(
        {
            eval "$native_list_cmd" | sed 's/^/[N] /'
            if command -v flatpak &>/dev/null; then
                flatpak list --app --columns=application | sed 's/^/[F] /'
            fi
        } | DTYPE="$dtype" fzf --multi --prompt="Uninstall (enter to select): " \
                            --preview 'ssu_preview {}' \
                            --preview-window=down:75% --border
    )
    [[ -z "$selection" ]] && return 0
    # Uninstall each selected entry
    while IFS= read -r line; do
        if [[ $line == "[F] "* ]]; then
            app=${line#"[F] "}
            flatpak uninstall -y --delete-data "$app"
        elif [[ $line == "[N] "* ]]; then
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
        fi
    done <<< "$selection"
}


#######################################################
# Source and initalize
#######################################################

# Yazi set CWD on exit
function y() {
	local tmp="$(mktemp -t "yazi-cwd.XXXXXX")" cwd
	yazi "$@" --cwd-file="$tmp"
	IFS= read -r -d '' cwd < "$tmp"
	[ -n "$cwd" ] && [ "$cwd" != "$PWD" ] && builtin cd -- "$cwd"
	rm -f -- "$tmp"
}

# Starship
if command -v starship &>/dev/null; then eval "$(starship init bash)"; fi
# Zoxide
if command -v zoxide &>/dev/null; then eval "$(zoxide init bash)"; fi
# FZF (guarded)
[[ -r /usr/share/fzf/key-bindings.bash ]] && source /usr/share/fzf/key-bindings.bash
[[ -r /usr/share/fzf/completion.bash ]] && source /usr/share/fzf/completion.bash


# Fastfetch and keybind only in interactive shells
if [[ $iatest -gt 0 ]]; then
    # Run fastfetch if available
    if command -v fastfetch &>/dev/null; then fastfetch; fi
    # Bind Ctrl+f to insert 'zi' followed by a newline
    bind '"\C-f":"zi\n"'
fi

export PATH="$HOME/.local/bin:$HOME/.cargo/bin:/var/lib/flatpak/exports/bin:$HOME/.local/share/flatpak/exports/bin:$PATH"

if [[ -z $DISPLAY ]] && [[ $(tty) = /dev/tty1 ]] && command -v startx &>/dev/null; then
    exec startx
fi
