# Order of the Sinking Star Trainer

使用 Jai 和项目内的 `modules/Simp` 实现的 Windows 下拉终端。
窗口无边框、半透明，覆盖游戏画面顶部的 70%，并跟随游戏窗口移动和调整尺寸。
配色参考 naysayer.nvim，正文、提示和编辑器图标使用 `data/fonts/Meslo-LG-Mono-Nerd-Regular.ttf`。
console 输出中 Meslo 缺少的中文字形使用 `data/fonts/NotoSansCJKsc-Regular.otf`，包括 `LICENSE` 中的“啥是比鸭”。双栏字幕的中文正文另用 `SourceHanSerifCN-SemiBold.otf`。
终端没有顶栏，输入行和命令回显统一使用 `$` 提示符。
启动画面循环播放 `data/images/blow-wave.gif`。三种 blow 效果共用这张 GIF，在输入栏上方居中，上下至少留出 24 个 DPI 缩放后的像素，选择可容纳的最大整数倍显示（如 320×240、640×480、960×720）。
图片内部底部居中显示 `Powered by blowave`。窗口连原尺寸也容纳不下时，在留白区域内裁切，不覆盖输入行。GIF 区域完全不透明，以 60% 图片颜色预先混合终端背景色；周围终端保持半透明。
提交第一条非空命令或执行 `clear` / `cl` 后收起 GIF，调整尺寸的 `toggle` 命令除外。空回车以及隐藏、重新打开终端不会清除这一状态。

双击 `ootss-cmd.exe` 即可启动程序，不会弹出 cmd 窗口。
右下角系统托盘会显示程序图标（来自 `data/images/icon.png`）：

- 单击图标显示终端。
- 右键图标可选择“显示终端”“隐藏终端”或“退出”，无需输入命令即可关闭程序。
- 图标可能收在托盘的 `^` 展开区域中。退出时会移除图标；资源管理器重启后会恢复图标。

发送脚本时打开托盘菜单，会先停止发送并松开当前按键。

普通构建在项目根目录生成 Windows GUI 程序 `ootss-cmd.exe`：

```powershell
jai first.jai
```

优化构建会生成 `bin/ootss-cmd.exe`，并将整个 `data/` 复制到 `bin/data/`，将 `LICENSE` 复制到 `bin/LICENSE`：

```powershell
jai first.jai -optimized
```

`-optimized` 可以简写为 `-o`。给其他人使用时，将整个 `bin/` 目录打包即可。程序和托盘图标在构建时内嵌；`about` 使用 `data/images/icon.png`，三种 `blow` 效果都使用 `data/images/blow-wave.gif`。

退出时，右键托盘图标选择“退出”，或在 overlay 中输入 `exit` / `terminate`。

程序按 `sinking_star.exe` 和 `Default Window Class` 查找游戏，优先匹配标题
`Order of the Sinking Star`，不会固定 PID 或窗口句柄。游戏未启动时，程序在托盘等待，不显示终端。
每 0.5 秒检查一次游戏窗口，发现游戏启动后自动显示终端，游戏关闭后自动隐藏。
建议使用无边框全屏或窗口模式；独占全屏通常无法显示独立的覆盖窗口。

| 按键 | 操作 |
| --- | --- |
| 反引号（Esc 下方的键） | 在游戏或终端中显示 / 收起终端 |
| `:`（Shift + `;`） | 在游戏中唤出终端 |
| `;` | 在游戏左下角打开 quick command 输入框 |
| Esc | 收起终端，把焦点还给游戏 |
| Ctrl + C / Ctrl + D | 隐藏终端，把焦点还给游戏 |
| Enter | 执行当前命令 |
| ↑ / ↓ | 查看命令历史，回到末尾可恢复未提交的输入 |
| ← / →、Home / End | 移动输入光标 |
| Backspace / Delete | 删除光标前 / 后的字符 |
| Ctrl + W / Ctrl + Delete | 删除光标前 / 后一个单词（以空白分隔） |
| Ctrl + U | 清除光标前的内容，保留光标后的内容 |
| Ctrl + V / Shift + Insert | 从剪贴板粘贴到光标处 |
| 鼠标滚轮、Page Up / Page Down | 浏览输出记录 |
| Ctrl + Q、Alt + F4 | 退出辅助程序 |

