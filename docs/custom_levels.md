# 自定义关卡指南（离线改包）

本文说明 Order of the Sinking Star Demo 的关卡文件结构，以及在不依赖游戏内编辑器的前提下，如何以现有关卡为模板制作自定义关卡。所有结论来自 2026-09-20 对本机 Demo（r62164，Steam public-testing 分支）的只读分析；游戏更新后需要重新核对。

已验证：发布版没有可用的编辑器或控制台开关。`-help` 列出的合法参数只有 `-language`、`-size`、`-no_vsync`、`-windowed`、`-fullscreen`、`-prefer_*`；`data/Developer.keymap` 里的 F1 控制台、Insert 标记关卡完成等动作名在可执行文件中不存在，是残留文件。因此自定义关卡只能通过修改数据包实现。

## 一、关卡由哪些文件组成

以 `mirror_1` 为例，一个关卡分散在四处：

| 位置 | 文件 | 内容 | 必需 |
| --- | --- | --- | --- |
| `data/levels.package` 内 | `data-common/mirror_1.entities` | 关卡里的全部实体：角色、镜子、石头、墙、门、相机、太阳、设置等 | 是 |
| `data/levels.package` 内 | `data-common/mirror_1.level_manifest` | 文本，列出该关引用的贴图和网格名，供预加载 | 是 |
| `data/levels.package` 内 | `data/level_sets/mirror.level_set` | 文本，一个世界的关卡顺序表 | 进入方式之一 |
| `data-common/` 散装 | `mirror_1.all_paint_data`（`allp` 头） | 顶点绘制颜色，按实体 ID 关联 | 否，缺失只记日志 |
| `data-common/` 散装 | `mirror_1.all_lightmap_data` | 烘焙光照贴图 | 否，缺失只记日志 |
| `data/levels/mirror_1/` 散装 | `13_1-probe.dds` 等 | 反射探针立方体贴图（DDS），文件名是探针实体 ID | 否 |

大地图入口是 `overworld.entities` 里的 `Level_Entry` 实体，共 132 个；其成员里直接写着目标关卡名，玩家站上去按 V 就进入该关。

游戏启动时把 `data/levels.package`、`materials.package`、`shaders.package`、`animation.package` 挂载为虚拟文件系统，再把 `data-common`、`data-pc`、字体和声音目录里的散装文件编入目录。找不到网格时打印 `Could not find mesh "%" for entity %, using placholder.` 并用占位模型，不会崩溃。

## 二、levels.package 的格式

这是 Jai 标准模块 `Simple_Package` 的格式，可以直接用该模块读写：

- 文件头 64 字节：`simp` 魔数、版本 1、flags 0、目录偏移。
- 条目数据依次排列，之后是目录：`toc!` 魔数、条目数，每个条目为 u32 名长、名称、NUL、u64 大小、u64 偏移。
- 本 Demo 共 238 个条目：114 个 `.entities`、114 个 `.level_manifest`、10 个 `.level_set`。

`scripts/inspect_levels.jai` 用这个模块只读解析并打印内容，见文末。

## 三、.level_set：一个世界的关卡表

纯文本，示例节选自 `data/level_sets/mirror.level_set`：

```text
[1]     # Version number; do not delete!

# Just mirrors, no rocks
mirror_1
mirror_2
# Now rocks as well
mirror_3
mirror_4 # optional
*choice
mirror_5
```

- 首行 `[1]` 是版本号。
- 每行一个关卡名，对应 `data-common/<名字>.entities`。
- `*choice` 是选择点，把关卡分成若干组，前一组完成后解锁下一组；`*worlds_collide`、`*choice_demo2` 之类是带名字的选择点。
- `#` 之后是注释，行尾也可以加注释。

四个世界的文件：`heroes1/2/3.level_set`（北方英雄）、`mirror.level_set`（东方镜子）、`promesst1_and_2.level_set`（西方激光，Demo 只含第一关）、`heroes_and_water.level_set`（水域），另有 `worlds_collide.level_set`（混合世界）、`intro`、`intro_hard_puzzles` 和 `overworld`。表里列出的许多关卡（如 `promesst2_streamlined`、`floating_gardens`）Demo 里没有对应的 `.entities`，说明游戏容忍缺失条目。

## 四、.level_manifest：资源清单

纯文本：

```text
[1]

;;;;; textures
Base_Metal_A-MASK
GAME_MIRR_Mirror_Magic-diffuse
...

;;;;; meshes
GAME_MIRR_Mirror_Magic_A
GAME_SOKO_Exit_A
...
```

