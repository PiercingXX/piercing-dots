#!/bin/bash
# GitHub.com/PiercingXX
# Server monitor layout (nvtop/htop/lnav). Old -monitor/-remote/-log flags
# still work. Host: SERVER_HOST in ~/.config/piercingxx/remotes.conf.
exec bash "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/remote-session.sh" --host server "$@"
