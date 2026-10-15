# New Command

## hint

```bash
hint <level_name>
```

if you omit <level_name>, it will auto detact curretn level_name and use it as default arugment.

just like `do` or `play`, `hint` will do a ounch of inputs. But instead of help you complete this level, it show you some tips or tricks that helpful for current level.

# Big Features

## runtime level editor

offer a list of entities, e.g.

- <entity_name_1> <x, y, z>
- <entity_name_2> <x, y, z>
- <entity_name_3> <x, y, z>
- <entity_name_4> <x, y, z>

A entity is a in-game object like Player/Cristal/Mirror/BeamCaster etc. You can choose a entity.

- Then `W/S/A/D` to move it
- `E` to rise up, `Q` to decline.
- `R` to clockwise rotate 90 degree, and `Shift+R` to anticlockwise rotate 90 degree.

`Ctrl+D` to duplicate current selected entity (default left near origin entity)

# Small Fixes

## hud text

when `hud_hide_on_focus_loss = true;`, only auto hide top-left hud text, do not auto hide hud notify text.

e.g. `noclip enable/disable` notify hud text should always show.

## jump command


## solution editor undo

Currently, when player press `undo` key, solution eidtor timeline scroll right,
and don't erase the undo key. Maybe we don't want that. When player press `Z`, we erase that key in timeline.

## key hold multi movement when recoding in solution editor

If user hold movement key like `W` for a whiel, in game character will move multiple steps.
But we only record once.

## time stop

Press `P` to pause time.

And change notify text to `Jotaro Kujo: “Star Platinum: The World!” Speed 0.0x`
when press `P` again, resume original speed. and notify `Jotaro Kujo: “And time resumes.” Speed ???`

Also play audio during the pahse.

- time-stop.ogg
- time-resume.ogg
- time-stop_alt.ogg
- time-resume_alt.ogg

Pause time when `time-stop.ogg` finised.

There is a 1/3 probability of using the alt version.

Remember to match "stop" and "resume" when using alt version.

Always single audio track at same time. That means when you abuse pressing p, no mutiple audio track playing at the same time.
