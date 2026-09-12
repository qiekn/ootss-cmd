---
name: ootss-game-memory
description: 在 ootss-cmd 中定位、读取和修改 Order of the Sinking Star 的玩家坐标，调查当前场景信息，并在游戏更新后重新验证内存布局。适用于位置命令、noclip、当前关卡识别、玩家地址失效和 SinkingStarHero 参考布局的兼容排查。
---

# 玩家内存定位与版本适配

从项目根目录执行操作。先阅读根目录 `AGENTS.md`，保留用户的代码和游戏数据；本技能记录的是已验证的方法，不保证任何 RVA 或字段偏移在新版本继续有效。

## 实现入口

| 文件 | 作用 |
| --- | --- |
| `src/platform/windows/process.jai` | 找进程和模块、解析内存中的 PE、封装 Windows 内存读写 |
| `src/game/memory.jai` | 定位当前场景管理器、筛选 `Guy`、读写和校验 XYZ |
| `src/game/position_reader.jai` | 验证签名、完整实体列表、所有 Guy 的身份和选择状态；读取受控整组及基准，用于写入期间的复核 |
| `src/game/position_selection.jai` | 按反射名称解析 status_flags / ACTIVE，按 XYZ 字典序选取实际受控实体 |
| `src/game/level.jai` | 独立读取当前场景资源名，区分 Overworld 与小关，供无名称命令使用 |
| `src/game/position_layout.jai` | 解析 Jai 反射元数据、验证五个 Vector3 字段并同步位置；读取场景名称 |
| `src/game/position_commands.jai` | 坐标、标记和 switch 命令；普通位移不发送方向键 |
| `src/game/position_markers.jai` | 在 data/markers.json 保存用户标记和 a–z 寄存器，迁移旧文件 |
| `src/game/noclip.jai`、`src/platform/windows/noclip.jai` | 拦截物理 WASD、排队移动；排除注入按键，失焦清除待执行移动 |
| `src/game/keymap.jai` | 读取实际绑定，包括 switch 使用的 TakeOrDrop（默认 V） |
| `src/platform/windows/input.jai` | 发送并释放按键，检查焦点和中断 |
| `.refs/sinkingstarhero/src/sinking_star_light_trainer.py` | 参考 trainer 的实体列表、类型信息和旧版本偏移 |
| `.refs/sinkingstarhero/tools/level_probe.py` | 参考项目的场景探查方法 |

参考目录实际为 **`.refs/sinkingstarhero`**。参考 trainer 还有捕获玩家的 hook 路径；本项目采用当前场景的实体列表，读取坐标不需要注入代码或安装游戏内 hook。

## 地址是怎样找到的

地址链如下。方括号表示从目标进程读取指针，不是在辅助程序中直接解引用。

```text
sinking_star.exe 的实际模块基址 B
  → 扫描已加载 PE 的 .text，匹配唯一的代码特征
  → 解码 RIP 相对引用，得到当前场景管理器的全局指针槽 S
  → manager = read_u64(S)
  → count = read_u64(manager + 0x370)
  → objects = read_u64(manager + 0x378)
  → 逐个读取 objects[i]，校验所属场景及 Guy 类型
  → 按反射发现的 status_flags / ACTIVE 筛出当前受控集合
  → 每个受控 entity + 0 / +4 / +8：三个 float32，依次为 X / Y / Z
  → 按 X、Y、Z 顺序比较，选择最小的实际实体作为位置基准
```

当前代码特征：

```text
4C 8B 35 ?? ?? ?? ?? 49 83 BE A8 0D 00 00 02
```

对应指令：

```asm
mov r14, [rip + disp32]
cmp qword ptr [r14 + 0xda8], 2
```

设匹配位置相对模块基址的偏移为 `r`：

```text
disp = little_endian_signed_int32(code[r + 3 : r + 7])
S = B + r + 7 + disp
manager = read_u64(S)
```

注意 `disp32` 是**有符号数**，`7` 是第一条指令的长度。必须只有一个匹配，且计算出的指针槽完整位于模块内。ASLR 会改变 B；不要保存一次运行的绝对地址供下次使用。

