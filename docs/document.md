# Order of the Sinking Star Overlay Console

使用 Jai 和项目内的 `modules/Simp` 实现的 Windows 下拉终端，覆盖在游戏《Order of the Sinking Star》画面上方。
可以向游戏发送按键、播放和编辑解法、查看双语字幕、瞬移、穿墙和自由摄像机。
窗口无边框、半透明，跟随游戏窗口移动和调整尺寸，配色参考 naysayer.nvim。

## 快速开始

### 构建

普通构建在项目根目录生成 `ootss-cmd.exe`：

```powershell
jai first.jai
```

优化构建生成 `bin/ootss-cmd.exe`，并把 `data/`、`LICENSE` 和 `config.rc` 复制到 `bin/`。
`fonts/` 只复制 `Meslo-LG-Mono-Nerd-Regular.ttf`；已有的 `bin/config.rc`、标记、解法和自定义脚本会保留。

```powershell
jai first.jai -optimized   # 可简写为 -o
```

给其他人使用时，打包整个 `bin/` 目录即可。

### 启动与退出

- 双击 `ootss-cmd.exe` 启动，右下角托盘显示程序图标。
- 程序按 `sinking_star.exe` 查找游戏，每 0.5 秒检查一次：游戏启动后自动显示终端，游戏关闭后自动隐藏。游戏未启动时在托盘等待。
- 建议游戏使用无边框全屏或窗口模式；独占全屏通常无法显示覆盖窗口。
- 退出：右键托盘图标选择“退出”，在终端输入 `exit` / `terminate`，或按 Ctrl+Q / Alt+F4。

### 字体

终端使用 `data/fonts/Meslo-LG-Mono-Nerd-Regular.ttf`。
中文字形（Noto Sans CJK SC）、英文字幕（Karmina Bold）和中文字幕（思源宋体）优先从游戏目录的 `data/fonts/` 读取，读取失败时使用程序旁 `data/fonts/` 中的同名文件。
发布包只附带 Meslo，因此需要配置 `game_path`，或先启动游戏再启动本程序。

### 终端快捷键

| 按键 | 操作 |
| --- | --- |
| `` ` ``（反引号） | 在游戏或终端中显示 / 收起终端 |
| `:`（Shift + `;`） | 在游戏中唤出终端，使用上次的非 mini 尺寸 |
| `;` | 在游戏左下角打开 quick command 输入框（mini） |
| Esc、Ctrl + C、Ctrl + D | 收起终端，把焦点还给游戏 |
| Enter | 执行当前命令 |
| ↑ / ↓ | 浏览命令历史，回到末尾可恢复未提交的输入 |
| ← / →、Home / End | 移动输入光标 |
| Backspace / Delete | 删除光标前 / 后的字符 |
| Ctrl + W / Ctrl + Delete | 删除光标前 / 后一个单词 |
| Ctrl + U | 清除光标前的内容 |
| Ctrl + V / Shift + Insert | 从剪贴板粘贴 |
| Tab / Shift + Tab | 补全命令、子命令、关卡名、标记名和选项；多个候选时先扩展共同前缀，再循环切换 |
| 鼠标滚轮、Page Up / Page Down | 浏览输出记录 |
| Ctrl + Q、Alt + F4 | 退出辅助程序 |

- 命令名和选项不区分大小写；参数和历史记录保留原始大小写。
- quick command 输入框只用来输入命令，不显示结果，按 Enter 后立即关闭并返回游戏。`show subtitles` 例外，会切换到完整终端显示字幕。
- 切换到其他窗口时终端自动隐藏，保留输入和历史。
- 粘贴支持中文和 emoji，换行和制表符转为空格。输入上限 1024 字节，超限的粘贴整体拒绝。
- 最多保留 256 行输出和 64 条命令历史。首次打开终端直接显示 `help` 的内容。

## 配置文件 config.rc

程序启动时读取可执行文件所在目录下的 `config.rc`（优化版为 `bin/config.rc`），修改后重启生效。
配置只定义选项、别名和快捷键，加载时不执行命令；格式错误会报告行号并保留原配置。

```ini
game_path = "E:/SteamLibrary/steamapps/common/Order of the Sinking Star Demo";
show_startup_blow = false;
freecam_speed = 12;
freecam_sensitivity = 0.1;
freecam_shift_multiplier = 4;
freecam_ctrl_multiplier = 0.25;

