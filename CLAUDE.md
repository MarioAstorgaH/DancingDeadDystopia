# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

"Dancing Dead Dystopia" (the repo directory is spelled `dead-dancing-distopia`): a mobile, portrait-orientation 2D game built with **Godot 4.7** using GDScript. The UI text is in Spanish (`JUGAR`, `CONFIGURACION`, `SALIR`), so keep any new player-facing strings in Spanish.

## Commands

Godot is installed at `/usr/bin/godot`. There is no build system, linter, or test suite.

```bash
godot --editor --path .                          # open in editor
godot --path . res://menu/screen_main_menu.tscn  # run starting from the main menu
godot --path . res://game/gameplay_scene.tscn    # run a specific scene
godot --headless --path . --import               # re-import assets / regenerate .godot/ cache
godot --headless --path . --check-only --script res://path/to/file.gd   # parse-check one script
godot --headless --path . -s res://tools/midi_to_chart.gd -- Assets/Songs/<id>   # lead.mid -> chart.json
godot --headless --path . -s res://tools/midi_to_chart.gd -- --all               # every song with a lead.mid
```

Re-run the converter after changing a `lead.mid` or the mapping rules in `chart_mapper.gd`; the generated `chart.json` files are not updated automatically.

`run/main_scene` is `menu/screen_main_menu.tscn` (referenced by UID), so `godot --path .` (or F5) starts at the menu.

The Godot MCP server (`mcp__godot__*`) may be available for launching or running the project, reading debug output, and creating or editing scenes.

## Display / platform settings

These settings constrain all UI and layout work:
- The design resolution is **1080×1920** (portrait), but the desktop window is overridden to 360×640 for testing. Use stretch mode `canvas_items` with aspect `expand`. Lay out UI with anchors and containers, not absolute positions.
- The project uses the `mobile` renderer, the `Mobile` feature tag, and handheld orientation `5` (sensor portrait). Use touch input, e.g. `TouchScreenButton` as in `gameplay_scene.tscn`.

## Structure

Code is organized by module. Each scene lives next to the scripts it uses, and the project root holds no scripts:
- `menu/`: the main menu (`screen_main_menu.tscn`, `menu_buttons.gd`). `menu_button_sound.gd` (`class_name MainMenuButton extends Button`) is unfinished: `play_sound()` has no body, so the script fails to parse, and no scene uses it yet. `button_container.gd` is an empty editor template.
- `settings/`: the settings screen and the `AudioSettings` autoload (`audio_settings.gd`).
- `song_select/`: the song select screen and its `song_card.tscn` rows.
- `songs/`: song and chart data shared by several modules: `SongInfo`, `SongLibrary`, `MidiFile`, `ChartMapper`. These are code modules; the song files themselves live in `Assets/Songs/`.
- `game/`: `gameplay_scene.tscn`, the game world.
- `hud/`: `hud.tscn`, the shared HUD for every song, instanced inside `gameplay_scene.tscn`. `blue_button.gd` is an empty `TouchScreenButton` template that isn't attached to anything yet.
- `tools/`: command-line scripts that don't run inside the game (`midi_to_chart.gd`).

Assets are organized by type under `Assets/`:
- `Assets/Images/Buttons/`: brain buttons in four colors (blue/green/red/yellow), each with a `_pressed` variant. These are probably the rhythm or dance input buttons. All of them are 480×480 with the brain in the same position. The pressed variant adds a glow in the padding. Keep new variants pixel-aligned, because `TouchScreenButton` draws from the top-left corner. Use a `shape` on the button so the touch area covers only the brain.
- `Assets/Images/Zombie/`: `zombie_frame_1..6.png`, an animation sequence intended for an `AnimatedSprite2D` / `SpriteFrames`.
- `Assets/Fonts/ghost_shadow/`: the title and menu font. It has no glyphs for accented letters such as `Ú` or for arrows such as `▲`, so player-facing text is written in uppercase without accents. Its glyphs are also drawn taller than the line height it reports. That's why the button styles use `content_margin_top = 40`, and why stacked labels need extra separation so they don't overlap.
- `Assets/configs/buttons/`: shared `StyleBox` `.tres` resources for the menu buttons' normal, hover, and pressed states. Reuse these resources for new menu buttons instead of creating inline styles.
- `Assets/Audio/audio perron/`: the button-press SFX (`.wav`) and `Plant Night Lullaby.m4a`. That file is corrupt (no valid header, not even `ffmpeg` can open it), so it needs to be replaced; Godot also can't import `.m4a`, so use `.ogg` or `.mp3`. `default_bus_layout.tres` defines the audio buses `MenuMusic`, `GameMusic`, and `Effects` (all routed to `Master`). Assign players to the matching bus.


