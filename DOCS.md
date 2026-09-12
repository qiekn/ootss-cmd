# Order of the Sinking Star Console

使用 Jai 和项目内的 `modules/Simp` 实现的 Windows 下拉终端。
窗口无边框、半透明，覆盖游戏画面顶部的 70%，并跟随游戏窗口移动和调整尺寸。
配色参考 naysayer.nvim，实际使用以下 4 款字体：

| 字体 | 用途 | 加载位置 |
| --- | --- | --- |
| Meslo LG Mono Nerd Regular | 终端输出和输入、提示、状态栏、解法编辑器及其 Nerd Font 图标、动画署名；字幕的角色名和注释 | 辅助程序的 `data/fonts/Meslo-LG-Mono-Nerd-Regular.ttf` |
| Noto Sans CJK SC Regular | 终端输出中 Meslo 缺少的中文字形，包括 `LICENSE` 中的“啥是比鸭” | 优先复用游戏的 `data/fonts/NotoSansCJKsc-Regular.otf`，缺失时使用辅助程序的同名文件 |
| Karmina Bold | 英文字幕正文 | 优先复用游戏的 `data/fonts/KarminaBold.otf`，缺失时使用辅助程序的 `data/fonts/Karmina-Bold.otf` |
| Source Han Serif CN SemiBold（思源宋体） | 中文字幕正文，以及字幕角色名、注释中 Meslo 缺少的中文字形 | 优先复用游戏的 `data/fonts/SourceHanSerifCN-SemiBold.otf`，缺失时使用辅助程序的同名文件 |

游戏目录由下文的 `game_path` 配置指定；未配置时从正在运行的游戏定位。游戏字体读取失败时，仍支持使用本地提供的回退字体。
发布包只附带 `Meslo-LG-Mono-Nerd-Regular.ttf`；其他字体从游戏目录读取，不由 `copy_data` 复制。
终端正文和输入为 20 像素，提示为 13 像素；编辑器主要字形为 21 像素、小字为 13 像素，均随 DPI 缩放。字幕字号随窗口宽度调整，1920 像素宽时正文为 36 像素，角色名和注释约为正文的 13/24。
中文回退目前用于终端输出和字幕；终端输入框、编辑器及保存名称输入框仍直接使用 Meslo。

`data/fonts/` 中暂未使用的字体是 `FiraCode-Retina.ttf`、`Karmina-BoldItalic.otf`、`Karmina-Regular.otf`、`Meslo-LG-Mono-Regular.ttf`、`NotoSerif-Regular.ttf`、`OpenSans-Regular.ttf`、`OpenSans-SemiBold.ttf` 和 `OpenSans-SemiBoldItalic.ttf`。游戏的其他字体目前也不参与辅助程序渲染。

终端没有顶栏，输入行和命令回显统一使用 `$` 提示符。
启动画面默认循环播放 `data/images/blow-wave.gif`，可在 `data/config.rc` 中关闭。三种 blow 效果共用这张 GIF，在输入栏上方居中，上下至少留出 24 个 DPI 缩放后的像素，选择可容纳的最大整数倍显示（如 320×240、640×480、960×720）。
图片内部底部居中显示 `Powered by blowave`。窗口连原尺寸也容纳不下时，在留白区域内裁切，不覆盖输入行。GIF 区域完全不透明，以 60% 图片颜色预先混合终端背景色；周围终端保持半透明。
提交第一条非空命令或执行 `clear` / `cl` 后收起 GIF，调整尺寸的 `toggle` 命令除外。空回车以及隐藏、重新打开终端不会清除这一状态。

双击 `ootss-cmd.exe` 即可启动程序。
右下角系统托盘会显示程序图标（来自 `data/images/icon.png`）：

