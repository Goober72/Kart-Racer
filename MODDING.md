# Modding Guide

Mods can add or replace **racers** (character + kart, optionally 3D models with
animations), **tracks** (a list of points, or a 3D model) and **items**. Every
racer has a **skill** with a quick (tap) and charged (hold) version. Skills and
items are built from the same **effects**, and you can write new effects or
whole skills in GDScript. Use the **Dev build** while
making mods: it shows errors with file names and line numbers, and you can
reload mods without restarting (F9 or the `reload` command).

## The quickest way: Create a Racer

In the Dev build (including the browser version) press **Create a Racer** on the
main menu. Pick a name, colors, stats and an ability. You get **15 points** to
spread across four stats (1–5 each) and ability power (1–3), so every racer
stays fair. **Save** adds them to the racer list, **Save + Test Drive** starts a
quick race, and **Share file** gives you the `.json` file to send to friends.

You can also make a **2D racer from PNG images** (see below), or **import a
character model and a kart model** (.glb) here, even on a phone: use Size/Turn until it faces away from the camera, Seat height to
sit the character in the kart, and **Test animations** to check them.

Created racers are saved as a normal mod called `my_racers` in your user mods
folder (see below), so you can open the file and keep editing it by hand, for
example to write a fully custom skill.

## Where mods go

| Running... | Mods folder |
|---|---|
| From the Godot editor | `<project>/mods/` |
| An exported build | `mods/` next to the `.exe` |
| Either (per-user) | `user://mods/`: on Windows `%APPDATA%\Godot\app_userdata\Kart Racer\mods` |
| Browser version | Mods in the repo's `mods/` folder are built in; your own creations live in browser storage |

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
    items/
      banana_peel.json
    scripts/            (optional, for scripted skills/effects)
      my_skill.gd
    models/             (optional, .glb files)
      speedy.glb
      speedy_kart.glb
      lava_loop.glb
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

## Skills

Every racer has one skill with two versions:
- **Tap** the skill button: the quick version, short cooldown (`cooldown`).
- **Hold** it for 1 second: the charged version, longer cooldown (`charged_cooldown`).

A skill is a list of **effects** for each version:
```json
"ability": {
  "name": "Root Quake",
  "cooldown": 8,
  "charged_cooldown": 13,
  "tap":     { "name": "Tremor",     "effects": [ { "type": "shockwave", "radius": 11 } ] },
  "charged": { "name": "Root Quake", "effects": [
      { "type": "shockwave", "radius": 18, "hit": { "spin": 0.8, "slow": 0.55 } },
      { "type": "drop", "shape": "vines", "single_use": false, "lifetime": 12 } ] }
}
```
Each base racer has its own skill, so look at `content/base/racers/` for more examples.

**Presets** save typing (the racer creator uses these):
`{"type": "boost" | "hop" | "shockwave" | "shield" | "oil" | "bolt" | "storm" | "cloud", "level": 1-3, "name": "My Skill"}`.

### Effects

Skills and items both use these. All numbers are optional.

| `type` | What it does | Options |
|---|---|---|
| `boost` | Speed up | `duration`, `power` (1.35 = 35% faster) |
| `hop` | Jump | `height`, `push` (extra speed) |
| `shield` | Block hits, soften wall bumps | `duration` |
| `shockwave` | Hit everyone nearby | `radius`, `color`, `hit` |
| `drop` | Leave a trap behind you | `shape` (`puddle`, `spikes`, `cloud`, `vines`, `box`), `radius`, `lifetime`, `count`, `spread`, `single_use`, `color`, `hit` |
| `throw` | Fire a projectile | `homing` (chase the racer ahead), `count`, `speed`, `size`, `color`, `lifetime`, `hit` |
| `zap` | Strike racers anywhere | `target` (`next`, `ahead`, `leader`, `all`), `color`, `hit` |
| `script` | Run your own GDScript | `script` (path), plus anything your script reads |

`hit` says what happens to whoever gets hit: `{"spin": seconds, "slow": 0-1, "bounce": upward speed}`.
Shields block hits.

### Scripted effects and skills
A custom effect, usable from any skill or item:
```json
{ "type": "script", "script": "scripts/warp_effect.gd", "distance": 35 }
```
```gdscript
extends KartEffect

func apply(user: Kart, params: Dictionary) -> void:
    user.add_boost(1.0, 1.2)
```
A fully custom skill: `"ability": {"type": "script", "script": "scripts/my_skill.gd", ...}`:
```gdscript
extends KartAbility

func activate(charged: bool) -> void:
    var power := 1.6 if charged else 1.3
    kart.add_boost(1.0, power)
```
Useful things on a `Kart`: `speed`, `max_speed`, `place`, `velocity`, `item`,
`add_boost(seconds, power)`, `spin(seconds)`, `flash(color, radius)`,
`shield_time`, `global_position`, `give_item(data)`. Helpers:
`Effects.apply(kart, {...})`, `Effects.hit(kart, {...})`, `Effects.others(kart)`,
`Effects.race_of(kart)` (has `.track` and `.karts`). See
`mods/example_mod/scripts/` for working examples.

> ⚠️ Script mods run real code on your computer. Only install mods from people you trust.

## Items

`items/<anything>.json`:
```json
{
  "id": "banana_peel",
  "name": "Peel",
  "label": "P",
  "color": "#f2e14e",
  "description": "Drop it behind you.",
  "uses": 1,
  "weights": [5, 3, 1],
  "effects": [ { "type": "drop", "shape": "puddle", "color": "#f2e14e", "hit": { "spin": 1.0 } } ]
}
```
- `label` and `color` make the icon on the HUD.
- `uses`: how many times it can be used (like Triple Nitro).
- `weights`: how likely it is when you're **[in 1st, in the middle, near the back]**.
  Use `0` to never give it in that group.
