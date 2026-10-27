class_name LaneNote
extends Node2D

## Una nota del juego. Todas saltan juntas en cada tiempo de la canción y siempre quedan
## a la altura de lo que les falta; el último salto aterriza sobre el botón justo a tiempo.
## Una nota especial junta varios golpes seguidos del mismo carril (corcheas, tresillos,
## semicorcheas): al tocarla retrocede lo que falta para el siguiente golpe y hay que
## volver a tocarla cuando regresa. Lleva un anillo y los golpes que le quedan.

const HOP_BEATS := 0.2  # duración máxima de un salto, en tiempos
const HOP_GROW := 0.18  # cuánto crece a mitad del salto, como si brincara hacia la cámara
const KNOCK_BEATS := 0.25  # duración máxima del retroceso al tocar una nota especial
const OUTLINE_COLOR := Color(0.05, 0.02, 0.08)
const OUTLINE_WIDTH := 6.0
const RING_WIDTH := 8.0
const MISS_COLOR := Color(1.0, 0.35, 0.35)
const FONT := preload("res://Assets/Fonts/ghost_shadow/Ghost Shadow.ttf")

## Las entradas del chart que forman la nota, ordenadas por tiempo: {time, beat, lane, ...}.
var hits: Array[Dictionary] = []
var color := Color.WHITE
var radius := 60.0

var _index := 0  # el golpe que sigue
var _since := 0.0  # tiempo (en negras) del último golpe, de donde sale el retroceso
var _flash := 0.0:
	set(value):
		_flash = value
		queue_redraw()


func lane() -> int:
	return hits[0].lane


## El golpe que sigue: la entrada del chart que hay que tocar ahora.
func target() -> Dictionary:
	return hits[_index]


func is_finished() -> bool:
	return _index >= hits.size()


## Coloca la nota para el tiempo `beat` de la canción. `hit_y` es la altura del botón
## y `beat_px` los píxeles que equivalen a un tiempo.
func place(beat: float, hit_y: float, beat_px: float) -> void:
	if is_finished():
		return
	var goal: float = target().beat
	var height := 0.0
	var t := 0.0
	if beat < goal:
		# Descansa a la altura que le faltaba en el último salto y salta en el siguiente
		# tiempo, o directo al botón si su golpe llega antes.
		var last_hop := maxf(floorf(beat), _since if _index > 0 else -INF)
		var next_hop := minf(floorf(beat) + 1.0, goal)
		var hop := minf(HOP_BEATS, next_hop - last_hop)
		t = clampf((beat - next_hop) / hop + 1.0, 0.0, 1.0)
		height = lerpf(goal - last_hop, goal - next_hop, ease(t, 0.5))
		if _index > 0:
			var knock := minf(KNOCK_BEATS, (goal - _since) / 2.0)
			height *= ease(clampf((beat - _since) / knock, 0.0, 1.0), 0.4)
	position.y = hit_y - height * beat_px
	scale = Vector2.ONE * (1.0 + HOP_GROW * sin(PI * t))


## Cuenta un golpe atinado en `beat`. Devuelve si a la nota le quedan golpes.
func hit(beat: float) -> bool:
	_advance(beat)
	if is_finished():
		_vanish(Vector2.ONE * 1.6, 0.15)
		return false
	_flash = 1.0
	create_tween().tween_property(self, "_flash", 0.0, 0.2)
	return true


## Cuenta un golpe fallado en `beat`. Devuelve si a la nota le quedan golpes.
func miss(beat: float) -> bool:
	_advance(beat)
	modulate = MISS_COLOR
	if is_finished():
		_vanish(scale, 0.3)
		return false
	create_tween().tween_property(self, "modulate", Color.WHITE, 0.3)
	return true


func _advance(beat: float) -> void:
	_index += 1
	_since = beat
	queue_redraw()


func _vanish(end_scale: Vector2, duration: float) -> void:
	var tween := create_tween().set_parallel()
	tween.tween_property(self, "scale", end_scale, duration)
	tween.tween_property(self, "modulate:a", 0.0, duration)
	tween.chain().tween_callback(queue_free)


func _draw() -> void:
	draw_circle(Vector2.ZERO, radius + OUTLINE_WIDTH, OUTLINE_COLOR)
	draw_circle(Vector2.ZERO, radius, color)
	var remaining := hits.size() - _index
	if hits.size() > 1 and remaining > 0:
		draw_arc(Vector2.ZERO, radius - RING_WIDTH, 0.0, TAU, 48, Color.WHITE, RING_WIDTH)
		# Los glifos de Ghost Shadow miden ~2.2 veces el tamaño de fuente y suben mucho
		# sobre la línea base; con estos valores el número queda centrado en el anillo.
		var size := int(radius * 0.6)
		var baseline := Vector2(-radius, size * 0.725)
		draw_string_outline(FONT, baseline, str(remaining), HORIZONTAL_ALIGNMENT_CENTER, radius * 2.0, size, 8, OUTLINE_COLOR)
		draw_string(FONT, baseline, str(remaining), HORIZONTAL_ALIGNMENT_CENTER, radius * 2.0, size)
	if _flash > 0.0:
		draw_circle(Vector2.ZERO, radius, Color(1.0, 1.0, 1.0, _flash * 0.8))
