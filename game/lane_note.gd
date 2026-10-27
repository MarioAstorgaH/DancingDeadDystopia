class_name LaneNote
extends Node2D

## Una nota del juego. No se desliza: salta hacia el botón con la figura de su tipo
## (1, 2, 3 o 4 saltos por tiempo) y aterriza sobre el botón justo en su tiempo.
## Todas avanzan la misma distancia por tiempo, así que la altura indica cuánto falta.

const HOP_BEATS := 0.2  # duración máxima de un salto, en tiempos
const HOP_GROW := 0.18  # cuánto crece a mitad del salto, como si brincara hacia la cámara
const OUTLINE_COLOR := Color(0.05, 0.02, 0.08)
const OUTLINE_WIDTH := 6.0
## Dónde van los puntos blancos de cada tipo, en fracciones del radio: un punto por salto.
const PIPS := {
	1: [Vector2.ZERO],
	2: [Vector2(-0.38, 0.0), Vector2(0.38, 0.0)],
	3: [Vector2(0.0, -0.4), Vector2(-0.38, 0.26), Vector2(0.38, 0.26)],
	4: [Vector2(-0.33, -0.33), Vector2(0.33, -0.33), Vector2(-0.33, 0.33), Vector2(0.33, 0.33)],
}

var note: Dictionary  # la entrada del chart: {time, beat, subdivision, lane, ...}
var color := Color.WHITE
var radius := 60.0
var judged := false


## Coloca la nota para el tiempo `beat` de la canción. `hit_y` es la altura del botón
## y `beat_px` los píxeles que avanza por tiempo.
func place(beat: float, hit_y: float, beat_px: float) -> void:
	var step: float = 1.0 / note.subdivision
	var steps_left: float = (note.beat - beat) / step
	var cell := ceilf(steps_left)
	# El salto ocupa el final del paso y aterriza justo en el tiempo de la figura.
	var hop := minf(HOP_BEATS / step, 0.5)
	var t := clampf((cell - steps_left - (1.0 - hop)) / hop, 0.0, 1.0)
	position.y = hit_y - (cell - ease(t, 0.5)) * step * beat_px
	scale = Vector2.ONE * (1.0 + HOP_GROW * sin(PI * t))


func hit() -> void:
	judged = true
	var tween := create_tween().set_parallel()
	tween.tween_property(self, "scale", Vector2.ONE * 1.6, 0.15)
	tween.tween_property(self, "modulate:a", 0.0, 0.15)
	tween.chain().tween_callback(queue_free)


func miss() -> void:
	judged = true
	modulate = Color(1.0, 0.35, 0.35)
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	tween.tween_callback(queue_free)


func _draw() -> void:
	draw_circle(Vector2.ZERO, radius + OUTLINE_WIDTH, OUTLINE_COLOR)
	draw_circle(Vector2.ZERO, radius, color)
	for pip in PIPS.get(note.subdivision, PIPS[4]):
		draw_circle(pip * radius, radius * 0.16, Color.WHITE)
