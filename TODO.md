# Fix

## solutioin player default key delay

Currently 250ms for each key. Even switch a character takes 250ms. These causes we can't finish `worlds_collde_heroes_and_stones`. We need to fix it.

## solution player support sprint

In OotSS, when you press `Ctrl`, it slows time and also enable sprint. Some level like Bard and stones, we need use sprint or quick input (less than 250ms) to move cristals before stone arrive. Anyway, there is still lots of things to do with solution player.

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

# Small Features

## key hold multi movement when recoding in solution editor

If user hold movement key like `W` for a whiel, in game character will move multiple steps.
But we only record once.
