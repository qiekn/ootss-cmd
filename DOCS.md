# 使用与开发

- [俯视相机、HUD 与大地图拍摄](docs/map-capture.md)
- [游戏内存布局与版本适配](docs/game-memory.md)
- [离线关卡格式](docs/custom_levels.md)

控制台内执行 `help` 查看命令；命令名称和相机选项不区分大小写。

`noclip` 模式下，W/S/A/D 每步移动一格；持续按住时默认间隔为 150 ms，按住左或右 Shift 加速至 2 倍（间隔 75 ms），松开后恢复原速。

`config.rc` 位于正在运行的 EXE 旁边，保存后自动重载，不需要重启。默认一直监听：空闲时只检查文件变更通知，不读取或解析配置；不监听子目录。连续保存会合并，并在两次读取内容一致后应用，通常约需 0.3 秒。支持编辑器通过临时文件重命名替换的保存方式。

配置必须整份有效才会替换旧设置。文件暂时缺失、被占用或解析失败时会短暂重试，最终失败则在控制台保留错误信息和行号（语法错误），继续使用上一份有效配置；修正并保存后会再次尝试。清空配置文件会恢复默认值。重载不会执行配置中的命令，也不会改变输入草稿、历史、临时 alias、当前字幕或编辑器进度。

别名、快捷键和 freecam 参数在重载后生效。快捷键旧队列会清空，已按下按键的释放仍按原来的拦截状态处理。`game_path` 更新后，后续字幕查询使用新目录，已加载字体会刷新；新目录缺少字体时控制台和已打开字幕保留原字体并记录提示。当前字幕文本保留到下一次查询。`show_startup_blow` 只影响下次启动，不会重新播放或关闭当前图片。

配置重载检查：`jai -quiet scripts/check_config_reload.jai -import_dir ../modules`。检查在 `.build/` 中使用独立配置文件，不改动个人配置或游戏状态。

HUD 可用 `hud_enabled` 控制总开关，`hud_show_level_name`、`hud_show_position`、`hud_show_notifications` 分别控制关卡名、坐标和通知。只保留关卡名时设置 `hud_show_position = false;`；每条 `hud_text = "custom text";` 新增一行自定义文字，可以重复写多条，`hud_text = "";` 保留一个空行。信息行直接按各项在文件中的先后顺序排列，把坐标配置移到关卡名配置上方即可先显示坐标。保存后生效，详细规则见 [HUD 配置](docs/map-capture.md#hud)。

引号中的 HUD 文字支持 `\n` 换行，例如 `hud_text = "First line\n\nSecond line";` 会在两段之间留一行空白。开头、结尾的换行会保留；`\\n` 显示字面上的 `\n`。

```powershell
jai -quiet first.jai -import_dir modules
jai -quiet first.jai -optimized -import_dir modules
```

普通构建输出到项目根目录；优化构建输出到 `bin/`，保留已有配置和玩家保存数据。运行中的旧程序需要退出后再启动新程序。

`speed 1.25` 设置游戏基础时间倍率，`speed 0` 暂停、`speed 1` 恢复正常。游戏前台且编辑器关闭时，`[` / `]` 按 `0.25、0.5、1、1.25、1.5、1.75、2、3、4` 切换；命令支持范围内任意倍率，例如 `speed 3.5`。原生快慢键仍会叠乘，细节见 [时间倍率](docs/map-capture.md#游戏时间倍率)。

大地图拍摄默认先在游戏按 Q，再手动运行 `./scripts/capture_map.jai`：从 `(80,69,80)` 向外拍摄，每张只保存中心 9 × 9 个世界格子，相机间隔 9 格，外围画面丢弃；`crop_world_size` 在脚本顶部配置。当前全图为 550 张，需要更新并重启助手后重新拍摄。拍摄中暂停模拟时间，结束或暂停后恢复之前的倍率。最终输出 `map/map.jpg`，默认质量 92、最大边长 32768；分块仍是无损 PNG。只想将已有截图按原计划重新导出为大图，可运行 `jai -quiet scripts/stitch_map.jai - map/capture-world --jpg map/map.jpg --max-side 32768 --quality 92`。