Scene flow so far: `screen_main_menu.tscn` → `screen_song_select.tscn` → `gameplay_scene.tscn`, or menu → `screen_settings.tscn`. VOLVER and the Android back gesture return to the menu.
- **Menu:** `menu_buttons.gd` is attached to `button_container` and handles all three menu buttons. JUGAR and CONFIGURACION call `change_scene_to_file`, and SALIR calls `quit()`.
- **Song select:** `SongLibrary` (`song_library.gd`, static) scans `res://Assets/Songs/` with `ResourceLoader.list_directory()`. Each song is a folder with a `song.json` (`title`, `artist`, `difficulty` 1–10, `audio` file name, optional `cover`) plus its audio. The duration is not stored; it comes from `AudioStream.get_length()`. Folders with a bad JSON or missing audio are skipped with a warning. Each folder also has a `lead.mid` (a MIDI containing only the lead melody) and the `chart.json` generated from it. `chart.json` holds `{version, source, notes: [{time, length, pitch, lane}]}` with times in seconds; `length` is kept for future hold notes, but for now every note is played as a tap. The MIDI's time 0 is taken as the start of the audio, so any lead-in silence in the audio belongs in an `offset` in `song.json`, applied by the gameplay. `song_select.gd` sorts by difficulty, name, artist or duration (tapping the same button again reverses the order) and instantiates `song_card.tscn` rows at runtime; their `pressed` signal is connected in code, the rest in the `.tscn`. The chosen song is stored in `SongLibrary.selected_song` (a static var, so it survives the scene change) for `gameplay_scene` to read. `Assets/Songs/` is empty for now, so the screen shows NO HAY CANCIONES. When exporting, add `*.json` to the preset's "non-resource files" filter or the `song.json` files won't be included in the `.pck`.
- **Charts (MIDI → lanes):** `MidiFile` (`midi_file.gd`) is a dependency-free parser for Standard MIDI Files (formats 0 and 1, tempo map, running status). `ChartMapper` (`chart_mapper.gd`) assigns 4 lanes, left to right `Lane { GREEN, RED, YELLOW, BLUE }`, with higher notes further right. Chords collapse to their highest note. The melody is split into phrases at rests of 1 beat or more, or every 4 bars, and each phrase is normalized over at least 7 semitones. The lane never moves against the melody: repeated notes stay in the same lane, small steps may stay in the same lane, a leap of 3 or more semitones moves at least 1 lane, and an octave moves at least 2 lanes.
- **Settings:** `AudioSettings` (`audio_settings.gd`) is an autoload. At startup it loads each bus's volume (0–100) from `user://settings.cfg` and applies it; 0 mutes the bus. In `screen_settings.tscn`, each slider row uses `volume_row.gd` with an exported `bus_name`. Values are saved when you leave the screen. To add a slider for a new bus, duplicate a row and change `bus_name`.
- **Gameplay:** the root is a `Node2D` for the game world. The HUD is a separate scene (`hud/hud.tscn`) instanced as `HUD`; put touch controls, score, etc. there, not in `gameplay_scene.tscn`. Touch controls go under the HUD's `CanvasLayer` and use anchored `Control`s, e.g. `bottom_left`, so they stay at the screen edges with `aspect="expand"`.

Scene paths are hardcoded `res://` strings (`*_SCENE` constants in the scripts, the autoload in `project.godot`, `SongLibrary.SONGS_DIR`), so update them if you move files. Moving a `.gd` without its `.gd.uid` breaks the `uid://` references.

## Godot file conventions

- `.tscn`/`.tres` files reference resources by both `uid://` and `res://` path. Each `.gd` has a companion `.gd.uid` file, and each imported asset has a `.import` file. Commit these companion files, and move or rename them together with their source files (preferably through the editor) so UIDs don't break.
- Signal connections are declared in the `.tscn` (`[connection ...]` sections), not in code. Check the scene file when tracing handlers.
- `.godot/` (the import cache) and `/android/` are gitignored. Line endings are normalized to LF (`.gitattributes`).