# 别名
tp = back;
custom_command = "back home";
fastplay = "play -superfast";

# 快捷键
map m = "move -z 1";
noremap w = "move -y 1";
map Ctrl+F1 = "tp home";
map , = noclip;
map o = "show subtitles";
```

### 选项

| 选项 | 默认值 | 说明 |
| --- | --- | --- |
| `game_path` | 空 | 包含 `sinking_star.exe` 的游戏安装目录，为空时从正在运行的游戏定位。带空格的路径用引号包围，推荐使用 `/`；相对路径以 exe 所在目录为基准 |
| `show_startup_blow` | `true` | 是否在启动时播放 wave 动画；关闭后仍可手动 `blow` |
| `freecam_speed` | `12` | 自由摄像机速度，每秒世界单位 |
| `freecam_sensitivity` | `0.1` | 每个鼠标计数转动的度数 |
| `freecam_shift_multiplier` | `4` | 按住 Shift 时的速度倍率 |
| `freecam_ctrl_multiplier` | `0.25` | 按住 Ctrl 时的速度倍率 |

四个 `freecam_` 选项都必须是正数。

### 别名

其余赋值定义命令别名：`tp a` 等于 `back a`，`fastplay mirror_1` 等于 `play -superfast mirror_1`。
支持换行或分号分隔、`#` 注释、单/双引号，以及 `alias tp=back;` 写法。名称不区分大小写，后面的同名定义覆盖前面的。
别名支持 Tab 补全、追加参数和嵌套展开；遇到循环或超长展开时不执行命令。`tp` 是 `back` 的内置别名，没有配置文件时仍可使用。

### 快捷键映射

- `map`（也可写作 `nmap`）：按键时执行命令，原始按键继续交给游戏或编辑器处理。
- `noremap`：执行命令并拦截原始按键的按下、长按重复和松开事件。例如上面的 W 只执行 `move -y 1`，不会再产生一次原生移动。
- 按键名不区分大小写，支持字母、数字、F1–F24，标点 `,` `.` `-` `/` `\` `[` `]`（也可写作 Comma、Period、Minus、Slash、Backslash、LeftBracket、RightBracket），以及 Space、Enter、Tab、Escape、Backspace、Up/Down/Left/Right、Home/End、PageUp/PageDown、Insert/Delete。
- `=` 和 `'` 写作 Plus（或 Equals）和 Quote；`;` 和 `` ` `` 用于打开控制台，不能映射。
- 可组合 `Ctrl+`、`Alt+`、`Shift+`、`Win+`，如 `noremap Ctrl+Shift+M = "back home";`。修饰键需完全匹配，同一组合以最后一条为准，不支持多键序列。
- 仅在游戏获得焦点时生效；每次按下只触发一次，长按不连发，脚本注入的按键不触发映射。
- 命令结果保留在完整终端中，不会为了显示结果弹出窗口。`show subtitles` 例外，会打开完整终端显示字幕。

## 命令

### 终端控制

| 命令 | 说明 |
| --- | --- |
| `help` | 显示全部命令、速度参数、重复语法和快捷键 |
| `clear` / `cl` | 清空输出和滚动记录，保留命令历史；也会清除字幕和启动动画 |
| `toggle full` / `small` / `normal` / `mini` | 调整终端尺寸：铺满客户区 / 高度 30% / 高度 70%（默认）/ 左下角输入框。切换保留历史、输出和当前图片或字幕 |
| `q` / `quit` | 隐藏终端，返回游戏 |
| `exit` / `terminate` | 关闭辅助程序 |
| `about` | 显示图标、作者 `qiekn` 和仓库地址 |
| `license` | 显示程序目录下的 `LICENSE` |
| `blow` | 清屏并播放下一种动画，顺序为 alien → mirror → wave，第一次输入播放 alien |
| `blow alien` / `mirror` / `wave` | 播放指定动画，不推进轮播次序 |
| `ls` / `echo` / `print` / `xyzzy` / `hello sailor` | 占位命令，只输出固定文字 |

