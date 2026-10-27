class_name ChartMapper
extends RefCounted

## Convierte las notas del lead (MIDI) en notas del juego con carril.
## Más aguda = más a la derecha. Cada frase se normaliza por separado para
## conservar la forma de la melodía y usar los 4 carriles en todas las secciones.

enum Lane { GREEN, RED, YELLOW, BLUE }

const LANE_COUNT := 4
const CHORD_WINDOW := 0.03  # segundos: notas más juntas cuentan como acorde
const PHRASE_MAX_BARS := 4
const MIN_PHRASE_SPAN := 7  # semitonos: una frase cerrada no salta a los extremos
const LEAP := 3  # semitonos: desde aquí el salto obliga a cambiar de carril
const OCTAVE := 12
## Figuras de varios golpes, de la más larga a la más corta, por cuántas caben en un
## tiempo: corcheas, tresillo de corcheas, semicorcheas.
const FIGURES := [2, 3, 4]
const GRID_TOLERANCE := 0.04  # tiempos que una nota puede desviarse de la rejilla
## Tiempos mínimos entre dos notas para que cambien de carril: más juntas se sentirían
## como dos notas a la vez en carriles distintos.
const LANE_CHANGE_BEATS := 0.5
const MAX_FIGURE_HITS := 4  # una figura no pasa de 4 golpes (4 semicorcheas en un tiempo)


## Devuelve las notas {time, length, pitch, lane, beat, subdivision, group} ordenadas por
## tiempo. `group` y `subdivision` dicen a qué figura pertenece la nota (ver _assign_figures).
static func map(midi: MidiFile) -> Array[Dictionary]:
	var chart: Array[Dictionary] = []
	for phrase in _split_phrases(_merge_chords(midi.notes), midi):
		_assign_lanes(phrase)
		chart.append_array(phrase)
	_assign_figures(chart, midi.tempo_map())
	return chart


## De cada acorde se queda la nota más aguda, que normalmente lleva la melodía.
static func _merge_chords(notes: Array[Dictionary]) -> Array[Dictionary]:
	var melody: Array[Dictionary] = []
	for note in notes:
		if not melody.is_empty() and note.time - melody[-1].time < CHORD_WINDOW:
			if note.pitch > melody[-1].pitch:
				melody[-1].pitch = note.pitch
				melody[-1].length = note.length
			continue
		melody.append(note.duplicate())
	return melody


## Corta una frase en cada silencio de un tiempo o más, o al llegar a PHRASE_MAX_BARS compases.
static func _split_phrases(melody: Array[Dictionary], midi: MidiFile) -> Array[Array]:
	var phrases: Array[Array] = []
	var phrase: Array[Dictionary] = []
	for note in melody:
		if not phrase.is_empty():
			var previous: Dictionary = phrase[-1]
			var rest: float = note.time - (previous.time + previous.length)
			var phrase_length: float = note.time - phrase[0].time
			if rest >= midi.beat_length_at(note.time) - 0.001 \
					or phrase_length >= midi.bar_length_at(phrase[0].time) * PHRASE_MAX_BARS:
				phrases.append(phrase)
				phrase = []
		phrase.append(note)
	if not phrase.is_empty():
		phrases.append(phrase)
	return phrases


static func _assign_lanes(phrase: Array[Dictionary]) -> void:
	var low := 127
	var high := 0
	for note in phrase:
		low = mini(low, note.pitch)
		high = maxi(high, note.pitch)
	var span := maxi(high - low, MIN_PHRASE_SPAN)
	var bottom := (low + high) / 2.0 - span / 2.0

	var previous: Dictionary = {}
	for note in phrase:
		var lane := roundi((note.pitch - bottom) / span * (LANE_COUNT - 1))
		if not previous.is_empty():
			lane = _keep_direction(previous, note.pitch, lane)
		note.lane = clampi(lane, 0, LANE_COUNT - 1)
		previous = note


## Nota igual → mismo carril. El carril nunca se mueve en contra de la melodía;
## los pasos chicos pueden quedarse en el carril (con 4 carriles no alcanza para
## mover cada paso de una escala), un salto mueve al menos 1 y una octava al menos 2.
static func _keep_direction(previous: Dictionary, pitch: int, lane: int) -> int:
	var step: int = pitch - previous.pitch
	if step == 0:
		return previous.lane
	var direction := signi(step)
	var min_move := 0
	if absi(step) >= OCTAVE:
		min_move = 2
	elif absi(step) >= LEAP:
		min_move = 1
	if (lane - previous.lane) * direction < min_move:
		lane = previous.lane + direction * min_move
	return lane


## Agrupa las notas como se escriben en la partitura: las corcheas, el tresillo o las
## semicorcheas de un mismo tiempo forman una figura, que en el juego es una sola nota de
## varios golpes (`subdivision` 2, 3 o 4). Una nota sola en su tiempo (negra, blanca o una
## corchea suelta) es una nota sencilla (`subdivision` 1). Las notas de una figura
## comparten `group` y carril.
## Una figura que empieza a menos de LANE_CHANGE_BEATS de la nota anterior se queda en el
## carril de esa nota, así nunca hay dos notas casi a la vez en carriles distintos.
static func _assign_figures(chart: Array[Dictionary], tempo: TempoMap) -> void:
	for note in chart:
		note.beat = tempo.beat_at(note.time)
		for figure in FIGURES:
			if _on_grid(note.beat, figure):
				note.beat = roundf(note.beat * figure) / figure
				break

	var groups: Array[Array] = []
	var start := 0
	while start < chart.size():
		var end := start + 1
		while end < chart.size() and _whole_beat(chart[end]) == _whole_beat(chart[start]):
			end += 1
		var notes := chart.slice(start, end)
		if notes.size() >= 2 and _figure_of(notes) > 0:
			groups.append(notes)
		else:
			for note in notes:
				groups.append([note])
		start = end

	# Una nota suelta justo antes de otra figura (una anacrusa) entra en esa figura: como
	# notas separadas quedarían casi encimadas en el mismo carril.
	var merged: Array[Array] = []
	for group in groups:
		var previous: Array = [] if merged.is_empty() else merged[-1]
		if previous.size() == 1 and previous.size() + group.size() <= MAX_FIGURE_HITS \
				and group[0].beat - previous[0].beat < LANE_CHANGE_BEATS - GRID_TOLERANCE \
				and _figure_of(previous + group) > 0:
			previous.append_array(group)
		else:
			merged.append(group)

	for i in merged.size():
		var group: Array = merged[i]
		var figure := _figure_of(group) if group.size() > 1 else 1
		var lane: int = group[0].lane
		if i > 0 and group[0].beat - merged[i - 1][-1].beat < LANE_CHANGE_BEATS - GRID_TOLERANCE:
			lane = merged[i - 1][-1].lane
		for note in group:
			note.subdivision = figure
			note.lane = lane
			note.group = i


## La figura más larga en cuya rejilla caen todas las notas, o 0 si no hay ninguna
## (por ejemplo, un tresillo mezclado con semicorcheas).
static func _figure_of(notes: Array) -> int:
	for figure in FIGURES:
		if notes.all(func(note): return _on_grid(note.beat, figure)):
			return figure
	return 0


## El tiempo (negra) en el que cae la nota.
static func _whole_beat(note: Dictionary) -> int:
	return floori(note.beat + GRID_TOLERANCE)


static func _on_grid(beat: float, subdivision: int) -> bool:
	var steps := beat * subdivision
	return absf(steps - roundf(steps)) <= GRID_TOLERANCE * subdivision
