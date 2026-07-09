#!/usr/bin/env bash
# Show only active/occupied workspaces for herbstluftwm

if ! command -v herbstclient >/dev/null 2>&1 || ! pgrep -x herbstluftwm >/dev/null 2>&1; then
    exit 0
fi

herbstclient tag_status 2>/dev/null | tr -s '[:space:]' '\n' | while IFS= read -r tag; do
    [[ -z "$tag" ]] && continue

    prefix="${tag:0:1}"
    name="${tag:1}"

    case "$prefix" in
        "#")
            # Focused tag
            echo "%{B#327bd1}%{F#ffffff} $name %{F- B-}"
            ;;
        ".")
            # Empty tag
            ;;
        "!"|"*"|"%")
            # Urgent tag variants
            echo "%{B#ff6767}%{F#ffffff} $name! %{F- B-}"
            ;;
        *)
            # Any other non-empty state (e.g. occupied/visible)
            echo " $name "
            ;;
    esac
done | tr '\n' ' '