名称对应 `data-pc/<名>.texture` 和 `data-common/<名>.compressed_mesh`。游戏加载关卡前按清单异步预载。清单缺项不会阻止加载，只是首次显示时才同步读取；清单多余项无害。复制模板关卡的清单，再补上新增实体用到的网格名即可。

## 五、.entities：实体表

二进制，`enty` 魔数，本 Demo 为版本 7。结构：

```text
u8[4]  "enty"
u16    version            = 7
u64    header_value       = 25
u64    type_count         = 86
type_count 次:
    u64 name_length
    u8[] name             如 "Guy"、"Mirror"
    u64 aux               该类型的成员版本数
u32    record_count
record_count 次:
    u32 entity_id
    u16 type_index        指向上面的类型表
    u32 diff_size
    u8[] diff
```

所有关卡共用同一张 86 项类型表（顺序相同），所以类型索引在关卡之间可以互换。实体 ID 在关卡内唯一；paint data 和探针文件按 ID 关联实体，新建实体取一个未用的 ID 即可。

### 记录的 diff 编码

diff 只存储与类型默认值不同的成员，所以一条 `Mirror` 记录只有 188 字节。布局：

```text
u16 成员号                 第一个成员（通常是 0，即 X 坐标）
成员值
之后每个成员:
    u8  0xFD
    u16 成员号
    成员值
```

成员号小于 0x1000 属于基类 `Entity`，0x1000 起属于该类型自身成员（0x1000 | 自身成员序号）。已确认的成员：

| 成员号 | 含义 | 值编码 |
| --- | --- | --- |
| 0x0000 / 0x0001 / 0x0002 | 位置 X / Y / Z | 4 字节前缀 + float |
| 0x0006 – 0x0009 | 朝向四元数 x/y/z/w | 4 字节前缀 + float |
| 0x0016 – 0x0018 | 三个 float，默认 1（可能是颜色或缩放） | 4 字节前缀 + float |
| 0x001F | 网格名或角色名，字符串 | 8 字节前缀 + u64 长度 + 字节 |
| 0x0021 – 0x0023 | 位置的另一份副本（参考工具称 out_x/y/z），与 0/1/2 相同 | 4 字节前缀 + float |
| Level_Entry 0x1000 | 目标关卡名，字符串 | 同 0x1F |
| Guy 0x1004 | u32 角色种类编号 | 4 字节前缀 + u32 |
| Guy 0x100E / 0x1011 | 起点 / 终点标记名 | 字符串 |
| Settings 0x1054 | 关卡名（与文件名相同） | 字符串 |

float 前的 4 字节在参考工具里叫“版本戳”，但实际观察到它等于该成员的默认值（X 默认 0，四元数 w 默认 1）；无论哪种解释，修改坐标时保留这 4 字节、只改后 4 字节即可。字符串是 u64 长度加 UTF-8 字节，无终止符。

实例（`mirror_1` 的 Guy，实体 ID 1048632）：

```text
0000  00000000 00001041      成员 0 = 9.0     (X)
fd 0100  00000000 00001041   成员 1 = 9.0     (Y)
fd 0600  00000000 00000080   成员 6 = -0.0
fd 0700  00000000 00000080   成员 7 = -0.0
fd 0800  00000000 f30435bf   成员 8 = -0.7071
fd 0900  0000803f f304353f   成员 9 =  0.7071 (绕 Z 转 90°)
...
fd 1f00  00000000 00000000  0600000000000000 "trader"      角色名
...
fd 0410  00000002 00000000                                 角色种类
fd 0e10  ... 1200000000000000 "mirror_new_1_start"          起点标记
fd 1110  ... 1000000000000000 "mirror_new_1_end"            终点标记
```

其余成员的名称需要从运行中的游戏读取反射元数据才能确定：本项目已有按名称遍历 `Guy` 成员的代码（`src/game/position_layout.jai`），成员号很可能就是反射成员数组的下标，扩展一下即可导出“成员号 → 名称、类型”对照表。

### 一个最小关卡包含什么

`mirror_1` 的 340 条记录按类型统计：

| 类型 | 数量 | 作用 |
| --- | --- | --- |
| Settings | 1 | 关卡设置：相机控制网格、关卡名、所属世界等 |
| Camera_Control | 1 | 相机位置与朝向，缺少时游戏要求重新保存关卡 |
| Sun | 1 | 太阳光，缺少时同上 |
| Sky, Fog, Wind, Ocean_Map | 各 1 | 环境 |
| Wall_Set | 4 | 一组墙体，成员含起点、方向和长度 |
| Guy | 1 | 玩家角色 `trader` |
| Mirror | 1 | 镜子，网格 `GAME_MIRR_Mirror_Magic_A` |
| Door | 1 | 出口，网格 `GAME_SOKO_Exit_A` |
| Marker | 1 | 起点/终点标记 |
| Inanimate | 275 | 纯装饰的地形与摆件 |
| Decal, Light_Probe, Fog_Volume, Group | 若干 | 装饰、光照探针、雾体、分组 |

