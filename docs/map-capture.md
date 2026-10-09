# 俯视相机与地图拍摄

## 手动取景

```text
freecam -topdown
show camera
set camera 80.25 81 18
freecam disable
```

`-topdown` 将镜头锁定为垂直向下、北朝上。重复执行保持开启。普通 `freecam` 仍是开关；`freecam enable` 切回鼠标自由视角。已有 `-pan` 固定视角平移模式保留；不提供 `-top` 缩写。

| 输入 | 俯视 / pan 模式 | 普通自由视角 |
| --- | --- | --- |
| W / S | 世界 Y 正 / 负，北 / 南 | 沿视线前 / 后 |
| A / D | 世界 X 负 / 正，西 / 东 | 沿视线左 / 右 |
| Q / E | 世界 Z 正 / 负，上升 / 下降 | 下降 / 上升 |
| Shift / Ctrl | 加速 / 减速 | 加速 / 减速 |

`show camera` 查询相机绝对 XYZ、视角、yaw/pitch 和垂直 FOV，使用只读句柄。`set camera` 需要先开启 freecam，接受有符号小数和科学计数法，例如 `1.5e2`；每个坐标必须有限且在 ±1,000,000 内。

坐标采用游戏原生世界单位，存储为 float32 Vector3。X/Y 与玩家网格同一坐标系，但相机位置可有小数；Z 是绝对世界高度。这里只移动相机。退出 freecam、失去相关窗口焦点或结束拍摄时，恢复进入自由相机前的视图和原生跟随模式。场景已切换时只释放原生模式，不把旧视图写入新场景。

## HUD

游戏左上角只显示两行：关卡资源名、玩家 XYZ。多控时复用 `show position` 的规则，选择受控实体中 `(x, y, z)` 字典序最小的实际实体，坐标完全相同时按实体 ID 决定。切换角色后重新采样受控集合；不显示相机、视角、Noclip 状态或拍摄进度。

`hud enable` 开启、`hud disable` 关闭，裸 `hud` 切换。默认开启，手动开关状态保留到助手退出；切换关卡或焦点不会重新启用手动关闭的 HUD。完整终端和迷你输入框打开时，两处 HUD 都自动隐藏，返回游戏后按手动开关状态恢复。HUD 不取得焦点，鼠标穿透；游戏最小化或切到无关窗口时隐藏。截图前至少预留 150 ms 隐藏助手 HUD；控制台 / 编辑器覆盖游戏时暂停拍摄。

通知保持水平居中，绘制区域顶部位于屏幕高度的 30%，文字约在上方三分之一处，短暂显示启用、关闭等消息，默认约 1.5 秒并淡出。字号统一按 `游戏客户区高度 / size` 计算，`size` 表示屏幕竖向能放下多少行字体：提示 `HUD_NOTICE_SIZE = 30`，左上角信息 `HUD_INFO_SIZE = 40`，在 `src/ui/hud.jai` 调整。1080p 时分别为 36px 和 27px，不再额外乘 DPI 倍率。两处使用游戏的 `KarminaBold.otf`，可回退到助手本地 `data/fonts/Karmina-Bold.otf`。

文字保留 FreeType 抗锯齿覆盖率，使用预乘 Alpha 和低透明度柔和阴影，无黑色色键描边。文字与尺寸不变时复用像素缓冲；HUD 不建立 OpenGL 窗口或调用 SwapBuffers，避免交换缓冲阻塞相机更新。玩家坐标使用独立只读 reader，每 200ms 更新，不加入编辑器录制或播放流程。

## 自动拍摄

脚本使用 Jai，通过 `-` 后面的参数接收命令。以下脚本的相对路径统一从项目根目录解析；控制台内的路径从助手 EXE 所在目录解析。脚本不会启动第二个相机控制器，而是向正在运行的助手排队发送拍摄请求。

先在游戏内调整画质、隐藏不需要的游戏 UI，并用俯视模式试取景。然后退出 freecam，关闭编辑器，创建一个小区域的试拍计划：

```powershell
jai -quiet scripts/capture_map.jai -import_dir ../modules - plan .build/capture-pilot 76 77 84 85 18 --ground 0 --overlap 0.3 --settle-ms 700 --scene overworld
jai -quiet scripts/capture_map.jai -import_dir ../modules - start .build/capture-pilot
```

参数顺序是 `目录 xmin ymin xmax ymax 相机绝对Z`。`--ground` 是用于换算截图比例的参考地面绝对 Z；它不修改地形。`--overlap` 默认 0.3，范围 0.1–0.8；`--settle-ms` 默认 500，范围 100–10000，实际至少等待 200 ms，以预留隐藏 HUD 的时间。范围与高度仅为例子，不代表已经验证的正式版全图边界。

提交后返回游戏，待 Enter、修饰键和移动键释放才开始。无需持续按键。程序按蛇形路径逐点移动，等待画面稳定，再保存完整无损 PNG。

```powershell
jai -quiet scripts/capture_map.jai -import_dir ../modules - status .build/capture-pilot
jai -quiet scripts/capture_map.jai -import_dir ../modules - pause
jai -quiet scripts/capture_map.jai -import_dir ../modules - resume
jai -quiet scripts/capture_map.jai -import_dir ../modules - cancel
```

也可直接在控制台使用：

```text
capture start "C:/path/to/capture-pilot/plan.json"
capture status
capture pause
capture resume
capture cancel
```

