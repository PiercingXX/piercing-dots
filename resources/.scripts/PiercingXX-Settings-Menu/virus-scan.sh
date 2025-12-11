#!/bin/bash
# GitHub.com/PiercingXX

#########################################################
# Virus Scan with ClamAV
#########################################################

# Tunables (override via env vars if you want different limits)
MAX_FILESIZE_MB=${MAX_FILESIZE_MB:-1024}    # single file cap
MAX_SCANSIZE_MB=${MAX_SCANSIZE_MB:-2048}   # total data per scan
MAX_RECURSION=${MAX_RECURSION:-32}
MAX_FILES=${MAX_FILES:-20000}
EXCLUDES=(
    "$HOME/.cache"
    "/proc"
    "/sys"
    "/dev"
)

USE_CLAMD=${USE_CLAMD:-1}  # prefer clamdscan if available for speed
SCAN_BIN="clamscan"
SCAN_OPTS=()
PRUNE_ARGS=()
PARALLEL_JOBS=${PARALLEL_JOBS:-$(nproc)}
FAST_RECENT_DAYS=${FAST_RECENT_DAYS:-60}
FAST_MAX_SIZE_MB=${FAST_MAX_SIZE_MB:-}
FAST_INCLUDE_EXTS=${FAST_INCLUDE_EXTS:-".exe .dll .so .bin .run .msi .bat .cmd .ps1 .vbs .sh .py .pl .rb .js .ts .go .php .jar .war .ear .class .apk .deb .rpm .pkg .dmg .AppImage .flatpak .snap .tar .gz .xz .bz2 .zip .7z .rar .iso"}

CLAMSCAN_OPTS=()

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

start_clamd_if_available() {
    # Try to start clamd with best-effort; ignore failures so we can fall back to clamscan
    for svc in clamav-daemon clamd@scan clamd; do
        sudo systemctl start "$svc" 2>/dev/null || true
    done
}

select_scanner() {
    if [ "$USE_CLAMD" -eq 1 ] && command -v clamdscan &>/dev/null; then
        start_clamd_if_available
        SCAN_BIN="clamdscan"
    else
        SCAN_BIN="clamscan"
    fi
}

build_scan_opts() {
    if [ "$SCAN_BIN" = "clamdscan" ]; then
        # clamdscan hands work to the daemon; multiscan uses multiple threads
        SCAN_OPTS=(
            --multiscan
            --fdpass
            -i
            --infected
            --no-summary
        )
    else
        SCAN_OPTS=(
            -r
            -i
            --bell
            --max-filesize="${MAX_FILESIZE_MB}M"
            --max-scansize="${MAX_SCANSIZE_MB}M"
            --max-recursion="$MAX_RECURSION"
            --max-files="$MAX_FILES"
            --alert-exceeds-max=yes
        )
    fi

    if [ "$SCAN_BIN" != "clamdscan" ]; then
        for ex in "${EXCLUDES[@]}"; do
            [ -d "$ex" ] || continue
            SCAN_OPTS+=(--exclude-dir="^${ex%/}")
        done
    fi
}

