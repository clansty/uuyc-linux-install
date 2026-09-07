# Wine 主控端硬解实验

这套实验工具用于修复 Wine 下 UU 主控端「设备性能受限」。2026-09-07，用户在应用修复后确认已能切换画质；进程映射也确认加载了修复模块。尚未完成解码像素校验、长时间连接和其他 GPU 的验证，因此保留实验标记。

## 已确认的边界

- 测试机器为 RX 7800 XT，Linux VA-API 能枚举硬解能力；这只能证明 Linux 驱动的基础能力，不能证明 UU 的 Windows D3D11 调用链已经打通。
- Wine 11.16 的 `ID3D11VideoDevice` 能暴露解码 profile，但 `CheckVideoDecoderFormat`、`GetVideoDecoderConfigCount`、`GetVideoDecoderConfig` 原本返回 `E_NOTIMPL`。
- `patches/wine-11.16-d3d11-video-query.patch` 只补这三个查询。它根据 Wine 实际枚举的 H.264 profile 暴露 NV12 支持，返回实验用的两种 bitstream 配置；没有实现新的解码或纹理共享路径。
- 只补 Wine 查询时，UU 创建 4K H.264 解码器后仍受 `ExtendedResourceSharing = FALSE` 阻塞。客户端补丁选择现成的同设备非共享纹理路径，不修改 Wine 的共享能力位，也不伪造检测结果。
- 早期 DXVK 对照使用了错误的检测器参数，不能据此判断硬解能力。当前成功路径使用 WineD3D Vulkan，不使用 DXVK。

## 客户端非共享路径

```sh
perl scripts/patch-controller-hwdecode.pl \
  patches/controller/uu-controller-4.39.2.1561-hwdecode.json \
  /原版UU/bin /新的输出目录
bash tests/test-controller-hwdecode-patch.sh
```

工具校验整个文件 SHA-256、偏移及原始字节，仅向全新目录输出 `streamer.dll` 和 `StreamerCodecDetector.exe`。版本不匹配会拒绝操作；不要对升级后的文件强制套用偏移。

两处修改分别允许已成功创建的 H.264 解码器继续使用、清除共享纹理标志，保留实际能力测试、创建及解码逻辑。反编译确认渲染器已有 `renderer adopts decoder d3d11 allocator for non-shared texture` 分支。

应用前退出 UU 并保留原始两个文件；把输出副本和构建得到的 `d3d11.dll` 放到 UU 的 `bin/`。只为主控进程及其检测器配置覆盖，避免影响其他 Wine 程序：

```sh
# WINEPREFIX 必须先设置为实际的 UU 前缀。
for app in GameViewer.exe StreamerCodecDetector.exe; do
  key='HKCU\Software\Wine\AppDefaults\'"$app"
  wine reg add "$key"'\DllOverrides' /v d3d11 /d native,builtin /f
  wine reg add "$key"'\Direct3D' /v renderer /d vulkan /f
  wine reg add "$key"'\Direct3D' /v decoder_backend /d vulkan /f
done
```

设置前应记录已有注册表值，恢复时还原它们；仅当原先没有这些值时才删除上述三个值。文件恢复则换回备份的两个 UU 文件，并移走新增的 `bin/d3d11.dll`。重启后从 `/proc/<实际UU进程PID>/maps` 检查 `d3d11.dll` 路径；若仍指向 `/usr/lib/wine/`，本次连接没有用到修复模块。

安装和完整前缀备份/恢复步骤见 ../INSTALL.md。

## 可重复构建

需要 Linux x86_64、Bash、curl、tar、sha256sum、patch、make、GCC、flex、bison、MinGW-w64 交叉编译器及 Wine 构建依赖。运行环境应与 Wine 11.16 的内部接口兼容。其他 Wine 版本需要重新验证。

```sh
bash scripts/build-wine-d3d11.sh /tmp/uu-d3d11-build
```

目标目录必须不存在；脚本不会覆盖现有构建，不会安装 DLL、修改 prefix 或重启 Wine。它从 Wine 官方镜像下载固定 tag，并校验归档 SHA-256：

```text
2b6d5cff784cb774f7f17b9a640b123ca8361d89c4280c0021b70bb6f3cd1b1c
```

离线构建可设置 `WINE_SOURCE_ARCHIVE=/绝对路径/wine-11.16.tar.gz`，仍执行同一校验。可用 `JOBS` 限制并行度，用 `MINGW_CC` 指定交叉编译器。

产物位于 `output/`，只包括实验 `d3d11.dll` 和 `uu-d3d11-video-probe.exe`。源码与中间文件留在指定目录，构建日志为 `build/configure.log`、`build/build.log`。