拍摄期间物理键盘输入、焦点改变、场景 / 相机身份改变、尺寸 / FOV 变化、窗口遮挡、黑帧或文件写入失败都会触发暂停。已完成的帧保留；`resume` 接着拍。助手重启后，对同一个计划执行 `start`，校验既有元数据和帧文件后续拍。不要在续拍前改变画质、地面参考高度、分辨率或计划；需要改变时使用新目录。

`start` 的脚本回执表示请求已排队。具体接受 / 拒绝结果见助手控制台或目录中的 `status.json`。没有生成状态文件时优先检查控制台。打开控制台查看会暂停正在进行的拍摄。

## 拼图和浏览

安装 libwebp 命令行工具，使 `cwebp` 在 PATH 中；例如 MSYS2 UCRT64 的 `mingw-w64-ucrt-x86_64-libwebp`。拍摄本身不依赖 cwebp。

```powershell
jai -quiet scripts/stitch_map.jai -import_dir ../modules - .build/capture-pilot .build/map-pilot
```

输出目录必须不存在，避免覆盖原图或已有地图。工具拒绝未拍完或坐标不一致的任务；读取每张 PNG 时检查尺寸和解码结果。内存中只保留当前瓦片和单张源图，不创建一张占用巨大内存的全图。

| 文件 | 用途 |
| --- | --- |
| 拍摄目录 `plan.json` | 世界坐标范围、高度、重叠率、等待时间 |
| 拍摄目录 `frame_000000.png` 等 | 完整原始截图，保留重叠边缘 |
| 拍摄目录 `manifest.json` | 分辨率、FOV、比例、行列及每帧实际设定 XYZ |
| 拍摄目录 `status.json` | 当前阶段、完成数量和状态消息 |
| 输出目录 `tiles/{z}/{y}/{x}.webp` | 512×512 无损 WebP 地图瓦片 |
| 输出目录 `pyramid/{z}/{y}/{x}.png` | 无损 PNG 金字塔；`0/0/0.png` 是全图缩略图 |
| 输出目录 `map.json` | 实际世界范围、像素比例和最大原生缩放级别 |
| 输出目录 `index.html` | Leaflet 浏览器，鼠标位置显示世界 X/Y |

通过现有静态服务器以 HTTP 提供输出目录，打开 `index.html`。示例查看器从 unpkg 加载 Leaflet 1.9.4，需要联网；也可替换为项目已有的本地 Leaflet。图层的像素宽高不必为 512 的整数倍，末端透明填充，实际地图范围记录在 `map.json` 中。

拼接采用固定高度下的参考地面比例：

```text
pixels_per_unit = image_height / (2 × (camera_z − ground_z) × tan(vertical_fov / 2))
step_x = crop_width / pixels_per_unit
step_y = crop_height / pixels_per_unit
```

中心裁切的边界对齐整数像素，蛇形拍摄顺序还原为从北向南的行；X 向右增加，Y 向下减少。末行 / 末列向外覆盖到完整裁切单元，因此实际范围可能稍大于计划。浮点元数据使用能往返保存的精度，避免续拍网格漂移。

## 接入 joric-ootss

把生成的地图目录放到 joric 站点下，例如 `captures/retail/`。它的 `tiles/{z}/{y}/{x}.webp` 路径顺序与现有项目一致，但不能直接沿用 Demo 的 192 单位范围、中心点和变换参数。

在创建 Leaflet 地图前加载 `captures/retail/map.json`，使用下面的 CRS；现有关卡标记仍用 `[worldY, worldX]`。图层路径加上 `captures/retail/` 前缀：

```javascript
const m = await (await fetch('captures/retail/map.json')).json();
const a = m.pixels_per_unit / 2 ** m.max_zoom;
const crs = L.extend({}, L.CRS.Simple, {
  transformation: new L.Transformation(a, -m.xmin * a, -a, m.ymax * a)
});
const bounds = [[m.ymin, m.xmin], [m.ymax, m.xmax]];
const map = L.map('map', { crs, minZoom: 0, maxZoom: m.max_zoom + 2 });
L.tileLayer('captures/retail/' + m.tile_url, {
  tileSize: 512, noWrap: true, bounds,
  maxNativeZoom: m.max_zoom, maxZoom: m.max_zoom + 2
}).addTo(map);
map.fitBounds(bounds);
```

生成的查看器已包含这一变换。正式版关卡位置是否与 Demo 标记一致仍需校验；新底图不会自动纠正旧版关卡目录。

## 当前边界与验证

这是透视俯视图，并非正交投影。参考地面可以按坐标准确拼接；高于 / 低于参考平面的墙、树、建筑仍可能产生透视接缝。增加中心裁切比例可减弱接缝；真正正交模式仍需找到并验证游戏的投影控制。

截图使用前台、无遮挡游戏客户区的桌面 BitBlt。保持窗口 / 无边框模式、完整客户区位于屏幕内；不支持在后台或被其他窗口遮挡时拍摄。游戏自身 UI、Steam 等进程内覆盖层、动态水面、粒子和昼夜变化仍会出现在图中。等待时间是固定延迟，不是游戏资源加载完成信号。先试拍小块区域，再决定高度、重叠率和等待时间。

```powershell
jai -quiet scripts/check_camera_capture.jai -import_dir ../modules
jai -quiet scripts/stitch_map.jai -import_dir ../modules - .build/map-fixture .build/map-test-output
```

回归检查涵盖俯视四元数、键位、命令验证 / 补全、网格范围、奇数分辨率裁切、元数据往返精度、蛇形排序和 PNG 像素拼接，不查看图片。生成的合成测试地图是 2148×1608、四级共 29 张瓦片。游戏内存接口已在运行中的正式版进行只读验证；完整实景拍摄与视觉接缝仍需试拍验收。