build_prune_args() {
    PRUNE_ARGS=()
    for ex in "${EXCLUDES[@]}"; do
        [ -d "$ex" ] || continue
        PRUNE_ARGS+=( -path "$ex" -o )
    done
    if [ ${#PRUNE_ARGS[@]} -gt 0 ]; then
        unset 'PRUNE_ARGS[${#PRUNE_ARGS[@]}-1]'  # drop trailing -o
        PRUNE_ARGS=( '(' "${PRUNE_ARGS[@]}" ')' -prune -o )
    fi
}

run_scan_stream() {
    local target="$1"
    if [ "$SCAN_BIN" = "clamdscan" ] && [ -d "$target" ] && [ ${#PRUNE_ARGS[@]} -gt 0 ]; then
        find "$target" "${PRUNE_ARGS[@]}" -type f -print0 | xargs -0 -r -n 2000 -P "$PARALLEL_JOBS" "$SCAN_BIN" "${SCAN_OPTS[@]}"
    else
        if [ "$SCAN_BIN" = "clamscan" ] && [ -d "$target" ]; then
            # Parallelize clamscan across files to utilize CPU when daemon is unavailable
            find "$target" -type f -print0 | xargs -0 -r -n 500 -P "$PARALLEL_JOBS" "$SCAN_BIN" "${SCAN_OPTS[@]}"
        else
            "$SCAN_BIN" "${SCAN_OPTS[@]}" "$target"
        fi
    fi
}

# Fast targeted scan over high-risk files
fast_scan() {
    gum style --border rounded --padding "1 2" --foreground 6 "Fast Targeted Scan - executables, scripts, archives, recent files"

    local log_file="/tmp/clamav-fast-scan.log"
    : > "$log_file"

    # Build find predicates
    local ext_regex=""
    for ext in $FAST_INCLUDE_EXTS; do
        ext=${ext#.}
        if [ -z "$ext_regex" ]; then
            ext_regex="$ext"
        else
            ext_regex="$ext_regex|$ext"
        fi
    done
    local ext_pred=( -iregex ".*\\.\($ext_regex\)$" )

    local size_pred=()
    [ -n "$FAST_MAX_SIZE_MB" ] && size_pred=( -size -"${FAST_MAX_SIZE_MB}M" )
    local recent_pred=( -mtime -"${FAST_RECENT_DAYS}" )
    local exec_pred=( -perm -111 )

    # Assemble prune for excludes
    build_prune_args

    # Compose the find command: prune excluded; select by (exec OR ext OR recent) AND size
    gum spin --spinner dot --title "Gathering fast scan file list..." -- true
    # Build the find command in current shell to expand arrays correctly
    {
        find "$HOME" \
            "${PRUNE_ARGS[@]}" \
            -type f \
            \( \( ${exec_pred[*]} -o ${recent_pred[*]} -o ${ext_pred[*]} \) ${size_pred:+-a ${size_pred[*]}} \) \
            -print0 2>/dev/null
    } > /tmp/clamav-fast-files.list

    if [ ! -s /tmp/clamav-fast-files.list ]; then
        gum style --foreground 3 "No candidate files found for fast scan."
        return
    fi

    # Run scanner over the collected list in parallel
    gum style --foreground 3 "Scanning fast list (may still take a bit)"
    xargs -0 -r -n 1000 -P "$PARALLEL_JOBS" "$SCAN_BIN" "${SCAN_OPTS[@]}" < /tmp/clamav-fast-files.list 2>&1 |
        gum spin --spinner dot --title "Fast Scan running..." --show-output -- cat | tee "$log_file"

    gum style --foreground 2 --bold "\n✓ Fast scan complete! Check /tmp/clamav-fast-scan.log for details."
}

# Recent Downloads preset
recent_downloads_scan() {
    gum style --border rounded --padding "1 2" --foreground 6 "Recent Downloads Scan"
    local log_file="/tmp/clamav-downloads-scan.log"
    : > "$log_file"

    local dl="$HOME/Downloads"
    if [ ! -d "$dl" ]; then
        gum style --foreground 3 "No Downloads directory found."
        return
    fi

    build_prune_args

    {
        find "$dl" -type f -mtime -"${FAST_RECENT_DAYS}" -print0 2>/dev/null
    } > /tmp/clamav-downloads-files.list

    if [ ! -s /tmp/clamav-downloads-files.list ]; then
        gum style --foreground 3 "No recent files in Downloads."
        return
    fi

    gum style --foreground 3 "Scanning recent Downloads files"
    xargs -0 -r -n 1000 -P "$PARALLEL_JOBS" "$SCAN_BIN" "${SCAN_OPTS[@]}" < /tmp/clamav-downloads-files.list 2>&1 |
        gum spin --spinner dot --title "Downloads Scan running..." --show-output -- cat | tee "$log_file"

    gum style --foreground 2 --bold "\n✓ Downloads scan complete! Check /tmp/clamav-downloads-scan.log for details."
}


# Auto-install gum if not found
if ! command -v gum &>/dev/null; then
    echo "gum is not installed. Attempting to install gum..."
    dtype=$(distribution)
    case "$dtype" in
        arch)
            if command -v paru &>/dev/null; then
                paru -S --noconfirm gum
            elif command -v yay &>/dev/null; then
                yay -S --noconfirm gum
            else
                sudo pacman -S --noconfirm gum
            fi
            ;;
        debian)
            sudo apt-get update && sudo apt-get install -y gum
            ;;
        fedora)
            sudo dnf install -y gum
            ;;
    esac
    if ! command -v gum &>/dev/null; then
        echo "Failed to install gum. Please install it manually."
        exit 1
    fi
fi

# Check if ClamAV is installed
check_clamav() {
    if ! command -v clamscan &>/dev/null; then
        gum style --foreground 3 "ClamAV is not installed. Attempting to install ClamAV..."
        install_clamav
        if ! command -v clamscan &>/dev/null; then
            gum style --foreground 1 "Failed to install ClamAV. Exiting."
            exit 1
        fi
    fi
}

# Function to display progress bar with gum
progress_scan() {
    local dir="$1"
    local description="$2"
    local log_file="/tmp/clamav-scan.log"
    
    gum style --foreground 3 "Scanning: $description"
    
    # Run scan and pipe to progress bar
    run_scan_stream "$dir" 2>&1 | gum spin --spinner dot --title "$description scanning..." --show-output -- cat | tee -a "$log_file"
}

# Function for full directory scan with file counting
full_progress_scan() {
    local dir="$1"
    local description="$2"
    local log_file="/tmp/clamav-full-scan.log"

    gum style --foreground 3 "Scanning: $description (this may take a while)"

    # Count total files to scan
    local total_files
    total_files=$(find "$dir" -type f 2>/dev/null | wc -l)
    if [ "$total_files" -eq 0 ]; then
        gum style --foreground 1 "No files found to scan."
        return 1
    fi
    > "$log_file"

    # Start clamscan in the background, outputting to log file
    run_scan_stream "$dir" 2>&1 | tee "$log_file" &
    local clam_pid=$!

    # Progress monitor loop
    local scanned=0
    local percent=0
    local last_percent=-1
    while kill -0 $clam_pid 2>/dev/null; do
        # Count lines in log that look like scan results (skip summary lines)
        scanned=$(grep -c ": OK$" "$log_file")
        percent=$((scanned * 100 / total_files))
        if [ "$percent" -ne "$last_percent" ]; then
            gum style --foreground 6 --bold "Scanning: $percent% ($scanned/$total_files)"
            last_percent=$percent
        fi
        sleep 2
    done

    # Final update after scan completes
    scanned=$(grep -c ": OK$" "$log_file")
    percent=$((scanned * 100 / total_files))
    gum style --foreground 2 "✓ Scan complete. $scanned files scanned. Results saved to $log_file"
}

# Install ClamAV
install_clamav() {
    local dtype
    dtype=$(distribution)
    
    gum spin --spinner dot --title "Installing ClamAV..." -- bash -c "
        case '$dtype' in
            arch)
                if command -v paru &>/dev/null; then
                    paru -S --noconfirm clamav
                elif command -v yay &>/dev/null; then
                    yay -S --noconfirm clamav
                else
                    sudo pacman -S --noconfirm clamav
                fi
                ;;
            debian)
                sudo apt-get update && sudo apt-get install -y clamav clamav-daemon
                ;;
            fedora)
                sudo dnf install -y clamav clamav-update
                ;;
        esac
    "
    
    if [ $? -eq 0 ]; then
        gum style --foreground 2 "✓ ClamAV installed successfully!"
    else
        gum style --foreground 1 "✗ Failed to install ClamAV"
        exit 1
    fi
}

