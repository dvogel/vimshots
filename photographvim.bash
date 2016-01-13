#!/usr/bin/env bash
# vim: filetype=bash

SCREEN_WIDTH="${SCREEN_WIDTH:-800}"
SCREEN_HEIGHT="${SCREEN_HEIGHT:-600}"

set -o errexit

function require_executable () {
    which "$1" 2>&1 > /dev/null || usage "Missing dependency: $1"
}

require_executable basename
require_executable dirname
require_executable gvim
require_executable ls
require_executable mkdir
require_executable readlink
require_executable scrot
require_executable wc
require_executable Xephyr

SELF_PATH=$(readlink -f "$0")
SELF_NAME=$(basename "$SELF_PATH")

function usage () {
    while [[ -n "$1" ]]; do
        echo ERROR: $1
        shift
    done

    echo
    echo "USAGE: ${SELF_NAME} <source dir> <search expr>"
    echo
    echo "The <source dir> option must contain files."
    echo

    exit 1
}

[[ "$BASH_VERSINFO" -lt 4 ]] && usage "Requires bash 4.3 or higher"
[[ "$BASH_VERSION" =~ ^4\.[012]\. ]] && usage "Requires bash 4.3 or higher"

output_dir="output${$}"

while [[ 1 ]]; do
    case $1 in
        -h|--help)
            usage
            ;;
        -o|--outdir)
            [[ -z "${2}" ]] && usage "Directory argument required for $1 option."
            output_dir="${2}"
            shift
            ;;
        --)
            shift
            break
            ;;
        *)
            break
            ;;
    esac

    shift
done


[[ -z "${1}" ]] && usage "You must specify a source directory."
[[ -z "${2}" ]] && usage "You must specify a search expression."
# source_code_dir=$(readlink -f "${1}")
source_code_dir="${1}"
search_expr="${2}"

n_source_files=$(ls -1 "${source_code_dir}" | wc -l)
if [[ "${n_source_files}" -eq 0 ]]; then
    echo "No source files found in ${source_code_dir}"
    exit 2
else
    echo "Found ${n_source_files} source files"
fi

mkdir -p "${output_dir}"
output_dir=$(readlink -f "${output_dir}")

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
while [[ 1 ]]; do
    sleep 1
    (gvim --serverlist | egrep VIMSHOTS) && break
done
for srcpath in "${source_code_dir}"/*; do
    srcfile=$(basename "${srcpath}")
    dstpath="${output_dir}/${srcfile}.png"
    $vimcmd --remote-send ":edit ${srcpath}<CR><CR>/${search_expr}<CR>zt<CR>"
    sleep 1
    scrot "${dstpath}.png"
    $vimcmd --remote-send ":bdel<CR><CR>"
done
$vimcmd --remote-send ":qall!<CR>"

n_screenshots=$(ls -1 "${output_dir}" | wc -l)
echo "Output ${n_screenshots} screenshots to ${output_dir}"

wait