启动画面默认循环播放 `data/images/blow-wave.gif`，提交第一条非空命令或执行 `clear` 后收起。
三种 `blow` 效果共用这张 GIF：`wave` 显示原图，`alien` 把左半边镜像到右边，`mirror` 把右半边镜像到左边。

### alias / unalias

在终端或 quick input 中临时修改别名，无需重启，不改写 `config.rc`：

```text
alias                          # 列出配置和临时别名
alias tp=back
alias custom_command="back home"
unalias custom_command         # 移除临时定义，恢复配置或内置命令
```

临时别名优先于文件配置。历史记录保留实际输入的别名。

### send / send_alt

向游戏发送按键，不需要引号：

```text
send wwww
send 1 ww 2 dd z r
send_alt R3U2C -rabbit
send -delay 20 w3 2 d
```

- `send` 按字母对应的键发送，例如 `wasd` 移动、`r` 重置、`z` 撤销。
- `send_alt` 使用 UDLR 方向：`U/D/L/R` 分别发送 `W/S/A/D`，`C` 直接发送 C 键，其他字母也发送对应键。等同于旧写法 `send --udlr`。
- 两者都不区分字母大小写，忽略空白，使用相同的重复语法和速度参数。
- 提交后等待 Enter 和修饰键松开，激活游戏窗口并收起终端，再依次发送。结束后游戏保持前台，重新打开终端可看到 `Sent 4 keys.` 等结果。
- 发送期间玩家按键、点击鼠标、滚动滚轮、切换窗口或唤回终端都会中止剩余操作，并释放程序按住的按键。
- 无参数、非法字符、找不到游戏或无法激活游戏时报错，不发送按键。

### 重复语法

| 写法 | 实际按键 | 说明 |
| --- | --- | --- |
| `send w3` | `www` | 紧跟字母的数字是重复次数，支持多位数 |
| `send (ad)3` | `adadad` | 小括号重复整段，支持 `(w2d)3`、`((ad)2w)3` 等嵌套；次数必须紧跟右括号 |
| `send www 3 www` | `www3www` | 用空白隔开的数字是角色切换键；开头、结尾也视为边界，`send 3` 直接切换角色 |
| `send (w 3 d)2` | `w3dw3d` | 组内同样可以用空格分隔数字键 |
| `send_alt R3 2 U2 C` | `ddd2wwc` | UDLR 写法 |
| `send _3` | 等待 3 个周期 | `_` 是空白等待，持续一个当前速度周期，不发送按键，也可放在重复组内 |

省略次数表示一次；次数必须为正数，展开后最多 65536 次按键。

### 速度参数

`send`、`send_alt`、`play`、`do` 共用以下参数，可放在操作串前后，不区分大小写，每次只能选一个预设：

| 参数 | 每键周期 | 游戏时间控制 |
| --- | --- | --- |
| 默认 | 250 ms | 无 |
| `-fast` | 175 ms | 无 |
| `-superfast` / `-rabbit` | 75 ms | 按住 `HoldForFastTime`（默认 Space） |
| `-slow` | 500 ms | 无 |
| `-superslow` / `-turtle` | 750 ms | 按住 `HoldForSlowTime`（默认 Control） |
| `-delay <ms>` | 指定值 | 正整数，优先于预设周期，并保留所选模式的加速或减速键 |

- 周期指按住时间加松开后的等待。按住最多 50 ms，短周期对半分配：`-delay 10` 按住 5 ms、松开 5 ms；175 ms 为 50 + 125。
- 加速和减速键从当前用户的 `Saved Games/Order of the Sinking Star/User.keymap` 的 `[UserKeyboard]` 读取。
- 实际速度受系统调度和游戏输入采样影响，漏步时增大 `-delay`。