# Update virus definitions
update_definitions() {
    gum style --foreground 3 --bold "Updating virus definitions..."
    
    # Stop freshclam service if running
    sudo systemctl stop clamav-freshclam.service 2>/dev/null || true
    
    gum spin --spinner dot --title "Downloading latest virus definitions..." -- sudo freshclam
    
    if [ $? -eq 0 ]; then
        gum style --foreground 2 "✓ Virus definitions updated successfully!"
        # Restart freshclam service
        sudo systemctl start clamav-freshclam.service 2>/dev/null || true
    else
        gum style --foreground 3 "⚠ Warning: Could not update definitions. Proceeding with existing database..."
        sudo systemctl start clamav-freshclam.service 2>/dev/null || true
    fi
}

# Quick scan (common user directories)
quick_scan() {
    gum style --border rounded --padding "1 2" --foreground 6 "Quick Scan - Scanning common user directories"
    
    SCAN_DIRS=(
        "$HOME/Downloads:Downloads"
        "$HOME/Documents:Documents"
        "$HOME/Desktop:Desktop"
        "$HOME/.local/share:.local/share"
    )
    
    > /tmp/clamav-scan.log  # Clear log file
    
    for dir_pair in "${SCAN_DIRS[@]}"; do
        dir="${dir_pair%:*}"
        name="${dir_pair##*:}"
        if [ -d "$dir" ]; then
            progress_scan "$dir" "$name"
        fi
    done
    
    gum style --foreground 2 --bold "\n✓ Quick scan complete! Check /tmp/clamav-scan.log for details."
}

# Full system scan
full_scan() {
    gum confirm "This will scan your entire home directory and may take a long time. Continue?" || return
    
    gum style --border rounded --padding "1 2" --foreground 6 "Full System Scan - This may take a while..."
    
    full_progress_scan "$HOME" "Full Home Directory"
    
    gum style --foreground 2 --bold "\n✓ Full scan complete! Check /tmp/clamav-full-scan.log for details."
}

