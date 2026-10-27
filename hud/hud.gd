class_name Hud
extends CanvasLayer

## HUD compartido por todas las canciones: los 4 carriles con sus botones
## (de izquierda a derecha verde, rojo, amarillo, azul) y la cuenta regresiva.

signal lane_pressed(lane: ChartMapper.Lane)
signal lane_released(lane: ChartMapper.Lane)

@onready var _countdown: Label = %countdown_label
## En el orden de ChartMapper.Lane.
@onready var _lanes: Array[LaneColumn] = [
	$hud_root/lanes/lane_green, $hud_root/lanes/lane_red,
	$hud_root/lanes/lane_yellow, $hud_root/lanes/lane_blue,
]


func add_note(note: LaneNote) -> void:
	_lanes[note.note.lane].add_note(note)


## Los carriles empiezan apagados; se encienden mientras corre el chart.
func set_lanes_enabled(enabled: bool) -> void:
	for lane in _lanes:
		lane.set_enabled(enabled)


## Altura del centro de los botones: ahí aterrizan las notas.
func hit_y() -> float:
	return _lanes[0].hit_y()


## Muestra el texto de la cuenta regresiva ("3", "2", "1", "YA"); vacío la oculta.
func show_countdown(text: String) -> void:
	_countdown.visible = text != ""
	_countdown.text = text


func _on_lane_pressed(lane: ChartMapper.Lane) -> void:
	lane_pressed.emit(lane)


func _on_lane_released(lane: ChartMapper.Lane) -> void:
	lane_released.emit(lane)
