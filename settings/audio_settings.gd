extends Node

## Autoload: carga, aplica y guarda el volumen (0-100) de cada bus de audio y el ajuste
## de latencia del ritmo.

const SETTINGS_PATH := "user://settings.cfg"
const SECTION := "audio"
const TIMING_SECTION := "timing"
const MIN_LATENCY_MS := -100.0
const MAX_LATENCY_MS := 400.0

var _config := ConfigFile.new()

## Milisegundos que el sonido (y el toque) llega más tarde de lo que calcula Godot. Lo usa
## SongPlayer para atrasar el reloj de las notas; se mide en la pantalla de calibración.
var latency_ms := 0.0:
	set(value):
		latency_ms = clampf(value, MIN_LATENCY_MS, MAX_LATENCY_MS)
		_config.set_value(TIMING_SECTION, "latency_ms", latency_ms)


func _ready() -> void:
	_config.load(SETTINGS_PATH)
	for i in AudioServer.bus_count:
		var bus := AudioServer.get_bus_name(i)
		set_volume(bus, _config.get_value(SECTION, bus, 100.0))
	latency_ms = _config.get_value(TIMING_SECTION, "latency_ms", 0.0)


func get_volume(bus: String) -> float:
	var index := AudioServer.get_bus_index(bus)
	if AudioServer.is_bus_mute(index):
		return 0.0
	return db_to_linear(AudioServer.get_bus_volume_db(index)) * 100.0


func set_volume(bus: String, percent: float) -> void:
	var index := AudioServer.get_bus_index(bus)
	if index == -1:
		push_warning("Bus de audio desconocido: %s" % bus)
		return
	AudioServer.set_bus_volume_db(index, linear_to_db(percent / 100.0))
	AudioServer.set_bus_mute(index, percent <= 0.0)
	_config.set_value(SECTION, bus, percent)


func save() -> void:
	_config.save(SETTINGS_PATH)
