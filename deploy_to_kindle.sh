#!/usr/bin/env bash

set -Eeuo pipefail  # Exit on error, unset variables, pipe failures
# set -x		 	# Print commands and their arguments as they are executed.

die() {
    set +xe
    echo '================================ DIE ===============================' >&2
    echo >&2 "$*"
    echo >&2 "Call stack:"
    local n=$((${#BASH_LINENO[@]} - 1))
    local i=0
    while [ $i -lt $n ]; do
        echo >&2 "    [$i] -- line ${BASH_LINENO[i]} -- ${FUNCNAME[i + 1]}"
        i=$((i + 1))
    done
    echo >&2 '================================ END ==============================='
    exit 1
}

SRC_DIR="${0%/*}"
DST_DIR=

case $(uname) in
    Linux) DST_DIR="/var/run/media/${USER}/Kindle/koreader/plugins" ;;
    *) ;;
esac


[[ -z "${DST_DIR}" ]] && die "Failed to detect destination directory for $(uname)\n"
[[ -e "${DST_DIR}" ]] || die "Destination director does not exist: ${DST_DIR}"

DST_DIR="${DST_DIR}/zen_ui.koplugin/"

if [[ -e "${DST_DIR}" ]]; then
    (
        cd "${DST_DIR}"
        for fn in *; do
            rsync -Pavh  "${SRC_DIR}/${fn}" .
        done
    )
else
    mkdir -p "${DST_DIR}"
    cp -aRfv ./* "${DST_DIR}"
fi
