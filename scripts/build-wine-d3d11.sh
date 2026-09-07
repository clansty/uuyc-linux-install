#!/usr/bin/env bash
set -Eeuo pipefail

if [[ $# != 1 || "$1" == --help ]]; then
    printf 'Usage: %s NEW_BUILD_DIRECTORY\nBuild experimental Wine 11.16 d3d11.dll and its query probe; no installation.\n' "$0"
    [[ ${1:-} == --help ]] && exit 0
    exit 2
fi

repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cc="${MINGW_CC:-x86_64-w64-mingw32-gcc}"
for tool in curl sha256sum tar patch make gcc flex bison "$cc"; do
    command -v "$tool" >/dev/null || { printf 'missing build tool: %s\n' "$tool" >&2; exit 1; }
done
# 独占新目录，避免覆盖已有源码或把旧对象混入实验结果。
mkdir -- "$1"
work_dir="$(cd -- "$1" && pwd)"
archive="$work_dir/wine-11.16.tar.gz"
if [[ -n ${WINE_SOURCE_ARCHIVE:-} ]]; then
    cp -- "$WINE_SOURCE_ARCHIVE" "$archive"
else
    curl --fail --location --retry 3 --connect-timeout 15 --max-time 600 \
        https://github.com/wine-mirror/wine/archive/refs/tags/wine-11.16.tar.gz -o "$archive"
fi
printf '%s  %s\n' 2b6d5cff784cb774f7f17b9a640b123ca8361d89c4280c0021b70bb6f3cd1b1c "$archive" | sha256sum --check
tar -xf "$archive" -C "$work_dir"
source_dir="$work_dir/wine-wine-11.16"
patch --batch --forward -d "$source_dir" -p1 < "$repo_dir/patches/wine-11.16-d3d11-video-query.patch"
mkdir "$work_dir/build" "$work_dir/output"
cd "$work_dir/build"
"$source_dir/configure" --enable-win64 --without-x --disable-tests > configure.log 2>&1
# builtin 标记会让 Wine 忽略 app-local 的 native 覆盖；这里只构建实验 d3d11。
sed -i 's/-Wl,--wine-builtin //g' Makefile
make -j "${JOBS:-$(getconf _NPROCESSORS_ONLN)}" dlls/d3d11/x86_64-windows/d3d11.dll > build.log 2>&1
cp dlls/d3d11/x86_64-windows/d3d11.dll "$work_dir/output/"
"$cc" -std=c11 -O2 -Wall -Wextra -Werror -Wl,--no-insert-timestamp \
    "$repo_dir/tests/probes/uu_d3d11_video_probe.c" -o "$work_dir/output/uu-d3d11-video-probe.exe" \
    -ld3d11 -ldxgi -ldxguid -luuid
printf 'Experimental artifacts: %s/output\nQuery success does not prove video decoding or UU high-quality support.\n' "$work_dir"
