class_name LaneColumn
extends Control

## Un carril del HUD: la franja de color y su botón de cerebro abajo.
## El botón se escala al ancho del carril, así que funciona con cualquier tamaño de pantalla.

signal pressed(lane: ChartMapper.Lane)
signal released(lane: ChartMapper.Lane)

const BRAIN_CENTER := Vector2(240, 225)  # centro del cerebro dentro de la textura de 480×480
const BRAIN_SIZE := Vector2(294, 262)
const BUTTON_FILL := 0.9  # parte del ancho del carril que ocupa el cerebro
const BOTTOM_MARGIN := 80.0  # espacio bajo el cerebro, para no chocar con la barra de gestos
const STRIP_ALPHA := 0.15
const STRIP_PRESSED_ALPHA := 0.35

@export var lane: ChartMapper.Lane
@export var color := Color.WHITE
@export var texture_normal: Texture2D
@export var texture_pressed: Texture2D

@onready var _strip: ColorRect = $strip
@onready var _button: TouchScreenButton = $button


func _ready() -> void:
	_button.texture_normal = texture_normal
	_button.texture_pressed = texture_pressed
	_set_strip_alpha(STRIP_ALPHA)
	_layout()


## Altura (en coordenadas del carril) del centro del cerebro: ahí deben llegar las notas.
func hit_y() -> float:
	return _button.position.y + BRAIN_CENTER.y * _button.scale.y


func _layout() -> void:
	# En pantallas anchas (tablets) el carril crece, pero el cerebro no pasa de su tamaño original.
	var s := minf(size.x * BUTTON_FILL / BRAIN_SIZE.x, 1.0)
	_button.scale = Vector2(s, s)
	var center := Vector2(size.x / 2.0, size.y - BOTTOM_MARGIN - BRAIN_SIZE.y / 2.0 * s)
	_button.position = center - BRAIN_CENTER * s


func _set_strip_alpha(alpha: float) -> void:
	_strip.color = Color(color, alpha)


func _on_button_pressed() -> void:
	_set_strip_alpha(STRIP_PRESSED_ALPHA)
	pressed.emit(lane)


func _on_button_released() -> void:
	_set_strip_alpha(STRIP_ALPHA)
	released.emit(lane)