Alt-Tab 或点击其他窗口时，终端自动隐藏，保留输入和历史记录，并让新窗口保持焦点。普通反引号热键只在游戏或终端获得焦点时注册。
冒号热键在游戏处于前台时唤出终端或将焦点移回已显示的终端；在终端中仍可正常输入冒号。
`;` 打开左下角的小输入框，共用终端的命令、输入草稿、历史、Tab 补全和编辑快捷键。输入框不显示输出区域或 GIF。
执行 `help`、`license`、`about`、`blow`、字幕等需要显示内容的命令时，会展开终端；发送操作仍会收起输入框并交回游戏焦点。

用 `toggle` 切换终端尺寸，参数不区分大小写，切换保留历史、输出及当前图片或字幕：

| 命令 | 尺寸与位置 |
| --- | --- |
| `toggle full` | 铺满游戏窗口的客户区 |
| `toggle small` | 从顶部展开，高度为游戏窗口的 30% |
| `toggle normal` | 从顶部展开，高度为游戏窗口的 70%（默认） |
| `toggle mini` | 左下角 quick command 输入框 |

`:` 和 mini 中的输出展开会使用上一次选择的非 mini 尺寸；`;` 始终打开 mini。

命令名不区分大小写，例如 `send`、`SEND`、`SeNd` 等效；参数和历史记录保留原始大小写。
输入 `clear` 或缩写 `cl` 可清空全部输出和滚动记录，保留命令历史；大写写法也有效。
无参数 `blow` 每次清屏并从头播放下一种效果，顺序为 alien → mirror → wave → alien；启动画面不占用次数，第一次输入 `blow` 播放 alien。
`blow alien`、`blow mirror`、`blow wave` 可直接指定动画，名称不区分大小写，也不推进无参数轮播的次序。
`alien` 保留 wave 的左半边并镜像到右边；`mirror` 保留右半边并镜像到左边；`wave` 显示原图。三种效果共用原始帧和播放节奏，无需额外的 alien、mirror GIF。
两种镜像效果在中心两侧各 4 个原图像素内平滑融合，减弱拼接线；其余区域保持原有清晰度。
`about` 显示图标、作者 `qiekn` 和仓库地址 `https://github.com/qiekn/ootss-cmd`。
`license` 读取程序目录下的 `LICENSE`，保留原文、缩进和空行；图标和文字输出均可滚动查看。输入 `help` 查看全部命令。
`q`、`quit` 隐藏终端并返回游戏；`exit`、`terminate` 关闭辅助程序。
粘贴支持中文和 emoji；换行、制表符转为空格，粘贴后按 Enter 执行。
输入上限为 1024 字节，超限粘贴会整体拒绝，避免执行被截断的脚本。

输入 `send` 加操作串即可控制游戏，不需要引号：

```text
send wwww
send 1 ww 2 dd z r
```

提交后会等待 Enter 和修饰键松开，确认游戏窗口完成激活后收起终端，再依次发送按键。
支持字母和数字，忽略空白；默认每个键的完整周期为 250 ms（按住 50 ms、松开后等待 200 ms）。
发送结束后保持游戏在前台，重新打开终端可看到 `Sent 4 keys.` 等结果。
发送期间玩家在游戏中按键、点击鼠标或滚动滚轮，会打断剩余操作，玩家输入仍会交给游戏。
程序注入的按键不会触发打断。切换到其他窗口或用热键唤回终端也会中止发送，并释放指令键和程序按住的时间修饰键。
无参数、非法字符、找不到游戏或无法激活游戏时会报错，不发送按键。

`send` 和 `send_alt` 都支持 `-delay 10` 或 `-delay 10ms`，参数可放在操作串前后：

```text
send_alt -delay 10ms R3U2C
send_alt R3U2C -delay 10
send -delay 20 w3 2 d
```

`-delay` 指每次按键的完整周期（按住时间 + 松开后的等待），单位为毫秒，必须为正整数。
例如 `-delay 10` 按住 5ms、松开后等待 5ms，理论上约每秒 100 次。
按下时长最多 50ms；短周期按对半分配，并以整数毫秒计时。例如 75ms 为按住 37ms、松开等待 38ms，175ms 为 50ms + 125ms。
`send` 和 `send_alt` 支持以下速度参数，放在操作串前后均可，参数不区分大小写：

