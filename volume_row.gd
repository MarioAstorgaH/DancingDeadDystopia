class_name VolumeRow
extends VBoxContainer

## Fila de configuración: un slider de 0 a 100 que controla el volumen de `bus_name`.

@export var bus_name := "Master"

@onready var _slider: HSlider = $controls/slider
@onready var _value_label: Label = $controls/value_label


func _ready() -> void:
	_slider.value = AudioSettings.get_volume(bus_name)
	_value_label.text = str(int(_slider.value))


func _on_slider_value_changed(value: float) -> void:
	AudioSettings.set_volume(bus_name, value)
	_value_label.text = str(int(value))
