# 验证记录

日期：2026-09-07。

## 已完成

- 固定下载地址实际下载成功，安装包 SHA-256 匹配。
- 独立新目录编译 winlogon、服务控制器和 Linux XEmbed 检测工具成功；启用 Wall/Wextra/Werror。
- 独立新目录从已校验 Wine 11.16 源归档完整构建 d3d11.dll 与视频查询探针成功。
- 对原始 UU 备份文件生成补丁成功，未修改运行中的用户安装。
- 补丁安全测试 15 项通过。
- 启动脚本/桌面入口测试 8 项通过，实际通过 gio launch 启动隔离程序，验证 prefix 和参数传递。
- XEmbed 检测：当前显示已有宿主返回 0，隔离测试显示无宿主返回 1，错误 DISPLAY 返回 2。
- 桥接启动工具在当前已有宿主时直接退出，不重启桥接服务。
- Bash 语法、Perl 语法和 Desktop Entry 格式检查通过。

## 第二台机器：Radeon 780M

2026-09-07，用户确认安装成功；随后通过 SSH 只读采集以下实际配置，没有重启 UU 或修改远端机器。公开记录省略地址、用户名和进程 PID。

| 项目 | 实际配置 | 检查来源 |
| --- | --- | --- |
| 发行版 | Arch Linux rolling | `/etc/os-release` |
| 内核 / 架构 | `7.2.3-1-cachyos` / x86_64 | `uname`、`lscpu` |
| CPU | AMD Ryzen 7 8745HS，8 核 16 线程 | `lscpu` |
| 内存 | 系统可用总内存约 30 GiB | `free -h` |
| GPU | AMD Radeon 780M Graphics，集成显卡；PCI `1002:1900` | `lspci`、`vulkaninfo --summary` |
| Vulkan 驱动 | RADV PHOENIX，Mesa `26.3.0-devel (git-dc886f34eb)` | `vulkaninfo --summary` |
| Mesa 包 | `mesa-git 26.3.0_devel.229136.dc886f34eb1-1` | `pacman -Q` |
| Wine 运行时 | `wine-11.17 (Staging)`；包 `wine-staging 11.17-1.1` | `wine --version`、`pacman -Q` |
| UU | `4.39.2.1561` | 安装包和原版后台文件哈希与固定版本清单匹配 |
| 图形桌面 | niri `26.04-1.1` + Noctalia；xwayland-satellite `0.8.2-1` | 包版本、niri 配置 |
| Wine 显示后端 | `Graphics=x11` | prefix 的 `user.reg` |
| DPI / 字体平滑 | DPI 130；FontSmoothing=2，Type=2，Orientation=1，Gamma=1400 | `user.reg` |
| 字体 | `cjkfonts`、`corefonts`；含 sourcehansans、unifont 及中日韩字体映射 | `winetricks.log` |
| Prefix | `~/.local/share/wineprefixes/uu-controller` | 启动器和桌面入口 |
| 应用级覆盖 | GameViewer.exe、StreamerCodecDetector.exe：`d3d11=native,builtin` | `user.reg` |
| 渲染 / 解码后端 | 两个应用均为 `renderer=vulkan`、`decoder_backend=vulkan` | `user.reg` |
| 补丁 DLL 构建来源 | Wine **11.16** 源码，configure 参数为 `--enable-win64 --without-x --disable-tests` | 保留的构建脚本、`config.log`、源归档哈希 |

### 启动与托盘

- 启动入口为 `~/.local/bin/uu-controller`；生成的 `.desktop` 显式传入上述 prefix。
- 采集时自定义入口仍使用通用图标 `preferences-desktop-remote-desktop`，Wine 原入口的图标为 `024B_GameViewer.0`，且尚未设置 `NoDisplay=true`。仓库后续已补充复用 UU 图标和隐藏原入口的流程，但本次没有将这项修改应用到远端。
- 桥接程序为 `/usr/bin/xembedsniproxy`，属于 `plasma-workspace 6.7.4-3.1`。用户明确指出该 KDE 包是安装 agent 为此次安装装入系统的。这是当时安装过程的偏差，不是预先存在的可复用依赖；新流程已改为确认需要桥接后只下载包并提取程序。本次仅记录，没有卸载远端软件包。
- 用户服务 `xembedsniproxy.service` 为 `active/running`，启用状态为 `static`；读取 `EnvironmentFile=%t/uuyc-xembed.env`，设置 `QT_QPA_PLATFORM=xcb`、`Restart=on-failure`、`RestartSec=1s`，并使用 `PartOf=graphical-session.target`。
- 唯一桥接登录入口为 niri 配置中的 `spawn-at-startup`，调用 `~/.local/bin/start-xembed-proxy`；未创建桥接的 XDG autostart 文件。
- 采集时专属环境文件为 `DISPLAY=:0`、`XAUTHORITY=""`。这是当次会话值，不应写死到其他机器的安装配置。

### 文件与加载核对

| 文件 | SHA-256 |
| --- | --- |
| UU 安装包 | `cf06187be7b1382eab9d53afa129e4dc0dc07b0c7526d1e7a849475e0ca046f5` |
| Wine 11.16 源归档 | `2b6d5cff784cb774f7f17b9a640b123ca8361d89c4280c0021b70bb6f3cd1b1c` |
| `bin/d3d11.dll` | `59d07f836b34ff0c6f5eabc7210cd753b73fa6de5c44590aa8285eaa7bdcee7b` |
| `bin/streamer.dll` | `c294c92b389c60072000e1faa97c8529115c6e5eace7a5e974b2f7c59e205b13` |
| `bin/StreamerCodecDetector.exe` | `cb9f2b9d3e2e2578d3193338165dec66c7154646df07c78a50eedf4684a39d7d` |
| `bin/GameViewerServer.exe`（原版） | `672ccca2aed867e8ce69436fd891fa167960e6df4a7159804bee220ef7b7be6c` |

安装的 `d3d11.dll` 与该机器构建目录中的产物哈希一致。当前 UU 进程的 `/proc/<PID>/maps` 确认加载应用目录中的 `d3d11.dll` 和 `streamer.dll`，同时加载系统 Wine 的 `wined3d.dll` 及 `libvulkan_radeon.so`。

因此应准确描述此案例为“Wine Staging 11.17 运行时 + 从 Wine 11.16 构建的查询补丁 DLL”，不能误写成使用 11.17 源码构建，也不能据此保证所有跨版本组合兼容。

## 验证边界

原安装环境中用户已确认 UU 可启动、托盘集成和高画质切换可用。新仓库的工具测试在隔离目录执行，没有重装或重启用户正在使用的 UU。

第二台机器的配置与模块加载已只读核实，安装成功由用户确认。本次未重新操作远端连接、切换画质、测量视频引擎或注销重登；不能从文件加载推断全部解码路径已通过。全部视频格式和长期硬解稳定性仍未验证。安装 agent 应按 INSTALL.md 完成目标机器上的最终验收，而不是沿用本记录宣称成功。
