class_name TempoMap
extends RefCounted

## Convierte entre segundos y tiempos (negras) siguiendo los cambios de tempo de la canción.
## Antes del primer cambio y después del último se extiende el tempo más cercano,
## así que también funciona con tiempos negativos (la cuenta regresiva).

## Tramos ordenados: {time, beat, bpm}; cada uno vale hasta que empieza el siguiente.
var _segments: Array[Dictionary] = []


static func from_array(entries: Array) -> TempoMap:
	var map := TempoMap.new()
	for entry in entries:
		map.add(float(entry.time), float(entry.beat), float(entry.bpm))
	if map._segments.is_empty():
		map.add(0.0, 0.0, 120.0)
	return map


## Agrega un tramo; uno en el mismo tiempo que el anterior lo reemplaza.
func add(time: float, beat: float, bpm: float) -> void:
	if not _segments.is_empty() and is_equal_approx(_segments[-1].time, time):
		_segments.pop_back()
	_segments.append({"time": time, "beat": beat, "bpm": bpm})


func to_array() -> Array[Dictionary]:
	return _segments.duplicate(true)


func beat_at(time: float) -> float:
	var segment := _segments[0]
	for entry in _segments:
		if entry.time > time:
			break
		segment = entry
	return segment.beat + (time - segment.time) * segment.bpm / 60.0


func time_at(beat: float) -> float:
	var segment := _segments[0]
	for entry in _segments:
		if entry.beat > beat:
			break
		segment = entry
	return segment.time + (beat - segment.beat) * 60.0 / segment.bpm
