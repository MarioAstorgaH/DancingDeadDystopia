class_name LaneNote
extends Node2D

## Una nota del juego. Todas saltan juntas en cada tiempo de la canción y siempre quedan
## a la altura de lo que les falta; el último salto aterriza sobre el botón justo a tiempo.
## Una nota especial es una figura de varios golpes (corcheas, tresillo o semicorcheas
## de un mismo tiempo): al tocarla retrocede lo que falta para el siguiente golpe y hay
## que volver a tocarla cuando regresa. Lleva un anillo y los golpes que le quedan.
## Una nota sostenida lleva una cola hacia arriba, tan larga como lo que hay que dejar el
## dedo. Mientras se sostiene, la cabeza se queda sobre el botón y la cola se acorta
## saltando con las demás notas hasta llegar al botón.
## Las notas hostiles (oscuras, con picos y una X) y las fantasma (semitransparentes) no se
## deben tocar: si llegan al botón sin que las toquen se desvanecen sin más.

const HOP_BEATS := 0.2  # duración máxima de un salto, en tiempos
const HOP_GROW := 0.18  # cuánto crece a mitad del salto, como si brincara hacia la cámara
const KNOCK_BEATS := 0.25  # duración máxima del retroceso al tocar una nota especial
## Hasta dónde retrocede (en tiempos de altura) aunque falte más para su siguiente golpe:
## la nota que viene detrás en el carril siempre descansa a un tiempo o más.
const KNOCK_HEIGHT := 0.5
const OUTLINE_COLOR := Color(0.05, 0.02, 0.08)
const OUTLINE_WIDTH := 6.0
const RING_WIDTH := 8.0
const MISS_COLOR := Color(1.0, 0.35, 0.35)
const TAIL_WIDTH := 0.9  # ancho de la cola, en fracción del radio de la nota
const HOLD_GLOW := 0.35  # brillo de la cabeza mientras se sostiene
const GHOST_ALPHA := 0.35  # opacidad de una nota fantasma
const HOSTILE_COLOR := Color(0.28, 0.05, 0.32)
const HOSTILE_MARK_COLOR := Color(0.95, 0.25, 0.35)
const SPIKES := 10  # picos alrededor de una nota hostil
const SPIKE_LENGTH := 0.3  # largo de los picos, en fracción del radio
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
var _holding := false  # se tocó la cabeza de la nota sostenida y sigue el dedo puesto
var _tail_px := 0.0  # largo de la cola, en píxeles hacia arriba desde el centro


func lane() -> int:
	return hits[0].lane


## El golpe que sigue: la entrada del chart que hay que tocar ahora.
func target() -> Dictionary:
	return hits[_index]


func note_type() -> Chart.NoteType:
	return hits[0].type


## Si es una nota que no se debe tocar (hostil o fantasma).
func is_trap() -> bool:
	return note_type() != Chart.NoteType.NORMAL


func is_finished() -> bool:
	return _index >= hits.size()


func is_hold() -> bool:
	return hits.size() == 1 and hits[0].hold > 0.0


func is_holding() -> bool:
	return _holding


## Cuándo hay que soltar la nota sostenida, en segundos del chart.
func end_time() -> float:
	return hits[0].end_time


func _ready() -> void:
	if note_type() == Chart.NoteType.GHOST:
		self_modulate.a = GHOST_ALPHA


## Coloca la nota para el tiempo `beat` de la canción. `hit_y` es la altura del botón
## y `beat_px` los píxeles que equivalen a un tiempo.
func place(beat: float, hit_y: float, beat_px: float) -> void:
	if is_finished():
		return
	var height := 0.0
	var t := 0.0
	if not _holding:  # sostenida, la cabeza se queda en el botón
		var goal: float = target().beat
		var hop := _hop(goal, beat, _since if _index > 0 else -INF, KNOCK_HEIGHT if _index > 0 else INF)
		height = hop.x
		t = hop.y
		if _index > 0 and beat < goal:
			var knock := minf(KNOCK_BEATS, (goal - _since) / 2.0)
			height *= ease(clampf((beat - _since) / knock, 0.0, 1.0), 0.4)
	position.y = hit_y - height * beat_px
	scale = Vector2.ONE * (1.0 + HOP_GROW * sin(PI * t))
	if is_hold():
		# El final de la cola salta como una nota más que aterriza al soltar.
		var top := _hop(hits[0].end_beat, beat, -INF, INF).x
		_tail_px = maxf(top - height, 0.0) * beat_px / scale.y
		queue_redraw()


## Altura (en tiempos) y avance (0 a 1) del salto de algo que aterriza en el botón en
## el tiempo `goal`. Descansa a la altura que le faltaba en el último salto (en un tiempo
## entero o en `since`) y salta en el siguiente tiempo, o directo al botón si `goal` llega
## antes. `cap` limita la altura.
static func _hop(goal: float, beat: float, since: float, cap: float) -> Vector2:
	if beat >= goal:
		return Vector2.ZERO
	var last_hop := maxf(floorf(beat), since)
	var next_hop := minf(floorf(beat) + 1.0, goal)
	var hop := minf(HOP_BEATS, next_hop - last_hop)
	var t := clampf((beat - next_hop) / hop + 1.0, 0.0, 1.0)
	return Vector2(lerpf(minf(goal - last_hop, cap), minf(goal - next_hop, cap), ease(t, 0.5)), t)


