# 游戏内存定位与读写

本文记录 ootss-cmd 如何在 `sinking_star.exe` 进程中定位当前场景、识别受控角色、读写玩家坐标，以及游戏更新后的重新验证方法。
文中的 RVA、字段偏移、实体 ID 和坐标都是特定 Demo 构建的观测值，只作为版本证据。
生产代码只依赖运行时校验通过的代码特征和游戏自带的 Jai 反射元数据，不保证任何偏移在新版本继续有效。

## 实现入口

| 文件 | 作用 |
| --- | --- |
| `src/platform/windows/process.jai` | 查找进程和模块、解析内存中的 PE、封装 Windows 内存读写 |
| `src/game/memory.jai` | 定位当前场景管理器、筛选 `Guy`、读写和校验 XYZ |
| `src/game/position_reader.jai` | 校验签名、完整实体列表、所有 Guy 的身份和选择状态；读取受控整组及基准，供写入期间复核 |
| `src/game/position_selection.jai` | 按反射名称解析 `status_flags` / `ACTIVE`，按 XYZ 字典序选取基准实体 |
| `src/game/position_layout.jai` | 解析 Jai 反射元数据，验证五个 Vector3 字段并同步位置；读取场景名称 |
| `src/game/level.jai` | 独立读取当前场景资源名，区分 Overworld 与小关，供无名称命令使用 |
| `src/game/position_commands.jai` | 坐标、标记和 `switch` 命令；位移不发送方向键 |
| `src/game/position_markers.jai` | 在 `data/markers.json` 保存标记和 a–z 寄存器，迁移旧文件 |
| `src/game/noclip.jai`、`src/platform/windows/noclip.jai` | 拦截物理 WASD 并排队移动；排除注入按键，失焦时清除待执行移动 |
| `src/game/keymap.jai` | 读取实际键位，包括 `switch` 使用的 TakeOrDrop（默认 V） |
| `src/platform/windows/input.jai` | 发送并释放按键，检查焦点和中断 |

