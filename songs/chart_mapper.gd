class_name ChartMapper
extends RefCounted

## Convierte las notas del lead (MIDI) en notas del juego con carril.
## Más aguda = más a la derecha. Cada frase se normaliza por separado para
## conservar la forma de la melodía y usar los 4 carriles en todas las secciones.
## Las notas en los canales de CHANNEL_TYPES son hostiles o fantasma (ver Chart.NoteType):
## no son parte de la melodía y van en un carril donde no estorben (ver _place_traps).

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
## Una nota nunca pide más de 2 golpes: las figuras más largas (tresillo, 4 semicorcheas)
## se parten en notas de 2 golpes o menos.
const MAX_FIGURE_HITS := 2
## Después de una nota de varios golpes, la siguiente que empiece a menos de esto (en tiempos)
## va en otro carril, para no repetir el mismo botón.
const SPREAD_BEATS := 1.0
## Canal MIDI (contando desde 1, como en los DAW) de cada tipo de nota especial; las de los
## demás canales son normales.
const CHANNEL_TYPES := {2: Chart.NoteType.HOSTILE, 3: Chart.NoteType.GHOST}
## Una nota sencilla que suena al menos HOLD_MIN_BEATS tiempos es una nota sostenida.
const HOLD_MIN_BEATS := 1.0
## Una nota sostenida se suelta al menos HOLD_GAP_BEATS antes de la siguiente nota, para
## que no haya que tocar otra mientras se sostiene.
const HOLD_GAP_BEATS := 0.5
const HOLD_STEP := 0.25  # la duración de una nota sostenida se redondea a semicorcheas


## Devuelve las notas {time, length, pitch, lane, beat, subdivision, group, hold, type}
## ordenadas por tiempo. `group` y `subdivision` dicen a qué figura pertenece la nota (ver
## _assign_figures), `hold` cuántos tiempos se sostiene (0 si es un toque, ver _assign_holds)
## y `type` es un Chart.NoteType.
static func map(midi: MidiFile) -> Array[Dictionary]:
	var melody: Array[Dictionary] = []
	var traps: Array[Dictionary] = []
	for midi_note in midi.notes:
		var note := midi_note.duplicate()
		note.type = CHANNEL_TYPES.get(note.channel + 1, Chart.NoteType.NORMAL)
		note.erase("channel")
		if note.type == Chart.NoteType.NORMAL:
			melody.append(note)
		else:
			traps.append(note)
	var tempo := midi.tempo_map()
	var chart := _lanes_by_phrase(_merge_chords(melody), midi)
	_assign_figures(chart, tempo)
	_assign_holds(chart, tempo)
	# Las trampas no se juntan en acordes: dos hostiles a la vez tapan dos carriles.
	chart.append_array(_place_traps(_lanes_by_phrase(traps, midi), chart, tempo))
	chart.sort_custom(func(a, b): return a.time < b.time or (a.time == b.time and a.lane < b.lane))
	# Numera las notas en orden de aparición.
	var ids := {}
	for note in chart:
		note.group = ids.get_or_add(note.group, ids.size())
	return chart


static func _lanes_by_phrase(notes: Array[Dictionary], midi: MidiFile) -> Array[Dictionary]:
	var mapped: Array[Dictionary] = []
	for phrase in _split_phrases(notes, midi):
		_assign_lanes(phrase)
		mapped.append_array(phrase)
	return mapped


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
## semicorcheas de un mismo tiempo forman una figura, que en el juego es una nota de
## varios golpes (`subdivision` 2, 3 o 4). Una figura de más de MAX_FIGURE_HITS se parte en
## varias notas. Una nota sola en su tiempo (negra, blanca o una corchea suelta) es una nota
## sencilla (`subdivision` 1). Los golpes de una nota comparten `group` y carril.
## Una nota que empieza a menos de LANE_CHANGE_BEATS de la anterior se queda en su carril,
## así nunca hay dos notas casi a la vez en carriles distintos. Pero después de una nota de
## varios golpes (o antes de una muy pegada) la siguiente cambia de carril (_other_lane).
static func _assign_figures(chart: Array[Dictionary], tempo: TempoMap) -> void:
	_snap_beats(chart, tempo)

	var groups: Array[Array] = []
	var start := 0
	while start < chart.size():
		var end := start + 1
		while end < chart.size() and _whole_beat(chart[end]) == _whole_beat(chart[start]):
			end += 1
		var notes := chart.slice(start, end)
		if notes.size() >= 2 and _figure_of(notes) > 0:
			for i in range(0, notes.size(), MAX_FIGURE_HITS):
				groups.append(notes.slice(i, i + MAX_FIGURE_HITS))
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
		if i > 0:
			var previous: Dictionary = merged[i - 1][-1]
			var gap: float = group[0].beat - previous.beat
			var close := gap < LANE_CHANGE_BEATS - GRID_TOLERANCE
			if (merged[i - 1].size() > 1 and gap < SPREAD_BEATS - GRID_TOLERANCE) \
					or (close and group.size() > 1):
				lane = _other_lane(previous.lane, lane, signi(group[0].pitch - previous.pitch))
			elif close:
				lane = previous.lane
		for note in group:
			note.subdivision = figure
			note.lane = lane
			note.group = i


