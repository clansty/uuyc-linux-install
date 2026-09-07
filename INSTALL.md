# 安装 UU 远程 Linux 主控：Agent 执行入口

你是执行安装的 agent。目标是在用户的 Linux 图形桌面安装可重复启动、有系统托盘入口、可连接远端设备的 UU 远程主控，并在兼容硬件上启用实验性 H.264 高画质修复。按下列顺序执行，在每阶段完成后验证，失败时按最后的排障规则处理。不要假定你读过任何聊天历史。

## 0. 获取仓库

仓库地址：`https://github.com/clansty/uuyc-linux-install.git`。

先检查当前目录是否已有本仓库的 `INSTALL.md`、`scripts/uu-controller` 和 `patches/controller/`。已有检出时使用它，不覆盖本地改动。尚未克隆时，在用户用于存放项目的位置执行：

```bash
git clone https://github.com/clansty/uuyc-linux-install.git
cd uuyc-linux-install
```

后面的命令均在仓库根目录的 **Bash** 中执行。先完整阅读本文件及 `AGENTS.md`，开始验证前阅读 `AGENTS_QA.md`。若私有仓库访问失败，请用户提供访问权限，不索要或记录其密码、访问令牌。

不同工具调用通常不共享 shell 变量。把实际 prefix、临时工作目录和 app_dir 记录在本次任务状态中；每次开启新 shell 都显式恢复这些变量，不能因为 WINEPREFIX 丢失而误操作默认前缀。

## 1. 检查环境和权限

验证基线：Linux x86_64、Wine Staging **11.16**、UU **4.39.2.1561**、AMD RX 7800 XT、Mesa RADV、X11 显示后端。原环境为 CachyOS、niri、xwayland-satellite。其他发行版、GPU、Wine 版本属于待验证组合，不能直接套用已成功结论。

以正在使用桌面的普通用户执行 Wine。确认：

```bash
uname -m
wine --version
command -v wine wineserver winegcc winetricks x86_64-w64-mingw32-gcc
printf 'DISPLAY=%s\n' "${DISPLAY:-}"
systemctl --user show-environment
```

所需工具：Git、Bash、Perl、curl、coreutils、procps、systemd 用户会话、Wine/对应版本 winegcc、Winetricks、MinGW-w64 C 编译器、GCC、X11 显示及 libX11 开发头文件。推荐 `notify-send`、`desktop-file-validate`、`xprop`。硬解构建还需要 make、flex、bison、patch、tar 和 Wine configure 要求的开发依赖；检查 Vulkan 能力可用 `vulkaninfo`。

按发行版包管理器确认包名后安装缺失依赖，不替换正在被其他程序使用的 Wine。硬解 DLL 按 Wine 11.16 构建；若系统版本不匹配，先解决版本隔离，不把它装进其他版本的 Wine。

必须在目标用户的真实图形会话执行启动，`DISPLAY` 应有效；Wayland 桌面需要工作正常的 XWayland。不要猜测显示号或复制别人的 D-Bus/Xauthority 环境。

## 2. 设置独立目录并下载

```bash
export WINEPREFIX="$HOME/.local/share/wineprefixes/uu-controller"
export WINEDEBUG=-all
repo_dir="$PWD"
work_dir="$(mktemp -d "${TMPDIR:-/tmp}/uuyc-install.XXXXXX")"
bash scripts/download-installer.sh "$work_dir/download"
```

下载工具使用固定版本地址：

```text
https://a56.gdl.netease.com/UURemote_Setup_4.39.2.1561_0904121034_gwqd.exe?key1=897e50b5c3777d90839894dda1a0c688&key2=6a9f022f&n=uuyc_4.39.2.exe
```

预期 SHA-256：`cf06187be7b1382eab9d53afa129e4dc0dc07b0c7526d1e7a849475e0ca046f5`。2026-09-07 已实下载核对。下载失败时可让用户提供相同哈希的离线安装包；禁止改用最新版后跳过校验。

若 prefix 已存在，先检查是否为用户现有 UU 安装；不能把下面的全新安装流程直接覆盖上去。对已有安装需先停止其会话、备份 prefix，然后只做缺失步骤。备份含账号数据，放在仓库外。

## 3. 初始化 Wine、字体和显示

仅对全新 prefix 执行：

