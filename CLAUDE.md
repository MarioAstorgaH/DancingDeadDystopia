# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

"Dancing Dead Dystopia" (`config/name` in `project.godot` is spelled `DeadDancingDistopia`): a mobile, portrait-orientation 2D game built with **Godot 4.7** using GDScript. The UI text is in Spanish (`JUGAR`, `CONFIGURACION`, `SALIR`), so keep any new player-facing strings in Spanish.

## Commands

Godot is installed at `/usr/bin/godot`. There is no build system, linter, or test suite.

```bash
godot --editor --path .                          # open in editor
godot --path . res://screen_main_menu.tscn       # run starting from the main menu
godot --path . res://gameplay_scene.tscn         # run a specific scene
godot --headless --path . --import               # re-import assets / regenerate .godot/ cache
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

Scene flow so far: `screen_main_menu.tscn` → `gameplay_scene.tscn`.
- **Menu:** `menu_buttons.gd` is attached to `button_container` and handles all three menu buttons. JUGAR calls `change_scene_to_file`, and SALIR calls `quit()`. CONFIGURACION is `disabled` until a settings screen exists.
- **Gameplay:** the root is a `Node2D` for the game world. Touch controls go under `HUD` (a `CanvasLayer`) and use anchored `Control`s, e.g. `bottom_left`, so they stay at the screen edges with `aspect="expand"`.

Scene paths are hardcoded `res://` strings, so update them if you move files.

## Godot file conventions

- `.tscn`/`.tres` files reference resources by both `uid://` and `res://` path. Each `.gd` has a companion `.gd.uid` file, and each imported asset has a `.import` file. Commit these companion files, and move or rename them together with their source files (preferably through the editor) so UIDs don't break.
- Signal connections are declared in the `.tscn` (`[connection ...]` sections), not in code. Check the scene file when tracing handlers.
- `.godot/` (the import cache) and `/android/` are gitignored. Line endings are normalized to LF (`.gitattributes`).