| 参数 | 每键周期 | 游戏时间控制 |
| --- | --- | --- |
| 默认 | 250 ms | 无 |
| `-fast` | 175 ms | 无 |
| `-superfast` / `-rabbit` | 75 ms | 按住 `HoldForFastTime`（默认 Space） |
| `-slow` | 500 ms | 无 |
| `-superslow` / `-turtle` | 750 ms | 按住 `HoldForSlowTime`（默认 Control） |

加速和减速键从当前用户的 `Saved Games/Order of the Sinking Star/User.keymap` 的 `[UserKeyboard]` 读取。
每次只能选择一个速度参数；显式 `-delay` 优先于预设周期，并保留所选模式的加速或减速。例如：

```text
send_alt R3U2C -rabbit
send w3 -fast
send_alt -turtle R3U2C
send_alt R3U2C -superfast -delay 100
```

请用 `-superfast` 或别名 `-rabbit` 自动按住加速键；发送过程中手动按空格也会触发打断。
这些参数只控制独立发送，不改变 solution 编辑器的录制与播放。实际速度受系统调度和游戏输入采样影响，漏步时增大 `-delay`。

`play <level_name>` 按名称读取 `data/solutions.json` 中已经保存的解法，直接按 `send_alt` 执行：

```text
play mirror_1
play mirror_1 -fast
play -rabbit mirror_1 -delay 100ms
play -slow mirror_1
```

关卡名不区分大小写，Tab 可补全已保存的名称和速度选项。支持上面所有速度参数、别名和 `-delay`，可放在名称前后。
此命令从游戏的当前位置开始发送，不重置关卡、不打开编辑器；请先在游戏中进入对应关卡并准备好起点。
找不到名称、解法为空或无效时不发送按键。玩家输入和焦点切换同样会打断播放。

`undo` 和 `z` 用于撤销，省略次数时撤销一次。`undo 100`、`z 100`、`z100` 都发送 100 次 Z 键。
撤销命令默认使用 10ms 周期，加上 `-fast` 时默认为 1ms；也可用 `-delay 20` 或 `-delay 20ms` 指定周期。
参数可放在次数前后，同时指定 `-fast` 和 `-delay` 时以 `-delay` 为准。次数必须为正整数，最多 65536 次。

```text
undo
undo 100
z100
z100 -fast
undo -fast 100
undo 100 -fast -delay 20ms
```

`reset` 和 `r` 都发送一次 R 键来重置游戏，使用 75ms 周期。编辑器开启时也可以执行；
R 键成功发送后，时间线退回起点，保留整段解法作为未来指令。

`send` 按字母对应的键发送，例如 `wasd` 控制移动，`R` 发送 R 键。
`send_alt` 使用 UDLR 方向：`U/D/L/R` 分别发送 `W/S/A/D`，`C` 直接发送 C 键，其他字母也发送对应键。
两个命令都不区分字母大小写，并使用相同的重复规则。

紧跟字母的数字表示该字母的总重复次数：`w3` 等于 `www`，`R4` 等于 `RRRR`，支持多位数。
小括号可以重复整段：`send (ad)3` 等于 `send adadad`，也支持 `(w2d)3` 和 `((ad)2w)3` 等嵌套写法。
次数必须紧跟右括号；`send (ad) 3` 发送 `ad3`，其中 `3` 是角色切换键。组内同样可以用空格分隔数字键。
`_` 表示空白等待，持续一个当前速度周期，不发送游戏按键；`_3` 等待三个周期，也可放在重复组内。
用空白把数字和字母分开时，数字就是角色切换按键：`www 3 www` 发送 `www3www`。
输入开头、结尾也视为边界，因此 `send 3`、`send 0` 可以直接切换角色。
省略次数表示一次；次数必须为正数，展开后的上限为 65536 次按键。

| 命令 | 实际按键序列 |
| --- | --- |
| `send w3` | `www` |
| `send (ad)3` | `adadad` |
| `send (w 3 d)2` | `w3dw3d` |
| `send_alt (UR)2` | `wdwd` |
| `send R3` | `rrr` |
| `send_alt R3` | `ddd`（向右三次） |
| `send www 3 www` | `www3www` |
| `send_alt R3 2 U2 C` | `ddd2wwc` |

原有的 `send --udlr` 写法也可使用，等同于 `send_alt`。

下面两行等效，都会发送 78 次按键：