```bash
mkdir -p "$(dirname "$WINEPREFIX")"
mkdir "$WINEPREFIX"
wineboot -u
winetricks cjkfonts corefonts
wine reg add 'HKCU\Software\Wine\Drivers' /v Graphics /d x11 /f
wine reg add 'HKCU\Control Panel\Desktop' /v LogPixels /t REG_DWORD /d 130 /f
wine reg add 'HKCU\Control Panel\Desktop' /v FontSmoothing /t REG_SZ /d 2 /f
wine reg add 'HKCU\Control Panel\Desktop' /v FontSmoothingType /t REG_DWORD /d 2 /f
wine reg add 'HKCU\Control Panel\Desktop' /v FontSmoothingOrientation /t REG_DWORD /d 1 /f
wine reg add 'HKCU\Control Panel\Desktop' /v FontSmoothingGamma /t REG_DWORD /d 1400 /f
```

DPI 130 是本次验证值，可在 `winecfg` 的显示设置中按用户屏幕调整。验收字体时检查中文显示、窗口实际大小和可读性，不只看注册表。

字体安装可能有交互窗口；观察进程与窗口完成安装，不将反复终止 wineserver 当作正常步骤。出现挂起时见第 9 节。

## 4. 安装 UU 和启动辅助程序

```bash
wine "$work_dir/download/uu-4.39.2.1561.exe"
```

在安装界面使用默认路径 `C:\Program Files\Netease\GameViewer`。安装后先退出自动弹出的 UU；登录及验证码由用户完成。确认以下文件存在：

```bash
app_dir="$WINEPREFIX/drive_c/Program Files/Netease/GameViewer"
test -f "$app_dir/GameViewer.exe"
test -f "$app_dir/bin/GameViewerServer.exe"
test -f "$app_dir/bin/uuyc-cli.exe"
bash scripts/build-helpers.sh "$work_dir/helpers"
mkdir -p "$WINEPREFIX/compat/controller"
install -m 755 "$work_dir/helpers/winlogon.exe" \
    "$work_dir/helpers/winlogon.exe.so" \
    "$work_dir/helpers/uu-service-control.exe" "$work_dir/helpers/xembed-owner" \
    "$WINEPREFIX/compat/controller/"
```

`winlogon` helper 提供 UU 后台所需的会话进程；服务控制 helper 用于发送 UU 自定义控制码 133。启动器等待后台及本地 IPC 就绪后再启动界面。

## 5. 系统托盘

先运行：

```bash
"$WINEPREFIX/compat/controller/xembed-owner"
```

退出码 0 表示当前显示已有 XEmbed 托盘宿主：直接进入第 6 节，不安装或启用桥接。退出码 1 表示没有宿主：确认桌面面板是否能启用原生 XEmbed 托盘；仅提供 StatusNotifierItem 的面板使用下面的 KDE `xembedsniproxy` 桥接。退出码 2 表示显示连接出错，先修复 DISPLAY，不能误判为缺少托盘。如果 agent 的命令环境启用了 `set -e`，用 `if` 捕获这些预期退出码。

若已有同名用户服务，检查后复用，不覆盖它。启动器同样查询 X11 selection owner，存在宿主就不会启动桥接；不依赖 GNOME/KDE 等桌面名称猜测。

使用发行版软件包提供的 `xembedsniproxy`，找到其真实可执行文件路径，确认依赖齐全。准备用户全局检测和会话启动工具；若目标文件已有内容，先核对并备份：

```bash
mkdir -p "$HOME/.local/libexec/uuyc" "$HOME/.local/bin" "$HOME/.config/systemd/user" "$HOME/.config/autostart"
install -m 755 "$work_dir/helpers/xembed-owner" "$HOME/.local/libexec/uuyc/"
install -m 755 scripts/start-xembed-proxy "$HOME/.local/bin/"
```

将以下服务的 `/绝对路径/xembedsniproxy` 替换为该路径，保存到 `~/.config/systemd/user/xembedsniproxy.service`：

```ini
[Unit]
Description=XEmbed to StatusNotifierItem tray bridge
PartOf=graphical-session.target

[Service]
Type=simple
EnvironmentFile=%t/uuyc-xembed.env
ExecStart=/绝对路径/xembedsniproxy
Environment=QT_QPA_PLATFORM=xcb
Restart=on-failure
RestartSec=1s
```