- 单击图标显示终端，快捷键 `:` `` ` `` `;`。
- 右键图标可选择“显示终端”“隐藏终端”或“退出”，无需输入命令即可关闭程序。
- 图标可能收在托盘的 `^` 展开区域中。退出时会移除图标；资源管理器重启后会恢复图标。

发送脚本时打开托盘菜单，会先停止发送并松开当前按键。

普通构建在项目根目录生成 Windows GUI 程序 `ootss-cmd.exe`：

```powershell
jai first.jai
```

优化构建会生成 `bin/ootss-cmd.exe`，将 `data/` 复制到 `bin/data/`（其中 `fonts/` 只复制 `Meslo-LG-Mono-Nerd-Regular.ttf`），并将 `LICENSE` 复制到 `bin/LICENSE`：

```powershell
jai first.jai -optimized
```

`-optimized` 可以简写为 `-o`。给其他人使用时，将整个 `bin/` 目录打包即可。程序和托盘图标在构建时内嵌；`about` 使用 `data/images/icon.png`，三种 `blow` 效果都使用 `data/images/blow-wave.gif`。

程序启动时读取可执行文件所在目录下的 `data/config.rc`（优化版使用 `bin/data/config.rc`），修改后重启生效。例如：

```ini
game_path = "E:/SteamLibrary/steamapps/common/Order of the Sinking Star Demo";
show_startup_blow = false;
tp = back;
custom_command = "back home";
fastplay = "play -superfast";
```

`game_path` 指向包含 `sinking_star.exe` 的游戏安装目录，不要写到 `data/` 或 `data/fonts/`。上例是本机路径，其他安装位置修改这一项即可；代码中没有固定的本地游戏路径。带空格的路径用引号包围，推荐使用 `/`。相对路径以辅助程序的 exe 所在目录为基准。
省略 `game_path` 或设置 `game_path = "";` 时，从正在运行的游戏定位。字体和字幕共用这个目录，配置在加载字体之前读取。
`show_startup_blow` 默认为 `true`；设为 `false` 关闭启动 wave，仍可手动使用 `blow`。
除 `game_path` 和 `show_startup_blow` 外，其余赋值定义命令别名：`tp a` 等于 `back a`，`custom_command` 等于 `back home`，`fastplay mirror_1` 等于 `play -superfast mirror_1`。
支持换行或分号分隔、`#` 注释、单/双引号，以及 `alias tp=back;` 写法。名称不区分大小写，后面的同名定义覆盖前面的定义。
配置只定义选项、别名和快捷键，加载时不执行命令；格式错误会报告行号并保留原配置。优化构建保留已有的 `bin/data/config.rc`，仅在缺失时复制默认配置。

在终端或 quick input 中使用 `alias` / `unalias` 临时修改，无需重启：

```text
alias tp=back
alias custom_command="back home"
alias
unalias custom_command
```

单独输入 `alias` 列出当前配置和临时别名。临时别名优先于文件配置，`unalias <name>` 仅移除临时定义，恢复同名配置或内置命令；不改写 `data/config.rc`。
`tp` 也是 `back` 的内置别名，没有配置文件时仍可使用。别名支持 Tab 补全、追加参数和嵌套展开；遇到循环或超长展开时不执行命令。
历史保留实际输入的别名；别名不参与 Zork 会话内的命令。

快捷键也写在 `data/config.rc` 中，修改后重启生效：

```ini
nmap m = "move -z 1";
noremap w = "move -y 1";
map Ctrl+F1 = "tp home";
```

`map` 和 `nmap` 等价：执行命令，同时让原始按键继续按游戏或编辑器的原有逻辑处理。
`noremap` 执行命令并拦截原始按下、长按重复和松开事件。例如上面的 W 只执行 `move -y 1`，不会再产生一次原生 W 移动。
命令支持配置和临时 alias；每次实际按下只触发一次，长按不连发，脚本注入的按键不触发映射。

按键名不区分大小写，支持字母、数字、F1–F24，以及 Space、Enter、Tab、Escape、Backspace、方向键 Up/Down/Left/Right、Home/End、PageUp/PageDown、Insert/Delete 等名称。
可以组合 `Ctrl+`、`Alt+`、`Shift+`、`Win+`，如 `noremap Ctrl+Shift+M = "back home";`。修饰键需要完全匹配，同一组合以最后一条定义为准；不支持多键序列。
快捷键仅在游戏获得焦点时生效，控制台和编辑器文本输入、保存确认不受影响。失焦或游戏窗口/进程变化会取消尚未执行的快捷键。
移动类命令在按下时执行；可能发送按键或打开输入框的其他命令等待触发键及修饰键释放后执行。命令结果保留在完整控制台中，不会为了显示结果弹出输入窗口，也不改动输入草稿和历史。

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
`;` 打开左下角的小输入框，共用终端的命令、输入草稿、历史、Tab 补全和编辑快捷键。
quick input 只用来输入命令，不显示执行结果。通常按 Enter 提交后立即关闭并返回游戏；空命令和错误命令也会关闭。
`show subtitles` 是例外：命令格式正确时直接切换到上一次使用的非 mini 终端尺寸，显示字幕或查找错误，并保留终端焦点。带选项或通过别名调用也适用。
命令历史和输出仍保留在完整终端中，可按 `:` 查看。已提交的播放、移动等操作会在 Enter 和修饰键释放后继续执行。

