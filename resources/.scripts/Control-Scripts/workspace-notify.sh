#!/bin/bash
# GitHub.com/PiercingXX
# Hyprland workspace switch notification daemon.
# Listens to the Hyprland IPC event socket and fires a 1-second
# dunstify notification whenever the active workspace changes.
# Shows current workspace number and all occupied workspaces.

NOTIFY_ID=99991
QUICK_TIMEOUT=1100

# --- Ensure required tools are available ---
for tool in jq hyprctl; do
    if ! command -v "$tool" &>/dev/null; then
        echo "workspace-notify: $tool not found." >&2
        exit 1
    fi
done

# Notification backend: dunstify (replace-ID support) > notify-send
if command -v dunstify &>/dev/null; then
    NOTIFY_BIN="dunstify"
elif command -v notify-send &>/dev/null; then
    NOTIFY_BIN="notify-send"
    # notify-send >=0.8 supports --replace-id; detect it
    notify-send --help 2>&1 | grep -q -- '--replace-id' && NOTIFY_REPLACE=true || NOTIFY_REPLACE=false
else
    echo "workspace-notify: need dunstify or notify-send for notifications." >&2
    exit 1
fi

# notify <replace_id> <urgency> <timeout_ms> <summary> <body>
notify() {
    local rid="$1" urgency="$2" timeout="$3" summary="$4" body="$5"
    if [[ "$NOTIFY_BIN" == "dunstify" ]]; then
        dunstify -r "$rid" -u "$urgency" -t "$timeout" "$summary" "$body"
    elif [[ "${NOTIFY_REPLACE:-false}" == true ]]; then
        notify-send --replace-id="$rid" -u "$urgency" -t "$timeout" "$summary" "$body"
    else
        # dunst stack-tag: replaces any notification with the same tag
        notify-send -u "$urgency" -t "$timeout" \
            -h "string:x-dunst-stack-tag:workspace-notify" \
            "$summary" "$body"
    fi
}

# Keep swaync popups/control center on the currently focused monitor.
update_swaync_monitor() {
    command -v swaync-client &>/dev/null || return 0

    local focused_monitor
    focused_monitor=$(hyprctl monitors -j 2>/dev/null | jq -r '.[] | select(.focused==true) | .name' | head -n1)
    [[ -n "$focused_monitor" && "$focused_monitor" != "null" ]] || return 0

    swaync-client --change-noti-monitor "$focused_monitor" -sw >/dev/null 2>&1 || true
    swaync-client --change-cc-monitor "$focused_monitor" -sw >/dev/null 2>&1 || true
}

# Determine best available IPC reader: socat > nc (unix) > python3
if command -v socat &>/dev/null; then
    IPC_CMD="socat"
elif command -v nc &>/dev/null && nc -h 2>&1 | grep -q -- '-U\|unix'; then
    IPC_CMD="nc"
elif command -v python3 &>/dev/null; then
    IPC_CMD="python3"
else
    echo "workspace-notify: need socat, nc (-U), or python3 for Hyprland IPC." >&2
    exit 1
fi

# --- Resolve Hyprland event socket ---
get_socket() {
    local runtime="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
    local sig="${HYPRLAND_INSTANCE_SIGNATURE}"
    if [ -z "$sig" ]; then
        echo "workspace-notify: HYPRLAND_INSTANCE_SIGNATURE not set." >&2
        exit 1
    fi
    echo "${runtime}/hypr/${sig}/.socket2.sock"
}

# --- Build and send the workspace notification ---
notify_workspace() {
    local current_id
    current_id=$(hyprctl activeworkspace -j 2>/dev/null | jq -r '.id') || return

    # Collect IDs of workspaces that have at least one window
    local occupied_ids
    mapfile -t occupied_ids < <(
        hyprctl workspaces -j 2>/dev/null \
        | jq -r '[.[] | select(.windows > 0) | .id] | sort | .[]'
    )

    # Build display string: [N] for current, plain N for others
    local parts=()
    for ws_id in "${occupied_ids[@]}"; do
        if [[ "$ws_id" == "$current_id" ]]; then
            parts+=("[${ws_id}]")
        else
            parts+=("${ws_id}")
        fi
    done

    # If current workspace has no windows it won't appear above; add it
    local found=false
    for ws_id in "${occupied_ids[@]}"; do
        [[ "$ws_id" == "$current_id" ]] && found=true && break
    done
    [[ "$found" == false ]] && parts+=("[${current_id}]")

    # Sort and join
    local body
    body=$(printf '%s\n' "${parts[@]}" \
        | sort -t'[' -k1,1 -V \
        | tr '\n' ' ' \
        | sed 's/[[:space:]]*$//')

    notify "$NOTIFY_ID" low "$QUICK_TIMEOUT" "Workspace ${current_id}" "Open: ${body}"
}

# --- Main event loop ---
socket=$(get_socket)

# Initialize swaync to current focused output on daemon startup.
update_swaync_monitor

ipc_stream() {
    case "$IPC_CMD" in
        socat)   socat -U - "UNIX-CONNECT:${socket}" 2>/dev/null ;;
        nc)      nc -U "${socket}" 2>/dev/null ;;
        python3) python3 - "${socket}" 2>/dev/null <<'PYEOF'
import socket as _s, sys
s = _s.socket(_s.AF_UNIX, _s.SOCK_STREAM)
s.connect(sys.argv[1])
while True:
    data = s.recv(4096)
    if not data: break
    sys.stdout.buffer.write(data)
    sys.stdout.buffer.flush()
PYEOF
        ;;
    esac
}

ipc_stream | while IFS= read -r line; do
    event="${line%%>>*}"
    case "$event" in
        workspace|focusedmon)
            update_swaync_monitor
            notify_workspace
            ;;
    esac
done
