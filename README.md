# UU Remote Controller for Wine

Linux 桌面上的网易 UU 远程主控安装资料与兼容工具。

把 [INSTALL.md](INSTALL.md) 交给安装 agent，从仓库定位、依赖检查开始，按阶段安装和验收。

默认流程包含 H.264 高画质补丁，不按显卡型号决定是否安装。验证基线为 UU 4.39.2.1561、Wine Staging 11.16、CachyOS x86_64、AMD RX 7800 XT、X11 显示后端；这是测试记录，不是显卡白名单。修复仍有实验性风险，其他环境需要实际验证，失败时由 agent 继续诊断可用解码路径。

源码来源与许可见 [THIRD_PARTY.md](THIRD_PARTY.md)。安装包和运行产物不提交到 Git。