用 `toggle` 切换终端尺寸，参数不区分大小写，切换保留历史、输出及当前图片或字幕：

| 命令 | 尺寸与位置 |
| --- | --- |
| `toggle full` | 铺满游戏窗口的客户区 |
| `toggle small` | 从顶部展开，高度为游戏窗口的 30% |
| `toggle normal` | 从顶部展开，高度为游戏窗口的 70%（默认） |
| `toggle mini` | 左下角 quick command 输入框 |

`:` 使用上一次选择的非 mini 尺寸；`;` 始终打开 mini。

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

`play [name]` 或等价的 `do [name]` 读取已经保存的解法，直接按 `send_alt` 执行。省略名称时使用当前进入的小关；指定名称时也支持 `data/custom_inputs.json` 中的自定义输入：

```text
play
play -rabbit
do -delay 100ms
play mirror_1
play mirror_1 -fast
play -rabbit mirror_1 -delay 100ms
play -slow mirror_1
do mirror_1 -rabbit
do my_test -rabbit
```

名称不区分大小写，Tab 合并补全两个文件中的 `name` 并去重，也可补全速度选项。同名时优先使用 `solutions.json` 中的关卡解法，与 `edit <name>` 一致。支持上面所有速度参数、别名和 `-delay`，可放在名称前后。
无名称时从当前场景读取关卡资源名，并查找 `data/solutions.json` 中该关的已保存解法；在 Overworld、菜单或场景读取失败时提示原因，不发送按键。
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

用 `show level` 查看当前关卡。程序从经过校验的当前场景管理器读取关卡资源名，例如 `quadrants_follow_up`；在大地图中显示 `Overworld`。
识别不依赖玩家坐标或角色数量。`show subtitles`、`edit`、`play` 和 `do` 省略名称时都使用这个小关名称；在 Overworld 时可先进入小关，或显式指定名称。

使用字幕浏览：

```text
show subtitles
show subtitles mirror_21
show subtitles heroes1_2_v2
show subtitles mirror_21 -comment
show subtitles -comment mirror_21
show subtitles mirror_21 -en
show subtitles mirror_21 -cn
show subtitles -sc mirror_21 -no_character -comment
```

`show subtitles` 按当前小关的场景名称查询字幕；`show subtitles -cn` 等选项也可直接用于当前小关。
指定名称的查询独立于当前关卡识别，命令、名称和选项均不区分大小写，选项可放在关卡名前或后。
程序优先从正在运行的游戏安装目录读取 `data/strings/subtitles/en.subtitles` 和 `s-cn.subtitles`（简体中文）。
也接受中文文件名 `ch.subtitles` / `ch-subtitles`。找不到运行目录时，会查找程序旁的 `data/strings/subtitles/` 和默认的 E 盘 Demo 安装目录。
字幕直接从安装文件读取，无需复制游戏文本到项目或修改游戏文件。

关卡资源名和字幕 ID 的对应关系保存在 `data/subtitles.json`，程序通过 `modules/Json` 读取它。
查询按映射中列出的完整 ID 选择字幕，并保持字幕文件的段落顺序。例如 `mirror_21` 对应 `mirror_post_clones_f`、`mirror_post_clones_f_mid` 和 `mirror_post_clones_f_end`。
Tab 按所选语言补全有对应字幕的关卡名。映射中的空列表不会按相似名称猜测字幕；输入不在关卡映射中时，仍支持原有的直接字幕 ID / 字幕分组查询。

使用生成器重新扫描游戏安装目录：

```powershell
jai scripts/generate_subtitles.jai - "E:/SteamLibrary/steamapps/common/Order of the Sinking Star Demo/data"
jai scripts/generate_subtitles.jai - "E:/SteamLibrary/steamapps/common/Order of the Sinking Star Demo/data" --check
```

单独的 `-` 把后续参数传给 Jai 脚本；第一个脚本参数是含有 `levels.package` 的游戏 `data` 目录，`-o <文件>` 可指定输出位置。
生成器通过 `#run` 直接执行，不生成可执行文件；SHA-256 和 Unicode 大小写折叠使用 Windows 系统 API（Windows 10 1703 及以上）。
它解析 Jai `Simple_Package` v1 索引，在每个 `.entities` 中检查完整字幕 ID 及其前面的 8 字节长度。
它读取英文和简中字幕 ID 的并集，支持 `:` / `::` 标题，不解包、不修改游戏文件。`--check` 只验证已有 JSON 是否需要更新。
每个 `levels` 条目包含 `level_name` 和 `subtitle_names` 数组，支持一关多段字幕；例如 `heroes1_2_v2` 对应 `warrior_heroes1_call`。
空数组表示包内未找到已知字幕引用；`unmapped_subtitle_names` 单独保留尚未确定关卡的 ID，不按相似名称猜测关系。
文件记录输入文件的 SHA-256，生成成功后原子替换，游戏更新后可重新生成。映射中的数组顺序是文件引用顺序，不代表游戏播放顺序。
当前 Demo 的映射包含 114 个关卡，其中 99 个有已确认引用，共 214 条关系；另有 25 个字幕 ID 尚未确定关卡。
优化构建会把 `data/subtitles.json` 随其他静态数据复制到 `bin/data/`。

