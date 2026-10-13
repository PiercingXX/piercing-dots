#!/bin/bash
# GitHub.com/PiercingXX
# Monitor layout on the Skippy box. Not skippy-desk.sh (local desk app).
# Host: SKIPPY_HOST in ~/.config/piercingxx/remotes.conf.
exec bash "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/remote-session.sh" --host skippy "$@"