已观察到的一次 Demo 构建中，特征 RVA 为 `0x1B937B`，槽 RVA 为 `0xA49CF0`；只读探查得到 `promesst1_streamlined` 的 `(15, 15, 0)`。这些是历史观测值，不是后续版本的固定配置。

2026-09-13 记录的本地 Demo `sinking_star.exe` 文件 SHA-256：`FF806DCB5D6E72FC8D5911AA13EC339D23B3D85B242AF5762F389DC93E15D726`。用它比较文件是否变化；运行时仍须校验代码特征与实体元数据。

### 玩家实体的独立校验

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

当前场景可以包含多个不同 `Guy`，每次按经过反射验证的 `Status_Flags.ACTIVE` 确定受控集合；未选中的 Guy 不参与位置基准或坐标写入。没有有效受控实体、越界、读不足字节、场景切换和未知布局均返回错误。不要因为看到了三个合理浮点数就认定找到了玩家。

游戏会保留先前场景的 manager 和 `Guy`，其中的坐标也可能完全合理。曾通过可写模块数据扫描找到多个候选 manager，最终通过反汇编引用确定当前场景的全局指针。因此**不能选第一个符合类型的对象或第一个合理的根指针**。

### 旧地址为什么不直接沿用

- 旧方案的 `sinking_star.exe + 0x009AF218` 在当时安装的游戏中读到空指针，已移除。
- 参考 trainer 的 manager 槽 RVA 为 `0x009ACB50`，与当时安装的 Demo 不同。
- 仅当旧版本 `0x2AF0CC` 处的 19 字节精确匹配下列特征时，代码才允许兼容旧槽：

  ```text
  80 7C 24 60 00 75 51 80 7C 24 76 00 74 4A 45 84 F6 74 2C
  ```

- 上述 gate 特征在实际 Demo 中移动到 `0x2BF73C`；这说明版本不同，不代表把所有地址平移相同距离就能修复。
- 参考代码的 pick 特征 `49 8D 8C 24 88 03 00 00 EB 3D` 在该 Demo 中不存在。代码和字段布局都可能改变。

## 经反射验证的位置字段

2026-09-13，同一 Demo hash 的只读探查从游戏自带的 Jai 类型元数据读到了以下字段。样本 `Guy` 类型 RVA 为 `0x5F20A8`，大小 `0x650`；生产代码按字段名和类型逐层解析，表中偏移只作版本证据。

| 完整成员路径 | 相对 Guy 的样本偏移 | 写入值 |
| --- | --- | --- |
| `entity.undoable_data.position` | `0x00` | 目标 XYZ |
| `entity.undoable_data.visual_position` | `0xA0` | 目标 XYZ |
| `entity.output_position` | `0x1D8` | 目标 XYZ |
| `pre_move_position` | `0x350` | 目标 XYZ |
| `velocity` | `0x338` | `(0, 0, 0)` |

Jai 类型头的前 32 字节为四个 u32（kind、ID、size、padding），后接名称的 u64 count/data。结构体成员数组的 count/data 位于类型描述符 `+0x40/+0x48`。成员步长 64 字节：名称 count/data 在 `+0/+8`，类型指针在 `+16`，有符号字段偏移在 `+24`，flags 在 `+32`；拒绝 flags 的常量位 `& 1`。

五个字段必须使用同一份 `Vector3` 元数据，大小均为 12；其 x/y/z 必须是 kind=1、大小=4 的浮点成员，偏移依次为 0/4/8。每一层检查字段完整落在父结构体内、成员名称唯一、类型和名称数据位于模块内。最终字段不得互相重叠，也不得覆盖识别玩家用的 owner、实体 ID 或类型指针。

临时证据保存在 `.build/player_field_metadata.json`，只读调查脚本为 `.build/inspect_position_state.py --members`；它们不是生产代码的依赖。此前几个相同浮点数的候选已通过字段名称、类型和嵌套关系得到进一步确认。仍未验证真实游戏中的瞬移画面、碰撞缓存与下一次移动，不能将反射通过或读回成功称为完整的游戏行为验证。不要盲写变换矩阵、网格缓存或其他相等浮点值。