查询成功后清空终端输出，左栏显示英文，右栏显示对应的中文，包括关卡的 `_start`、`_mid`、`_end` 等段落。
添加 `-en` 时只显示英文，并在整个输出区域内居中；`-cn` 和 `-sc` 效果相同，只显示居中的简体中文。
双语和单语言的字幕区域都在窗口中央，占窗口宽度的 70%；双语两栏共同使用这一区域。
字号随实际窗口宽度缩放，1920 像素宽时正文约为 36 像素，角色名和注释保持较小字号。窗口大小变化时自动更新字体、间距、换行和滚动范围。
单语言模式只读取所选语言的字幕文件；不加语言选项时恢复双栏。英文和中文选项不能同时使用。
保留原有换行，长句和注释自动折行。两栏按对白块对齐；翻译将同一角色的对白拆成不同数量的字幕时，按该角色的整段讲话对齐。
某一语言缺少段落时会显示提示，不会把后续角色的对白错配过去。时间戳和 `= _` 清除字幕标记不显示。
默认隐藏 `++` 注释，添加 `-comment` 时以黄色显示。
添加 `-no_character` 或等效别名 `-nosayer` 隐藏说话者名称及其占用的行，可与语言选项和 `-comment` 一起使用。

英文正文使用 Karmina Bold，中文正文使用思源宋体 CN SemiBold，优先复用游戏字体，加载位置和本地回退见开头的字体表。中英正文均使用白色 `#ffffff`，不显示顶部关卡名以及“English”和“简体中文”栏标题。
角色名和注释使用较小的 Meslo，缺少的中文字形使用同字号的思源宋体。
所有角色名统一使用 trader 的墨绿色 `#398e82`，可在 `src/ui/console_theme.jai` 的 `SUBTITLE_SPEAKER_COLOR` 中调整。

鼠标滚轮、Page Up / Page Down 可浏览全部字幕，Ctrl+Home / Ctrl+End 跳到开头或末尾；字幕不受普通输出的 256 行限制。
字幕滚动条贴在窗口最右边。
输入行始终保留。`clear` / `cl` 清除字幕；执行产生普通输出的命令后返回普通终端输出。
按 Tab 补全命令、`show` 子命令和关卡名，也支持 `edit` 的关卡、自定义名称与 `blow` 的动画名。
有多个候选时先扩展共同前缀，再按 Tab 向后循环，Shift+Tab 向前循环；补全只替换光标所在的词，保留后面的参数。

使用解法编辑器：

```text
edit
edit mirror_21
open editor
edit custom my_test
```

`edit` 打开当前小关的解法，`edit solution` 是兼容别名。尚无记录的当前小关会打开按场景名标识的空解法，点击 Save 并确认后才保存。
`edit <level_name>` 按名称加载解法，例如 `edit mirror_21`；命令与关卡名不区分大小写，显式名称独立于当前关卡识别和坐标读取。
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

读取、修改玩家坐标：

```text
show position
set position 80 79 0
```