### play / do

读取已保存的解法，按 `send_alt` 的方式发送：

```text
play                    # 当前小关的解法
play mirror_1 -fast
do -rabbit mirror_1 -delay 100ms
do my_test -rabbit      # data/custom_inputs.json 中的自定义输入
```

- 省略名称时读取当前场景的关卡名，查找 `data/solutions.json` 中该关的解法；在大地图、菜单或场景读取失败时提示原因。
- 指定名称时优先使用 `solutions.json` 中的关卡解法，其次是 `custom_inputs.json`。名称不区分大小写，Tab 补全两个文件中的名称和速度选项。
- 从游戏当前位置开始发送，不重置关卡、不打开编辑器；请先进入对应关卡并回到起点。
- 支持全部速度参数和 `-delay`。找不到名称、解法为空或无效时不发送。

### undo / z

发送 Z 键撤销，省略次数时撤销一次：

```text
undo
undo 100
z100
z100 -fast
undo 100 -fast -delay 20ms
```

默认周期 10 ms，`-fast` 为 1 ms，也可用 `-delay` 指定；同时给出时以 `-delay` 为准。次数必须为正整数，最多 65536。

### reset / r

发送一次 R 键重置关卡，使用 75 ms 周期。
编辑器开启时也可执行：R 键发送后时间线退回起点，整段解法保留为未来指令。

### show level

显示当前关卡的资源名，例如 `quadrants_follow_up`；在大地图中显示 `Overworld`。
`show subtitles`、`edit`、`play`、`do` 省略名称时都使用这个名称。

### show position / set position

```text
show position
set position 80 79 0
set position -12.5 2e1 0
```

- `show position` 显示当前受控角色的坐标，例如 `(80, 79, 0)`。同时控制多个副本时，先比较 X、再比较 Y、Z，取最小的角色作为基准。用 C 或数字键切换角色后，下一次查询重新读取。
- `set position <x> <y> <z>` 把基准角色放到目标坐标，其余受控副本按同一偏移平移，保持间距；未选中的角色不动。支持负数、小数和科学记数法，三个数必须齐全且在 ±1000000 以内。
- 游戏未启动、场景未加载、版本特征不匹配或没有受控角色时报错。
- 编辑器开启时，修改坐标会暂停播放和录制，之后可直接继续；保存确认期间不能修改坐标。

### move / move_xy

给所有受控角色加上相同偏移，省略的轴保持原值，不发送方向键：

```text
move 2 -3        # X +2、Y -3
move 2 -3 1      # 同时 Z +1
move_xy 2 -3     # 等同于 move 2 -3
move -x -2       # 单轴：-x / -y / -z 加一个数值
move -y 3
move -z 1
```

`move -x 0` 和 `move -y 0` 不执行移动。

### 位置标记 mark / back / tp

| 命令 | 操作 |
| --- | --- |
| `mark home` | 把当前位置保存为 home |
| `mark home 80 79 0` | 保存指定坐标；同名标记会更新 |
| `mark` / `mark 80 79 0` / `add markers 80 79 0` | 保存到下一个自动寄存器，按 a → b → … → z → a 循环覆盖 |
| `list markers` | 列出标记名称和坐标 |
| `remove markers home` | 删除指定标记 |
| `rename home start` | 重命名；目标名称已存在时拒绝覆盖 |
| `back start` / `tp start` | 把受控整组平移到该标记，方式同 `set position` |
| `reset marker registers` | 清空 a–z 并从 a 重新开始，保留其他名称 |

- 省略坐标时使用 `show position` 的同一基准；显式指定名称不推进寄存器。
- 名称不区分大小写，支持中文、字母、数字、`_`、`-`、`.`，最多 128 字节，Tab 可补全。
- 标记保存在程序目录的 `data/markers.json`，与关卡入口文件 `data/marker.json` 分开。新文件不存在时自动迁移旧的 `data/position_markers.json`。

