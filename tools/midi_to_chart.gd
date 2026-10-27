extends SceneTree

## Convierte el lead.mid de una canción en su chart.json.
## Uso:
##   godot --headless --path . -s res://tools/midi_to_chart.gd -- Assets/Songs/<id>
##   godot --headless --path . -s res://tools/midi_to_chart.gd -- --all

const MIDI_NAME := "lead.mid"
const CHART_NAME := SongLibrary.CHART_NAME
const LANE_NAMES := ["verde", "rojo", "amarillo", "azul"]
const FIGURE_NAMES := {2: "corcheas", 3: "tresillos", 4: "semicorcheas"}


func _initialize() -> void:
	var folders := _folders_from_args(OS.get_cmdline_user_args())
	if folders.is_empty():
		printerr("Uso: godot --headless --path . -s res://tools/midi_to_chart.gd -- Assets/Songs/<id> | --all")
		quit(1)
		return
	var failed := 0
	for folder in folders:
		if not _convert(folder):
			failed += 1
	quit(1 if failed > 0 else 0)


func _folders_from_args(args: PackedStringArray) -> PackedStringArray:
	var folders := PackedStringArray()
	if args.has("--all"):
		for dir in DirAccess.get_directories_at(SongLibrary.SONGS_DIR):
			if FileAccess.file_exists(SongLibrary.SONGS_DIR + dir + "/" + MIDI_NAME):
				folders.append(SongLibrary.SONGS_DIR + dir)
		return folders
	for arg in args:
		if arg.begins_with("res://"):
			folders.append(arg.trim_suffix("/"))
		elif arg.is_absolute_path():
			folders.append(ProjectSettings.localize_path(arg).trim_suffix("/"))
		else:
			folders.append(("res://" + arg).simplify_path())
	return folders


func _convert(folder: String) -> bool:
	var midi := MidiFile.load_file(folder + "/" + MIDI_NAME)
	if midi == null:
		return false
	var chart := ChartMapper.map(midi)
	if chart.is_empty():
		printerr("%s: el MIDI no tiene notas" % folder)
		return false

	# Una entrada por línea para que el archivo se pueda leer y comparar en git.
	var tempo_lines := PackedStringArray()
	for segment in midi.tempo_map().to_array():
		tempo_lines.append("\t\t" + JSON.stringify({
			"time": snappedf(segment.time, 0.0001),
			"beat": snappedf(segment.beat, 0.0001),
			"bpm": snappedf(segment.bpm, 0.001),
		}, "", false))
	var note_lines := PackedStringArray()
	for note in chart:
		note_lines.append("\t\t" + JSON.stringify({
			"time": snappedf(note.time, 0.001),
			"length": snappedf(note.length, 0.001),
			"pitch": note.pitch,
			"lane": note.lane,
			"beat": snappedf(note.beat, 0.0001),
			"subdivision": note.subdivision,
			"group": note.group,
		}, "", false))
	var text := '{\n\t"version": %d,\n\t"source": "%s",\n\t"tempo": [\n%s\n\t],\n\t"notes": [\n%s\n\t]\n}\n' % [
		Chart.VERSION, MIDI_NAME, ",\n".join(tempo_lines), ",\n".join(note_lines)]

	var file := FileAccess.open(folder + "/" + CHART_NAME, FileAccess.WRITE)
	if file == null:
		printerr("%s: no se pudo escribir %s" % [folder, CHART_NAME])
		return false
	file.store_string(text)
	file.close()
	_print_summary(folder, chart)
	return true


func _print_summary(folder: String, chart: Array[Dictionary]) -> void:
	var last: Dictionary = chart[-1]
	var duration: float = maxf(last.time + last.length - chart[0].time, 0.001)
	var per_lane := [0, 0, 0, 0]
	for note in chart:
		per_lane[note.lane] += 1
	var lanes := PackedStringArray()
	for lane in LANE_NAMES.size():
		lanes.append("%s %d" % [LANE_NAMES[lane], per_lane[lane]])
	var simple := 0
	var figures := {}
	for i in chart.size():
		var note: Dictionary = chart[i]
		if note.subdivision == 1:
			simple += 1
		elif i == 0 or chart[i - 1].group != note.group:
			figures[note.subdivision] = figures.get(note.subdivision, 0) + 1
	var parts := PackedStringArray(["sencillas %d" % simple])
	for figure in ChartMapper.FIGURES:
		parts.append("%s %d" % [FIGURE_NAMES[figure], figures.get(figure, 0)])
	print("%s: %d golpes, %.2f golpes/s | %s | %s" % [
		folder, chart.size(), chart.size() / duration, ", ".join(lanes), ", ".join(parts)])
