# 游戏更新后的兼容性检查提示词

在本项目打开助手后，发送：

> 按 `docs/game-update-prompt.md` 检查并修复本次游戏更新兼容性。

也可以复制以下完整提示词：

```text
游戏 Order of the Sinking Star 更新了。请检查并修复 ootss-cmd 与当前游戏版本的兼容性。

先读 AGENTS.md 和 docs/game-memory.md，保留我的 config.rc、存档、截图及其他未提交修改。不要自动提交，也不要覆盖用户维护的 README。

1. 确认实际运行的 sinking_star.exe 路径、PID、EXE 的 SHA-256 和 PE 信息；确认正在运行的助手是否为最新编译产物，区分旧助手、游戏更新、场景不合适和真正的 layout 不兼容。
2. 先运行 jai -quiet scripts/inspect_game_layout.jai -import_dir ../modules、jai -quiet scripts/inspect_speed.jai -import_dir ../modules 的只读诊断，以及 jai -quiet scripts/check_game_layout.jai -import_dir ../modules - "实际游戏 EXE 路径" 的离线检查。分别检查当前场景、玩家受控集合与位置读写字段、相机模式/姿态/投影、探索迷雾开关、基础/原生时间倍率及 dt/累计时钟数据流。记录每项通过或失败的具体原因，不能以 show position 正常推断其他功能正常。不要把没有错误文字直接当成所有游戏内操作均验证通过。
3. 如果失败，比较现有版本证据与新 EXE 的代码和 Jai 反射元数据。按名称发现类型和字段，从指令计算相对地址及字段偏移，交叉验证调用、分支与上传参数。保留旧版本支持；拒绝缺失、歧义、越界或不一致的证据。不要只平移旧地址，不要放宽校验来让未知布局通过。
4. 完成必要修复。所有辅助脚本及回归检查使用 Jai，放在 scripts/。补充真正受影响的正常、截断、歧义、字段冲突和恢复失败检查；相机/迷雾/时间改动需运行 check_game_layout.jai、check_camera_capture.jai、check_centered_capture.jai、check_fog.jai、check_speed.jai（都加 -import_dir ../modules）。按项目 first.jai 入口编译，并验证有关的普通/优化构建。运行中的 EXE 无法覆盖时，不要结束它，说明需要手动重启。
5. 更新 docs/game-memory.md 中的版本指纹、布局证据和诊断用法。若新增检查入口，也同步更新这份提示词，避免下次使用过时命令。
6. 最后简要报告：本次版本、哪些功能正常、修复了什么、哪些检查通过，以及需要我手动执行的命令。

限制：你可以只读检查进程和磁盘、修改项目代码、运行仅操作测试内存的检查以及编译。不要自动写游戏内存、设置 speed、切换 fog/unfog、开启 freecam/noclip、按 Q 切换视图、移动玩家、开始拍摄、修改存档或重启/关闭游戏与助手。不要查看截图。实际画面和游戏内写操作由我手动验证；需要我提供错误文字或测试结果时再询问。

不要承诺一次修复能兼容未来所有版本。对仍无法验证的功能保留禁用和明确错误，并说明下一步需要什么证据。
```
