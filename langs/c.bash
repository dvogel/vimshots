#!/usr/bin/env bash
# vim: filetype=bash

set -o errexit

SELF_DIR=$(dirname $(readlink -f "$0"))

awk_script='{ if ($1 == function_name) { found=1; print $3 } else if (found == 1) { print $3; exit } }'
bounds=$(ctags -x --c-kinds=f "$1" | sort -k 3 -n | awk --assign function_name="$2" -f "${SELF_DIR}/c_extract_method.awk")

function_start=
next_start=
for n in $bounds; do
    [[ -z "$function_start" ]] && function_start="$n"
    [[ -n "$function_start" ]] && next_start="$n"
done

if [[ -n "$function_start" && -n "$next_start" ]]; then
    function_length=$(($next_start - $function_start))
    approx=$(cat "$1" | head -n $(($next_start - 2)) | tail -n $function_length)
    echo "$approx"
    # last_line_num=$(echo "$approx" | grep -n --no-filename "^}" | cut -f1 -d:)
    # echo "$approx" | head -n $last_line_num
fi