## 怎样读写

1. 通过游戏窗口取得 PID，再枚举 `sinking_star.exe` 模块，取得本次运行的基址和大小。查询只请求 `PROCESS_QUERY_LIMITED_INFORMATION | PROCESS_VM_READ`；`ReadProcessMemory` 必须报告完整读取。
2. 明确的坐标修改才增加 `PROCESS_VM_WRITE | PROCESS_VM_OPERATION`。`game_write_position` 和位置命令使用 `game_write_position_to(..., instant = true)`；每次创建新的 reader，重新解析当前 manager、完整对象列表、所有 Guy 的选择状态及受控集合。
3. `set position` 用目标减去受控基准，`move` 直接用给定偏移，为每个受控实体计算目的地。用 float64 检查每个结果的范围后转为 float32，保持组内相对位置。单轴 X/Y 的零偏移不写内存、不切换焦点。
4. 在第一笔写入前解析所有受控实体的全部五个字段，检查目的地与原值完整可读、有限且在允许范围。拒绝未知、损坏、越界、彼此重叠、覆盖身份或选择状态的字段，以及实体之间的内存重叠。重复的实体指针去重。
5. 对每个受控实体依次清零 velocity，同步 pre_move_position、position、visual_position、output_position。每次 `WriteProcessMemory` 只写该字段的 12 字节；字段之间复核签名、完整实体列表、所有 Guy 的 owner、类型、实体 ID 和选择状态，最后读回每个目标的全部字段。判断整组身份，不因平移中途空间基准暂时改变而停止。不能覆盖整个 Guy 结构。
6. 发生部分写入、控制组切换或读回失败时停止；`changed` 表示可能已经改变游戏，错误信息不能声称没有修改，也不自动回写旧值。这是逐字段、逐实体写入，不是原子事务。底层保留的逻辑坐标测试路径也按受控整组处理，但不应替代正式命令的 instant 路径。

`set position`、各形式 `move`、`move_xy`、`back` / `tp` 只同步这些字段，不再补发 Right 或任何方向键。旧的原生移动后纠正一格逻辑已移除。控制台位移等待 Enter/修饰键释放并交回游戏焦点；quick input 关闭后只允许向提交时的同一游戏 HWND/PID 执行。

`noclip` 消费物理 WASD，每次通过相同 writer 请求一格位移，不发送替代方向键、不阻塞等待按键周期。持续按住仍按 250 ms 间隔重复，这不是已验证的游戏最低间隔。只按进程生命周期缓存签名 locator，复核代码字节后使用；玩家地址不能跨写入复用。失焦、游戏切换、保存确认或失败会清除待移动队列，注入事件不会再次触发移动。

保存确认期间拒绝坐标修改；发生写入后暂停编辑器录制和播放，但保留解法、执行边界和未保存修改。手动对齐后允许继续播放、跳转和录制，不再用旧的同步标记锁住编辑器。

## 共享 reader 与编辑器

`Game_Position_Reader` 核对定位指令的完整字节、当前 manager、对象数量及完整指针数组；列表改变时重新解析所有有效 `Guy`。同一列表也会重新读取所有 Guy 的 owner、类型、实体 ID 和 status_flags，对 ACTIVE 实体读取 XYZ，再复核完整列表和所有身份、选择状态，拒绝混合切换前后的控制组。

正常读取通过 `selection_version` 记录选择或身份变化，因此 C / 数字键切换不依赖对象列表变化或辅助程序捕获按键。基准按实际受控实体的 XYZ 字典序取最小值，坐标完全相同时按实体 ID 决定。没有 ACTIVE 实体时返回错误，不能回退到首个 Guy。

`allow_resolve = false` 不打开进程、不扫描代码、不分配内存或重新搜索实体；在一次写入内核对原控制集合，变化时立即失败。`game_position_sample_same_group` 允许空间基准在分批平移中改变；它不授权下一次写入复用原实体地址。

