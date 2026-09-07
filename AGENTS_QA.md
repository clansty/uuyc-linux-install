# QA 经验

- Wine helper 必须使用目标运行版本对应的 winegcc 编译，MinGW 编译的是服务控制器和视频探针。
- 验证 C 文件用实际 Wine/MinGW 编译器；宿主 LSP 缺少 Windows 头文件或拒绝工作区外路径，不等于源码不能编译。
- 临时 prefix 先用 mkdir 创建为当前用户所有；所有 wine、winetricks、wineserver 命令显式携带 WINEPREFIX。
- 检测器参数为 `--batch 32 <device_id> <当前LUID>`，LUID 必须在同一次 Wine 会话枚举；0 不是 D3D11 解码实现编号。
- Wine DLL 必须去掉 wine-builtin 链接标记，并从实际进程 maps 确认 app-local d3d11.dll 已加载。只看注册表不够。
- 注册表键用单引号固定部分与双引号变量拼接，避免反斜杠转义 `$app`。
- Query 成功、创建 4K decoder、真实画质切换属于不同验收阶段。2026-09-07 原环境用户确认画质可切换，未完成全格式和长期硬解验证。
- 残留窗口用 `_NET_WM_PID` 定位，不使用桌面转发进程 PID。主线程为 Z 时用 `ps -T` 检查其他线程，确认归属后仅终止旧进程。
- 软件退出后 systemd active 不能证明后台仍在运行；启动器需要同时检查同 prefix 的 GameViewerServer.exe。
- Desktop Entry 的反斜杠有字段解析和 Exec 参数解析两层，百分号还涉及 field code；用 gio launch 执行隔离测试入口，确认含空格、美元符号、引号、反斜杠、反引号和百分号的 prefix 原样到达子进程，不能只依赖 desktop-file-validate。
- 图形 target 的顺序不能保证 X11 可连接或 systemd manager 环境新鲜。桥接启动由每次桌面登录触发，先验证连接，再写服务专属 EnvironmentFile；当前已验证宿主检测的存在/不存在/显示错误三种状态，注销重登须用户安排。