# Custom directory scan
custom_scan() {
    scan_path=$(gum input --placeholder "Enter directory path to scan (e.g., /home/user/Documents)")
    
    if [ -z "$scan_path" ]; then
        gum style --foreground 1 "No path provided!"
        return
    fi
    
    if [ ! -d "$scan_path" ]; then
        gum style --foreground 1 "Directory does not exist: $scan_path"
        return
    fi
    
    gum style --border rounded --padding "1 2" --foreground 6 "Scanning: $scan_path"
    
    gum style --border rounded --padding "1 2" --foreground 6 "Scanning: $scan_path"
    
    local log_file="/tmp/clamav-custom-scan.log"
    
    # Run scan with progress indication and logging
    run_scan_stream "$scan_path" 2>&1 | gum spin --spinner arc --title "Custom Directory" --show-output -- cat | tee "$log_file"
    
    gum style --foreground 2 --bold "\n✓ Scan complete! Check /tmp/clamav-custom-scan.log for details."
}

# Scan a specific file
file_scan() {
    scan_file=$(gum file ~)
    
    if [ -z "$scan_file" ]; then
        gum style --foreground 1 "No file selected!"
        return
    fi
    
    if [ ! -f "$scan_file" ]; then
        gum style --foreground 1 "File does not exist: $scan_file"
        return
    fi
    
    gum style --border rounded --padding "1 2" --foreground 6 "Scanning file: $scan_file"
    
    if [ "$SCAN_BIN" = "clamdscan" ]; then
        "$SCAN_BIN" -i --infected --fdpass "$scan_file"
    else
        "$SCAN_BIN" --max-filesize="${MAX_FILESIZE_MB}M" -i --bell "$scan_file"
    fi
    
    echo ""
    read -p "Press Enter to continue..."
}

# View scan logs
view_logs() {
    log_choice=$(gum choose "Quick Scan Log" "Full Scan Log" "Custom Scan Log" "Back")
    
    case "$log_choice" in
        "Quick Scan Log")
            if [ -f /tmp/clamav-scan.log ]; then
                gum pager < /tmp/clamav-scan.log
            else
                gum style --foreground 1 "No quick scan log found!"
            fi
            ;;
        "Full Scan Log")
            if [ -f /tmp/clamav-full-scan.log ]; then
                gum pager < /tmp/clamav-full-scan.log
            else
                gum style --foreground 1 "No full scan log found!"
            fi
            ;;
        "Custom Scan Log")
            if [ -f /tmp/clamav-custom-scan.log ]; then
                gum pager < /tmp/clamav-custom-scan.log
            else
                gum style --foreground 1 "No custom scan log found!"
            fi
            ;;
        "Back"|"")
            return
            ;;
    esac
}

# Main menu
main_menu() {
    check_clamav
    select_scanner
    build_scan_opts
    build_prune_args
    
    while true; do
        clear
        gum style --border double --padding "1 2" --foreground 6 --bold "🦠 ClamAV Virus Scanner"
        
        choice=$(gum choose \
            "🔄 Update Virus Definitions" \
            "⚡ Quick Scan" \
            "🚀 Fast Targeted Scan" \
            "📥 Recent Downloads Scan" \
            "🔍 Full Home Directory Scan" \
            "📁 Scan Custom Directory" \
            "📄 Scan Specific File" \
            "📋 View Scan Logs" \
            "🚪 Back to Main Menu")
        
        case "$choice" in
            "🔄 Update Virus Definitions")
                update_definitions
                read -p "Press Enter to continue..."
                ;;
            "⚡ Quick Scan")
                quick_scan
                read -p "Press Enter to continue..."
                ;;
            "🚀 Fast Targeted Scan")
                fast_scan
                read -p "Press Enter to continue..."
                ;;
            "📥 Recent Downloads Scan")
                recent_downloads_scan
                read -p "Press Enter to continue..."
                ;;
            "🔍 Full Home Directory Scan")
                full_scan
                read -p "Press Enter to continue..."
                ;;
            "📁 Scan Custom Directory")
                custom_scan
                read -p "Press Enter to continue..."
                ;;
            "📄 Scan Specific File")
                file_scan
                ;;
            "📋 View Scan Logs")
                view_logs
                ;;
            "🚪 Back to Main Menu"|"")
                clear
                exit 0
                ;;
        esac
    done
}

# Run main menu
main_menu
