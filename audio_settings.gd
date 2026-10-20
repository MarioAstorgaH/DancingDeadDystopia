extends Node

## Autoload: carga, aplica y guarda el volumen (0-100) de cada bus de audio.

const SETTINGS_PATH := "user://settings.cfg"
const SECTION := "audio"

var _config := ConfigFile.new()


func _ready() -> void:
	_config.load(SETTINGS_PATH)
	for i in AudioServer.bus_count:
		var bus := AudioServer.get_bus_name(i)
		set_volume(bus, _config.get_value(SECTION, bus, 100.0))


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
