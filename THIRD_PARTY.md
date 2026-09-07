# 来源与许可

`src/winlogon.c`、`src/uu_service_control.c` 及最初的兼容工具来自
https://github.com/lachlanchen/uu-remote-ubuntu-bridge 。保留其 MIT LICENSE 与版权声明。
本仓库新增的脚本和文档同样采用 MIT 许可。

Wine 源码修改 `patches/wine-11.16-d3d11-video-query.patch` 基于 Wine 11.16，
适用 Wine 的 LGPL-2.1-or-later 条款。构建脚本下载固定版本源码，保留其中的
COPYING.LIB 与源码；分发编译 DLL 时必须同时履行对应源码和许可证义务。
来源：https://github.com/wine-mirror/wine/tree/wine-11.16 。

UU 安装包和修改后的厂商二进制仍属于网易，本仓库只提供下载地址及本地补丁工具。
Wine、Winetricks、字体、驱动及 KDE xembedsniproxy 各自遵循其原有许可。