- `effects`: any effects from the table above, including `script`.

Item boxes are placed automatically (see `item_rows` in tracks). Look at
`content/base/items/` for the built-in items and `mods/example_mod/items/` for
a JSON-only item and a scripted one.

## 3D models for racers

```json
"character_model": {
  "file": "models/me.glb",
  "scale": 1.0,
  "rotation_y": 0,
  "offset": [0, 0, 0],
  "animations": { "idle": "Idle", "drive": "Drive", "steer_left": "LeanLeft", "steer_right": "LeanRight",
                  "boost": "Boost", "skill": "Special", "hit": "Hit", "win": "Cheer", "lose": "Sad" }
},
"kart_model": {
  "file": "models/my_kart.glb",
  "scale": 1.0,
  "rotation_y": 0,
  "seat": [0, 0.55, 0],
  "wheels": [],
  "front_wheels": []
}
```
- Use either, both or neither. Without `kart_model` you get the default kart
  (in your colors); without `character_model` you get the default driver.
- **Animations** are chosen automatically from what the kart is doing. If you
  leave `animations` out, the game guesses from the names (an animation with
  "idle" in its name becomes idle, "drive"/"run" becomes drive, "left"/"right",
  "boost", "skill"/"attack", "hit"/"spin", "win"/"cheer"/"victory", "lose"/"sad").
  Only `idle` is really needed.
- **Wheels**: any part with "wheel" in its name spins. Ones with "front"/"F"
  in the name (e.g. `Wheel_FL`) also turn when steering. Or list node names in
  `wheels` / `front_wheels`. A kart animation (e.g. a bouncing engine) loops.
- The character's origin (0,0,0) is placed at the kart's `seat`.

**Making models in Blender (free):**
1. Model facing **-Y** in Blender (that's "forward" for the game), 1 unit = 1 meter.
   A kart is about 1.5 m wide and 2.5 m long, with wheels resting on the ground (z = 0).
2. For animations, use an Armature or animate objects directly; give each Action
   a clear name (Idle, Drive, Cheer...) and push it to the NLA or tick "All Actions" when exporting.
3. **File → Export → glTF 2.0**, Format: **glTF Binary (.glb)**, with "Animation" enabled.
4. Import it with Create a Racer, or put it in your mod's `models/` folder.

The example mod's racer **Rivet** (`mods/example_mod/racers/rivet.json`) uses an
animated robot and a rocket kart. `tools/make_example_models.gd` shows how they're built.

## 2D racers (PNG images)

A racer can be drawn instead of modelled, like retro kart games. The picture
always faces the camera.

**In game:** Create a Racer → **2D Sprites**:
- **Pick images** (or **Pick folder** on a computer): select all your images at
  once and they're sorted into animations by their file names.
- **One by one**: choose an animation with `<` `>`, then **Add frames** to put
  images into it whatever they're called.
- **Covers**: *whole kart* (your picture shows kart and driver) or *driver only*
  (your picture sits in a 3D kart). **Size**, and **Smooth/Pixel** for
  pixel-art vs. smooth images.

**File names** (any order, any case, `-` or `_`):
`<animation>[_<view>][_<frame number>].png`
- animation: `idle` (the only one you need), `drive`, `left`, `right`, `boost`,
  `skill`, `hit`, `win`, `lose`. Missing ones fall back to drive/idle.
- view (optional): `back` (what you see behind your own kart), `front`, `side`.
  Draw side views facing **right**; they're mirrored for the other side.
  Without views, the same picture is used from every angle.
- frame number: frames play in number order (`drive_1`, `drive_2`, ...).

Examples: `idle.png`, `drive_1.png`, `drive_2.png`, `drive_back_1.png`,
`left_back_1.png`, `hit_side_2.png`, `win_front_1.png`.

**In a mod file:**
```json
"sprite": {
  "folder": "sprites/pip",
  "covers": "kart",
  "height": 2.4,
  "fps": 6,
  "pixel_art": true
}
```
Images in the folder are sorted by name, or list them yourself with
`"frames": {"idle": {"back": ["a.png", "b.png"], "any": ["c.png"]}}`.
See the example mod's **Pip** (`mods/example_mod/sprites/pip/`), drawn by
`tools/make_example_sprites.gd`. PNG with transparency works best; WEBP and JPG
also load.

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
  "model_collision": false,
  "road": true,
  "ground": true,
  "item_rows": [0.22, 0.62],
  "items_per_row": 4
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

### Tracks made entirely from a 3D model
Build the whole track (road, walls, ground, scenery) in Blender, then:
```json
{ "id": "lava_loop", "name": "Lava Loop", "model": "models/lava_loop.glb",
  "model_collision": true, "road": false, "ground": false, "tree_count": 0 }
```
The game still needs a **racing line**: it decides where the race starts, counts
laps, places racers, guides the computer drivers and respawns you. Two ways to
give it one:

- **Markers in the model (easiest for Blender users):** add Empties along the
  middle of your road, in race order, named `Path_001`, `Path_002`, `Path_003`...
  `Path_001` is the start/finish line, and the race heads toward `Path_002`.
  Optional markers: `ItemBox...` (an item box at each), `BoostPad...` (a boost
  pad, facing the Empty's -Y), `Start` (where you appear in free roam).
  The example mod's **Loop Park** works like this.
- **Record it in game:** main menu → **Import Track Model** (Dev build, works on
  phones too). You're dropped onto your model in free roam with the recorder
  running: drive the route pressing **+ Point** (F5) at each corner, starting at
  the finish line, then **Preview** and **Save track**. The points are saved into
  the track's file, and from then on it's a normal race track.

Item boxes default to two rows (`item_rows`); set `"item_rows": []` for none.

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