```text
send_alt UR4DLUL2RDLUCUCU3D2CDUC2U3R7L7DC2U3L7CD2CDUCR3CU3R3CLUL
send_alt URRRRDLULLRDLUCUCUUUDDCDUCCUUURRRRRRRLLLLLLLDCCUUULLLLLLLCDDCDUCRRRCUUURRRCLUL
```

首次打开终端直接显示 `help` 的内容，与手动输入 `help` 共用同一个 procedure。
格式参考 `jai -help`：左侧命令或参数，右侧对齐说明，示例缩进到下一行。
包含命令、别名、速度参数、重复语法和常用快捷键；从帮助开头显示，可用滚轮或 Page Up / Page Down 浏览。

`ls`、`echo`、`print` 仍只执行各自的占位 procedure：

```text
$ ls
ls command is here.
$ echo
echo command is here.
$ print
print command is here.
```

另外支持 `xyzzy` 和 `hello sailor`（直接输入，不需要引号）：

```text
$ xyzzy
Nothing happens here.
$ HELLO SAILOR
Nothing happens here.
```

上述占位命令可以带参数，现阶段会忽略参数。空输入不执行，未知命令会显示错误。
最多保留 256 行输出和 64 条命令历史。

`src/ui/console.jai` 包含命令表；`src/game/commands.jai` 负责向游戏发送操作；
`src/platform/windows/clipboard.jai` 负责读取 Windows 剪贴板；
`src/platform/windows/console.jai` 连接已有的启动终端并处理 Ctrl+C / Ctrl+Break 信号；
`src/platform/windows/send_monitor.jai` 在独立发送期间监听玩家输入以便打断；
`src/platform/windows/tray.jai` 负责托盘图标和显示、隐藏、退出菜单；
`src/ui/console_view.jai` 负责 Simp 绘制；
`src/ui/console_theme.jai` 保存 naysayer 配色；
`src/platform/windows/overlay.jai` 负责窗口、热键和透明度；`src/game/state.jai` 定义游戏识别规则，调用平台的进程窗口查找。
在该文件中调整 `OVERLAY_HEIGHT_PERCENT` 和 `OVERLAY_OPACITY` 可修改高度比例和不透明度。

Jai 代码中的 `send("w3 2 d")` 和 `send_alt("R3 2 U")` 接口位于 `src/platform/windows/input.jai`，使用相同的解析规则。
通过 `hold_ms`、`interval_ms` 可调整速度；终端使用同文件的 `send_sequence` 发送已经展开的按键序列。

使用字幕浏览：

```text
show subtitles
show subtitles mirror_6
show subtitles mirror_6 -comment
show subtitles -comment mirror_6
show subtitles mirror_6 -en
show subtitles mirror_6 -cn
show subtitles -sc mirror_6 -no_character -comment
```

`show subtitles` 按当前游戏坐标查找关卡名；当前坐标地址仍待确认，无法识别时会提示使用 `show subtitles <level_name>`。
指定名称的查询不读取坐标，命令、名称和选项均不区分大小写，选项可放在关卡名前或后。
程序优先从正在运行的游戏安装目录读取 `data/strings/subtitles/en.subtitles` 和 `s-cn.subtitles`（简体中文）。
也接受中文文件名 `ch.subtitles` / `ch-subtitles`。找不到运行目录时，会查找程序旁的 `data/strings/subtitles/`，以及 `subtitles.md` 指定的 E 盘 Demo 安装目录。
字幕直接从安装文件读取，无需复制游戏文本到项目或修改游戏文件。

查询成功后清空终端输出，左栏显示英文，右栏显示对应的中文，包括关卡的 `_start`、`_mid`、`_end` 等段落。
添加 `-en` 时只显示英文，并在整个输出区域内居中；`-cn` 和 `-sc` 效果相同，只显示居中的简体中文。
双语和单语言的字幕区域都在窗口中央，占窗口宽度的 70%；双语两栏共同使用这一区域。
字号随实际窗口宽度缩放，1920 像素宽时正文约为 48 像素，角色名和注释保持较小字号。窗口大小变化时自动更新字体、间距、换行和滚动范围。
单语言模式只读取所选语言的字幕文件；不加语言选项时恢复双栏。英文和中文选项不能同时使用。
保留原有换行，长句和注释自动折行。两栏按对白块对齐；翻译将同一角色的对白拆成不同数量的字幕时，按该角色的整段讲话对齐。
某一语言缺少段落时会显示提示，不会把后续角色的对白错配过去。时间戳和 `= _` 清除字幕标记不显示。
默认隐藏 `++` 注释，添加 `-comment` 时以黄色显示。
添加 `-no_character` 或等效别名 `-nosayer` 隐藏说话者名称及其占用的行，可与语言选项和 `-comment` 一起使用。