`show position` 只读查询当前受控角色的三个 float 坐标，例如 `(80, 79, 0)`。用 C 或数字键切换角色后，下一次查询会重新读取选择状态。
同时控制多个副本时，从这些受控实体中先比较 X，再比较 Y、Z，取最小的实际角色作为基准；坐标完全相同时用实体 ID 确定顺序。
例如 A=`(1, 5, 0)`、B=`(3, 2, 0)`，显示 A 的 `(1, 5, 0)`。
参考 [SinkingStarHero](https://github.com/wudi-7mi/sinkingstarhero) 的实体查找方式，通过代码特征定位当前关卡，
在其对象列表中校验 `Guy` 实体，并通过游戏反射数据中的 `Status_Flags.ACTIVE` 确定当前受控集合。每次操作重新定位，避免使用切换场景前的玩家地址。
未选中的角色不参与查询或移动；`thief` 与 `thief_alt` 即使技能相同，也按各自的选择状态处理。
游戏未启动、场景未加载、版本特征不匹配或没有有效受控角色时输出错误；`edit <level_name>` 仍可独立于坐标读取使用。

`set position <x> <y> <z>` 将该基准角色放到目标坐标，当前受控的所有副本按同一偏移平移，保持彼此间距。
例如三个受控角色位于 `(4, 2, 0)`、`(6, 2, 0)`、`(11, 5, 0)`，执行 `set position 20 30 1` 后，
它们分别位于 `(20, 30, 1)`、`(22, 30, 1)`、`(27, 33, 1)`。
每个受控角色都会同步逻辑坐标、显示坐标和移动起点，并清除速度。命令不区分大小写，支持负数、小数和科学记数法，
例如 `set position -12.5 2e1 0`；三个数必须齐全、有限且位于 `-1000000` 到 `1000000` 之间。
写入前检查整组身份、每个角色的目标坐标及全部同步字段，任一项无效则整组不写入。写入中途若角色切换、场景变化或访问失败，会停止并报告可能已经发生的部分修改。
编辑器打开时，坐标修改会暂停播放和录制，保留未保存内容和播放位置；
之后可直接继续播放、录制或拖动时间线，无需重新打开编辑器。保存确认尚未结束时不能修改坐标。

相对移动给所有当前受控角色加上相同偏移，同步逻辑和显示位置；省略的轴各自保持原值：

```text
move 2 -3
move 2 -3 1
move_xy 2 -3
move -x -2
move -y 3
move -z 1
```

例如 `move 2 -3` 让每个受控角色的 X +2、Y -3 并保留各自的 Z；加上第三个参数 `1` 则同时让 Z +1。
`move -x <value>` 和 `move -y <value>` 按数值的正负增减相应坐标，两者输入 `0` 时不执行移动。
单轴模式每次指定一个 `-x`、`-y` 或 `-z` 和一个数值，选项不区分大小写，Tab 可补全。
这些位置命令都不发送方向键，避免原生移动再叠加一步。

在大地图使用 `switch <level_name>` 进入指定关卡，例如：

```text
switch mirror_21
```

它从 `data/marker.json` 查找关卡入口，先瞬移到入口坐标，再发送 `User.keymap` 中的 `TakeOrDrop` 按键（默认 V）。
关卡名不区分大小写，支持 Tab 补全，独立于重命名的解法和自定义脚本。已进入小关卡时，需要先返回大地图。

用位置标记保存和返回坐标：

| 命令 | 操作 |
| --- | --- |
| `mark home` | 将当前位置保存为 home |
| `mark home 80 79 0` | 保存指定坐标；同名标记会更新 |
| `mark 80 79 0` / `add markers 80 79 0` | 保存到下一个默认寄存器 |
| `mark` | 将当前位置保存到下一个默认寄存器 |
| `list markers` | 列出标记名称和坐标 |
| `remove markers home` | 删除指定标记 |
| `rename home start` | 重命名，目标名称已存在时拒绝覆盖 |
| `back start` / `tp start` | 瞬移到该标记的坐标 |
| `reset marker registers` | 清空 a–z，从 a 重新开始，保留其他名称 |

省略坐标的 `mark` 使用 `show position` 的同一基准；`back` / `tp` 按 `set position` 的方式平移当前受控整组。

自动寄存器按 a → b → … → z → a 循环，回到 a 时覆盖原值；显式指定名称不会推进寄存器。
名称不区分大小写，支持中文、字母、数字、`_`、`-`、`.`，不含空白，最多 128 字节；Tab 可补全已有标记。
所有 a–z 寄存器和命名标记都保存在程序目录的 `data/markers.json`，与关卡目录 `data/marker.json` 分开。
每条标记只包含 `name` 和 `position`；文件外层的 `next_register` 保存下一个自动寄存器。
新文件不存在时会自动迁移旧的 `data/position_markers.json`，保留旧文件；已有新文件时以新文件为准。
读取失败、保存失败或参数错误不会推进寄存器；优化构建保留安装目录中已有的标记、解法和自定义脚本。

`noclip` 切换穿行模式，`noclip enable` 开启，`noclip disable` 关闭。开启后，在游戏前台按物理 W/S/A/D，
分别让当前受控整组同步移动 Y +1、Y -1、X -1、X +1，不发送替代方向键。
轻点一次请求移动一格，例如 D 让 X 从 10 到 11。位置校验复用经过复核的代码定位结果，每次仍重新解析当前受控角色。
支持长按，按 250ms 间隔重复移动；处理单次移动时不等待按键按住／释放周期。忽略 Windows 自动重复和程序注入事件，离开游戏焦点会清空待执行移动，重新按键才继续。
控制台和编辑器中的文字输入、带修饰键的快捷键不受影响。noclip 开关仅在本次运行中生效，不修改游戏碰撞代码。

地址定位、读写实现和游戏更新后的适配步骤见项目技能 [ootss-game-memory](skills/ootss-game-memory/SKILL.md)。

编辑器在游戏画面底部居中显示。关卡解法按名称导入和保存，共享入口坐标的不同关卡各自保留解法和笔记。
切换编辑会话需要保存确认时，保留已经解析好的目标关卡名；确认期间游戏切换场景不会改变这个目标。

竖直播放线固定在中间，左侧是已经发送到游戏的指令，右侧是未来指令。打开一个新会话时播放位置为 0；
播放已有答案前，请将游戏放在该答案的起点。重新打开同一个编辑会话会保留播放位置。
拖动时指令条平滑跟随鼠标，光标变为手形，松开或取消拖动后恢复；跨过完整格子才请求执行或撤销。
滚轮连续累积移动距离，包括触控板和高精度滚轮的部分刻度；播放未追上时继续滚动也不会丢失之前的目标。
链接图标控制拖动和滚轮是否影响游戏。开启时执行对应的撤销／输入；关闭时暂停播放，只改变编辑器的播放起点，不发送游戏输入。
两种状态下，中间的竖直播放线都固定不动。重新开启链接或按 Play / Rabbit 时，从拖动后选定的新起点继续，不补执行两者之间的指令。
时间线用箭头显示 U/D/L/R，C 显示为 `nf-md-swap_horizontal_variant`，X 显示为 `nf-md-function`；输入、执行和保存仍使用原来的指令字母。
空白等待格使用 `nf-md-sleep` 图标，在编辑器中输入 `b` 或 `_` 插入，保存和导出统一使用 `_`。
底部按钮使用 Nerd Font 图标，鼠标悬停时显示操作名称，录制和播放按钮会随状态切换图标。
点击 `nf-fa-minimize` 图标可收起为底部居中的简洁时间线，实时预览录制结果、当前位置和总步数；点击 `nf-fa-edit` 图标恢复编辑器。
收起和恢复保留播放位置、录制开关和未保存修改，不会暂停正在播放的序列。收起后输入焦点回到游戏。
精简版保留完整时间线交互：拖动、滚轮、Ctrl+滚轮缩放、点击未来格子后输入和粘贴、选择与删除均可使用。已执行格也可选择和删除。
精简版左侧的录制按钮可点击切换开始 / 停止录制；右侧的 Edit 按钮恢复完整界面。
Edit 旁边也有链接按钮，可切换拖动是否影响游戏。
按 `N` 也可在精简版和完整版之间切换，编辑器或游戏获得焦点时都可用；长按不会反复切换，保存命名时仍可正常输入 N。

| 操作 | 效果 |
| --- | --- |
| 向右拖动指令条 / 向上滚轮 | 以 10 ms 周期快速回退；可撤销动作发送 Z，C、数字键和等待格只回退时间线 |
| 向左拖动指令条 / 向下滚轮 | 每跨过一个格子执行一条未来指令 |
| Record / Stop Recording | 开始 / 停止录制游戏窗口中的键盘输入 |
| Undo / `[` | 撤销一步，250 ms 周期 |
| Step / `]` | 执行一步，250 ms 周期 |
| `j` / `l` | 加快 / 放慢一档；共五档，长按不会连续换档 |
| Play / Pause | 播放 / 暂停 |
| Space / `k` | 切换播放 / 暂停；优先于游戏中的加速或减速键绑定 |
| 游戏加速键 / 减速键 | 播放中切换为 `-fast` / `-turtle`，从 User.keymap 读取 |
| 点击格子 | 将文本光标放在此处；已执行格可选择和删除，未来格还可插入和替换 |
| W/S/A/D 或 ↑/↓/←/→ | 插入上 / 下 / 左 / 右移动指令 |
| B / `_` | 插入一个空白等待格 |
| Ctrl+左右方向键、Home / End | 移动文本光标；Home / End 到当前侧的首尾；按住 Shift 可选择 |
| Backspace / Delete | 删除格子，包括已执行部分；只修改时间线，不向游戏发送撤销 |
| Ctrl+A | 光标在 executed 时全选 executed，在 future 时全选 future |
| Ctrl+V / Shift+Insert | 按 UDLR 格式粘贴解法，支持 `R4X2` 等重复缩写 |
| Ctrl+C | 复制当前完整解法，编辑器或游戏获得焦点时都可使用 |
| Ctrl+滚轮 | 调整格子宽度 |
| Save / Ctrl+S | 打开保存确认；临时编辑器可输入自定义名称 |
| Reset | 重置游戏并恢复上一次保存的解法，播放位置回到 0，丢弃未保存修改 |
| Rabbit（`nf-md-rabbit`） | 从当前执行边界继续快速播放；每步 75ms，并按住配置中的加速键 |
| 链接按钮 | 开关拖动／滚轮的游戏输入；关闭时只重新设定播放起点，中间竖线固定 |
| Export（`nf-fa-clipboard`） | 将当前完整解法复制到系统剪贴板，使用 UDLR 文本格式 |
| N / Minimize / Edit | 切换精简版 / 完整编辑器，保留时间线操作能力 |
| Exit / `close editor` | 关闭编辑器；有修改时先确认保存 / 放弃 / 取消 |
| Esc | 暂停播放，返回游戏输入 |

文本光标与播放线相互独立。新增、粘贴和替换只作用于未来指令；已执行部分可直接删除记录。
删除已执行格会相应左移执行边界，游戏本身不撤销。
手动编辑不再直接输入 U/D/L/R：D 表示向右，向下用 S 或 ↓，C/X/F/V 和数字键仍可输入对应动作。
存档和粘贴解法继续使用 UDLR 格式，键盘编辑会自动转换为对应指令。
C 和数字键只切换角色，不进入游戏的撤销记录，等待格也不增加撤销记录。Undo 按钮、`[` 和拖动回退经过这些格子时，不发送 Z；
玩家在游戏中直接按 Z 时，时间线会跳过末尾的角色切换指令，再回退一条实际动作。向前播放仍会正常发送 C 和数字键。
录制把每次真实按下的游戏按键插入播放线处并推进播放线，保留原来的未来：
`UUU|LLLL` 中录制 `sssddd` 后成为 `UUUDDDRRR|LLLL`。插入过程中右侧未来指令保持原位，只有左侧已执行部分平滑移动。
录制按键按下事件，长按键的游戏内部自动移动不会被推断成多次移动；录制时请逐次按键。
程序自己发送的按键、编辑器中的文字输入、其他窗口的按键不会被录制。手动 Undo 会回退播放线；
录制时按游戏重置键（默认 R）会删除已执行的指令，保留未来并继续录制：`UUU|LLLL` 变为 `|LLLL`。
未开启录制时，可以在游戏中手动移动到脚本起点，再继续播放；手动移动不追加记录，也不会锁定编辑器。
播放期间也允许游戏接收手动移动。显式修改内存坐标会暂停录制与播放，之后可继续使用当前会话；游戏进程更换时仍需重新打开编辑器绑定新进程。
未开启录制时按 R，或通过终端执行 `reset` / `r`，会重置游戏并将完整的当前解法回到起点。
编辑器 Reset 按钮恢复上次成功 Save 的内容（尚未保存时恢复打开时的内容），保留录制开关状态；不会自动保存被丢弃的修改。
Rabbit 从当前执行边界继续播放剩余解法，包含未保存的修改；保留独立文本光标、录制开关及上次保存的版本。
Pause 按钮或 Esc 可暂停；暂停、完成或切换窗口时会释放加速键，恢复 Play 保留所选速度，Step / Undo 按钮仍为 250ms。
Export 复制全部指令（包括已执行和未来的部分），数字角色键前后保留空格，可直接用于 `send_alt`；导出不会保存文件、改变播放位置或中断录制与播放。

录制和播放不采集每一步的玩家位置，也不根据位置变化标记移动是否有效。多角色与原地改变机关的动作由玩家自行判断，可直接选择并删除时间线记录。

编辑器中的 `U/D/L/R` 对应 Forward/Backward/Left/Right，`C/X/F/V` 对应切换角色/Activate/FriendlyDragon/TakeOrDrop，数字是角色选择键。
键位从当前 Windows 用户的 `Saved Games/Order of the Sinking Star/User.keymap` 的 `[UserKeyboard]` 部分读取。
Step 和 Undo 按钮，以及 `[` / `]` 每步 250ms，按住 50ms、松开等待 200ms，不按时间修饰键。
`J` 加快一档，`K` 切换播放 / 暂停，`L` 放慢一档；长按不会重复换档，到最快或最慢时不再改变。
播放和暂停时都可选择速度，新会话默认 normal，暂停后保留选择。当前速度显示在时间线的进度文字中。

| 播放速度 | 每步周期 | 游戏时间键 |
| --- | --- | --- |
| superfast | 75ms | 按住 HoldForFastTime |
| fast | 175ms | 无 |
| normal | 250ms | 无 |
| slow | 500ms | 无 |
| superslow | 750ms | 按住 HoldForSlowTime |

播放时按配置中的 `HoldForFastTime` 切换为 `-fast`（175ms，无时间修饰键）；按 `HoldForSlowTime` 切换为 `-turtle`（750ms，按住游戏减速键）。
速度切换在当前按键周期结束后生效，松开实体键后保持所选速度；`,` 和 `.` 不控制播放器。
Space 始终切换播放 / 暂停，即使游戏将它绑定为加速或减速键。播放中的速度切换只响应其他配置按键；Rabbit 按钮仍可使用游戏的加速键。
向左拖动或向下滚轮追赶时间线时，每步 75ms 并按住配置中的 `HoldForFastTime`（当前是 Space）。
向右拖动或向上滚轮回退时，使用 10ms 快速撤销（按住 5ms、松开等待 5ms），不按时间修饰键。
等待格持续一个当前速度周期，完成后推进播放线；中途暂停不会将未完成的等待标为已执行。
暂停、切走窗口、打开终端、退出时都会释放程序按住的按键。
编辑器开启期间使用编辑器的播放/撤销按钮；要运行独立的 `send` / `send_alt` / `play` / `do` / `undo` 命令，先用 `close editor` 或编辑器的 Exit 按钮关闭它。

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
前向使用 superfast（75ms，并按住 HoldForFastTime），后向使用默认 Undo 间隔（10ms，不按时间修饰键），独立于所选播放速度。
此缩写用于终端输入；编辑器或游戏获得焦点时，`J` 是加快播放一档。
必须先打开编辑器，目标范围为 0 到解法总步数；越界或格式错误时保留当前状态，不发送按键。
执行有效跳转时将输入焦点交给游戏，终端失去焦点后自动隐藏，编辑器继续显示；单纯点击终端或切换到其他窗口会暂停播放，不抢回焦点。

`data/solutions.json` 是由 `modules/Json` 读写的数组，每条记录包含 `position: [x, y, z]`、`area`、`name`、`note` 和 `solution`。
从 `data/marker.json` 中提取 `type=level` 的 Point，z 暂为 0；按名称匹配 `data/solutions.txt` 中的 `name:solution` 预填答案。
当前包含 105 个关卡，其中 104 个有预填答案。txt 中没有对应 marker 的 7 条答案保留在原文件中，不猜测它们的位置。
之后导入只添加缺少的关卡，不覆盖已经保存的解法（包括刻意清空的解法）和备注。`note` 字段预留给后续注释功能。
保存时先写临时文件，再替换目标文件；保存失败会保留原数据，关闭编辑器时也会保留未保存的编辑内容供重试。

`src/solution/timeline.jai` 管理时间线编辑和录制插入，`src/solution/transport.jai` 逐步执行并释放按键，
`src/game/position_reader.jai` 负责读坐标时的玩家身份校验，`src/game/position_layout.jai` 根据反射元数据校验并同步位置字段，
`src/game/level.jai` 独立读取当前场景名称，供无名称的字幕、解法编辑和播放命令使用，
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
│  ├─ game_paths.jai
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
│  ├─ level.jai
│  ├─ subtitle_mapping.jai
│  └─ subtitles.jai
├─ solution/
│  ├─ solution.jai
│  ├─ editor.jai
│  ├─ editor_save.jai
│  ├─ editor_view.jai
│  ├─ timeline.jai
│  └─ transport.jai
└─ ui/
   ├─ config.jai
   ├─ fonts.jai
   ├─ console.jai
   ├─ console_completion.jai
   ├─ console_images.jai
   ├─ console_theme.jai
   ├─ console_view.jai
   └─ subtitles_view.jai
```

字幕映射、解析、命令选项、补全、字体选择、双栏换行与单语言居中可通过无界面测试验证：

```powershell
jai -quiet tests/first.jai
./.build/subtitles_tests.exe
```

也可向测试程序传入实际的 `data/strings/subtitles` 目录，检查安装文件中的所有中英段落。测试不打开窗口、不发送游戏按键、不生成截图。

当前关卡读取、默认命令和按名称保存可通过隔离夹具验证；`--read-level` 只读取正在运行的游戏场景，不发送输入：

```powershell
jai -quiet tests/position_first.jai
./.build/position_tests.exe
./.build/position_tests.exe --read-level
jai -quiet tests/controls_first.jai
./.build/controls_tests.exe
```
