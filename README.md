# Order of the Sinking Star Trainer

使用 Jai 在 Windows 64 位系统上向前台游戏发送按键。

在 `src/main.jai` 中修改操作串：

```jai
send("wwwwdddd");                   // 连续按 4 次 W，再按 4 次 D
send("1ww 2dd z r");                // 切换角色、移动、撤销、重置
send("wwdd", hold_ms = 50, interval_ms = 250);
```

支持 `a-z`、`A-Z` 和数字行的 `0-9`。大小写表示同一个键，不会按 Shift。
空格、Tab 和换行仅用于分隔，不会发送空格键或回车。

每个键默认按住 50 ms，松开后等待 150 ms，再按下一个键。
游戏动画期间漏操作时，增大 `interval_ms`；按键本身未识别时，可以增大 `hold_ms`。
`send` 会等待整个序列完成，成功返回 `true`；输入不支持、发送失败或中止时返回 `false`。
串联多次调用时应检查返回值，避免中止后继续执行后面的操作：

```jai
if !send("1wwww") return;
if !send("2dddd") return;
```

在 PowerShell 中编译、运行：

```powershell
jai -quiet first.jai
.\ootss-helper.exe
```

启动后有 3 秒时间切换到游戏窗口。发送期间保持游戏在前台，并松开手动按住的其他键。
按住 Esc 或切换前台窗口，会在下一次按键前中止当前 `send`。

实现位于 `src/keyboard.jai`，通过 `#load "keyboard.jai";` 复用。
底层使用 `SendInput` 的扫描码模式，模拟按下和松开。
它发送给当前前台窗口，不支持向后台游戏定向发送；游戏也需要允许模拟输入。
如果游戏以管理员权限运行，辅助程序需要相应权限。