### switch

在大地图中进入指定关卡：

```text
switch mirror_21
```

从 `data/marker.json` 查找关卡入口，先瞬移到入口坐标，再发送 `User.keymap` 中的 `TakeOrDrop` 键（默认 V）。
关卡名不区分大小写，支持 Tab 补全。已在小关中时需先返回大地图。

### noclip

`noclip` 切换穿行模式，`noclip enable` / `noclip disable` 显式开关。
开启后在游戏前台按物理 W/S/A/D，分别让受控整组移动 Y +1、Y -1、X -1、X +1，不发送方向键。

- 轻点一次移动一格，长按按 150 ms 间隔重复；忽略 Windows 自动重复和程序注入的按键。
- 离开游戏焦点会清空待执行移动；控制台、编辑器文字输入和带修饰键的快捷键不受影响。
- 只在本次运行中生效，不修改游戏碰撞代码。

### freecam

`freecam` 切换自由摄像机，`freecam enable` 开启，`freecam disable` 关闭并恢复原视角。
默认是鼠标视角模式，`freecam -pan` 是固定视角的平移模式；主世界和小关卡都可以使用。

| 按键 | 鼠标模式 | 平移模式 `-pan` |
| --- | --- | --- |
| W / S | 沿视线前进 / 后退 | 沿关卡上 / 下平移（Y +/-） |
| A / D | 向画面左 / 右平移 | 沿关卡左 / 右平移（X -/+） |
| Q / E | 沿世界 Z 轴下降 / 上升 | 远离 / 靠近地面（Z +/-） |
| 鼠标 | 转动视角，俯仰限制 ±89° | 不占用 |
| Shift / Ctrl | 加速 / 减速 | 加速 / 减速 |

- 已开启时再次执行 `freecam` 关闭。鼠标模式下 `freecam -pan` 切到平移模式，平移模式下 `freecam enable` 切回鼠标模式，再次 `freecam -pan` 则关闭。
- 长按连续移动，默认每秒 12 个世界单位，组合方向键不增加总速度；速度、灵敏度和倍率见配置选项。
- 鼠标模式下光标锁定在游戏窗口中心；打开控制台或编辑器、切到平移模式或关闭时释放。
- 开启时暂停编辑器播放、录制和 noclip 移动；切到其他应用或切换场景时自动关闭。配置中的 `noremap` 优先于摄像机按键。

### show subtitles

查看关卡的中英文字幕：

```text
show subtitles                          # 当前小关
show subtitles mirror_21
show subtitles mirror_21 -comment       # 显示 ++ 注释（黄色）
show subtitles mirror_21 -en            # 只显示英文，居中
show subtitles -cn mirror_21            # 只显示简体中文，-sc 相同
show subtitles mirror_21 -no_character  # 隐藏说话者名称，别名 -nosayer
```

- 名称和选项不区分大小写，选项可放在关卡名前后；`-en` 与 `-cn` 不能同时使用。Tab 补全有字幕的关卡名。
- 字幕直接从游戏安装目录（`game_path` 或正在运行的游戏）的 `data/strings/subtitles/en.subtitles` 和 `s-cn.subtitles` 读取，不复制、不修改游戏文件。
- 关卡名与字幕 ID 的对应关系在 `data/subtitles.json`，例如 `mirror_21` 对应 `mirror_post_clones_f` 及其 `_mid`、`_end` 段落。不在映射中的输入仍可按字幕 ID 直接查询。
- 默认左栏英文、右栏中文，按对白块对齐；某一语言缺少段落时显示提示。时间戳和清除标记不显示。
- 滚轮、Page Up / Page Down 浏览，Ctrl+Home / Ctrl+End 跳到开头或末尾；字幕不受 256 行限制。`clear` 清除字幕，其他有输出的命令也会返回普通终端。
- 通过 quick input 或快捷键执行时，会打开完整终端显示字幕。