英文正文使用 `data/fonts/Karmina-Bold.otf`，中文正文使用 `data/fonts/SourceHanSerifCN-SemiBold.otf`。中英正文均使用白色 `#ffffff`，不显示顶部关卡名以及“English”和“简体中文”栏标题。
角色名和注释使用较小的 Meslo，缺少的中文字形使用同字号的思源宋体。
所有角色名统一使用 trader 的墨绿色 `#398e82`，可在 `src/ui/console_theme.jai` 的 `SUBTITLE_SPEAKER_COLOR` 中调整。

鼠标滚轮、Page Up / Page Down 可浏览全部字幕，Ctrl+Home / Ctrl+End 跳到开头或末尾；字幕不受普通输出的 256 行限制。
字幕滚动条贴在窗口最右边。
输入行始终保留。`clear` / `cl` 清除字幕；执行产生普通输出的命令后返回普通终端输出。
按 Tab 补全命令、`show` 子命令和关卡名，也支持 `edit` 的关卡、自定义名称与 `blow` 的动画名。
有多个候选时先扩展共同前缀，再按 Tab 向后循环，Shift+Tab 向前循环；补全只替换光标所在的词，保留后面的参数。

使用解法编辑器：

```text
edit mirror_21
open editor
edit custom my_test
```

`edit <level_name>` 按关卡名加载 `data/solutions.json` 中的解法，并打开编辑器，例如 `edit mirror_21`。
命令与关卡名不区分大小写；该方式不读取游戏坐标，`show position` 的地址不可用时也能打开。
先在游戏中进入所选关卡并回到解法起点。保存时更新所选关卡的解法；名字不存在会报错并保留当前编辑会话。

`open editor` 打开一个空白临时编辑器，不读取坐标、不绑定关卡。录制、播放和修改方式与普通解法相同。
点击 Save 或按 Ctrl+S 后，输入自定义名称，再点击 Save 或按 Enter 确认。名称支持字母、数字、中文等 Unicode 字符、`_`、`-` 和 `.`，不含空格；`temp`、`solution` 是保留名称。
名称按 UTF-8 保存；当前 Meslo 字体缺少部分中文和 emoji 字形，使用 `my_test` 这样的名称可完整显示。
临时内容单独保存在 `data/custom_inputs.json`，沿用解法的 JSON 数组格式，每条记录包含 `position: [0, 0, 0]`、`area: "none"`、`name`、`note` 和 `solution`。
这些记录按名称区分，不会因为坐标相同而互相覆盖，也不会从 marker 或 solutions.txt 导入关卡。
保存后可用 `edit custom my_test` 重新打开；`edit my_test` 在没有同名关卡时也会查找自定义输入。

普通解法和自定义输入保存前都会显示确认界面。自定义名称已存在，或存档在编辑期间被其他程序修改时，会额外要求明确确认 Overwrite；取消不会写文件。
保存页的标题、名称、占位提示和按钮统一使用随 DPI 缩放的 13px 字号，输入光标按同一字体对齐。
输入 `close editor` 或点击 Exit 可以关闭编辑器。关闭编辑器、切换关卡、退出程序时，如果有未保存修改，会提供 Save / Discard / Cancel：保存后继续原操作、放弃修改，或取消操作并继续编辑。
保存失败会保留编辑内容和确认界面，供修改名称或重试；游戏已经关闭时，退出确认仍可操作。

编辑器打开后，可以在终端使用以下命令；未打开编辑器时会报错，四个命令都不接受额外参数：

| 命令 | 行为 |
| --- | --- |
| `record` | 开始录制并将输入焦点交给游戏；重复执行仍保持录制 |
| `pause` | 暂停播放，保留录制开关和当前位置 |
| `stop` | 停止播放和录制，保留当前位置及全部指令 |
| `save` | 打开现有保存确认界面，确认后才写入文件 |

原有的按位置打开方式仍保留：

```text
show position
edit solution
```

