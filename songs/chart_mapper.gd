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


## Devuelve las notas {time, length, pitch, lane} ordenadas por tiempo.
static func map(midi: MidiFile) -> Array[Dictionary]:
	var chart: Array[Dictionary] = []
	for phrase in _split_phrases(_merge_chords(midi.notes), midi):
		_assign_lanes(phrase)
		chart.append_array(phrase)
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
