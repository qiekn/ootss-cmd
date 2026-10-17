## Order of the Sinking Star Overlay Console

![teaser](./screenshots/teaser.jpg)

NOTE: OotSS is frequently updated, so some features of this tool may stop working from time to time. I’m currently spending most of my time playing through the game, so I may fix these issues later. Last verified with game version r67271 (October 17, 2026).

Recommand use [AutoHotKey](https://www.autohotkey.com/) to remap you CapsLock to Ctrl

```
CapsLock::Ctrl
```

## Build

```bash
jai first.jai -optimized # can be shortened to -o
```

The output executable file is `bin/ootss-cmd.exe`. The configuration file is `config.rc` (you can set your game path here). Run OotSS before launching this application if you haven't set game_path in `config.rc`.

## Features

### Subtitles

![subtitles](./screenshots/subtitles.jpg)

### Noclip

![noclip](./screenshots/noclip.jpg)

### Freecam

![freecam](./screenshots/freecam.jpg)

![freecam_2](./screenshots/freecam_2.jpg)

### Solution Player / Editor

![solution](./screenshots/solution_editor.jpg)

### Alias & Keymap

```bash
# Use alias name=command in the console for a temporary override.
# unalias name removes that override and restores this file's definition.

tp = back;

fastplay = "play -superfast";
fastdo = "play -superfast";
subtitles = "show subtitles"
level_name = "show level"

# Custom Keymaps
map m = "move -z 1";
map , = noclip;
map o = "show subtitles";
```

### Position markers and Teleport

![markers](./screenshots/markers.jpg)

### Others

For more, see [console.jai](./src/ui/console.jai) `CONSOLE_COMMANDS` , or use `help` command.

Here is a [Document](docs/document.md). But AI-Generated.

## References

**Solutions**

- https://sinkingstar.wikitactics.com/
- https://joric.github.io/ootss/
