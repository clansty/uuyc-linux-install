#!/usr/bin/env bash
set -Eeuo pipefail
if [[ $# != 1 || ${1:-} == --help ]]; then
    printf 'usage: bash scripts/build-helpers.sh NEW_OUTPUT_DIRECTORY\n'
    [[ ${1:-} == --help ]] && exit 0
    exit 2
fi
repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
winegcc_bin="${WINEGCC:-winegcc}"
mingw_cc="${MINGW_CC:-x86_64-w64-mingw32-gcc}"
command -v "$winegcc_bin" >/dev/null
command -v "$mingw_cc" >/dev/null
command -v gcc >/dev/null
mkdir -- "$1"
output_dir="$(cd -- "$1" && pwd)"
"$winegcc_bin" -O2 -Wall -Wextra -Werror -mwindows \
    -o "$output_dir/winlogon.exe" "$repo_dir/src/winlogon.c"
"$mingw_cc" -O2 -Wall -Wextra -Werror -municode \
    -o "$output_dir/uu-service-control.exe" "$repo_dir/src/uu_service_control.c" -ladvapi32
gcc -std=c11 -O2 -Wall -Wextra -Werror \
    "$repo_dir/src/xembed_owner.c" -o "$output_dir/xembed-owner" -lX11
printf 'Helpers: %s\n' "$output_dir"
