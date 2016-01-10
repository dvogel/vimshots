#!/usr/bin/env bash
# vim: filetype=bash


function require_executable () {
    which "$1" 2>&1 > /dev/null || usage "Missing dependency: $1"
}

require_executable basename
require_executable dirname
require_executable egrep
require_executable git
require_executable printf
require_executable readlink

set -o errexit

SELF_PATH=$(readlink -f "$0")
SELF_NAME=$(basename "${SELF_PATH}")

function usage () {
    while [[ -n "$1" ]]; do
        echo ERROR: $1
        shift
    done
    echo
    echo "USAGE: ${SELF_NAME} file_to_search search_expr"
    echo
    exit 1
}


opt_outdir="output${$}"

while [[ 1 ]]; do
    case $1 in
        -o|--outdir)
            [[ -z "${2}" ]] && usage "Directory argument required for $1 option."
            opt_outdir="${2}"
            shift
            ;;
        -h|--help)
            usage
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


search_filename="$1"
search_expr="$2"
[[ -z "${search_filename}" ]] && usage "You must specify a file to search."
[[ -z "${search_expr}" ]] && usage "You must specify a search expression."
search_filename=$(readlink -f "${search_filename}")

git_repo_path=$(cd $(dirname "${search_filename}") && git rev-parse --show-toplevel)
git_relative_path="${search_filename#${git_repo_path}/}"
base_filename=$(basename "${search_filename}")

mkdir -p "${opt_outdir}"
opt_outdir=$(readlink -f "${opt_outdir}")
commits_file="${opt_outdir}/commits"
(
    cd $(dirname "${search_filename}") \
        && git log --reverse -L :${search_expr}:${search_filename} \
        | grep ^commit \
        | cut -d ' ' -f 2 \
        > "${commits_file}"
)
wait

n_commits=$(cat "${commits_file}" | wc -l)
if [[ "${n_commits}" -eq 0 ]]; then
    echo "No commits matching search expression."
    exit 2
elif [[ "${n_commits}" -gt 9999 ]]; then
    # If this limit is increased, the commit index padding also needs to be increased.
    echo "Search expression found ${n_commits}. That would take way too long."
    exit 2
fi

echo "Extracting ${n_commits} revisions of ${base_filename}"
n=0
cd "${git_repo_path}"
while read c; do
    if [[ -n "${c}" ]]; then
        echo -e -n "\033[00G${n}/${n_commits}"
        padded_n=$(printf "%04d" ${n})
        git show "${c}:${git_relative_path}" > "${opt_outdir}/${padded_n}-${c}-${base_filename}"
        n=$(($n + 1))
        echo -e -n "\033[00G${n}/${n_commits}"
    fi
done < "${commits_file}"
echo -e "\033[00G${n}/${n_commits}"


rm -f "${commits_file}"
n_files=$(ls -1 "${opt_outdir}" | wc -l)
echo "Output ${n_files} revisions of ${base_filename} to ${opt_outdir}"