游戏更新后可重新扫描安装目录生成映射，`--check` 只验证是否需要更新，`-o <文件>` 指定输出位置：

```powershell
jai scripts/generate_subtitles.jai - "<游戏目录>/data"
jai scripts/generate_subtitles.jai - "<游戏目录>/data" --check
```

### 解法编辑器 edit / open editor / close editor

```text
edit                    # 当前小关的解法，edit solution 是兼容别名
edit mirror_21          # 按名称加载
open editor             # 空白临时编辑器，保存时命名
edit custom my_test     # 打开已保存的自定义输入
close editor            # 关闭，有未保存修改时确认
```

- `edit` 打开当前小关在 `data/solutions.json` 中的解法；尚无记录时打开按场景名标识的空解法，保存后才写入。
- `edit <name>` 在没有同名关卡时也会查找自定义输入；名字不存在会报错并保留当前编辑会话。
- 播放前请先在游戏中进入对应关卡并回到解法起点；编辑器不重置关卡。
- `open editor` 不绑定关卡。保存时输入名称（字母、数字、中文、`_`、`-`、`.`，不含空格；`temp`、`solution` 保留），记录写入 `data/custom_inputs.json`。Meslo 缺少部分中文字形，建议使用 `my_test` 这样的英文名称。
- 保存前显示确认界面；名称已存在或文件在编辑期间被修改时要求确认 Overwrite。关闭编辑器、切换关卡、退出程序时如有未保存修改，提供 Save / Discard / Cancel。
- 编辑器开启期间请使用编辑器自己的播放和撤销；要运行独立的 `send` / `send_alt` / `play` / `do` / `undo`，先 `close editor`。

编辑器打开后可在终端使用以下命令，未打开编辑器时报错：

| 命令 | 行为 |
| --- | --- |
| `record` | 开始录制并把焦点交给游戏；重复执行仍保持录制 |
| `pause` | 暂停播放，保留录制开关和当前位置 |
| `stop` | 停止播放和录制，保留当前位置和全部指令 |
| `save` | 打开保存确认界面，确认后才写入文件 |
| `jump <n>` / `j <n>` | 前进或撤销到第 n 步，不重置游戏：`jump 0` 回到起点，`jump $` 到末尾。前向 75 ms 并按住加速键，后向 10 ms |

`jump` 的范围是 0 到解法总步数，越界或格式错误时保留当前状态。有效跳转会把焦点交给游戏，终端自动隐藏，编辑器继续显示。
`j` 缩写只用于终端输入；编辑器或游戏获得焦点时，`J` 是加快播放一档。

### 编辑器操作

编辑器显示在游戏画面底部，竖直播放线固定在中间：左侧是已发送到游戏的指令，右侧是未来指令。
时间线用箭头显示 U/D/L/R，C 显示为切换图标，X 为函数图标，等待格为睡眠图标。底部按钮使用 Nerd Font 图标，悬停显示操作名称。