```bash
systemctl --user daemon-reload
"$HOME/.local/bin/start-xembed-proxy"
systemctl --user status xembedsniproxy.service --no-pager
```

每次登录由桌面会话运行启动工具。创建 `~/.config/autostart/uuyc-xembed.desktop`，把 Exec 换成安装用户的真实绝对路径（路径有空格时遵循 Desktop Entry 引号/转义规则）：

```ini
[Desktop Entry]
Type=Application
Name=XEmbed tray bridge
Exec=/用户HOME/.local/bin/start-xembed-proxy
Terminal=false
```

用 `desktop-file-validate` 检查自启动文件。桌面不执行 XDG autostart 时，在其原生登录启动配置中执行同一工具；例如 niri 的 `spawn-at-startup`，二者选一。必须从图形会话触发，不能从没有 DISPLAY 的 TTY 或 SSH 执行。

工具在本次会话环境中等待 X11 可连接，存在 XEmbed 宿主时直接返回；否则把本次 DISPLAY/XAUTHORITY 原子写入权限 0600 的用户运行时文件，供专属服务读取，并启动服务。不依赖用户 systemd manager 的历史环境，也不改其全局环境；锁避免登录自启动与 UU 启动器并发启动桥接。不要同时为此服务配置 `WantedBy=default.target` 或 `graphical-session.target` 自动启用。如果迁移旧的已启用服务，先记录原配置并移除其自动启用关系，不必因此中断当前连接。

`PartOf` 使支持 systemd 图形会话的桌面在注销时停止服务；其他桌面需把 `systemctl --user stop xembedsniproxy.service` 接入其注销钩子。此方案面向每个 Unix 用户一个活动图形会话；同一用户多会话需要按显示隔离服务与环境文件。

完成后实际注销重登验收（会中断当前连接，需用户安排）：检查服务读取本次环境、面板显示图标、其他 Wine 程序也能使用托盘。不能以“服务进程存在”或仅添加 After=graphical-session.target 代替该验证。启动器也会在缺少宿主时调用同一工具，因此按需启动仍会刷新本次环境。

## 6. 创建启动脚本和桌面入口

下面的工具实际安装启动脚本，并生成包含当前用户绝对路径及目标 prefix 的 `.desktop`，不会覆盖已有同名文件：

```bash
perl scripts/install-launcher.pl "$WINEPREFIX" \
    "$HOME/.local/bin" "${XDG_DATA_HOME:-$HOME/.local/share}/applications"
desktop-file-validate "${XDG_DATA_HOME:-$HOME/.local/share}/applications/uu-controller.desktop"
"$HOME/.local/bin/uu-controller" start
```

已有入口时先检查和备份再更新，不能直接删除。桌面图标调用该启动脚本，不直接调用 UU 的 exe。命令行使用自定义 prefix 时继续显式设置 `WINEPREFIX`；桌面入口已固定安装时的 prefix。

验收：UU 主窗口出现、能登录并列出设备；最小化到托盘后能从系统托盘恢复；在软件菜单退出后再次点击桌面入口可打开。关闭自动更新，以免固定版本补丁被升级覆盖。

## 7. 实验性 H.264 高画质修复

先完成基础连接，再进行此阶段。当前成功范围是 Wine 11.16 + Vulkan Video + H.264 8-bit NV12。HEVC、HDR、10-bit、4:4:4、其他 GPU 尚未验证。构建前确认 GPU/驱动可暴露 Vulkan 视频解码能力；仅 VA-API 可用不等于 Wine 链路可用。

```bash
bash scripts/build-wine-d3d11.sh "$work_dir/d3d11"
bash tests/test-controller-hwdecode-patch.sh
perl scripts/patch-controller-hwdecode.pl \
    patches/controller/uu-controller-4.39.2.1561-hwdecode.json \
    "$app_dir/bin" "$work_dir/patched"
```

构建脚本下载并校验 Wine 11.16 源码，补齐三个 D3D11 视频能力查询，输出 app-local `d3d11.dll` 和查询探针。UU 补丁校验整个原文件哈希和每处原始字节，使 H.264 解码器使用已有的同设备非共享纹理路径。硬解仍由 WineD3D Vulkan Video 提供。查询 DLL 的构建和限制详见 `docs/hwdecode.md`。

