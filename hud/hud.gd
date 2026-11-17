class_name Hud
extends CanvasLayer

## HUD compartido por todas las canciones: los 4 carriles con sus botones (de izquierda
## a derecha verde, rojo, amarillo, azul), la cuenta regresiva, el combo, la vida, la
## calificación de cada toque y la pausa (que también sirve de pantalla de fin al morir).

signal lane_pressed(lane: ChartMapper.Lane)
signal lane_released(lane: ChartMapper.Lane)
signal pause_requested
signal resume_requested
signal retry_requested
signal quit_requested

const COMBO_POP := 1.25  # cuánto crece el número del combo con cada acierto
const JUDGEMENT_TIME := 0.4  # segundos que se ve la calificación antes de desvanecerse
const JUDGEMENT_ALPHA := 0.6  # semitransparente, para que se vean las notas que pasan detrás

@onready var _countdown: Label = %countdown_label
@onready var _pause_menu: PauseMenu = %pause_menu
@onready var _combo: Control = %combo
@onready var _combo_value: Label = %combo_value
@onready var _judgement: Label = %judgement_label
@onready var _health_bar: HealthBar = %health_bar
## En el orden de ChartMapper.Lane.
@onready var _lanes: Array[LaneColumn] = [
	$hud_root/lanes/lane_green, $hud_root/lanes/lane_red,
	$hud_root/lanes/lane_yellow, $hud_root/lanes/lane_blue,
]

var _combo_pop: Tween
var _judgement_pop: Tween


func add_note(note: LaneNote) -> void:
	_lanes[note.lane()].add_note(note)


## Muestra el combo actual con un saltito; en 0 (después de fallar) se oculta.
func show_combo(combo: int) -> void:
	_combo.visible = combo > 0
	if combo == 0:
		return
	_combo_value.text = "X%d" % combo
	_combo_value.pivot_offset = _combo_value.size / 2.0
	if _combo_pop:
		_combo_pop.kill()
	_combo_pop = create_tween()
	_combo_value.scale = Vector2.ONE * COMBO_POP
	_combo_pop.tween_property(_combo_value, "scale", Vector2.ONE, 0.12)


## Muestra cómo salió un toque ("PERFECTO", "BIEN", "OK", "FALLO") con un saltito.
func show_judgement(text: String, color: Color) -> void:
	_judgement.text = text
	_judgement.pivot_offset = _judgement.size / 2.0
	_judgement.modulate = Color(color, JUDGEMENT_ALPHA)
	_judgement.scale = Vector2.ONE * COMBO_POP
	_judgement.visible = true
	if _judgement_pop:
		_judgement_pop.kill()
	_judgement_pop = create_tween()
	_judgement_pop.tween_property(_judgement, "scale", Vector2.ONE, 0.1)
	_judgement_pop.tween_interval(JUDGEMENT_TIME)
	_judgement_pop.tween_property(_judgement, "modulate:a", 0.0, 0.2)


## Muestra la vida, de 0 a 1 (la señal `changed` de Health).
func show_health(fraction: float) -> void:
	_health_bar.set_fraction(fraction)


## Se acabó la vida: el menú de pausa sin CONTINUAR.
func show_game_over() -> void:
	_pause_menu.show_game_over()
	_pause_menu.visible = true


## Si el dedo sigue sobre el botón del carril.
func is_lane_pressed(lane: ChartMapper.Lane) -> bool:
	return _lanes[lane].is_pressed()


func show_pause_menu(shown: bool) -> void:
	_pause_menu.visible = shown


func is_pause_menu_shown() -> bool:
	return _pause_menu.visible


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


func _on_pause_button_pressed() -> void:
	pause_requested.emit()


func _on_pause_menu_resumed() -> void:
	resume_requested.emit()


func _on_pause_menu_retried() -> void:
	retry_requested.emit()


func _on_pause_menu_quit() -> void:
	quit_requested.emit()
