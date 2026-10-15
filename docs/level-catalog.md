# 自动提取关卡名、区域和入口坐标

[`data/level-catalog.json`](../data/level-catalog.json) 从游戏 `data/levels.package` 自动生成，不需要在地图上逐个标记，也不需要启动游戏。关卡目录只保留一个独立脚本 `scripts/generate_level_catalog.jai`，包含包读取、实体解析、生成和自检。

```powershell
jai -quiet scripts/generate_level_catalog.jai - "<游戏安装目录>/data/levels.package"

# 游戏更新后重新生成；也可以指定输出文件或只校验现有文件
jai -quiet scripts/generate_level_catalog.jai - "<游戏安装目录>/data/levels.package" -o data/level-catalog.json
jai -quiet scripts/generate_level_catalog.jai - "<游戏安装目录>/data/levels.package" --check
```

脚本只读取游戏包。相对输入/输出路径从项目根目录解析。全部解析成功后，先写临时文件再原子替换输出；失败不覆盖现有目录。结果按名称排序，包含源包 SHA-256，重复运行产生相同内容。它不导入或覆盖个人标记、笔记与解法。

## 文件内容

根对象只保留 `source` 和 `levels`。`source` 记录包名、SHA-256 和场景名；`levels` 数组只包含具有完整入口数据的记录，每条记录保留四个字段：

```json
{
  "name": "metamirror_same_dir_v2",
  "region": "metamirrors",
  "position": [135, 66, 0],
  "entity_id": 46137392
}
```

| 字段 | 含义 |
| --- | --- |
| `name` | 当前包中的 `.entities` 资源名；匹配不区分大小写 |
| `region` | 原始 `.level_set` 文件名，不含扩展名；排除 `draft_*`、`drafts_*` 和 `design_illustrations` 这些开发用集合，不按关卡名字前缀猜测区域 |
| `position` | 入口的游戏世界 `[X, Y, Z]`，保留负数、高度和原始 float32 精度 |
| `entity_id` | `overworld.entities` 中直接指向该名称的 `Level_Entry` 实体 ID，便于追溯源记录 |

坐标是大地图入口位置，不是小关内部角色坐标、图片像素或经纬度。不同名字即使共用坐标仍是不同记录；同名多入口分别输出一条记录，按名称和实体 ID 排序。每个输出记录必须有唯一的非开发用区域归属；若后续游戏包出现缺失或多个区域，生成器会报错，避免任意选择区域。

生成时排除资源缺失的记录、名称以 `menu_` 开头的设置菜单背景（不区分大小写），以及没有大地图入口的记录。不再输出 `available`、`areas`、`entrances` 或 `level_sets` 字段。

2026-10-15 本机包有 974 个实体资源名、5 个仅被引用但资源缺失的名称；过滤掉这 5 个缺失资源名称、33 个菜单背景和余下 21 个没有入口的资源后，输出 **920 条记录，对应 920 个不同关卡名称**。这些记录均有一个区域和一个入口。其他版本按实际包内容生成，数量不写死。

`switch <level_name>` 和它的 Tab 补全直接读取此目录，名称不区分大小写，例如 `switch 3d_intro_heroes` 会使用入口 `[80, 74, 33]`。它只在当前场景为大世界 `overworld` 时生效：先检查目录和场景，将当前受控角色组的锚点传送到入口（保留组内相对位置），同步逻辑/显示 XYZ，再发送当前用户键位配置中的 `TakeOrDrop`（默认 V）触发入口。小关卡、菜单、未知名称、同名多入口或无效目录都会拒绝执行。写入前、各字段之间及发送按键前继续检查场景，避免排队期间换场景后套用大世界坐标。

目录独立于个人标记、解法和自定义输入；`data/marker.json` 仍用于旧解法导入。优化构建会把新目录复制到 `bin/data/level-catalog.json`。

传送前先完成游戏激活；写入后留出入口检测更新的时间，再确认同一场景与传送目标并发送 V。完整受控组校验在写入阶段完成，V 前不再检查 `ACTIVE` 或整张实体列表是否与上一帧一致，避免原生更新误拦截按键。真实的场景、目标身份或坐标变化仍会中止按键，并在坐标变化时显示目标与实际位置。`go = switch;` 这样的配置别名使用同一流程。

## 解析依据与验证

- 生成脚本内的 Simple_Package v1 读取器检查边界、重名和重叠，并计算 SHA-256、原子替换输出。字幕生成器保持独立运行。
- 同一个脚本验证 `enty` v7 类型表、记录数量、类型索引、长度和文件结尾；返回的数据视图借用源包缓冲区。每次生成的数组和字符串由同一个 Pool 管理。
- 当前支持实体基类版本 25 和 `Level_Entry` 版本 25。只沿成员边界解析入口基类字段与 `0x1000` 目标字符串，不在二进制中搜索类似名称或分隔符。
- 坐标成员 `0/1/2` 为旧默认值 0 与当前 float32；缺省坐标为 0。`0x21/0x22/0x23` 若存在必须与对应坐标一致。字符串成员 `0x0b`、`0x1f`、`0x1000` 为旧/新长度及内容；`0x20` 为默认空的材质覆盖数组；其他已验证基类成员使用明确宽度。未知版本、字段、无效坐标或截断数据会报错。
- 关卡集要求 `[1]` 头，忽略空行、`#` 注释和 `*` 开头的选择/字形指令；其余行作为完整资源名匹配。开发用集合不作为区域输出。
- 浮点数使用足够精度输出，并逐坐标核对 JSON 解析后的值，避免默认显示精度造成舍入。

```powershell
# 合成边界检查：截断、无效版本/名字、重复字段、非有限坐标、字符串中的假分隔符等
jai -quiet scripts/generate_level_catalog.jai - --self-test

# 再校验实际包的完整解析和每个坐标的 JSON 往返精度
jai -quiet scripts/generate_level_catalog.jai - "<游戏安装目录>/data/levels.package" --self-test --check

# 运行时目录校验、名称补全和大小关场景隔离；不向游戏写入或发送按键
jai -quiet scripts/check_game_layout.jai -import_dir ../modules
```
