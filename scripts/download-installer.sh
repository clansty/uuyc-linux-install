#!/usr/bin/env bash
set -Eeuo pipefail
if [[ $# != 1 || ${1:-} == --help ]]; then
    printf 'usage: bash scripts/download-installer.sh NEW_DOWNLOAD_DIRECTORY\n'
    [[ ${1:-} == --help ]] && exit 0
    exit 2
fi
mkdir -- "$1"
target="$(cd -- "$1" && pwd)/uu-4.39.2.1561.exe"
curl --fail --location --retry 2 --connect-timeout 15 --max-time 600 \
    'https://a56.gdl.netease.com/UURemote_Setup_4.39.2.1561_0904121034_gwqd.exe?key1=897e50b5c3777d90839894dda1a0c688&key2=6a9f022f&n=uuyc_4.39.2.exe' \
    -o "$target"
printf '%s  %s\n' cf06187be7b1382eab9d53afa129e4dc0dc07b0c7526d1e7a849475e0ca046f5 "$target" | sha256sum --check
printf 'Installer: %s\n' "$target"