`show position` 只读查询游戏中的三个 float 坐标，例如 `(80, 79, 0)`。
按 Cheat Engine 的指针链读取 `*(sinking_star.exe + 0x009AF218)`，再读取偏移 `0/4/8`；游戏未启动、仍在加载或指针不可读时输出错误。
当前地址仍待确认，可先使用按关卡名打开的方式。
`edit solution` 根据当前位置加载解法，在游戏画面底部居中打开半透明编辑器。当前任意可读位置都允许打开：
关卡准入检查保留在 `editor_position_allowed` 的 `// @TODO` 中。没有 marker 的位置保存为 `custom`，以坐标命名。

竖直播放线固定在中间，左侧是已经发送到游戏的指令，右侧是未来指令。打开一个新会话时播放位置为 0；
播放已有答案前，请将游戏放在该答案的起点。重新打开同一个编辑会话会保留播放位置。
拖动时指令条平滑跟随鼠标，光标变为手形，松开或取消拖动后恢复；跨过完整格子才请求执行或撤销。
滚轮连续累积移动距离，包括触控板和高精度滚轮的部分刻度；播放未追上时继续滚动也不会丢失之前的目标。
时间线用箭头显示 U/D/L/R，C 显示为 `nf-md-swap_horizontal_variant`，X 显示为 `nf-md-function`；输入、执行和保存仍使用原来的指令字母。
空白等待格使用 `nf-md-sleep` 图标，在编辑器中输入 `b` 或 `_` 插入，保存和导出统一使用 `_`。
底部按钮使用 Nerd Font 图标，鼠标悬停时显示操作名称，录制和播放按钮会随状态切换图标。
点击 `nf-fa-minimize` 图标可收起为底部居中的简洁时间线，实时预览录制结果、当前位置和总步数；点击 `nf-fa-edit` 图标恢复编辑器。
收起和恢复保留播放位置、录制开关和未保存修改，不会暂停正在播放的序列。收起后输入焦点回到游戏。
精简版保留完整时间线交互：拖动、滚轮、Ctrl+滚轮缩放、点击未来格子后输入和粘贴、选择与删除均可使用。只有未来指令可编辑。
精简版左侧的录制按钮可点击切换开始 / 停止录制；右侧的 Edit 按钮恢复完整界面。
按 `N` 也可在精简版和完整版之间切换，编辑器或游戏获得焦点时都可用；长按不会反复切换，保存命名时仍可正常输入 N。

| 操作 | 效果 |
| --- | --- |
| 向右拖动指令条 / 向上滚轮 | 以 10 ms 周期快速回退；可撤销动作发送 Z，C、数字键和等待格只回退时间线 |
| 向左拖动指令条 / 向下滚轮 | 每跨过一个格子执行一条未来指令 |
| Record / Stop Recording | 开始 / 停止录制游戏窗口中的键盘输入 |
| Undo / `[` | 撤销一步，250 ms 周期 |
| Step / `]` / `j` | 执行一步，250 ms 周期；`j` 支持长按连续前进 |
| `l` | 撤销一步，125 ms 周期；支持长按连续撤销 |
| Play / Pause | 播放 / 暂停 |
| Space / `k` | 切换播放 / 暂停；优先于游戏中的加速或减速键绑定 |
| 游戏加速键 / 减速键 | 播放中切换为 `-fast` / `-turtle`，从 User.keymap 读取 |
| 点击未来格子 | 将文本光标放在此处，开始编辑 |
| W/S/A/D 或 ↑/↓/←/→ | 插入上 / 下 / 左 / 右移动指令 |
| B / `_` | 插入一个空白等待格 |
| Ctrl+左右方向键、Home / End | 移动文本光标；再按住 Shift 可选择未来指令 |
| Backspace / Delete、Ctrl+A | 删除文本 / 选择全部未来指令 |
| Ctrl+V / Shift+Insert | 按 UDLR 格式粘贴解法，支持 `R4X2` 等重复缩写 |
| Ctrl+C | 复制当前完整解法，编辑器或游戏获得焦点时都可使用 |
| Ctrl+滚轮 | 调整格子宽度 |
| Save / Ctrl+S | 打开保存确认；临时编辑器可输入自定义名称 |
| Reset | 重置游戏并恢复上一次保存的解法，播放位置回到 0，丢弃未保存修改 |
| Rabbit（`nf-md-rabbit`） | 重置游戏，从头测试当前完整解法；每步 75ms，并按住配置中的加速键 |
| Export（`nf-fa-clipboard`） | 将当前完整解法复制到系统剪贴板，使用 UDLR 文本格式 |
| N / Minimize / Edit | 切换精简版 / 完整编辑器，保留时间线操作能力 |
| Exit / `close editor` | 关闭编辑器；有修改时先确认保存 / 放弃 / 取消 |
| Esc | 暂停播放，返回游戏输入 |

