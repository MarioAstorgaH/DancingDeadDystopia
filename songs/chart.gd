class_name Chart
extends RefCounted

## Las notas de una canción, leídas de su `chart.json` (lo genera `tools/midi_to_chart.gd`).

const VERSION := 4
## Las notas normales se tocan. Las hostiles dañan si se tocan y las fantasma (semitransparentes)
## cuentan como fallo; dejar pasar cualquiera de las dos no hace nada.
enum NoteType { NORMAL, HOSTILE, GHOST }
## Cómo se escribe cada tipo en el `type` de `chart.json`. Una nota sin `type` es normal.
const TYPE_NAMES := {NoteType.HOSTILE: "hostile", NoteType.GHOST: "ghost"}

var tempo: TempoMap
## Ordenadas por tiempo: {time, length, pitch, lane, beat, subdivision, group, hold, type,
## end_beat, end_time}. `type` es un NoteType. Las notas con el mismo `group` forman una
## figura de varios golpes (ver ChartMapper). Una nota con `hold` > 0 se sostiene hasta
## `end_beat` (en tiempos) o `end_time` (en segundos); en un toque son iguales a `beat` y `time`.
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
		var beat := float(note.beat)
		var hold := float(note.get("hold", 0.0))
		chart.notes.append({
			"time": float(note.time),
			"length": float(note.length),
			"pitch": int(note.pitch),
			"lane": int(note.lane),
			"beat": beat,
			"subdivision": int(note.subdivision),
			"group": int(note.group),
			"hold": hold,
			"type": _parse_type(path, note.get("type", "")),
			"end_beat": beat + hold,
			"end_time": chart.tempo.time_at(beat + hold) if hold > 0.0 else float(note.time),
		})
	return chart


static func _parse_type(path: String, name: String) -> NoteType:
	if name == "" or name == "normal":
		return NoteType.NORMAL
	var type = TYPE_NAMES.find_key(name)
	if type == null:
		push_warning("%s: tipo de nota desconocido '%s'; se toma como normal" % [path, name])
		return NoteType.NORMAL
	return type