## Cuenta un golpe atinado en `beat`. Devuelve si a la nota le quedan golpes; una nota
## sostenida empieza a sostenerse y sigue hasta `release()`.
func hit(beat: float) -> bool:
	if is_hold() and not _holding:
		_holding = true
		_since = beat
		_flash = 1.0
		create_tween().tween_property(self, "_flash", 0.0, 0.2)
		return true
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


## Una nota hostil o fantasma que pasó sin que la tocaran.
func pass_by() -> void:
	_index = hits.size()
	_vanish(scale, 0.2)


## Se tocó una nota hostil o fantasma: se rompe en rojo.
func trigger() -> void:
	_index = hits.size()
	modulate = MISS_COLOR
	_vanish(Vector2.ONE * 1.6, 0.25)


## Termina una nota sostenida: `completed` si se sostuvo hasta el final, si no se soltó antes.
func release(completed: bool) -> void:
	_holding = false
	_index = hits.size()
	if completed:
		_tail_px = 0.0
		_vanish(Vector2.ONE * 1.6, 0.15)
	else:
		modulate = MISS_COLOR
		_vanish(scale, 0.3)


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
	if note_type() == Chart.NoteType.HOSTILE:
		_draw_hostile()
		return
	if _tail_px > 0.0:
		_draw_tail()
	draw_circle(Vector2.ZERO, radius + OUTLINE_WIDTH, OUTLINE_COLOR)
	draw_circle(Vector2.ZERO, radius, color)
	if _holding:
		draw_circle(Vector2.ZERO, radius, Color(1.0, 1.0, 1.0, HOLD_GLOW))
	if hits.size() > 1 and not is_finished():
		draw_arc(Vector2.ZERO, radius - RING_WIDTH, 0.0, TAU, 48, Color.WHITE, RING_WIDTH)
		_draw_badge()
	if _flash > 0.0:
		draw_circle(Vector2.ZERO, radius, Color(1.0, 1.0, 1.0, _flash * 0.8))


## Una nota hostil: una bola oscura con picos y una X roja, para que no se confunda.
func _draw_hostile() -> void:
	var outline := PackedVector2Array()
	var body := PackedVector2Array()
	for i in SPIKES * 2:
		var r := radius * (1.0 + SPIKE_LENGTH) if i % 2 == 0 else radius * 0.85
		var direction := Vector2.from_angle(TAU * i / (SPIKES * 2) - PI / 2.0)
		outline.append(direction * (r + OUTLINE_WIDTH))
		body.append(direction * r)
	draw_colored_polygon(outline, OUTLINE_COLOR)
	draw_colored_polygon(body, HOSTILE_COLOR)
	var d := radius * 0.4
	for line in [[Vector2(-d, -d), Vector2(d, d)], [Vector2(d, -d), Vector2(-d, d)]]:
		draw_line(line[0], line[1], OUTLINE_COLOR, radius * 0.3 + OUTLINE_WIDTH)
		draw_line(line[0], line[1], HOSTILE_MARK_COLOR, radius * 0.3)


## La cola de la nota sostenida: una barra redondeada del centro de la cabeza hacia arriba.
## Al sostenerla se aclara.
func _draw_tail() -> void:
	var width := radius * TAIL_WIDTH
	var top := Vector2(0.0, -_tail_px)
	var tail_color := color.lightened(0.35) if _holding else color.darkened(0.3)
	draw_line(Vector2.ZERO, top, OUTLINE_COLOR, width + OUTLINE_WIDTH * 2.0)
	draw_circle(top, width / 2.0 + OUTLINE_WIDTH, OUTLINE_COLOR)
	draw_line(Vector2.ZERO, top, tail_color, width)
	draw_circle(top, width / 2.0, tail_color)


## Lo que identifica a una nota especial: por ahora los golpes que le quedan. Aquí irá
## el ícono de cada tipo (`hits[0].subdivision`: 2 corcheas, 3 tresillo, 4 semicorcheas).
func _draw_badge() -> void:
	# Los glifos de Ghost Shadow miden ~2.2 veces el tamaño de fuente y suben mucho
	# sobre la línea base; con estos valores el número queda centrado en el anillo.
	var size := int(radius * 0.6)
	var baseline := Vector2(-radius, size * 0.725)
	var text := str(hits.size() - _index)
	draw_string_outline(FONT, baseline, text, HORIZONTAL_ALIGNMENT_CENTER, radius * 2.0, size, 8, OUTLINE_COLOR)
	draw_string(FONT, baseline, text, HORIZONTAL_ALIGNMENT_CENTER, radius * 2.0, size)
