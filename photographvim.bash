#!/usr/bin/env bash

SEARCH_EXPR="${SEARCH_EXPR:?You must set SEARCH_EXPR to the term vim should search for.}"
SCREEN_WIDTH="${SCREEN_WIDTH:-800}"
SCREEN_HEIGHT="${SCREEN_HEIGHT:-600}"

set -o errexit
set -o xtrace

which basename
which dirname
which gvim
which ls
which readlink
which scrot
which Xephyr

SELF_PATH=$(readlink -f $(dirname "$0"))
SELF_NAME=$(basename "$SELF_PATH")

function usage () {
    while [[ -n "$1" ]]; do
        echo $1
    done

    echo "USAGE: ${SELF_NAME}"
    echo
    echo "No options available"

    exit 1
}

[[ "$BASH_VERSINFO" -lt 4 ]] && usage "Requires bash 4.3 or higher"
[[ "$BASH_VERSION" =~ ^4\.[012]\. ]] && usage "Requires bash 4.3 or higher"

function select_next_display () {
    max_display_num=0
    display_sockets=$(ls -1 /tmp/.X11-unix)
    for d in $display_sockets; do
        dn="${d#X}"
        if [[ "${dn}" -gt "${max_display_num}" ]]; then
           max_display_num="${dn}"
       fi
    done
    echo $((${max_display_num} + 1))
}

XEPHYR_DISPLAY=:$(select_next_display)
Xephyr -ac -br -screen "${SCREEN_WIDTH}x${SCREEN_HEIGHT}" -reset -terminate "${XEPHYR_DISPLAY}" &

export DISPLAY="${XEPHYR_DISPLAY}"
export HOME=`pwd`/home
vimcmd="gvim -R --servername VIMSHOTS"

$vimcmd
$vimcmd --remote home/.vimrc
sleep 1
$vimcmd --remote-send "/${SEARCH_EXPR}<CR>"
sleep 1
scrot test.png
$vimcmd --remote-send ":qall!<CR>"

wait

