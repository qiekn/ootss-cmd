# 使用与开发

- [俯视相机、HUD 与大地图拍摄](docs/map-capture.md)
- [游戏内存布局与版本适配](docs/game-memory.md)
- [离线关卡格式](docs/custom_levels.md)

控制台内执行 `help` 查看命令；命令名称和相机选项不区分大小写。

```powershell
jai -quiet first.jai -import_dir modules
jai -quiet first.jai -optimized -import_dir modules
```

普通构建输出到项目根目录；优化构建输出到 `bin/`，保留已有配置和玩家保存数据。运行中的旧程序需要退出后再启动新程序。