## Las notas sencillas largas se sostienen: `hold` es cuántos tiempos (en semicorcheas
## enteras) hay que dejar el dedo después de tocarla. Se cortan HOLD_GAP_BEATS antes de la
## siguiente nota; si así quedan más cortas que HOLD_MIN_BEATS son un toque normal (0).
static func _assign_holds(chart: Array[Dictionary], tempo: TempoMap) -> void:
	for i in chart.size():
		var note: Dictionary = chart[i]
		note.hold = 0.0
		if note.subdivision != 1:
			continue
		var end := tempo.beat_at(note.time + note.length)
		if i + 1 < chart.size():
			end = minf(end, chart[i + 1].beat - HOLD_GAP_BEATS)
		var hold := floorf((end - note.beat) / HOLD_STEP + GRID_TOLERANCE) * HOLD_STEP
		if hold >= HOLD_MIN_BEATS:
			note.hold = hold


## `lane` si es distinto de `previous`; si no, el carril de al lado hacia donde va la melodía
## (`direction`), o hacia el centro si repite nota o ya está en la orilla.
static func _other_lane(previous: int, lane: int, direction: int) -> int:
	if lane != previous:
		return lane
	if direction == 0:
		direction = 1 if previous < LANE_COUNT / 2.0 else -1
	if previous + direction < 0 or previous + direction >= LANE_COUNT:
		direction = -direction
	return previous + direction


## Las notas hostiles y fantasma no se tocan: cada una va en el carril de su altura, pero si
## ahí cae a menos de LANE_CHANGE_BEATS de otra nota (o encima de una sostenida) se pasa al
## carril libre más cercano. Si no queda ninguno libre se descarta.
static func _place_traps(traps: Array[Dictionary], chart: Array[Dictionary], tempo: TempoMap) -> Array[Dictionary]:
	_snap_beats(traps, tempo)
	var placed: Array[Dictionary] = []
	for trap in traps:
		trap.subdivision = 1
		trap.hold = 0.0
		trap.group = -1 - placed.size()  # map() los vuelve a numerar
		var lanes := range(LANE_COUNT)
		lanes.sort_custom(func(a, b): return absi(a - trap.lane) < absi(b - trap.lane))
		for lane in lanes:
			if not _lane_busy(lane, trap.beat, chart) and not _lane_busy(lane, trap.beat, placed):
				trap.lane = lane
				placed.append(trap)
				break
	return placed


static func _lane_busy(lane: int, beat: float, notes: Array[Dictionary]) -> bool:
	for note in notes:
		if note.lane == lane and beat > note.beat - LANE_CHANGE_BEATS \
				and beat < note.beat + note.hold + LANE_CHANGE_BEATS:
			return true
	return false


## Pasa cada nota a tiempos (`beat`), ajustada a la rejilla más gruesa en la que cae.
static func _snap_beats(notes: Array[Dictionary], tempo: TempoMap) -> void:
	for note in notes:
		note.beat = tempo.beat_at(note.time)
		for figure in FIGURES:
			if _on_grid(note.beat, figure):
				note.beat = roundf(note.beat * figure) / figure
				break


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
