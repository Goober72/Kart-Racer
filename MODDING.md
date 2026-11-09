# Modding Guide

Mods can add or replace **racers** (character + kart) and **tracks**. Racers can
have **scripted abilities** written in GDScript. Use the **Dev build** while
making mods: it shows errors with file names and line numbers, and you can
reload mods without restarting (F9 or the `reload` command).

## Where mods go

| Running... | Mods folder |
|---|---|
| From the Godot editor | `<project>/mods/` |
| An exported build | `mods/` next to the `.exe` |
| Either (per-user) | `user://mods/`: on Windows `%APPDATA%\Godot\app_userdata\Kart Racer\mods` |

The in-game **Mods** button lists the exact folders and any problems.

## Mod structure

```
mods/
  my_cool_mod/
    mod.json
    racers/
      speedy.json
    tracks/
      lava_loop.json
    scripts/            (optional, for scripted abilities)
      my_ability.gd
    models/             (optional, .glb / .gltf files)
      speedy.glb
```

### mod.json
```json
{
  "id": "my_cool_mod",
  "name": "My Cool Mod",
  "version": "1.0",
  "author": "Your name",
  "description": "What it adds.",
  "priority": 0,
  "enabled": true
}
```
- `priority`: mods load lowest-first. If two mods use the same racer/track id,
  the one loaded **last** wins. Use this to make a mod that *replaces* base
  content: give your racer the id `comet` and it replaces Comet.
- `enabled`: set to `false` to switch a mod off without deleting it.

## Racers

`racers/<anything>.json`:
```json
{
  "id": "speedy",
  "name": "Speedy",
  "description": "Shown in the menu.",
  "body_color": "#2f7de1",
  "accent_color": "#ffffff",
  "helmet_color": "#ffcc33",
  "driver_color": "#c98b5a",
  "stats": {
    "max_speed": 31,
    "acceleration": 17,
    "handling": 2.3,
    "drift": 1.0
  },
  "ability": { "type": "boost", "name": "Turbo", "duration": 1.6, "power": 1.4, "cooldown": 8 },
  "model": "",
  "model_scale": 1.0,
  "model_rotation_y": 0
}
```

| Stat | Meaning | Base game range |
|---|---|---|
| `max_speed` | Top speed in m/s (×3.6 = km/h) | 28 – 34 |
| `acceleration` | How fast you reach top speed | 13 – 22 |
| `handling` | Turn rate | 1.9 – 2.9 |
| `drift` | How quickly drift boosts charge | 0.9 – 1.2 |

Anything you leave out uses a default.

### Built-in abilities
| `type` | Parameters |
|---|---|
| `boost` | `duration`, `power` (speed multiplier), `cooldown` |
| `hop` | `height`, `push`, `cooldown` |
| `shockwave` | `radius`, `slow` (0–1), `cooldown` |
| `shield` | `duration`, `cooldown` |
| `none` | no ability |
| `script` | `script`: path to your .gd file, plus any parameters you want |

All abilities accept `name` (shown on the HUD) and `cooldown` (seconds).

### Scripted abilities
```json
"ability": { "type": "script", "script": "scripts/my_ability.gd", "name": "Magnet", "strength": 3 }
```
```gdscript
extends KartAbility

func activate() -> void:
    # params holds everything from the "ability" object
    var strength := float(params.get("strength", 1.0))
    kart.add_boost(1.0, 1.2 + 0.1 * strength)

func on_tick(delta: float) -> void:
    pass  # runs every physics frame
```
Useful things on `kart`: `speed`, `max_speed`, `place`, `velocity`,
`add_boost(seconds, power)`, `spin(seconds)`, `flash(color, radius)`,
`shield_time`, `global_position`. `get_other_karts()` returns every other kart.
See `mods/example_mod/scripts/comeback_boost.gd` for a working example.

> ⚠️ Script mods run real code on your computer. Only install mods from people you trust.

