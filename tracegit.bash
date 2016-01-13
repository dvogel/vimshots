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
SELF_DIR=$(dirname "${SELF_PATH}")
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


search_filename="$1"
search_expr="$2"
[[ -z "${search_filename}" ]] && usage "You must specify a file to search."
[[ -z "${search_expr}" ]] && usage "You must specify a search expression."
search_filename=$(readlink -f "${search_filename}")

git_repo_path=$(cd $(dirname "${search_filename}") && git rev-parse --show-toplevel)
git_relative_path="${search_filename#${git_repo_path}/}"
base_filename=$(basename "${search_filename}")

mkdir -p "${output_dir}"
output_dir=$(readlink -f "${output_dir}")
commits_file="${output_dir}/commits"
(
    cd "${git_repo_path}" \
        && git log --reverse --format=%H "${git_relative_path}" \
        > "${commits_file}"
        # && git log --reverse -L :${search_expr}:${search_filename} \
        # | grep ^commit \
        # | cut -d ' ' -f 2 \
        # > "${commits_file}"
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

echo "Examining ${n_commits} revisions of ${base_filename}"
scratch_file1=$(mktemp --tmpdir="${output_dir}" "1-XXXXXX.c")
scratch_file2=$(mktemp --tmpdir="${output_dir}" "2-XXXXXX.c")
prev_content_hash=
n=0
cd "${git_repo_path}"
while read c; do
    if [[ -n "${c}" ]]; then
        no_such_file_in_commit="false"
        echo -e -n "\033[00G${n}/${n_commits}"
        padded_n=$(printf "%04d" ${n})
        git show "${c}:${git_relative_path}" 2> /dev/null > "${scratch_file1}" || no_such_file_in_commit="true"
        if [[ "${no_such_file_in_commit}" == "false" ]]; then
            bash "${SELF_DIR}/langs/c.bash" "${scratch_file1}" "${search_expr}" > "${scratch_file2}"
            current_content_hash=$(cat "${scratch_file2}" | md5sum)
            if [[ "${current_content_hash}" != "${prev_content_hash}" ]]; then
                cp "${scratch_file2}" "${output_dir}/${padded_n}-${c}-${base_filename}"
            fi
            prev_content_hash="${current_content_hash}"
        fi
        n=$(($n + 1))
        echo -e -n "\033[00G${n}/${n_commits}"
    fi
done < "${commits_file}"
echo -e "\033[00G${n}/${n_commits}"

rm -f "${scratch_file1}" "${scratch_file2}"
rm -f "${commits_file}"
n_files=$(ls -1 "${output_dir}" | wc -l)
echo "Output ${n_files} revisions of ${base_filename} to ${output_dir}"