用户已因多角色机制放弃 Check。编辑器没有 Check 按钮/命令、静止移动标记或录制/播放位置采样；不要恢复这些功能。历史性能样本（同一 Demo 的 1000 次有效缓存读取平均约 0.018 ms）只说明读取本身的开销，不证明能通过坐标识别无效动作。

## 多角色控制：实现与验证

2026-09-14，在上述相同 SHA-256 的 Demo 中进行了只读调查。最初在 `heroes1_15` 看到两个经 owner / Guy 类型校验的实体；调整前的 `game_find_player` 和 reader 因为多个 Guy 而停止，未使用选择状态。现已通过下面的证据扩展为 ACTIVE 受控集合。

通过游戏自带枚举元数据确认了以下名称和值，偏移仍只是此版本的观测证据：

| 完整字段 / 枚举 | 样本偏移及类型 | 观察 |
| --- | --- | --- |
| `entity.undoable_data.status_flags` / `Status_Flags` | `0x5C`，u16 | `DEAD=1`、`FALLING=2`、`ACTIVE=4`、`ON_EXIT=16`、`TRANSMUTING=32` |
| `entity.undoable_data.entity_flags` / `Entity_Flags` | `0x28`，u64 | 包含 `MIRRORED=65536`；镜像标记本身不等于当前受控 |
| `skill_flags` / `Skill_Flags` | `0x348`，u32 | 包含 `TRADER=2048`，还有其他技能；技能相同不能单独证明属于同一控制组 |

`position_selection.jai` 按 `Guy.entity.undoable_data.status_flags` 的成员名称逐层发现偏移；要求 Status_Flags 为完整的 enum、底层为 unsigned 16-bit integer，且名称数组中恰好一个 `ACTIVE`，其值是能放入 u16 的正单比特。枚举的 internal_type 位于 `+32`，names / values 的 count/data 分别位于 `+40/+48` 和 `+56/+64`，values 使用 s64；枚举 status_flags 位于 `+72`，enum_type_flags 位于 `+74`。此 Demo 的 Status_Flags 是普通 enum，`enum_type_flags=0`，不能要求它带 enum_flags 标记。实际 ACTIVE=4 与实体字段偏移 0x5c 仅为观测证据，不作未知版本的硬编码回退。

首次样本中，实体 ID `1048594` 位于 `(2, 1, 0)`，`status_flags=4`；实体 ID `1048608` 位于 `(6, 1, 0)`，`status_flags=0`。这是 `ACTIVE` 可用于选择状态调查的具体线索，当时尚无多控样本。首次证据保存在 `.build/control_state_heroes1_15.json`。

同日用户手动进入 `mirror_12`，并明确确认场上三个角色正在同时受控。只读检查仍为同一 PID / 游戏 SHA-256，当前场景完整实体列表中有三个经 owner / Guy 类型验证的实体：

| 实体 ID | XYZ | `status_flags` | `MIRRORED` 位 |
| --- | --- | --- | --- |
| `1048631` | `(11, 5, 0)` | `4`（ACTIVE） | 未置位 |
| `1072693267` | `(6, 2, 0)` | `4`（ACTIVE） | 已置位 |
| `1072693298` | `(4, 2, 0)` | `4`（ACTIVE） | 未置位 |

三个实体的 `turn_order_id` 都是 `1048631`，`turn_order` 都是 `1506`；反射成员 `Guy.turn_order_id` 的样本偏移为 `0x368`，类型为 4 字节 `Pid`。共享该 ID 是额外的分组线索，尚未证明它在所有角色、关卡和变换情况下都足以单独定义控制组。三者 `skill_flags` 均为 `2`（SINGLE_PUSH），未设置 TRADER 技能位；当前控制判断不应依赖人物称呼与技能枚举的映射。

该样本确认：在用户确认的三体多控状态下，三个 Guy 全部带 ACTIVE；按 MIRRORED 筛选会漏掉两个受控实体。按约定的实际实体 XYZ 字典序，锚点为 `(4, 2, 0)`，实体 ID `1072693298`。证据保存在 `.build/control_state_mirror_12.json`；`.build/control_state_evidence.json` 保存最近一次采样。

