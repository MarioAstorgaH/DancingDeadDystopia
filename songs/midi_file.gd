class_name MidiFile
extends RefCounted

## Lector de archivos MIDI estándar (formatos 0 y 1).
## Convierte las notas a segundos usando el mapa de tempo del archivo.

const DEFAULT_TEMPO := 500000  # microsegundos por negra (120 BPM)

## Notas ordenadas por tiempo: {time, length, pitch}, en segundos.
var notes: Array[Dictionary] = []

var _ticks_per_quarter := 480
var _tempos: Array[Dictionary] = []  # {tick, time, tempo}
var _signatures: Array[Dictionary] = []  # {time, numerator, denominator}
var _data: PackedByteArray
var _pos := 0
var _truncated := false


static func load_file(path: String) -> MidiFile:
	var bytes := FileAccess.get_file_as_bytes(path)
	if bytes.is_empty():
		push_error("No se pudo leer el MIDI: %s" % path)
		return null
	var midi := MidiFile.new()
	var error := midi._parse(bytes)
	if error != "":
		push_error("MIDI inválido (%s): %s" % [path, error])
		return null
	return midi


## Duración de una negra (un tiempo) en segundos.
func beat_length_at(time: float) -> float:
	var tempo := DEFAULT_TEMPO
	for entry in _tempos:
		if entry.time > time:
			break
		tempo = entry.tempo
	return tempo / 1_000_000.0


## El mapa de tempo del archivo, para convertir segundos a tiempos (negras).
func tempo_map() -> TempoMap:
	var map := TempoMap.new()
	for entry in _tempos:
		map.add(entry.time, float(entry.tick) / _ticks_per_quarter, 60_000_000.0 / entry.tempo)
	return map


## Duración de un compás en segundos, según el tempo y el compás vigentes.
func bar_length_at(time: float) -> float:
	var numerator := 4
	var denominator := 4
	for signature in _signatures:
		if signature.time > time:
			break
		numerator = signature.numerator
		denominator = signature.denominator
	return beat_length_at(time) * numerator * 4.0 / denominator


func _parse(bytes: PackedByteArray) -> String:
	_data = bytes
	_pos = 0
	if _read_string(4) != "MThd":
		return "falta la cabecera MThd"
	var header_length := _read_u32()
	var header_end := _pos + header_length
	_read_u16()  # formato: 0 o 1, se leen igual
	var track_count := _read_u16()
	var division := _read_u16()
	if division & 0x8000:
		return "la división SMPTE no está soportada"
	if division == 0:
		return "división de tiempo inválida"
	_ticks_per_quarter = division
	_pos = header_end

	var raw_tempos: Array[Dictionary] = []
	var raw_signatures: Array[Dictionary] = []
	var raw_notes: Array[Dictionary] = []
	for i in track_count:
		var chunk := _read_string(4)
		var chunk_end := _read_u32() + _pos
		if _truncated or chunk_end > _data.size():
			return "archivo truncado"
		if chunk == "MTrk":
			var error := _parse_track(chunk_end, raw_tempos, raw_signatures, raw_notes)
			if error != "":
				return error
		_pos = chunk_end

	_build_tempo_map(raw_tempos)
	for signature in raw_signatures:
		_signatures.append({
			"time": _tick_to_time(signature.tick),
			"numerator": signature.numerator,
			"denominator": signature.denominator,
		})
	_signatures.sort_custom(func(a, b): return a.time < b.time)

	for note in raw_notes:
		var start := _tick_to_time(note.tick)
		notes.append({"time": start, "length": _tick_to_time(note.end_tick) - start, "pitch": note.pitch})
	notes.sort_custom(func(a, b): return a.time < b.time or (a.time == b.time and a.pitch < b.pitch))
	return ""


func _parse_track(end: int, raw_tempos: Array[Dictionary], raw_signatures: Array[Dictionary], raw_notes: Array[Dictionary]) -> String:
	var tick := 0
	var running_status := 0
	var open_notes := {}  # canal * 128 + nota -> índices en raw_notes (FIFO)
	while _pos < end:
		tick += _read_varlen()
		var byte := _read_u8()

		if byte == 0xFF:
			var type := _read_u8()
			var length := _read_varlen()
			var start := _pos
			if start + length > end:
				return "evento meta fuera de la pista"
			if type == 0x51 and length >= 3:
				raw_tempos.append({"tick": tick, "tempo": (_data[start] << 16) | (_data[start + 1] << 8) | _data[start + 2]})
			elif type == 0x58 and length >= 2:
				raw_signatures.append({"tick": tick, "numerator": _data[start], "denominator": 1 << _data[start + 1]})
			_pos = start + length
			continue
		if byte == 0xF0 or byte == 0xF7:
			_pos += _read_varlen()
			continue

		if byte >= 0x80:
			running_status = byte
		elif running_status == 0:
			return "dato sin status previo"
		else:
			_pos -= 1  # running status: este byte ya es el primer dato

		var kind := running_status & 0xF0
		if kind == 0xC0 or kind == 0xD0:
			_read_u8()
			continue
		var key := (running_status & 0x0F) * 128 + _read_u8()
		var velocity := _read_u8()
		if kind == 0x90 and velocity > 0:
			raw_notes.append({"tick": tick, "end_tick": -1, "pitch": key % 128})
			open_notes.get_or_add(key, []).append(raw_notes.size() - 1)
		elif (kind == 0x80 or kind == 0x90) and not open_notes.get(key, []).is_empty():
			raw_notes[open_notes[key].pop_front()].end_tick = tick

	if _truncated or _pos > end:
		return "pista truncada"
	# Notas que nunca se apagaron: terminan donde termina la pista.
	for indices in open_notes.values():
		for i in indices:
			raw_notes[i].end_tick = tick
	return ""


func _build_tempo_map(raw_tempos: Array[Dictionary]) -> void:
	raw_tempos.sort_custom(func(a, b): return a.tick < b.tick)
	_tempos = [{"tick": 0, "time": 0.0, "tempo": DEFAULT_TEMPO}]
	for entry in raw_tempos:
		_tempos.append({"tick": entry.tick, "time": _tick_to_time(entry.tick), "tempo": entry.tempo})


func _tick_to_time(tick: int) -> float:
	var current: Dictionary = _tempos[0]
	for entry in _tempos:
		if entry.tick > tick:
			break
		current = entry
	return current.time + (tick - current.tick) * current.tempo / 1_000_000.0 / _ticks_per_quarter


func _read_u8() -> int:
	if _pos >= _data.size():
		_truncated = true
		_pos += 1
		return 0
	_pos += 1
	return _data[_pos - 1]


func _read_u16() -> int:
	return (_read_u8() << 8) | _read_u8()


func _read_u32() -> int:
	return (_read_u16() << 16) | _read_u16()


func _read_varlen() -> int:
	var value := 0
	for i in 4:
		var byte := _read_u8()
		value = (value << 7) | (byte & 0x7F)
		if byte & 0x80 == 0:
			break
	return value


func _read_string(length: int) -> String:
	var text := ""
	for i in length:
		text += char(_read_u8())
	return text