### Custom kart/character models
Set `"model": "models/speedy.glb"` to replace the default kart with your own
3D model. Make models in Blender (free) and export as **glTF 2.0 (.glb)**.
The kart faces **-Z** (Blender's -Y forward / "Forward: -Z" in the exporter),
1 unit = 1 meter, wheels resting at height 0. A normal kart is about 1.5 m wide
and 2.4 m long. Use `model_scale` and `model_rotation_y` to fix size or direction.

## Tracks

`tracks/<anything>.json`:
```json
{
  "id": "lava_loop",
  "name": "Lava Loop",
  "description": "Shown in the menu.",
  "width": 14,
  "laps": 3,
  "points": [
    [0, 0, 0], [80, 0, 0], [130, 5, 40], [100, 8, 100], [20, 4, 110], [-30, 0, 50]
  ],
  "boost_pads": [0.25, [0.6, -3], [0.6, 3]],
  "road_color": "#3b3b42",
  "curb_color_a": "#e84a3c",
  "curb_color_b": "#f4f4f4",
  "wall_color": "#9c7a55",
  "wall_height": 1.4,
  "ground_color": "#4f8f3f",
  "sky_top_color": "#2f6fd0",
  "sky_horizon_color": "#c8e6ff",
  "sun_angle": 50,
  "tree_count": 90,
  "tree_color": "#2e6b2a",
  "model": "",
  "model_collision": false
}
```

### How a track is made
The game joins your `points` into a smooth closed loop and builds the road,
striped curbs, walls, start line, boost pads, ground and trees automatically.

- **Points** are `[x, y, z]` in meters. `y` is height, so hills are just
  points with bigger `y`. The race starts at the first point and goes toward
  the second.
- Keep points roughly **30–60 m apart**. Use more points for tight corners.
- Don't let the loop cross itself. Bridges and crossovers aren't supported yet.
- Keep slopes gentle: about 1 m of height change per 4 m of distance at most.
- **Boost pads** are positions around the lap from `0.0` (start) to `1.0` (end).
  Use `[position, sideways_offset]` to move a pad left (-) or right (+).

### Three ways to make the points
1. **Sketch it:** draw your track on graph paper, one square = 10 m, and
   copy the corner coordinates into the file.
2. **Record it in the Dev build** (easiest):
   - Open the console (F1) and type `sandbox` to go to an empty field.
   - Type `track_new lava_loop`.
   - Drive your route, or press **F6** to fly with the free camera, and
     press **F5** at every corner. Pink numbered posts show your points.
   - `track_undo` removes the last point. `track_preview` turns your points
     into a real track you can drive on straight away.
   - `track_save` writes it to `mods/my_tracks/tracks/lava_loop.json`.
     Run `reload` and it appears in the menu.
   - To tweak an existing track: start a race on it, then `track_edit`.
3. **Build scenery in Blender:** set `"model": "models/scenery.glb"` to add your
   own buildings, bridges, mountains and so on around the generated road. With
   `"model_collision": true` karts can drive on and bump into the model too.

## Dev console commands

Press **F1** (or the backtick key) in the Dev build and type `help`. Highlights:

| Command | What it does |
|---|---|
| `reload` / F9 | Reload all mods and restart the race |
| `mods` | Show loaded mods and every loading message |
| `race <track> [racer] [opponents] [laps]` | Jump straight into a race |
| `sandbox` | Empty field for testing and track recording |
| `speed <x>`, `timescale <x>`, `boost`, `charge` | Testing helpers |
| `tp <meters>` | Teleport along the track |
| `finish` | Test the results screen |
| `pos` | Print your position (to copy into a track file) |
| `freecam` / F6 | Fly around |
| `track_new`, `track_point` (F5), `track_undo`, `track_preview`, `track_save`, `track_edit` | Track recorder |

F3 shows a debug overlay with speed, position, track offset and drift charge.

## Sharing mods
Zip your mod's folder and send it. Your friends unzip it into their `mods/`
folder. Keep it to your own original work or assets you're allowed to share:
please don't include models, textures, music or sounds ripped from commercial games.