文本光标与播放线相互独立，只能修改未来指令；已经执行的部分必须先撤销才能修改。
手动编辑不再直接输入 U/D/L/R：D 表示向右，向下用 S 或 ↓，C/X/F/V 和数字键仍可输入对应动作。
存档和粘贴解法继续使用 UDLR 格式，键盘编辑会自动转换为对应指令。
C 和数字键只切换角色，不进入游戏的撤销记录，等待格也不增加撤销记录。Undo 按钮、`[` 和拖动回退经过这些格子时，不发送 Z；
玩家在游戏中直接按 Z 时，时间线会跳过末尾的角色切换指令，再回退一条实际动作。向前播放仍会正常发送 C 和数字键。
录制把每次真实按下的游戏按键插入播放线处并推进播放线，保留原来的未来：
`UUU|LLLL` 中录制 `sssddd` 后成为 `UUUDDDRRR|LLLL`。插入过程中右侧未来指令保持原位，只有左侧已执行部分平滑移动。
录制按键按下事件，长按键的游戏内部自动移动不会被推断成多次移动；录制时请逐次按键。
程序自己发送的按键、编辑器中的文字输入、其他窗口的按键不会被录制。手动 Undo 会回退播放线；
录制时按游戏重置键（默认 R）会删除已执行的指令，保留未来并继续录制：`UUU|LLLL` 变为 `|LLLL`。
未开启录制时的游戏移动或游戏进程更换会暂停该会话，需要重新执行 `edit <level_name>`、`edit custom <name>` 或 `edit solution` 建立新的起点。
未开启录制时按 R，或通过终端执行 `reset` / `r`，会重置游戏并将完整的当前解法回到起点。
编辑器 Reset 按钮恢复上次成功 Save 的内容（尚未保存时恢复打开时的内容），保留录制开关状态；不会自动保存被丢弃的修改。
Rabbit 测试包含当前未保存的修改，保留录制开关及上次保存的版本；游戏接受重置键后才将时间线回到起点，并在释放重置键后开始加速播放。
Pause 按钮或 Esc 可暂停测试；暂停、测试完成或切换窗口时会释放加速键，之后普通 Play / Step 仍使用 250ms。
Export 复制全部指令（包括已执行和未来的部分），数字角色键前后保留空格，可直接用于 `send_alt`；导出不会保存文件、改变播放位置或中断录制与播放。

编辑器中的 `U/D/L/R` 对应 Forward/Backward/Left/Right，`C/X/F/V` 对应切换角色/Activate/FriendlyDragon/TakeOrDrop，数字是角色选择键。
键位从当前 Windows 用户的 `Saved Games/Order of the Sinking Star/User.keymap` 的 `[UserKeyboard]` 部分读取。
Play、Step 和 Undo 按钮，以及 `[` / `]` 使用普通速度，每步 250ms，按住 50ms、松开等待 200ms，不按加速键。
`j` 每步 250ms；`l` 撤销加快一倍，每步 125ms（按住 50ms、松开等待 75ms）。
长按 `j` 连续前进、长按 `l` 连续撤销，节奏由播放器控制，不受系统键盘重复速度影响。松开后完成当前步便停止；`,` 和 `.` 不再控制播放器。
播放时按配置中的 `HoldForFastTime` 切换为 `-fast`（175ms，无时间修饰键）；按 `HoldForSlowTime` 切换为 `-turtle`（750ms，按住游戏减速键）。
切换在当前按键周期结束后生效，松开实体键后保持所选速度。暂停后重新 Play 恢复普通速度。
Space 始终切换播放 / 暂停，即使游戏将它绑定为加速或减速键。播放中的速度切换只响应其他配置按键；Rabbit 按钮仍可使用游戏的加速键。
向左拖动或向下滚轮追赶时间线时，每步 75ms 并按住配置中的 `HoldForFastTime`（当前是 Space）。
向右拖动或向上滚轮回退时，使用 10ms 快速撤销（按住 5ms、松开等待 5ms），不按时间修饰键。
等待格持续一个当前速度周期，完成后推进播放线；中途暂停不会将未完成的等待标为已执行。
暂停、切走窗口、打开终端、退出时都会释放程序按住的按键。
编辑器开启期间使用编辑器的播放/撤销按钮；要运行独立的 `send` / `send_alt` / `play` / `undo` 命令，先用 `close editor` 或编辑器的 Exit 按钮关闭它。

