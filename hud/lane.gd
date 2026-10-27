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
const NOTE_FILL := 0.3  # radio de las notas, en fracción del ancho del carril
const NOTE_MAX_RADIUS := 90.0
const DISABLED_MODULATE := Color(0.45, 0.45, 0.45, 0.7)
const ENABLE_FADE := 0.25  # segundos

@export var lane: ChartMapper.Lane
@export var color := Color.WHITE
@export var texture_normal: Texture2D
@export var texture_pressed: Texture2D

@onready var _strip: ColorRect = $strip
@onready var _button: TouchScreenButton = $button
@onready var _notes: Node2D = $notes

var _fade: Tween


## Encendido, el carril se ve normal y responde al toque. Apagado (como empieza) se ve
## gris y el botón no responde; las notas no se apagan, para que se vean llegar.
func set_enabled(enabled: bool) -> void:
	_button.process_mode = Node.PROCESS_MODE_INHERIT if enabled else Node.PROCESS_MODE_DISABLED
	if not enabled:
		_set_strip_alpha(STRIP_ALPHA)
	var target := Color.WHITE if enabled else DISABLED_MODULATE
	if _fade:
		_fade.kill()
	_fade = create_tween().set_parallel()
	_fade.tween_property(_button, "modulate", target, ENABLE_FADE)
	_fade.tween_property(_strip, "modulate", target, ENABLE_FADE)


## Agrega una nota al carril; sus coordenadas son relativas al centro del carril.
func add_note(note: LaneNote) -> void:
	note.color = color
	note.radius = minf(size.x * NOTE_FILL, NOTE_MAX_RADIUS)
	_notes.add_child(note)


func _ready() -> void:
	_button.texture_normal = texture_normal
	_button.texture_pressed = texture_pressed
	_set_strip_alpha(STRIP_ALPHA)
	_button.process_mode = Node.PROCESS_MODE_DISABLED
	_button.modulate = DISABLED_MODULATE
	_strip.modulate = DISABLED_MODULATE
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
	_notes.position.x = size.x / 2.0


func _set_strip_alpha(alpha: float) -> void:
	_strip.color = Color(color, alpha)


func _on_button_pressed() -> void:
	_set_strip_alpha(STRIP_PRESSED_ALPHA)
	pressed.emit(lane)


func _on_button_released() -> void:
	_set_strip_alpha(STRIP_ALPHA)
	released.emit(lane)