| 操作 | 效果 |
| --- | --- |
| 向右拖动 / 向上滚轮 | 以 10 ms 周期快速回退；可撤销的动作发送 Z，C、数字键和等待格只回退时间线 |
| 向左拖动 / 向下滚轮 | 每跨过一格执行一条未来指令，75 ms 并按住加速键 |
| 链接按钮 | 开关拖动 / 滚轮是否影响游戏；关闭时只移动播放起点，不发送输入 |
| Record | 开始 / 停止录制游戏中的键盘输入 |
| Undo / `[`、Step / `]` | 撤销 / 执行一步，250 ms |
| Play / Pause、Space / `K` | 播放 / 暂停；Space 优先于游戏的加速键绑定 |
| `J` / `L` | 加快 / 放慢一档，共五档，长按不会连续换档 |
| 游戏加速键 / 减速键 | 播放中切换为 `-fast` / `-turtle` |
| Rabbit | 从当前执行边界快速播放剩余解法，75 ms 并按住加速键 |
| 点击格子 | 放置文本光标；未来格可插入和替换，已执行格可选择和删除 |
| W/S/A/D 或方向键 | 插入上 / 下 / 左 / 右移动；C/X/F/V 和数字键插入对应动作 |
| B / `_` | 插入一个等待格 |
| Ctrl + ← / →、Home / End | 移动文本光标，按住 Shift 选择 |
| Ctrl + A | 全选光标所在侧（已执行或未来） |
| Backspace / Delete | 删除格子，包括已执行部分；只修改时间线，不向游戏发送撤销 |
| Ctrl + C、Export | 把完整解法按 UDLR 格式复制到剪贴板，可直接用于 `send_alt` |
| Ctrl + V / Shift + Insert | 按 UDLR 格式粘贴，支持 `R4X2` 等缩写 |
| Ctrl + 滚轮 | 调整格子宽度 |
| Save / Ctrl + S | 打开保存确认 |
| Reset | 重置游戏并恢复上次保存的解法，播放位置回到 0，丢弃未保存修改 |
| `N` / Minimize / Edit | 在精简时间线和完整编辑器之间切换，保留播放位置和未保存修改 |
| Exit | 关闭编辑器，有修改时先确认 |
| Esc | 暂停播放，返回游戏输入 |

- 录制把每次真实按下的游戏按键插入播放线处并推进播放线，保留原来的未来：`UUU|LLLL` 中录制 `sssddd` 后成为 `UUUDDDRRR|LLLL`。请逐次按键，长按不会推断成多次移动。
- 录制时按游戏重置键（默认 R）会删除已执行指令，保留未来并继续录制。未录制时按 R 或执行 `reset`，整段解法回到起点。
- 未录制时可在游戏中手动移动到起点再播放，手动移动不追加记录。
- C、数字键和等待格不进入游戏的撤销记录：回退经过它们时不发送 Z；玩家在游戏中按 Z 时，时间线跳过末尾的角色切换再回退一条实际动作。
- `U/D/L/R` 对应 Forward/Backward/Left/Right，`C/X/F/V` 对应切换角色/Activate/FriendlyDragon/TakeOrDrop，键位从 `User.keymap` 读取。

播放速度共五档，当前速度显示在时间线的进度文字中；暂停后保留选择，Step / Undo 按钮始终为 250 ms：

| 速度 | 每步周期 | 游戏时间键 |
| --- | --- | --- |
| superfast | 75 ms | 按住 HoldForFastTime |
| fast | 175 ms | 无 |
| normal | 250 ms | 无 |
| slow | 500 ms | 无 |
| superslow | 750 ms | 按住 HoldForSlowTime |

## 数据文件

程序目录下的 `data/`：

| 文件 | 内容 |
| --- | --- |
| `solutions.json` | 关卡解法数组，每条包含 `position`、`area`、`name`、`note`、`solution`。从 `marker.json` 的关卡 Point 生成，并按名称用 `solutions.txt` 预填；再次导入只添加缺少的关卡，不覆盖已保存的解法和备注 |
| `custom_inputs.json` | `open editor` 保存的自定义输入，格式同上，按名称区分 |
| `markers.json` | 位置标记和下一个自动寄存器 `next_register` |
| `marker.json` | 关卡入口坐标，供 `switch` 使用 |
| `subtitles.json` | 关卡名到字幕 ID 的映射，由 `scripts/generate_subtitles.jai` 生成 |

保存时先写临时文件再替换目标文件；保存失败会保留原数据和编辑内容供重试。

## 开发参考

- 命令表在 `src/ui/console.jai`；按键发送在 `src/game/commands.jai` 和 `src/platform/windows/input.jai`；编辑器在 `src/solution/`。
- `src/platform/windows/overlay.jai` 中的 `OVERLAY_HEIGHT_PERCENT` 和 `OVERLAY_OPACITY` 控制终端高度比例和不透明度；配色和字幕角色名颜色在 `src/ui/console_theme.jai`。
- 内存地址定位、读写实现和游戏更新后的适配步骤见 [game-memory.md](game-memory.md)。
