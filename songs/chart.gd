class_name Chart
extends RefCounted

## Las notas de una canción, leídas de su `chart.json` (lo genera `tools/midi_to_chart.gd`).

const VERSION := 2

var tempo: TempoMap
## Ordenadas por tiempo: {time, length, pitch, lane, beat, subdivision}.
var notes: Array[Dictionary] = []


static func load_file(path: String) -> Chart:
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary:
		push_warning("%s no existe o no es válido" % path)
		return null
	if int(data.get("version", 0)) < VERSION:
		push_warning("%s es de una versión vieja; vuelve a correr tools/midi_to_chart.gd" % path)
		return null

	var chart := Chart.new()
	chart.tempo = TempoMap.from_array(data.get("tempo", []))
	for note in data.get("notes", []):
		chart.notes.append({
			"time": float(note.time),
			"length": float(note.length),
			"pitch": int(note.pitch),
			"lane": int(note.lane),
			"beat": float(note.beat),
			"subdivision": int(note.subdivision),
		})
	return chart