Wine 自带的链接参数 `--wine-builtin` 会使 app-local DLL 不能按预期作为 native 覆盖加载。因此脚本在生成的 Makefile 中移除该标记，再构建 d3d11 目标；它没有构建或替换整个 Wine。

## 独立 prefix 红绿验证

下面的 prefix 路径必须专供实验，不能指向运行 UU 的 prefix。确保当前会话具备 X11 显示与 Vulkan 设备访问。将路径替换成实际构建路径后执行：

```sh
export WINEPREFIX=/tmp/uu-d3d11-probe-prefix
mkdir "$WINEPREFIX"
wineboot -u
wine reg add 'HKCU\Software\Wine\Direct3D' /v renderer /d vulkan /f
WINEDLLOVERRIDES='d3d11=b' wine /tmp/uu-d3d11-build/output/uu-d3d11-video-probe.exe
WINEDLLOVERRIDES='d3d11=n' wine /tmp/uu-d3d11-build/output/uu-d3d11-video-probe.exe
```

原版预期三个查询报告 `80004001`，最终退出码为 1。实验 DLL 的查询及非法参数检查通过时退出码为 0。无适配器、创建设备失败、缺失接口或 negative case 不符合预期都会使探针失败。它对每个枚举出的适配器执行检查，因此多显卡机器可能因其中一个设备不支持而失败。

探针动态输出 adapter index、LUID、vendor/device ID、显存和共享资源能力。不要复用另一台机器或上次会话的 LUID 来调用 UU 检测器。`ExtendedResourceSharing` 当前仅报告，不作为查询测试的成功条件；它是后续端到端验证的独立障碍。

探针不提交码流、不检查解码像素、不验证 UU 的画质菜单。实际硬解最终还需要真实码流、输出图像校验、GPU 视频引擎活动证据及 UU 高画质连接测试。禁止仅凭这个探针的退出码宣称高画质修复。

## 工具检查

```sh
bash -n scripts/build-wine-d3d11.sh
bash scripts/build-wine-d3d11.sh --help
x86_64-w64-mingw32-gcc -std=c11 -O2 -Wall -Wextra -Werror \
  tests/probes/uu_d3d11_video_probe.c -o /tmp/uu-d3d11-video-probe.exe \
  -ld3d11 -ldxgi -ldxguid -luuid
```

宿主 clangd 若没有 MinGW target 配置，会误报 `windows.h` 缺失；检查探针应使用上述交叉编译命令，而不是宿主 Linux 头文件集。

## 2026-09-07 复现记录

从校验过的源归档在全新目录运行构建脚本，构建、交叉编译与 Bash 语法检查均成功。`--help` 退出 0，传入已有目录退出 1 并拒绝覆盖。

在独立 prefix、Wine Staging 11.16、Vulkan renderer、RX 7800 XT 上，对同一个探针只切换 `WINEDLLOVERRIDES`：

| 检查 | 原版 `d3d11=b` | 实验 `d3d11=n` |
| --- | --- | --- |
| 三个视频查询 | `80004001` (`E_NOTIMPL`) | `00000000` (`S_OK`) |
| H.264 NV12 | 0 | 1 |
| 配置数量 | 0 | 2 |
| 不支持的输出格式 | `E_NOTIMPL` | `S_OK`，supported 为 0 |
| NULL profile / NULL desc / 越界配置索引 / 宽度 0 | `E_NOTIMPL` | `80070057` (`E_INVALIDARG`) |
| ExtendedResourceSharing | 0 | 0 |
| query_failures / 退出码 | 11 / 1 | 0 / 0 |

该记录只验证查询实现的红绿变化，没有运行 UU 连接或实际解码，也没有改动用户正在使用的 Wine 会话。Wine 会拒绝直接在不属于当前用户的 `/tmp` 下自动创建 prefix，所以示例先用 `mkdir` 创建用户拥有的目录。

随后运行完整检测器对照：只补查询时 `RESULT,1,1,8,0,0,0`；加非共享路径补丁后 `RESULT,1,1,8,3840,2160,1`。检测命令是 `StreamerCodecDetector.exe --batch 32 <device_id> <当前LUID>`；`32` 是此版本的 D3D11 解码实现编号，不能用编码实现编号 `0` 替代。

安装到主控前缀并确认加载正确 DLL 后，用户反馈「现在可以了」。这是画质切换的使用验证；不是所有格式、帧率和 GPU 的兼容性保证。H.265、HDR、10-bit、4:4:4 未验证，当前补丁只针对 H.264 8-bit NV12。
