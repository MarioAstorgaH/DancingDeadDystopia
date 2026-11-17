class_name HealthBar
extends Control

## La barra de vida: se llena de izquierda a derecha y pasa de rojo a verde según cuánta
## vida queda. Llega suave a cada valor y parpadea en blanco al bajar.

const LOW_COLOR := Color(0.9, 0.25, 0.25)
const HIGH_COLOR := Color(0.35, 0.85, 0.35)
const BACK_COLOR := Color(0.05, 0.02, 0.08, 0.8)
const OUTLINE_COLOR := Color(0.05, 0.02, 0.08)
const OUTLINE_WIDTH := 6
const EASE_TIME := 0.15  # segundos para llegar al nuevo valor
const FLASH_TIME := 0.25

var _shown := 0.5  # lo que se dibuja, de 0 a 1
var _flash := 0.0
var _tween: Tween
var _back := StyleBoxFlat.new()
var _fill := StyleBoxFlat.new()


func _ready() -> void:
	_back.bg_color = BACK_COLOR
	_back.border_color = OUTLINE_COLOR
	_back.set_border_width_all(OUTLINE_WIDTH)


## Muestra la vida (`fraction` de 0 a 1).
func set_fraction(fraction: float) -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween().set_parallel()
	_tween.tween_method(_set_shown, _shown, fraction, EASE_TIME)
	if fraction < _shown:
		_flash = 1.0
		_tween.tween_method(_set_flash, 1.0, 0.0, FLASH_TIME)


func _set_shown(value: float) -> void:
	_shown = value
	queue_redraw()


func _set_flash(value: float) -> void:
	_flash = value
	queue_redraw()


func _draw() -> void:
	var radius := int(size.y / 2.0)
	_back.set_corner_radius_all(radius)
	_fill.set_corner_radius_all(radius - OUTLINE_WIDTH)
	draw_style_box(_back, Rect2(Vector2.ZERO, size))
	var inner := Rect2(Vector2.ONE * OUTLINE_WIDTH, size - Vector2.ONE * OUTLINE_WIDTH * 2.0)
	if _shown <= 0.0:
		return
	inner.size.x = maxf(inner.size.x * _shown, inner.size.y)  # nunca más angosta que redonda
	_fill.bg_color = LOW_COLOR.lerp(HIGH_COLOR, _shown).lerp(Color.WHITE, _flash * 0.6)
	draw_style_box(_fill, inner)
