# 安装 UU 远程 Linux 主控：Agent 执行入口

你是执行安装的 agent。目标是在用户的 Linux 图形桌面安装可重复启动、有系统托盘入口、可连接远端设备的 UU 远程主控，默认安装 H.264 高画质兼容补丁，并验证实际连接。按下列顺序执行，在每阶段完成后验证，失败时按最后的排障规则继续处理。不要假定你读过任何聊天历史。

## 0. 获取仓库

仓库地址：`https://github.com/clansty/uuyc-linux-install.git`。

先检查当前目录是否已有本仓库的 `INSTALL.md`、`scripts/uu-controller` 和 `patches/controller/`。已有检出时使用它，不覆盖本地改动。尚未克隆时，在用户用于存放项目的位置执行：

```bash
git clone https://github.com/clansty/uuyc-linux-install.git
cd uuyc-linux-install
```

若 HTTPS 克隆报 TLS unexpected EOF，可单次尝试 `git -c http.version=HTTP/1.1 clone https://github.com/clansty/uuyc-linux-install.git`。先检查失败留下的目录，不覆盖已有文件；不要关闭 TLS 校验。

后面的命令均在仓库根目录的 **Bash** 中执行。先完整阅读本文件及 `AGENTS.md`，开始验证前阅读 `AGENTS_QA.md`。若私有仓库访问失败，请用户提供访问权限，不索要或记录其密码、访问令牌。

不同工具调用通常不共享 shell 变量。把实际 prefix、临时工作目录和 app_dir 记录在本次任务状态中；每次开启新 shell 都显式恢复这些变量，不能因为 WINEPREFIX 丢失而误操作默认前缀。

## 1. 检查环境和权限

验证基线：Linux x86_64、Wine Staging **11.16**、UU **4.39.2.1561**、AMD RX 7800 XT、Mesa RADV、X11 显示后端。原环境为 CachyOS、niri、xwayland-satellite。这是已有测试记录，不是显卡白名单：其他 GPU 同样执行默认补丁安装和实际验收，不能因为型号不同就跳过。其他环境的效果需要实测，不能直接套用成功结论；Wine/UU 版本仍须满足补丁的接口和文件校验要求。

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

### 5.1 先检测，只选择一条路线

在当前图形会话运行，显式捕获检测器的退出码：

```bash
tray_status=0
"$WINEPREFIX/compat/controller/xembed-owner" || tray_status=$?
printf 'tray_status=%s\n' "$tray_status"
```

| 检测结果 | Agent 的决定 |
| --- | --- |
| 0：已有 XEmbed 宿主 | 复用现有托盘，直接进入第 6 节。本节结束，不下载包、不创建桥接或自启动配置。 |
| 1：没有 XEmbed 宿主 | 确认用户面板已启用 StatusNotifierItem（SNI）托盘，再进入 5.2。 |
| 2 或其他错误 | 修复显示连接或检测工具后重测，不能据此安装桥接。 |

若面板连 SNI 托盘也未启用，先配置面板再继续。只在任务记录中写明最终选择的路线，不同时部署多套托盘宿主。检测按当前 X11 selection owner 判断，不按桌面名称猜测。

### 5.2 确认需要桥接后，获取单个程序

本节只供 5.1 确认需要桥接的机器执行。目标程序固定为 KDE `xembedsniproxy`。

