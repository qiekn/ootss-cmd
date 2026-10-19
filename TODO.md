# Features

## solutions.json hotload

## solution editor timeline actually pause time

In speed 1x. each key 250ms, when player forward one key, resume time, wait (250ms / speed), then pause time.

## measture time

- guys move speed
- guys fall speed
- push/pull stone/mirrors speed
- rover speed
- stone skipping speed
- crystal stone skipping speed

## solution format

switch guys: `<space>number<space>` to `number<space>`  
e.g. from `DDLL 1 UDD 2 LLL` to `DDLL 1UDD 2LLL`

wat time: `_seconds_` to `<seconds>`

## Runtime level editor

offer a list of entities, e.g.

- <entity_name_1> <x, y, z>
- <entity_name_2> <x, y, z>
- <entity_name_3> <x, y, z>
- <entity_name_4> <x, y, z>

A entity is a in-game object like Player/Cristal/Mirror/BeamCaster etc. You can choose a entity.

- `W/S/A/D` to move it
- `E` to rise up, `Q` to decline.
- `R` to clockwise rotate 90 degree, and `Shift+R` to anticlockwise rotate 90 degree.
- `Ctrl+D` to duplicate current selected entity

# Refactor

Remove AI-Generated code
