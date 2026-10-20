# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

"Dancing Dead Dystopia" (the repo directory is spelled `dead-dancing-distopia`): a mobile, portrait-orientation 2D game built with **Godot 4.7** using GDScript. The UI text is in Spanish (`JUGAR`, `CONFIGURACION`, `SALIR`), so keep any new player-facing strings in Spanish.

## Commands

Godot is installed at `/usr/bin/godot`. There is no build system, linter, or test suite.

```bash
godot --editor --path .                          # open in editor
godot --path . res://screen_main_menu.tscn       # run starting from the main menu
godot --path . res://gameplay_scene.tscn         # run a specific scene
godot --headless --path . --import               # re-import assets / regenerate .godot/ cache
godot --headless --path . --check-only --script res://path/to/file.gd   # parse-check one script
```

`run/main_scene` is `screen_main_menu.tscn`, so `godot --path .` (or F5) starts at the menu.

The Godot MCP server (`mcp__godot__*`) may be available for launching or running the project, reading debug output, and creating or editing scenes.

## Display / platform settings

These settings constrain all UI and layout work:
- The design resolution is **1080×1920** (portrait), but the desktop window is overridden to 360×640 for testing. Use stretch mode `canvas_items` with aspect `expand`. Lay out UI with anchors and containers, not absolute positions.
- The project uses the `mobile` renderer, the `Mobile` feature tag, and handheld orientation `5` (sensor portrait). Use touch input, e.g. `TouchScreenButton` as in `gameplay_scene.tscn`.

## Structure

Scenes and scripts live at the project root. Assets are organized by type under `Assets/`:
- `Assets/Images/Buttons/`: brain buttons in four colors (blue/green/red/yellow), each with a `_pressed` variant. These are probably the rhythm or dance input buttons. All of them are 480×480 with the brain in the same position. The pressed variant adds a glow in the padding. Keep new variants pixel-aligned, because `TouchScreenButton` draws from the top-left corner. Use a `shape` on the button so the touch area covers only the brain.
- `Assets/Images/Zombie/`: `zombie_frame_1..6.png`, an animation sequence intended for an `AnimatedSprite2D` / `SpriteFrames`.
- `Assets/Fonts/ghost_shadow/`: the title and menu font.
- `Assets/configs/buttons/`: shared `StyleBox` `.tres` resources for the menu buttons' normal, hover, and pressed states. Reuse these resources for new menu buttons instead of creating inline styles.
- `Assets/Audio/audio perron/`: the button-press SFX (`.wav`) and the menu music `Plant Night Lullaby.m4a`. Godot can't import `.m4a` (it has no `.import` file), so the music has to be converted to `.ogg` or `.mp3` before it can be used. `default_bus_layout.tres` defines the audio buses `MenuMusic`, `GameMusic`, and `Effects` (all routed to `Master`). Assign players to the matching bus.
- `Assets/Scripts/`: reusable scripts. `menu_button_sound.gd` (`class_name MainMenuButton extends Button`) is unfinished: `play_sound()` has no body, so the script fails to parse, and no scene uses it yet.

The root-level `blue_button.gd` and `button_container.gd` are empty editor templates that no scene references.

Scene flow so far: `screen_main_menu.tscn` → `gameplay_scene.tscn` or `screen_settings.tscn` (VOLVER returns to the menu).
- **Menu:** `menu_buttons.gd` is attached to `button_container` and handles all three menu buttons. JUGAR and CONFIGURACION call `change_scene_to_file`, and SALIR calls `quit()`.
- **Settings:** `AudioSettings` (`audio_settings.gd`) is an autoload. At startup it loads each bus's volume (0–100) from `user://settings.cfg` and applies it; 0 mutes the bus. In `screen_settings.tscn`, each slider row uses `volume_row.gd` with an exported `bus_name`. Values are saved when you leave the screen. To add a slider for a new bus, duplicate a row and change `bus_name`.
- **Gameplay:** the root is a `Node2D` for the game world. Touch controls go under `HUD` (a `CanvasLayer`) and use anchored `Control`s, e.g. `bottom_left`, so they stay at the screen edges with `aspect="expand"`.

Scene paths are hardcoded `res://` strings, so update them if you move files.

## Godot file conventions

- `.tscn`/`.tres` files reference resources by both `uid://` and `res://` path. Each `.gd` has a companion `.gd.uid` file, and each imported asset has a `.import` file. Commit these companion files, and move or rename them together with their source files (preferably through the editor) so UIDs don't break.
- Signal connections are declared in the `.tscn` (`[connection ...]` sections), not in code. Check the scene file when tracing handlers.
- `.godot/` (the import cache) and `/android/` are gitignored. Line endings are normalized to LF (`.gitattributes`).