用户随后进入 `quadrants_follow_up`，并明确区分两个角色为 `thief` 与 `thief_alt`：它们并非镜像复制，在此关卡通过 C 分别切换控制，不是同时控制。只读采样看到两个 Guy，技能都为 `4`（PULL），MIRRORED 均未置位，但选择状态不同。下面的坐标 / ID 尚未分别映射到 thief 和 thief_alt 名称：

| 实体 ID | XYZ | `status_flags` | `turn_order_id` | `turn_order` |
| --- | --- | --- | --- | --- |
| `50331737` | `(8, 17, 0)` | `0` | `50331737` | `808` |
| `59768875` | `(8, 19, 0)` | `4`（ACTIVE） | `59768875` | `608` |

此样本与用户描述的两个独立角色择一控制一致：两者技能相同，只有上方实体带 ACTIVE，各自的 turn_order_id 不同。技能相同不能证明人物身份相同，也不能据此把 thief 和 thief_alt 合并成控制组。按 ACTIVE 集合确定基准时应得到 `(8, 19, 0)`；不能把未选中的 `(8, 17, 0)` 加入集合后再取字典序最小值。证据保存在 `.build/control_state_quadrants_follow_up.json`。

同一场景的 C 切换动态对照已通过：用户按一次 C 且两名角色不移动，2026-09-14 02:36:39 UTC 到 02:38:22 UTC 的两次变化样本中，ID `59768875` 的 ACTIVE 从 4 变为 0，ID `50331737` 从 0 变为 4；场景、实体 ID 和坐标均未变化。证据为 `.build/control_state_watch_20260914T023639136500Z.json`。后一次观察 `.build/control_state_watch_20260914T024605477909Z.json` 只有基线，未验证数字键切换。镜像产生 / 移除的动态过程及实际游戏内整组坐标写入也尚未验证。

`Entity.entity_manager` 的指针类型确实指向 `Entity_Manager`，但此构建的 manager 类型没有成员反射记录（成员数为零，TYPE_INFO_NONE）；不能假定能按字段名直接发现 manager 的选择列表。只读脚本和本次证据分别保存在 `.build/inspect_control_state.py`、`.build/control_state_evidence.json`，不是生产代码依赖；该脚本只申请查询和读取权限，不注入按键、不写游戏内存。

已实现用户确定的命令语义：每次重新识别当前受控角色及其所有同时受控的镜像副本，排除其他未选中的角色。`show position` 取这个集合内实际实体的 `(x, y, z)` 字典序最小值：先比 X，再比 Y，再比 Z；不分别取各轴最小值拼成虚拟点。`set position` 使用“目标坐标减去该锚点坐标”作为整组统一位移，`move` 使用参数作为整组统一位移，二者保持组内相对位置。`mark`、`back` / `tp` 和 noclip 复用相同语义。

实现后的生产只读接口 `.build/position_tests.exe --read-game` 在相同 Demo 的 `overworld` 读到 `(81, 62, 0)`，五个位置字段反射通过，1000 次有缓存的复核读取全部有效。`tests/position_selection.jai` 用隔离内存验证独立角色选择、三体平移、间距保持、未选角色及背景实体不变、整组预检和部分失败。上述结果不等同于游戏内碰撞与后续原生移动已经验收；未写真实游戏内存、未注入输入。

## 当前场景与 switch

当前 manager 的 `+0x00/+0x08` 是 Jai 字符串的 count/data，已只读观察到 `overworld`、`promesst1_streamlined`、`intro` 和 `quadrants_follow_up`。`game_player_scene_name` 仍配合已验证玩家用于 switch 的场景约束。

`src/game/level.jai` 的 `game_read_scene` / `game_read_scene_from` 通过同一唯一代码特征定位当前 manager，独立读取名称，不读取 Guy、角色选择状态或内部 XYZ。限制名称为 1–128 字节的资源名（字母、数字、下划线、连字符和点），完整读取后再次核对签名、manager 指针、字符串头及名称内容。场景或名称改变时返回错误；不保留上次关卡供失败时使用。

