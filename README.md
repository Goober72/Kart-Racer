# Kart Racer

An original arcade kart racer built to be modded. Drift through corners, charge
up boosts, use your racer's special ability, and race against computer drivers.
Add your own racers and tracks by dropping a folder into `mods/`.

Made with [Godot 4.3](https://godotengine.org/download/archive/4.3-stable/) (free and open source).

## Two versions: Dev and Play

The same project exports two versions of the game:

| | **Dev build** (`KartRacer-Dev`) | **Play build** (`KartRacer`) |
|---|---|---|
| For | Making and testing mods | Just playing |
| Mods load | Yes | Yes |
| Dev console (F1) | Yes | No |
| Debug overlay (F3) | Yes | No |
| Track recorder (F5) + free camera (F6) | Yes | No |
| Hot reload of mods (F9) | Yes | No |
| Mod errors shown on screen | Yes, with file and line | Problem list in the Mods menu |
| Sandbox test track | Yes | Hidden |
| Exported as | Debug (console window shows logs) | Release (faster) |

Running the project from the Godot editor always behaves like the Dev build.
To try the Play build from the editor, add `--play` under
*Project → Project Settings → Editor → Run → Main Run Args* (or launch with `godot -- --play`).

## Getting the game

### Option A: download a build (no Godot needed)
Every push to `main` builds the game automatically on GitHub:
1. Open the repo's **Actions** tab, then the latest **Build game** run.
2. Scroll to **Artifacts** and download `KartRacer-Windows-Play` (or `-Dev`, or the Linux versions).
3. Unzip it and run `KartRacer.exe` (or `KartRacer-Dev.exe`).

Pushing a tag such as `v0.1.0` also creates a GitHub Release with all four zips attached.

### Option B: run from source
1. Install [Godot 4.3](https://godotengine.org/download/archive/4.3-stable/) (the standard version, not .NET).
2. In the Project Manager click **Import** and pick this folder's `project.godot`.
3. Press **F5** (Run Project).

### Exporting yourself
Install the 4.3 export templates (*Editor → Manage Export Templates*), then
*Project → Export* and choose one of the presets:
`Windows - Dev`, `Windows - Play`, `Linux - Dev`, `Linux - Play`.
Use **Export With Debug** for Dev and plain **Export** for Play.
Copy the `mods/` folder next to the exported game so mods are found.

## Controls

| Action | Keyboard | Gamepad |
|---|---|---|
| Accelerate | W / Up | RT or A |
| Brake / reverse | S / Down | LT |
| Steer | A D / Left Right | Left stick / D-pad |
| Drift (hold while turning) | Space / Shift | RB or B |
| Ability | E / F | X or LB |
| Respawn | R | Y |
| Pause | Esc / P | Start |

**Drifting:** hold drift while turning. Sparks go blue, then orange, then purple.
Let go to get a boost; the longer the drift, the bigger the boost.

## Modding

See **[MODDING.md](MODDING.md)**. Short version: a mod is a folder in `mods/`
with a `mod.json`, plus `racers/*.json` and/or `tracks/*.json`. Tracks are just
a list of points; the game builds the road, walls and scenery for you. The Dev
build can record a track while you drive or fly around.

## Project layout

```
content/base/        Base game racers and tracks (loaded exactly like a mod)
mods/                Mods (example_mod is included)
scenes/              Main menu and race scenes (they're built in code)
scripts/autoload/    BuildInfo (dev/play), ModLoader, GameState
scripts/kart/        Kart physics, visuals, player/AI controllers, abilities
scripts/race/        Race rules, track generator, camera, boost pads
scripts/ui/          Menus and HUD
scripts/dev/         Dev-build tools (console, recorder, free cam)
tests/               Automated smoke test
```

Run the automated test (it races every track with computer drivers):
```
godot --headless --fixed-fps 60 --path . res://tests/smoke_test.tscn
```

## A note on assets

Everything in this project is original. Please don't add models, music or
other assets ripped from commercial games: they're copyrighted, and they would
make the project impossible to share. Make your own, or use assets with a
license that allows it (for example CC0 models from sites like Kenney.nl,
Quaternius or Poly Pizza).
