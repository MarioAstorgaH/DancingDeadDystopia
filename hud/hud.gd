class_name Hud
extends CanvasLayer

## HUD compartido por todas las canciones: los 4 carriles con sus botones
## (de izquierda a derecha verde, rojo, amarillo, azul) y la cuenta regresiva.

signal lane_pressed(lane: ChartMapper.Lane)
signal lane_released(lane: ChartMapper.Lane)

@onready var _countdown: Label = %countdown_label


## Muestra el texto de la cuenta regresiva ("3", "2", "1", "YA"); vacío la oculta.
func show_countdown(text: String) -> void:
	_countdown.visible = text != ""
	_countdown.text = text


func _on_lane_pressed(lane: ChartMapper.Lane) -> void:
	lane_pressed.emit(lane)


func _on_lane_released(lane: ChartMapper.Lane) -> void:
	lane_released.emit(lane)