1. 先检查系统或用户目录中是否已有可用的 `xembedsniproxy`。存在则复用其绝对路径，不下载。
2. 确实缺少时，通过当前发行版的官方包文件索引定位包含它的软件包，选与本机发行版版本和 CPU 架构匹配的包。可以参考 [Arch 包文件查询](https://wiki.archlinux.org/title/Official_repositories_web_interface) 或 [Ubuntu 包内容查询](https://packages.ubuntu.com/)。包名和二进制在包内的位置以索引为准，不假定所有发行版都相同。
3. **只下载包到临时目录，不把整个包安装到系统。** 使用官方元数据/签名校验下载，记录来源、版本和哈希；不得运行包内安装脚本。
4. 列出包内容，精确提取 `xembedsniproxy` 单个文件到临时目录，再复制到 `~/.local/libexec/uuyc/xembedsniproxy`。不把 KDE 的服务、自启动项及其余文件一起复制过去。

提取时根据包格式执行一个命令。先把 `bridge_package` 设为已校验的包路径，`bridge_member` 设为列表中查到的精确成员路径（含可能的 `./` 前缀）：

```bash
bridge_stage="$(mktemp -d "${TMPDIR:-/tmp}/uuyc-tray.XXXXXX")"
# .deb：先用 dpkg-deb --fsys-tarfile "$bridge_package" | tar -tf - 列出文件。
# libarchive 支持的其他包：先用 bsdtar -tf "$bridge_package" 列出文件。
case "$bridge_package" in
  *.deb)
    dpkg-deb --fsys-tarfile "$bridge_package" |
      tar -xOf - "$bridge_member" > "$bridge_stage/xembedsniproxy"
    ;;
  *)
    bsdtar -xOf "$bridge_package" "$bridge_member" > "$bridge_stage/xembedsniproxy"
    ;;
esac
file "$bridge_stage/xembedsniproxy"
ldd "$bridge_stage/xembedsniproxy"
```

上面的 `ldd` 仅对已验证来源的发行版程序执行。确认架构匹配、没有 `not found` 后，检查目标文件是否已存在；存在则先核对和备份，不能直接覆盖：

```bash
mkdir -p "$HOME/.local/libexec/uuyc"
install -m 755 "$bridge_stage/xembedsniproxy" "$HOME/.local/libexec/uuyc/xembedsniproxy"
```

提取程序不等于它是静态独立程序。若缺少共享库或 Qt xcb 平台插件，先列明缺失的最小运行依赖再处理；不要通过安装整个 Plasma/KDE 包来补齐。不要把其他发行版的库覆盖到系统库目录。复用已有程序时也要检查运行依赖。

### 5.3 固定使用用户服务管理桥接

桥接的管理方式统一为：**图形登录入口 → `start-xembed-proxy` → 用户级 systemd 服务**。不另外直接自启动 `xembedsniproxy`。

先检查现有同名文件和服务；已存在时核对、备份后复用或迁移，不能再建一套并行服务。准备辅助工具：

```bash
mkdir -p "$HOME/.local/libexec/uuyc" "$HOME/.local/bin" "$HOME/.config/systemd/user"
install -m 755 "$work_dir/helpers/xembed-owner" "$HOME/.local/libexec/uuyc/"
install -m 755 scripts/start-xembed-proxy "$HOME/.local/bin/"
```

创建 `~/.config/systemd/user/xembedsniproxy.service`。下例使用提取到用户目录的程序；5.2 复用已有程序时，只将 ExecStart 替换为它的真实绝对路径：

```ini
[Unit]
Description=XEmbed to StatusNotifierItem tray bridge
PartOf=graphical-session.target

[Service]
Type=simple
EnvironmentFile=%t/uuyc-xembed.env
ExecStart="%h/.local/libexec/uuyc/xembedsniproxy"
Environment=QT_QPA_PLATFORM=xcb
Restart=on-failure
RestartSec=1s
```

```bash
systemctl --user daemon-reload
"$HOME/.local/bin/start-xembed-proxy"
systemctl --user status xembedsniproxy.service --no-pager
"$WINEPREFIX/compat/controller/xembed-owner"
```

本阶段要求检测器返回 0、桥接服务没有启动错误。缺少 Qt 插件时检查该服务的 journal，不能仅凭 `ldd` 全部通过就判断可运行。真实 UU 托盘图标在第 6 节启动应用后验证。

### 5.4 选择一个登录触发入口

Agent 先检查当前桌面实际执行哪种登录自启动，**仅配置其中一个入口**：

- 桌面执行 XDG autostart：创建下面的 `~/.config/autostart/uuyc-xembed.desktop`，不再配置合成器启动项。
- 桌面不执行 XDG autostart：在桌面的原生登录配置里调用 `~/.local/bin/start-xembed-proxy`（如 niri 的 `spawn-at-startup`），不创建上述 autostart 文件。

XDG 入口模板如下，Exec 必须替换为用户的实际绝对路径；有空格时按 Desktop Entry 规则引用，并用 `desktop-file-validate` 检查：

```ini
[Desktop Entry]
Type=Application
Name=XEmbed tray bridge
Exec=/用户HOME/.local/bin/start-xembed-proxy
Terminal=false
```

不要对桥接服务执行 `systemctl --user enable`，也不要再挂到 `default.target` 或 `graphical-session.target` 启动。如果迁移旧的已启用服务，记录原配置后移除旧自动启用关系。

登录触发必须来自真实图形会话。工具会等待 X11 可连接，已有宿主则退出；否则将本次 DISPLAY/XAUTHORITY 写入权限 0600 的专属运行时文件，再启动服务。因此无需依赖 systemd manager 留下的环境，也不修改其全局环境。UU 启动器按需调用同一工具，锁会避免并发启动。

`PartOf` 负责在 systemd 图形会话注销时停止服务；桌面没有这种会话集成时，agent 还需在其注销钩子调用 `systemctl --user stop xembedsniproxy.service`。此方案只覆盖每个 Unix 用户一个活动图形会话。

### 5.5 验收后继续安装

记录所选托盘路线、程序来源及唯一登录入口，进入第 6 节启动 UU 后再检查最小化到托盘能否恢复。用户方便中断连接时，再实际注销重登，确认本次显示环境和托盘恢复；未实测就明确记录未验证。

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

## 7. 默认安装 H.264 高画质补丁

先完成基础连接，再执行本阶段；这是默认安装流程，不是仅供某款显卡选择的可选项。为所有满足 Wine/UU 版本要求的安装应用补丁，然后依据真实检测和连接结果判断。不要因显卡不是 RX 7800 XT、其他型号尚未验证，或初步能力枚举失败而直接跳过。

补丁目前针对 Wine 11.16 + Vulkan Video + H.264 8-bit NV12，仍有实验性兼容风险。记录 GPU/驱动和 Vulkan 视频能力用于后续诊断；仅 VA-API 可用不等于 Wine 链路可用。HEVC、HDR、10-bit、4:4:4 不由当前补丁保证支持。

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

如果应用后不能连接、画质仍受限或出现渲染错误，agent 应继续排障，不以“不是已验证显卡”结束安装：先检查 DLL 加载、驱动和 Vulkan Video，再依据检测器及连接日志定位能力查询、解码创建或画面输出的失败环节。必要时尝试 UU 与远端共同支持的其他编解码格式、其他可用的硬件解码后端或兼容修复；每次更换路径都要实际连接验收。当前 H.264 补丁不能直接当作 HEVC 等格式的实现，也不能仅伪造能力标志绕过检测。保留可恢复的基线；只有确认硬解方案不可用时才向用户说明软件解码兜底的限制。若必须改变固定版本或需要新的授权，说明具体证据并请求用户决定，不跳过哈希校验。

## 8. 最终验收与交付

让用户选择并授权测试远端设备；不要自行操作设备上的业务数据。

1. 从生成的桌面入口打开 UU；退出后再打开也成功。
2. 最小化后从系统托盘恢复；中文和 DPI 可用。
3. 实际连接，确认视频更新、鼠标键盘输入和需要的音频工作。
4. 默认补丁安装后，在真实连接中打开画质菜单，选择高画质并确认图像持续更新；失败则返回第 7 节继续排障。
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