Settings、Camera_Control、Sun 是硬性要求（可执行文件里有对应的报错文本），Guy 和 Door 决定可玩性，其余都可以删。

### 各世界的玩法实体

| 世界 | 类型 | 说明 |
| --- | --- | --- |
| 通用 | Guy, Rock, Door, Wall_Set, Gate, Switch, Monster, Gem, Gem_Slot, Freezer, Teleporter | 角色、石头、出口、墙、门闸、开关、怪物、宝石与插槽、冰、传送 |
| 东方 | Mirror | 镜子，31 关使用 |
| 西方 | Promesst_Light | 激光底座（网格 `GAME_PROM_Laser_Base_A`），Demo 只有 4 关使用 |
| 北方 | Guy 的种类编号区分战士/盗贼/法师/牧师/吟游诗人/德鲁伊 | 键位文件中 1–9 对应 Warrior/Thief/Wizard/Priestess/Bard/Druid/Sailor/Gemsman/Trader |
| 水域 | Ocean_Map, Lily, Elevator_Platform | 水面、莲叶、升降台 |

`worlds_collide_heroes_and_mirrors_v3` 之类的官方关卡已经把英雄、镜子、激光混在同一关，说明引擎不限制跨世界组合。

## 六、制作流程

以 `mirror_1` 为模板做一关 `my_level`：

1. **备份** `data/levels.package`。Steam 校验文件完整性会还原改动，改包只在本机生效。
2. **提取模板**：用 `Simple_Package` 读出 `data-common/mirror_1.entities` 和 `.level_manifest`。
3. **改名**：条目名改为 `data-common/my_level.entities` / `.level_manifest`；把 Settings 记录的 0x1054 字符串改成 `my_level`（字符串变长时要同步改 u64 长度和记录的 `diff_size`）。Guy 的起止标记名和 Marker 名保持成对即可。
4. **编辑实体**：
   - 移动：改成员 0/1/2 与 0x21/0x22/0x23 的 float。网格坐标是整数，Z 一般为 0。
   - 复制：复制整条记录，改实体 ID。跨关卡复制时类型索引不用改。
   - 新增激光：从 `promesst1_streamlined` 复制一条 `Promesst_Light` 记录，改坐标和朝向；把 `GAME_PROM_Laser_Base_A` 加进清单。
   - 删除：直接去掉记录并减少 `record_count`。删掉 Inanimate 装饰不影响玩法。
   - 墙体：`Wall_Set` 的自身成员含整数起点、方向和长度，具体成员号待反射对照表确认；先只做平移较稳妥。
5. **挂到入口**，二选一：
   - 在某个 `.level_set` 里加一行 `my_level`（文本，最简单，但只能按顺序解锁）。
   - 在 `overworld.entities` 里复制一条 `Level_Entry`，改坐标和 0x1000 的目标关卡名，放到大地图空位上。
6. **重建包**：用 `Simple_Package.Create_Package` 把全部条目（含新条目）写回 `levels.package`。散装的 paint、lightmap、probe 文件不复制也能运行，只是没有顶点色和烘焙光照。
7. **测试**：启动游戏，查看 `logs/` 最新日志里的 `Loading level 'my_level'` 及后续警告。

## 七、风险与限制

- 只改本机文件，不写游戏内存；改错会导致加载失败或崩溃，日志会指出原因。
- 未做反射对照表之前，只有坐标、朝向、名称、关卡引用这几类成员可以放心修改。
- 存档目录 `Saved Games/Order of the Sinking Star/<存档名>/` 按关卡名保存 `.history` 和完成状态，自定义关卡名不要与官方重名。
- Demo 缺少的资源（正式版关卡引用的网格）无法凭空补上，只能用现有网格。

## 八、工具

只读解析脚本（Jai `#run`，不修改游戏文件）：

```powershell
# 列出关卡集原文、资源清单和 114 关的实体类型使用统计
jai -quiet scripts/inspect_levels.jai - "<游戏目录>/data/levels.package"

# 某关的清单原文、实体类型计数和全部记录
jai -quiet scripts/inspect_levels.jai - "<游戏目录>/data/levels.package" mirror_1

# 某关某类型记录的字符串与十六进制
jai -quiet scripts/inspect_levels.jai - "<游戏目录>/data/levels.package" overworld Level_Entry
```

后续如需真正制作关卡，计划补两个工具：从运行中的游戏导出“成员号 → 名称”对照表，以及一个基于 `Simple_Package` 的提取 / 替换 / 重建脚本。
