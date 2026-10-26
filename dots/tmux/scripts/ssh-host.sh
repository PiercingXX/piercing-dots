#!/bin/sh
# Print the destination host of the ssh running in the foreground of a pane.
# Usage: ssh-host.sh <pane_pid>
pgid=$(ps -o tpgid= -p "$1" 2>/dev/null | tr -d ' ')
[ -n "$pgid" ] || exit 0
set -- $(ps -o args= -p "$pgid" 2>/dev/null)
shift # drop "ssh"
while [ $# -gt 0 ]; do
    case "$1" in
        --) shift; break ;;
        -[BbcDEeFIiJLlmOoPpQRSWw]) shift 2 ;; # option with separate argument
        -*) shift ;;
        *) break ;;
    esac
done
host=${1#*@}
printf '%s' "${host:-ssh}"
