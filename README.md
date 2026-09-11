# Order of the Sinking Star Trainer

使用 Jai 和项目内的 `modules/Simp` 实现的 Windows 下拉终端。
窗口无边框、半透明，覆盖游戏画面顶部的 70%，并跟随游戏窗口移动和调整尺寸。
配色参考 naysayer.nvim，正文和提示使用 `data/fonts` 中的 Meslo 字体。
终端没有顶栏，输入行和命令回显统一使用 `$` 提示符。

双击 `ootss-cmd.exe` 即可启动程序，不会弹出 cmd 窗口。
右下角系统托盘会显示程序图标（来自 `data/images/icon.png`）：

- 单击图标显示终端。
- 右键图标可选择“显示终端”“隐藏终端”或“退出”，无需输入命令即可关闭程序。
- 图标可能收在托盘的 `^` 展开区域中。退出时会移除图标；资源管理器重启后会恢复图标。

发送脚本时打开托盘菜单，会先停止发送并松开当前按键。

编译 GUI 版本和终端调试版本：

```powershell
jai -quiet first.jai
```

图标会在构建时转换成多个尺寸并内嵌到程序，运行时不需要单独读取 `data/images/icon.png`。
给其他人使用时，将 `ootss-cmd.exe` 和 `data` 文件夹一起复制到同一个目录即可。

调试时，在 PowerShell 或 MSYS2/Bash 中运行：

```text
./ootss-cmd
```

终端会等待程序结束；在启动它的终端按 Ctrl+C 或 Ctrl+Break 即可退出，发送脚本期间也会先松开当前按键。
PowerShell/cmd 会选择编译生成的 `ootss-cmd.com`；Bash 使用同名无后缀脚本启动它。
调试时保留这些入口文件与 `data` 文件夹。双击启动使用 `ootss-cmd.exe`。

退出时，右键托盘图标选择“退出”，或在 overlay 中输入 `exit` / `terminate`。
overlay 输入框内的 Ctrl+C 仍用于隐藏终端。

程序按 `sinking_star.exe` 和 `Default Window Class` 查找游戏，优先匹配标题
`Order of the Sinking Star`，不会固定 PID 或窗口句柄。游戏未启动时，程序在托盘等待，不显示终端。
每 0.5 秒检查一次游戏窗口，发现游戏启动后自动显示终端，游戏关闭后自动隐藏。
同一次游戏运行中，手动隐藏终端后不会被定时检查重新展开；游戏未运行时，热键和托盘的显示操作也不会打开终端。
建议使用无边框全屏或窗口模式；独占全屏通常无法显示独立的覆盖窗口。

| 按键 | 操作 |
| --- | --- |
| 反引号（Esc 下方的键） | 在游戏或终端中显示 / 收起终端 |
| `:`（Shift + `;`） | 在游戏中唤出终端 |
| Ctrl + 反引号 | 从其他窗口唤出 / 收起终端 |
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

Alt-Tab 或点击其他窗口时，终端自动隐藏。普通反引号热键只在游戏或终端获得焦点时注册。
冒号热键用于游戏在前台且终端隐藏时；终端打开后可以正常输入冒号。

命令名不区分大小写，例如 `send`、`SEND`、`SeNd` 等效；参数和历史记录保留原始大小写。
输入 `clear` 或缩写 `cl` 可清空全部输出和滚动记录，保留命令历史；大写写法也有效。
`q`、`quit` 隐藏终端并返回游戏；`exit`、`terminate` 关闭辅助程序。
粘贴支持中文和 emoji；换行、制表符转为空格，粘贴后按 Enter 执行。
输入上限为 1024 字节，超限粘贴会整体拒绝，避免执行被截断的脚本。

输入 `send` 加操作串即可控制游戏，不需要引号：

```text
send wwww
send 1 ww 2 dd z r
```

提交后会等待 Enter 和修饰键松开，确认游戏窗口完成激活后收起终端，再依次发送按键。
支持字母和数字，忽略空白；默认每个键的完整周期为 75 ms（按住 37 ms、松开后等待 38 ms）。
发送结束后保持游戏在前台，重新打开终端可看到 `Sent 4 keys.` 等结果。
发送期间按 Esc、切换到其他窗口或用热键唤回终端，会中止剩余操作并松开正在按住的键。
无参数、非法字符、找不到游戏或无法激活游戏时会报错，不发送按键。

`send` 和 `send_alt` 都支持 `-delay 10` 或 `-delay 10ms`，参数可放在操作串前后：

```text
send_alt -delay 10ms R3U2C
send_alt R3U2C -delay 10
send -delay 20 w3 2 d
```

`-delay` 指每次按键的完整周期（按住时间 + 松开后的等待），单位为毫秒，必须为正整数。
例如 `-delay 10` 按住 5ms、松开后等待 5ms，理论上约每秒 100 次；不指定时，`send` 和 `send_alt` 均使用 75ms 的默认周期，等同于 `-delay 75`。
可以配合游戏中手动按住空格加速。实际速度受系统调度和游戏输入采样影响，漏步时增大 `-delay`。

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

`send` 按字母对应的键发送，例如 `wasd` 控制移动，`R` 发送 R 键。
`send_alt` 使用 UDLR 方向：`U/D/L/R` 分别发送 `W/S/A/D`，`C` 直接发送 C 键，其他字母也发送对应键。
两个命令都不区分字母大小写，并使用相同的重复规则。

紧跟字母的数字表示该字母的总重复次数：`w3` 等于 `www`，`R4` 等于 `RRRR`，支持多位数。
用空白把数字和字母分开时，数字就是角色切换按键：`www 3 www` 发送 `www3www`。
输入开头、结尾也视为边界，因此 `send 3`、`send 0` 可以直接切换角色。
省略次数表示一次；次数必须为正数，展开后的上限为 65536 次按键。

| 命令 | 实际按键序列 |
| --- | --- |
| `send w3` | `www` |
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

`ls`、`echo`、`print`、`help` 仍只执行各自的占位 procedure：

```text
$ ls
ls command is here.
$ echo
echo command is here.
$ print
print command is here.
$ help
help command is here.
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

`src/console.jai` 包含命令表；`src/game_commands.jai` 负责向游戏发送操作；
`src/win/clipboard_windows.jai` 负责读取 Windows 剪贴板；
`src/win/process_console_windows.jai` 连接已有的启动终端并处理 Ctrl+C / Ctrl+Break 信号；
`src/win/tray_windows.jai` 负责托盘图标和显示、隐藏、退出菜单；
`src/console_view.jai` 负责 Simp 绘制；
`src/console_theme.jai` 保存 naysayer 配色；
`src/win/overlay_windows.jai` 负责窗口、热键、游戏定位和透明度。
在该文件中调整 `OVERLAY_HEIGHT_PERCENT` 和 `OVERLAY_OPACITY` 可修改高度比例和不透明度。

Jai 代码中的 `send("w3 2 d")` 和 `send_alt("R3 2 U")` 接口位于 `src/keyboard.jai`，使用相同的解析规则。
通过 `hold_ms`、`interval_ms` 可调整速度；终端使用同文件的 `send_sequence` 发送已经展开的按键序列。