编辑器打开后再次打开终端，包括用 `;` 打开左下角输入框，时间线仍保持在游戏上方，输入焦点留在终端。
终端中的 `jump`（缩写 `j`）可从当前播放位置前进或撤销到指定步数，不重置游戏：

```text
jump 13
jump 0
jump $
j 13
j 0
j $
```

`jump 13` / `j 13` 表示已有 13 步执行完成，`jump 0` / `j 0` 回到起点，`jump $` / `j $` 到当前解法末尾。
此缩写用于终端输入；编辑器或游戏获得焦点时，`J` 仍然是前进一步。
必须先打开编辑器，目标范围为 0 到解法总步数；越界或格式错误时保留当前状态，不发送按键。
执行有效跳转时将输入焦点交给游戏，终端失去焦点后自动隐藏，编辑器继续显示；单纯点击终端或切换到其他窗口会暂停播放，不抢回焦点。

`data/solutions.json` 是由 `modules/Json` 读写的数组，每条记录包含 `position: [x, y, z]`、`area`、`name`、`note` 和 `solution`。
从 `data/marker.json` 中提取 `type=level` 的 Point，z 暂为 0；按名称匹配 `data/solutions.txt` 中的 `name:solution` 预填答案。
当前包含 105 个关卡，其中 104 个有预填答案。txt 中没有对应 marker 的 7 条答案保留在原文件中，不猜测它们的位置。
之后导入只添加缺少的关卡，不覆盖已经保存的解法（包括刻意清空的解法）和备注。`note` 字段预留给后续注释功能。
保存时先写临时文件，再替换目标文件；保存失败会保留原数据，关闭编辑器时也会保留未保存的编辑内容供重试。

`src/solution/timeline.jai` 管理未来编辑和录制插入，`src/solution/transport.jai` 逐步执行并释放按键，
`src/solution/editor.jai` 管理编辑会话，`src/solution/editor_view.jai` 使用 GetRect 的矩形布局与命中检测及 Simp 绘制。
Windows 窗口和录制钩子在 `src/platform/windows/editor.jai`，坐标与键位读取分别在 `src/game/memory.jai` 和 `src/game/keymap.jai`。
保存确认、临时输入命名与覆盖检查在 `src/solution/editor_save.jai`。

源码按平台、游戏、解法和 UI 分组，入口仍为 `src/main.jai`，构建命令仍为 `jai -quiet first.jai`：

```text
src/
├─ main.jai
├─ platform/windows/
│  ├─ clipboard.jai
│  ├─ input.jai
│  ├─ process.jai
│  ├─ subtitles.jai
│  ├─ overlay.jai
│  ├─ image.jai
│  ├─ tray.jai
│  ├─ console.jai
│  ├─ editor.jai
│  └─ send_monitor.jai
├─ game/
│  ├─ commands.jai
│  ├─ keymap.jai
│  ├─ memory.jai
│  ├─ state.jai
│  └─ subtitles.jai
├─ solution/
│  ├─ solution.jai
│  ├─ editor.jai
│  ├─ editor_save.jai
│  ├─ editor_view.jai
│  ├─ timeline.jai
│  └─ transport.jai
└─ ui/
   ├─ console.jai
   ├─ console_completion.jai
   ├─ console_images.jai
   ├─ console_theme.jai
   ├─ console_view.jai
   └─ subtitles_view.jai
```

字幕解析、命令选项、补全、字体选择、双栏换行与单语言居中可通过无界面测试验证：

```powershell
jai -quiet tests/first.jai
./.build/subtitles_tests.exe
```

也可向测试程序传入实际的 `data/strings/subtitles` 目录，检查安装文件中的所有中英段落。测试不打开窗口、不发送游戏按键、不生成截图。
