# 使用与开发

- [俯视相机、HUD 与大地图拍摄](docs/map-capture.md)
- [游戏内存布局与版本适配](docs/game-memory.md)
- [离线关卡格式](docs/custom_levels.md)
- [自动提取关卡名、区域和入口坐标](docs/level-catalog.md)

控制台内执行 `help` 查看命令；命令名称和相机选项不区分大小写。

关卡解法使用 `data/solutions.json`，自定义输入使用 `data/custom_inputs.json`，两者都是 JSON 数组，每条只保存 `name`、`note`、`solution`：

```json
[
  {"name": "mirror_1", "note": "", "solution": "R2XL4XL6U"},
  {"name": "my_route", "note": "中间等待 3.5 秒", "solution": "R2_3.5_U"}
]
```

`play` / `do`、Tab 补全和编辑器只读写这两个 JSON 文件，不读取或回退到 TXT。名称不区分大小写，重复名称或无效 JSON 会报错；允许空解法。编辑器保存保留其他记录及最新的 `note`，外部改动仍需覆盖确认。入口位置和区域由 `data/level-catalog.json` 提供，不写入解法。旧 JSON 的 `position`、`area` 在读取时忽略，下次保存时移除。

等待写作 `_秒数_`，例如 `_3.5_`；在编辑器按 B 或 `_` 插入默认 0.25 秒，游戏录制时按 B 也可插入。普通和迷你时间线都显示纯数值时长（如 `0.25`），双击可修改，Enter 应用、Esc 取消。执行等待时，格子按实际经过的时间从右向左越过固定播放线，走完一格才完成等待。时长精确到毫秒，普通、兔速和拖动播放均保留指定时长。旧 `_` 每个按 0.25 秒处理，`____` 可合并为 `_1_`；`scripts/merge_solution_waits.jai` 可批量合并两个 JSON 中相邻的等待，保留其他按键及 `note`。

兔子按钮再次点击会暂停。兔速只对这次播放生效，暂停或播放结束后，普通 Play 恢复之前选择的速度。

`switch <level_name>` 使用 `data/level-catalog.json` 中的完整 XYZ 传送到关卡入口，再触发 TakeOrDrop（默认 V）。仅在大世界生效，小关卡内会拒绝执行；支持关卡名称 Tab 补全。目录由 `scripts/generate_level_catalog.jai` 从游戏 `levels.package` 生成，详见上面的入口数据文档。

`noclip` 模式下，W/S/A/D 每步移动一格；持续按住时默认间隔为 150 ms，按住左或右 Shift 加速至 2 倍（间隔 75 ms），松开后恢复原速。

方向按当前相机视角换算为最近的网格轴。`move -view 0 1` 向屏幕上方移动一格，`move -view 1 0` 向右移动一格；原有 `move -x/-y/-z` 和数值参数继续表示世界坐标。

开启 freecam 并调好相机后用 `lock` 固定视角并将移动键交还玩家，`unlock` 恢复自由相机操作；两条命令仅在 freecam 已开启时生效。`freecam disable` 恢复游戏跟随。`freecam -topdown` 会同时居中到受控角色头顶，再次执行可重新居中。

`subtitle_font_size = 30;` 控制中英文字幕对白字号，按「游戏窗口客户区高度 / 配置值」计算，取整且最小为 1 像素。例如游戏高度为 1080 时，30 对应 36 像素，20 对应 54 像素。数值范围为 1–1000，越小字越大；省略时默认 30。说话人和注释按比例使用较小字号。保存配置或调整游戏窗口高度后自动更新字号、换行和滚动范围；切换控制台大小只改变可见区域和布局，不改变字号。

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

游戏中按 `P` 立即显示 `Jotaro Kujo: “Star Platinum: The World!”` 并播放时停音效，播完后暂停，再单独显示 `Speed 0x`；再按 `P` 立即显示 `Jotaro Kujo: “And time resumes.”` 并播放配对恢复音效，保持暂停直到音效结束，再恢复原倍率并单独显示 `Speed <原倍率>x`。每次开始有 1/3 概率使用 alt 音效。连续按键会先停止旧音轨，再播放新音轨；停止音效期间再按 P 会取消即将发生的暂停，恢复音效期间再按 P 会取消本次恢复并保留最初的倍率。离开游戏取消尚未完成的时停，退出助手恢复其控制的速度。自定义 P 映射优先。

时停配置放在正在运行的 EXE 旁的 `config.rc`，支持热重载：

```ini
time_stop_alt_probability = 0.3333333333333333;
time_stop_no_audio = false;
```

`time_stop_alt_probability` 范围为 0～1，默认 1/3；0 始终使用普通版本，1 始终使用 alt。更改概率只影响下次选音，当前停止/恢复仍保持配对。`time_stop_no_audio = true;` 禁用音频和台词，按 P 立即暂停、再次按下立即恢复，只显示 `Speed 0x` / `Speed <原倍率>x`。播放期间启用此选项会停止音频并立即完成当前暂停或恢复。删除配置项恢复默认值；无效概率或布尔值会使整份新配置被拒绝，保留旧设置。

编辑器默认播放 `1x`，正向鼠标拖动/滚轮使用 Rabbit `4x`，`jump` 保留 `16x`。`jump` 等待提交键释放和焦点交接后执行：向前继续播放，向后重置再重放。Z 删除撤销的步骤；录制时 Shift+R 添加显示为 R、保存为 `!` 的重置动作。录制时 T 设置两次动作之间的游戏时间计时器，自动插入等待并计入快慢速变化，详见[编辑器操作](docs/document.md#编辑器操作)。

`hud_hide_on_focus_loss` 只控制左上角信息，失焦不会隐藏通知；控制台打开、截图及 HUD 总开关仍按原规则隐藏两处面板。

`speed 1.25` 设置游戏基础时间倍率，`speed 0` 暂停、`speed 1` 恢复正常。游戏前台且编辑器关闭时，`[` / `]` 按 `0.25、0.5、1、1.25、1.5、1.75、2、3、4` 切换；命令支持范围内任意倍率，例如 `speed 3.5`。原生快慢键仍会叠乘，细节见 [时间倍率](docs/map-capture.md#游戏时间倍率)。

大地图拍摄默认先在游戏按 Q，再手动运行 `./scripts/capture_map.jai`：从 `(80,69,80)` 向外拍摄，每张只保存中心 9 × 9 个世界格子，相机间隔 9 格，外围画面丢弃；`crop_world_size` 在脚本顶部配置。当前全图为 550 张，需要更新并重启助手后重新拍摄。拍摄中暂停模拟时间，结束或暂停后恢复之前的倍率。最终输出 `map/map.jpg`，默认质量 92、最大边长 32768；分块仍是无损 PNG。只想将已有截图按原计划重新导出为大图，可运行 `jai -quiet scripts/stitch_map.jai - map/capture-world --jpg map/map.jpg --max-side 32768 --quality 92`。

代码风格检查使用 `jai -quiet scripts/format_style.jai`，添加 `- --write` 可应用成组声明/赋值对齐和 main 公共依赖的去重。范围为 `first.jai`、`src/`、`scripts/`；独立模块保留自己的依赖，第三方模块不参与。