参考项目 [SinkingStarHero](https://github.com/wudi-7mi/sinkingstarhero) 位于本地 `.refs/sinkingstarhero`（不入库）：`src/sinking_star_light_trainer.py` 提供实体列表、类型信息和旧版本偏移，`tools/level_probe.py` 提供场景探查方法。
参考 trainer 通过 hook 捕获玩家；本项目改为遍历当前场景的实体列表，读取坐标不注入代码、不安装游戏内 hook。

## 地址链

方括号表示从目标进程读取指针，不是在辅助程序中直接解引用：

```text
sinking_star.exe 的实际模块基址 B
  → 扫描已加载 PE 的 .text，匹配唯一的代码特征
  → 解码 RIP 相对引用，得到当前场景管理器的全局指针槽 S
  → manager = read_u64(S)
  → count   = read_u64(manager + 0x370)
  → objects = read_u64(manager + 0x378)
  → 逐个读取 objects[i]，校验所属场景及 Guy 类型
  → 按反射发现的 status_flags / ACTIVE 筛出当前受控集合
  → 每个受控 entity + 0 / +4 / +8：三个 float32，依次为 X / Y / Z
  → 按 X、Y、Z 顺序比较，选择最小的实体作为位置基准
```

### 代码特征

```text
4C 8B 35 ?? ?? ?? ?? 49 83 BE A8 0D 00 00 02
```

```asm
mov r14, [rip + disp32]
cmp qword ptr [r14 + 0xda8], 2
```

设匹配位置相对模块基址的偏移为 `r`：

```text
disp    = little_endian_signed_int32(code[r + 3 : r + 7])
S       = B + r + 7 + disp
manager = read_u64(S)
```

- `disp32` 是有符号数，`7` 是第一条指令的长度。
- 特征必须只有一个匹配，计算出的指针槽必须完整位于模块内。
- ASLR 会改变 B，不能保存一次运行的绝对地址供下次使用。

### 玩家实体校验

| 位置 | 类型 / 要求 |
| --- | --- |
| `manager + 0x370` | u64 对象数，必须在 1–20000 之间 |
| `manager + 0x378` | u64 对象指针数组，完整可读 |
| `entity + 0xF0` | u64 所属管理器，必须等于当前 manager |
| `entity + 0x100` | u32 实体 ID，用于区分连续采样中的玩家身份 |
| `entity + 0x108` | u64 类型描述符指针，必须位于可执行模块内 |
| `type + 0x00` | u32 kind，必须为 7 |
| `type + 0x08` | u32 实体大小，至少 `0x110` |
| `type + 0x10` | u64 名称长度，必须为 3 |
| `type + 0x18` | u64 名称指针，位于模块内，内容精确为 `Guy` |
| `entity + 0x00/04/08` | float32 XYZ，有限，绝对值不超过 1000000 |

- 当前场景可以包含多个 `Guy`，每次按反射验证的 `Status_Flags.ACTIVE` 确定受控集合；未选中的 Guy 不参与位置基准和写入。
- 没有有效受控实体、越界、读取字节不足、场景切换和未知布局都返回错误。三个合理的浮点数不能作为找到玩家的依据。
- 游戏会保留先前场景的 manager 和 `Guy`，其中的坐标同样合理。调查时曾通过扫描可写模块数据找到多个候选 manager，最终靠反汇编引用确定当前场景的全局指针，因此不能选第一个符合类型的对象或第一个合理的根指针。

### 历史观测值

| 项目 | 值 |
| --- | --- |
| Demo 构建 | r62164，Steam public-testing |
| `sinking_star.exe` SHA-256（2026-09-13） | `FF806DCB5D6E72FC8D5911AA13EC339D23B3D85B242AF5762F389DC93E15D726` |
| 特征 RVA | `0x1B937B` |
| 槽 RVA | `0xA49CF0` |
| 只读探查结果 | `promesst1_streamlined` 中读到 `(15, 15, 0)` |

用 SHA-256 比较游戏文件是否变化；运行时仍须校验代码特征和实体元数据。

### 不再沿用的旧地址

- 旧方案的 `sinking_star.exe + 0x009AF218` 在当时安装的游戏中读到空指针，已移除。
- 参考 trainer 的 manager 槽 RVA 为 `0x009ACB50`，与本地 Demo 不同。只有旧版本 `0x2AF0CC` 处的 19 字节精确匹配下列特征时，代码才允许兼容这个旧槽：

  ```text
  80 7C 24 60 00 75 51 80 7C 24 76 00 74 4A 45 84 F6 74 2C
  ```

- 这段 gate 特征在本地 Demo 中位于 `0x2BF73C`，说明版本不同；把所有地址平移相同距离并不能修复。
- 参考代码的 pick 特征 `49 8D 8C 24 88 03 00 00 EB 3D` 在本地 Demo 中不存在。代码和字段布局都可能改变。

## 位置字段

2026-09-13 在同一 Demo 上，从游戏自带的 Jai 类型元数据读到以下字段。样本 `Guy` 类型 RVA 为 `0x5F20A8`，大小 `0x650`。
生产代码按字段名和类型逐层解析，表中偏移只作版本证据：

| 完整成员路径 | 相对 Guy 的样本偏移 | 写入值 |
| --- | --- | --- |
| `entity.undoable_data.position` | `0x00` | 目标 XYZ |
| `entity.undoable_data.visual_position` | `0xA0` | 目标 XYZ |
| `entity.output_position` | `0x1D8` | 目标 XYZ |
| `pre_move_position` | `0x350` | 目标 XYZ |
| `velocity` | `0x338` | `(0, 0, 0)` |

### Jai 类型元数据布局

- 类型头前 32 字节为四个 u32：kind、ID、size、padding；随后是名称的 u64 count/data。
- 结构体成员数组的 count/data 位于类型描述符 `+0x40/+0x48`。成员步长 64 字节：名称 count/data 在 `+0/+8`，类型指针在 `+16`，有符号字段偏移在 `+24`，flags 在 `+32`；flags 带常量位（`& 1`）的成员拒绝写入。
- 枚举类型：internal_type 位于 `+32`，names 的 count/data 位于 `+40/+48`，values 的 count/data 位于 `+56/+64`（s64），enum status_flags 位于 `+72`，enum_type_flags 位于 `+74`。

### 字段校验规则

- 五个字段必须使用同一份 `Vector3` 元数据，大小均为 12；其 x/y/z 必须是 kind=1、大小 4 的浮点成员，偏移依次为 0/4/8。
- 每一层检查字段完整落在父结构体内、成员名称唯一、类型和名称数据位于模块内。
- 最终字段不得互相重叠，也不得覆盖识别玩家用的 owner、实体 ID 或类型指针。
- 只写这五个字段，不修改变换矩阵、网格缓存或其他数值相等的浮点数。
- 反射通过和读回成功只证明字段位置正确，不等于完整验证了游戏内的瞬移画面、碰撞缓存和下一次移动。

## 受控角色的选择

### 选择状态的来源

`position_selection.jai` 按 `Guy.entity.undoable_data.status_flags` 的成员名称逐层发现偏移，要求：

- `Status_Flags` 是完整的 enum，底层为 unsigned 16-bit integer；
- 名称数组中恰好一个 `ACTIVE`，其值是能放入 u16 的正单比特；
- 本地 Demo 的 `Status_Flags` 是普通 enum（`enum_type_flags = 0`），因此不要求它带 enum_flags 标记。

实际 `ACTIVE = 4` 与字段偏移 `0x5C` 只是观测证据，不作为未知版本的硬编码回退。

2026-09-14 通过枚举元数据确认的名称和值：

| 完整字段 / 枚举 | 样本偏移及类型 | 观察 |
| --- | --- | --- |
| `entity.undoable_data.status_flags` / `Status_Flags` | `0x5C`，u16 | `DEAD=1`、`FALLING=2`、`ACTIVE=4`、`ON_EXIT=16`、`TRANSMUTING=32` |
| `entity.undoable_data.entity_flags` / `Entity_Flags` | `0x28`，u64 | 包含 `MIRRORED=65536`；镜像标记本身不等于当前受控 |
| `skill_flags` / `Skill_Flags` | `0x348`，u32 | 包含 `TRADER=2048` 等；技能相同不能证明属于同一控制组 |
| `turn_order_id` | `0x368`，4 字节 `Pid` | 同组副本共享该 ID；只是额外线索，未证明足以单独定义控制组 |

`Entity.entity_manager` 指向 `Entity_Manager`，但此构建的 manager 类型没有成员反射记录（`TYPE_INFO_NONE`），无法按字段名发现 manager 的选择列表。

### 命令语义

- 每次请求重新识别当前受控角色及其所有同时受控的镜像副本，排除未选中的角色。
- `show position` 取该集合内实际实体 `(x, y, z)` 的字典序最小值：先比 X，再比 Y，再比 Z；坐标完全相同时按实体 ID 决定。不分别取各轴最小值拼成虚拟点。
- `set position` 用“目标坐标减去锚点坐标”作为整组统一位移，`move` 用参数作为整组位移，二者保持组内相对位置。`mark`、`back` / `tp` 和 noclip 复用相同语义。
- 没有 ACTIVE 实体时返回错误，不回退到第一个 Guy。

### 只读样本

以下样本均在上述 SHA-256 的 Demo 中采集。只读脚本 `.build/inspect_control_state.py` 只申请查询和读取权限，不注入按键、不写游戏内存；证据保存在本地 `.build/control_state_*.json`。

| 场景 | 观察 | 结论 |
| --- | --- | --- |
| `heroes1_15` | 两个 Guy：ID `1048594` 在 `(2, 1, 0)`，`status_flags=4`；ID `1048608` 在 `(6, 1, 0)`，`status_flags=0` | `ACTIVE` 可区分选择状态 |
| `mirror_12` | 用户确认三个角色同时受控。三个 Guy 全部 `status_flags=4`，只有 ID `1072693267` 带 `MIRRORED`；`turn_order_id` 都是 `1048631`，`skill_flags` 都是 `2`（SINGLE_PUSH） | 按 `MIRRORED` 筛选会漏掉两个受控实体；锚点为 `(4, 2, 0)`，ID `1072693298` |
| `quadrants_follow_up` | `thief` 与 `thief_alt` 通过 C 分别切换，不同时控制。两个 Guy 技能都是 `4`（PULL），`MIRRORED` 均未置位；ID `50331737` 在 `(8, 17, 0)` 为 0，ID `59768875` 在 `(8, 19, 0)` 为 ACTIVE，各自 `turn_order_id` 不同 | 技能相同不等于同组；锚点应为 `(8, 19, 0)`，不能把未选中实体加入集合 |
| `quadrants_follow_up`（按 C） | 用户按一次 C 且角色不移动：ID `59768875` 的 ACTIVE 从 4 变 0，ID `50331737` 从 0 变 4；场景、ID 和坐标不变 | C 切换只改变 `status_flags`，选择读取不能依赖对象列表变化 |

尚未验证：数字键切换、镜像产生 / 移除的动态过程，以及真实游戏内的整组坐标写入。

### 编辑器不做的事

编辑器没有 Check 按钮、静止移动标记，也不在录制 / 播放时采样玩家位置：多角色和原地改变机关的动作无法仅凭坐标变化判断是否有效，由玩家自行选择并删除时间线记录。
读取本身开销很小（同一 Demo 上 1000 次有缓存读取平均约 0.018 ms），不是取消该功能的原因。

## 读写流程

1. 通过游戏窗口取得 PID，枚举 `sinking_star.exe` 模块，取得本次运行的基址和大小。查询只申请 `PROCESS_QUERY_LIMITED_INFORMATION | PROCESS_VM_READ`，`ReadProcessMemory` 必须报告完整读取。
2. 只有明确的坐标修改才追加 `PROCESS_VM_WRITE | PROCESS_VM_OPERATION`。位置命令使用 `game_write_position_to(..., instant = true)`，每次创建新的 reader，重新解析当前 manager、完整对象列表、所有 Guy 的选择状态及受控集合。
3. `set position` 用目标减去锚点，`move` 直接用给定偏移，为每个受控实体计算目的地；用 float64 检查范围后转为 float32，保持组内相对位置。单轴 X/Y 的零偏移不写内存、不切换焦点。
4. 第一笔写入前解析所有受控实体的全部五个字段，检查目的地与原值完整可读、有限且在允许范围。拒绝未知、损坏、越界、彼此重叠、覆盖身份或选择状态的字段，以及实体之间的内存重叠；重复的实体指针去重。
5. 对每个受控实体依次清零 `velocity`，再同步 `pre_move_position`、`position`、`visual_position`、`output_position`。每次 `WriteProcessMemory` 只写该字段的 12 字节；字段之间复核签名、完整实体列表、所有 Guy 的 owner、类型、实体 ID 和选择状态，最后读回每个目标的全部字段。按整组身份判断，不因平移中途空间锚点暂时改变而停止。不覆盖整个 Guy 结构。
6. 发生部分写入、控制组切换或读回失败时停止。`changed` 表示可能已经改变游戏，错误信息不声称没有修改，也不自动回写旧值。这是逐字段、逐实体写入，不是原子事务。底层保留的逻辑坐标测试路径同样按受控整组处理，但不替代正式命令的 instant 路径。

### 命令与写入的关系

- `set position`、各形式 `move`、`move_xy`、`back` / `tp` 只同步上述字段，不补发任何方向键；旧的“原生移动后纠正一格”逻辑已移除。
- 控制台位移等待 Enter / 修饰键释放并交回游戏焦点；quick input 关闭后只允许向提交时的同一游戏 HWND / PID 执行。
- `noclip` 消费物理 WASD，每次通过相同 writer 请求一格位移，不发送替代方向键、不阻塞等待按键周期。持续按住按 `NOCLIP_REPEAT_DELAY`（150 ms）重复，这不是已验证的游戏最低间隔。只按进程生命周期缓存签名 locator，使用前复核代码字节；玩家地址不跨写入复用。失焦、游戏切换、保存确认或失败会清除待移动队列，注入事件不会触发移动。
- 保存确认期间拒绝坐标修改。写入后暂停编辑器录制和播放，保留解法、执行边界和未保存修改；手动对齐后可继续播放、跳转和录制。

### 共享 reader

- `Game_Position_Reader` 核对定位指令的完整字节、当前 manager、对象数量及完整指针数组；列表改变时重新解析所有有效 `Guy`。同一列表也会重新读取所有 Guy 的 owner、类型、实体 ID 和 `status_flags`，对 ACTIVE 实体读取 XYZ，再复核完整列表和所有身份，拒绝混合切换前后的控制组。
- `selection_version` 记录选择或身份变化，因此 C / 数字键切换不依赖对象列表变化，也不需要辅助程序捕获按键。
- `allow_resolve = false` 时不打开进程、不扫描代码、不分配内存、不重新搜索实体，只在一次写入内核对原控制集合，变化时立即失败。
- `game_position_sample_same_group` 允许空间锚点在分批平移中改变，但不授权下一次写入复用原实体地址。

## 当前场景名与 switch

- 当前 manager 的 `+0x00/+0x08` 是 Jai 字符串的 count/data，已观察到 `overworld`、`promesst1_streamlined`、`intro` 和 `quadrants_follow_up`。
- `src/game/level.jai` 的 `game_read_scene` / `game_read_scene_from` 通过同一代码特征定位 manager，独立读取名称，不读取 Guy、选择状态或 XYZ。名称限制为 1–128 字节的资源名（字母、数字、下划线、连字符和点），完整读取后再次核对签名、manager 指针、字符串头及内容；场景或名称改变时返回错误，不保留上次关卡供失败时使用。
- 2026-09-14 用只申请 QUERY_LIMITED_INFORMATION / VM_READ 的生产接口（`position_tests.exe --read-level`）在同一 Demo 中读到 `quadrants_follow_up`。
- `show level` 显示场景名并区分 Overworld。无名称的 `show subtitles`、`play`、`do`、`edit` 通过 `game_resolve_level_name` 使用已进入的小关；Overworld、菜单和非关卡场景不能作为默认小关。显式名称不调用场景读取。
- `switch <level_name>` 从 `data/marker.json` 读取官方关卡入口，保留同坐标的不同关卡名，不用改名的解法或 custom input 替换目录名称。先验证名称、坐标、当前场景为 `overworld`（`game_player_scene_name` 配合已验证玩家检查）和 `User.keymap` 中的 `TakeOrDrop` 绑定，再瞬移；写后核对玩家和坐标，最后发送并释放 TakeOrDrop（默认 V）。在小关内拒绝该命令；普通位置命令不发送这个键。

## 关卡数据

`data/levels.package`、`.entities`、`.level_manifest` 和 `.level_set` 的格式，以及离线制作自定义关卡的方法，见 [custom_levels.md](custom_levels.md)。与本文相关的两点：

- 可执行文件保留了编辑器与控制台：反射选项名 `open_editor`、`open_console`、`editor_level`、`cheats`、`no_sound`、`no_steam`、`running_packaged` 等成簇出现，还有 `level`、`switch`、`Restart`、`Playtest` 等控制台命令名。参考 trainer 使用 `-open_console` 启动参数；打包版能否真正打开编辑器尚未验证。
- 参考 trainer 的运行时刷对象通过注入代码调用游戏的 create / init / register / apply_diff 函数（旧版 RVA）。本项目不采用代码注入。

## 游戏更新后的排查流程

1. **记录实际版本。** 找到正在运行的可执行文件，记录路径、大小、时间和 SHA-256。历史路径是 `E:/SteamLibrary/steamapps/common/Order of the Sinking Star Demo/sinking_star.exe`，不能假定未来仍然如此。

   ```powershell
   Get-Process -Name sinking_star | Select-Object Id, Path
   Get-FileHash -LiteralPath '实际游戏路径/sinking_star.exe' -Algorithm SHA256
   ```

2. **区分环境错误和版本错误。** 未启动、尚未加载关卡、进程权限不足和特征未匹配是不同问题。Windows error 5 是访问被拒绝，不证明偏移失效。
3. **先只读复现。** 记录模块范围、代码段 RVA、特征匹配数、解码出的槽、manager、对象数、`Guy` 数量及坐标，不要输出整块进程内存。
4. **检查旧特征是否还能定位。** 读取已加载 PE 的 `.text`，验证 PE32+ / x64、段大小和边界。也可以离线扫描 exe，但磁盘文件偏移不等于 RVA，必须按节表转换。
5. **特征失效时定位引用。** 对照 `.refs/sinkingstarhero` 的代码、字符串、类型名与原指令。可用只读 Python `ctypes` 探查，或用 `objdump -d -Mintel` 反汇编（本机为 `C:/msys64/ucrt64/bin/objdump.exe`，未安装 Capstone）。
6. **候选只是候选。** 必要时只读扫描可写模块段中的合理 manager 指针，逐一验证对象列表、`Guy` 类型和 owner；进入 / 退出多个场景再采样，确定哪个根随当前场景变化，并反向检查该全局变量的代码引用。不能把扫描得到的第一个候选放进写入路径。
7. **重新验证字段。** 特征找到不代表 `0x370/0x378`、`0xF0`、`0x108` 或 XYZ 仍有效。比较已知位置和移动前后的样本，检查类型元数据和邻接字段。
8. **选择有边界的定位方式。** 新特征应包含稳定操作码，把 RIP 位移等易变字节设为通配符，并验证唯一性和目标范围。证据不足时返回“不支持此版本”，不加入只凭版本名或裸 RVA 的写入回退。
9. **同步代码、测试和本文。** 区分新的历史观测值和算法要求；记录游戏文件 hash、证据及不再成立的偏移。旧版本支持只在其指令证据匹配时生效。

## 验证

`tests/` 目录在本项目被 Git 忽略；若当前 checkout 缺失，需建立同等的隔离夹具，不依赖旧的 `.build` 产物。
常规测试不写真实游戏内存、不发送真实游戏输入、不查看截图。

```powershell
jai -quiet tests/position_first.jai
.\.build\position_tests.exe               # 进程内 PE / 实体夹具
.\.build\position_tests.exe --read-level  # 只读取正在运行游戏的场景名
.\.build\position_tests.exe --read-game   # 只读取真实游戏的玩家和场景，需要有可读玩家
```

| 测试 | 覆盖 |
| --- | --- |
| `tests/position.jai` | 唯一 / 缺失 / 重复特征、有符号 RIP 位移、旧版本回退、场景切换、多玩家、无效坐标、相对移动边界、只读句柄写入失败 |
| `tests/position_layout.jai` | 完整 Guy / 反射夹具：五个字段精确写入、其他字节保持原样，重叠 / 常量 / 越界 / 不兼容类型在写入前失败 |
| `tests/position_reader.jai` | 冷启动、禁用重新定位的验证路径、连续坐标变化、同数量列表替换、场景切换、多 Guy、签名字节变化 |
| `tests/position_selection.jai` | 同列表内选择变化、独立 thief 变体、多个 ACTIVE、副本指针去重、XYZ 字典序及实体 ID 平局、整组平移、未选角色逐字节不变、末尾副本损坏或越界时全组拒绝、部分写入后 `changed = true` 且不回滚 |
| `tests/position_storage.jai` | 标记迁移、schema、官方入口查找和改绑的 TakeOrDrop，使用隔离 JSON |
| `tests/level.jai` | 场景读取独立于多 Guy、无效坐标和实体列表；背景场景、过渡时根指针 / 名称头 / 内容改变、无效名称、唯一特征和只读权限 |
| `tests/current_level_commands.jai` | 默认 `edit` / `play` / `do`、Overworld 拒绝、显式名称独立性、相同坐标下的不同关卡记录；保存测试使用 `.build/current_level_save` 的独立数据 |
| `tests/editor_features.jai`（经 `tests/controls_first.jai`） | 固定中心线、链接开关两种拖动语义、禁用游戏输入后选定新起点、已执行格删除、五档速度；使用模拟按键 |
| noclip 回归 | 四方向、点击 / 持键节奏、队列、取消和注入事件过滤 |

`--read-game` 在同一 Demo 的 `overworld` 读到 `(81, 62, 0)`，五个位置字段反射通过，1000 次有缓存的复核读取全部有效。这不等同于游戏内碰撞和后续原生移动已经验收。

`.build/` 下的 Python 探查脚本（`position_probe.py`、`inspect_position_state.py`、`inspect_control_state.py`）和证据 JSON 都是调查时的临时产物，不是生产代码或测试的依赖。

需要构建 GUI 时，优化构建输出到 `bin/`，避免替换仍在运行的根目录程序；打包保留安装目录已有的 `markers.json`、`position_markers.json`、`solutions.json`、`custom_inputs.json`、Zork 存档和 `config.rc`：

```powershell
jai -quiet first.jai -optimized -import_dir modules
```