通知用户该步骤需要退出 UU，确认没有进行中的远端操作后停止目标会话，备份完整 prefix。备份必须位于 prefix 外且路径不存在：

```bash
"$HOME/.local/bin/uu-controller" stop
backup_dir="${WINEPREFIX}.before-hwdecode-$(date +%Y%m%d-%H%M%S)"
test ! -e "$backup_dir"
cp -a --reflink=auto "$WINEPREFIX" "$backup_dir"
install -m 644 "$work_dir/patched/streamer.dll" \
    "$work_dir/patched/StreamerCodecDetector.exe" \
    "$work_dir/d3d11/output/d3d11.dll" "$app_dir/bin/"
for app in GameViewer.exe StreamerCodecDetector.exe; do
  key='HKCU\Software\Wine\AppDefaults\'"$app"
  wine reg add "$key"'\DllOverrides' /v d3d11 /d native,builtin /f
  wine reg add "$key"'\Direct3D' /v renderer /d vulkan /f
  wine reg add "$key"'\Direct3D' /v decoder_backend /d vulkan /f
  wine reg query "$key" /s
done
"$HOME/.local/bin/uu-controller" start
```

保存 `backup_dir` 的实际路径到仓库外的安装记录。必须检查当前 UU 进程 `/proc/<PID>/maps` 中加载的 `d3d11.dll` 来自 UU `bin/`，而非 `/usr/lib/wine/`。进程命令行可能变为 `source=...`，结合 prefix 环境和映射确认，不能只按名字猜 PID。

## 8. 最终验收与交付

让用户选择并授权测试远端设备；不要自行操作设备上的业务数据。

1. 从生成的桌面入口打开 UU；退出后再打开也成功。
2. 最小化后从系统托盘恢复；中文和 DPI 可用。
3. 实际连接，确认视频更新、鼠标键盘输入和需要的音频工作。
4. 修复高画质时，在真实连接中打开画质菜单，选择高画质并确认图像持续更新。
5. 记录实际 UU/Wine/驱动版本、GPU、设置、补丁哈希和验证结果；日志与截图存仓库外。

只有第 4 项完成才能报告画质切换修复。视频查询探针成功或创建 4K decoder 不等于完成真实解码验证。完整硬解结论还需视频引擎活动、真实码流输出和稳定性验证；未做的明确写未验证。

向用户交付桌面入口位置、启动/停止命令、备份位置、已验证结果和限制。

## 9. 排障与恢复

- 界面不出现：检查启动器报错、同 prefix 的 GameViewerServer.exe、本地 `uuyc-cli.exe version` 和对应 `uu-controller-<prefix摘要>.service` 日志。不要仅凭 systemd active 判定正常。
- Wine 操作卡住：确认是否在等待交互窗口；保存日志后，仅在允许中断目标 UU 会话时执行 `WINEPREFIX="$WINEPREFIX" wineserver -k`。不要终止其他前缀。
- 独立托盘窗口：检查 XEmbed 宿主、桥接器环境和面板 SNI 支持，保留可恢复 UU 界面的入口。
- 残留窗口：用 `xprop` 的 `_NET_WM_PID` 查真实进程，再检查 `/proc/<PID>/environ` 的 prefix 和 `ps -T -p <PID>`，只处理已确认的旧进程。
- 仍受性能限制：先确认应用级注册表和实际加载 DLL，再查检测器结果。检测器调用为 `--batch 32 <device_id> <当前LUID>`，使用查询探针动态获取 LUID，不写死设备 ID 或旧 LUID。
- 补丁失败：保留输出和原文件，停止应用；不要修改哈希清单强行通过。
- 回滚：停止目标 UU 会话，将当前 prefix 重命名为一个新故障留存目录，再把第 7 节的完整备份复制回原 prefix 路径。这样同时恢复文件、注册表和账号状态；备份后的设置/会话变化不随之保留。确认恢复成功后由用户决定何时清理留存目录。

卸载时先停止目标会话，核实后移走本工具创建的启动脚本与 `.desktop`，保留 prefix 作为可恢复数据。全局托盘桥接可能仍供其他应用使用，先确认其使用情况再决定是否停用。