2026-09-14，使用仅 QUERY_LIMITED_INFORMATION / VM_READ 的生产读取接口，在上述 SHA-256 未变的 Demo 中读到 `quadrants_follow_up`。命令为 `.build/position_tests.exe --read-level`；没有发送输入、修改坐标或查看图像。这证明该样本的当前场景读取有效，不将一次样本当作未来版本的偏移保证。

`switch <level_name>` 从 `data/marker.json` 读取官方关卡入口，保留同坐标的不同关卡名，不使用已改名的解法或 custom input 替换目录名称。先验证名称、坐标、当前场景为 `overworld` 和 `User.keymap` 中的 `TakeOrDrop` 绑定，再瞬移；写后核对玩家和坐标，最后发送并释放 TakeOrDrop（默认 V）。在小关内拒绝该命令，要求先回大地图；普通位置命令不会发送这个键。

`show level` 显示场景名并区分 Overworld。无名称的 `show subtitles`、`play`、`do`、`edit` 和 `edit solution` 通过 `game_resolve_level_name` 使用已进入的小关；Overworld、菜单和非关卡支持场景不能作为默认小关。显式名称不调用场景读取，保留独立使用方式。播放需要该关已保存的解法；编辑允许尚无存档/入口记录的当前小关建立空解法，仍须明确确认 Save 才写入。

解法导入、编辑和保存按不区分大小写的关卡名识别记录，去掉旧的坐标合并/保存回退。不同关卡共享大地图入口时不会混用解法或笔记，切换编辑会话的保存确认保留已解析的目标名。按关卡查看和修改 note 的命令仍是后续工作；`Solution_Record.note` 可以复用，写入时重新加载并保留其他字段和记录。

所有自动寄存器和自定义标记都写入 `data/markers.json`；每个条目只有 name/position，next_register 单独放在顶层。新文件缺失时迁移 `data/position_markers.json`，保留旧文件；已有新文件始终优先。`list markers` 只列名称和坐标，不显示 next-register footer。

## 游戏更新后的排查流程

1. **记录实际版本。** 先找正在运行的可执行文件；记录路径、文件大小、时间和 SHA-256。例如在 PowerShell 中：

   ```powershell
   Get-Process -Name sinking_star | Select-Object Id, Path
   Get-FileHash -LiteralPath '实际游戏路径/sinking_star.exe' -Algorithm SHA256
   ```

   历史路径是 `E:/SteamLibrary/steamapps/common/Order of the Sinking Star Demo/sinking_star.exe`，不能假定未来仍然如此。

2. **区分环境错误和版本错误。** 未启动、尚未加载关卡、进程权限不足和 AOB 未匹配是不同问题。Windows error 5 表示访问被拒绝，不证明偏移失效。沙箱拒绝跨进程操作时，按当前工具的权限机制处理。
3. **先只读复现。** 记录模块范围、代码段 RVA、特征匹配数、解码出的槽、manager、对象数、`Guy` 数量及坐标，避免输出整块进程内存。
4. **检查旧特征是否还能定位。** 读取已加载 PE 的 `.text`，验证 PE32+ / x64、段大小和边界。也可以离线扫描 exe；注意磁盘文件偏移不等于 RVA，必须按 PE 节表转换。
5. **特征失效时定位引用。** 对照 `.refs/sinkingstarhero` 的代码、字符串、类型名与原指令。可以用只读 Python `ctypes` 探查，或通过 `objdump -d -Mintel` 反汇编；此环境曾使用 `C:/msys64/ucrt64/bin/objdump.exe`，不要假设已安装 Capstone。
6. **候选只是候选。** 必要时只读扫描可写模块段中的合理 manager 指针，逐一验证对象列表、`Guy` 类型和 owner；进入/退出多个场景并再次采样，确定哪个根随当前场景变化。反向检查该全局变量的代码引用，不能把扫描得到的第一个候选放进写入路径。
7. **重新验证字段。** 特征找到不代表 `0x370/0x378`、`0xF0`、`0x108` 或 XYZ 仍有效。比较游戏中已知位置/移动前后的样本，检查类型元数据和邻接字段。优先使用用户已有的只读观察。
8. **选择有边界的定位方式。** 新特征应包含稳定操作码，将 RIP 位移等易变字节设为通配符，并验证唯一性和目标范围。没有充分证据时返回“不支持此版本”；不要加入只凭版本名字或裸 RVA 的写入回退。
9. **同步代码、测试和本文。** 把新的历史观测值与算法要求区分开。记录游戏文件 hash、证据及不再成立的偏移；保留只有在其指令证据匹配时才生效的旧版本支持。

## 验证

使用现有的 `tests/position.jai` 进程内 PE/实体夹具验证读写。这些测试文件在本项目被 Git 忽略；若当前 checkout 缺失，建立同等的隔离夹具，不依赖旧 `.build` 产物。

```powershell
jai -quiet tests/position_first.jai
.\.build\position_tests.exe
```

覆盖唯一/缺失/重复特征、有符号 RIP 位移、旧版本回退、场景切换、多玩家、无效坐标、相对移动边界及只读句柄写入失败。`tests/position_layout.jai` 使用完整 Guy/反射夹具，验证五个字段的精确写入、其他字节保持原样，以及重叠/常量/越界/不兼容类型在写入前失败。noclip 回归覆盖四方向、点击/持键节奏、队列、取消和注入事件过滤。

`tests/position_reader.jai` 覆盖冷启动、禁用重新定位的验证路径、连续坐标变化、同数量列表替换、场景切换、多 Guy 和签名字节变化。`tests/position_storage.jai` 验证标记迁移、schema、官方入口查找和改绑的 TakeOrDrop，使用隔离 JSON，不修改用户的 markers/solutions 数据。
`tests/position_selection.jai` 覆盖同列表内选择变化、独立 thief 变体、多个 ACTIVE、副本指针去重、XYZ 字典序及实体 ID 平局、set / move 整组平移、未选角色逐字节不变、最后一个副本字段损坏或目的地越界时全组拒绝、选择字段重叠、非基准成员切换、普通枚举布局及 ACTIVE 位变化。最后一个副本使用只读页时，验证前面的副本已写入、返回 changed=true、停止后续写入且不回滚。全部使用测试进程自己的内存。
`tests/editor_features.jai` 通过 `tests/controls_first.jai` 验证固定中心线、开关两种拖动语义、禁用游戏输入后选定新播放起点、已执行格删除、五档速度和 Check 移除。测试使用模拟按键，不进行真实游戏操作。

`tests/level.jai` 验证当前场景读取独立于多 Guy、无效坐标和实体列表，覆盖背景场景、过渡时根指针/名称头/内容改变、无效名称、唯一特征和只读权限。`tests/current_level_commands.jai` 验证默认 edit/play/do、Overworld 拒绝、显式名称独立性和相同坐标下的不同关卡记录，保存测试使用 `.build/current_level_save` 的独立数据。字幕测试覆盖相同默认场景路径及所选语言。

仅查询当前关卡，无需存在唯一可读玩家：

```powershell
.\.build\position_tests.exe --read-level
```

真实游戏的只读验证入口（需要有可读玩家，可在大地图或小关中执行；包含反射字段偏移及场景名称验证）：

```powershell
.\.build\position_tests.exe --read-game
```

常规测试不写真实游戏、不发送真实游戏输入、不查看截图。旧的 `.build/position_probe.py` 是调查时的临时脚本，不能作为本技能或生产代码的依赖。

需要构建 GUI 时遵守项目构建规则；优化构建输出到 `bin/`，可避免替换仍在运行的根目录程序。打包保留安装目录已有的 markers.json、position_markers.json、solutions.json、custom_inputs.json、Zork 存档及 config.rc：

```powershell
jai -quiet first.jai -optimized -import_dir modules
```
