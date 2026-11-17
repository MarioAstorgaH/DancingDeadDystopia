extends Node2D

## Toca la canción elegida en el selector después de una cuenta regresiva y hace
## bajar sus notas saltando al ritmo. Atinar sube la melodía y fallar la baja.
## Los golpes de cada figura se juntan en notas especiales que rebotan, y las notas largas
## se sostienen. Las notas hostiles y fantasma no se deben tocar. Cada acierto y fallo mueve
## la vida (Health); al llegar a 0 se acaba la canción. Se puede pausar y al terminar la
## canción pasa a la pantalla de resultados.

const SONG_SELECT_SCENE := "res://song_select/screen_song_select.tscn"
const RESULTS_SCENE := "res://results/screen_results.tscn"
const LEAD_IN := 3.0  # segundos para que el jugador se prepare
## Cuándo dice cada palabra `cuenta_regresiva.wav`, en segundos desde que empieza.
## La canción arranca con la última.
const COUNTDOWN_CUES := [[0.12, "3"], [0.85, "2"], [1.61, "1"], [2.49, "YA"]]
const GO_TIME := 0.6  # segundos que se queda el "YA" en pantalla
const LOOKAHEAD_BEATS := 4.0  # tiempos que tarda una nota en bajar de arriba al botón
const TOP_MARGIN := 120.0  # píxeles libres arriba de donde empiezan a verse las notas
## Tolerancia (segundos antes o después del golpe) de cada calificación, de la más exacta a
## la más amplia. Todas cuentan como acierto; fuera de la última es un fallo.
const JUDGEMENTS := [
	[0.06, "PERFECTO", Color(1.0, 0.85, 0.3)],
	[0.12, "BIEN", Color(0.45, 0.85, 0.35)],
	[0.18, "OK", Color(0.35, 0.6, 0.95)],
]
const HIT_WINDOW := 0.18  # la tolerancia más amplia de JUDGEMENTS
## Un golpe no se puede tocar antes que el anterior de su carril, pero la tolerancia
## antes del golpe nunca baja de esto.
const MIN_WINDOW := 0.06
## Una nota sostenida se puede soltar hasta esto antes de su final sin fallarla.
const RELEASE_WINDOW := 0.15
const MISS_TEXT := "FALLO"
const MISS_COLOR := Color(0.9, 0.3, 0.3)
## Una nota hostil o fantasma cuenta como tocada a menos de esto (segundos) de su tiempo.
const TRAP_WINDOW := 0.12
const HOSTILE_TEXT := "AUCH"
const HOSTILE_COLOR := Color(0.75, 0.3, 0.95)
const RESUME_COUNT := 3  # segundos de cuenta regresiva al salir de la pausa
const END_DELAY := 1.0  # segundos entre el final de la canción y los resultados

var _chart: Chart
var _groups: Array[Array] = []  # los golpes de cada nota, en orden de aparición
var _next_group := 0  # índice en _groups de la siguiente nota por aparecer
var _active: Array[LaneNote] = []  # notas en pantalla con golpes pendientes o sostenidas
var _countdown_played := false
var _offset := 0.0  # el `offset` de song.json
var _lanes_enabled := false
var _result := SongResult.new()
var _combo := 0
var _resuming := false  # corre la cuenta regresiva para salir de la pausa
var _ended := false
var _dead := false

@onready var _player: SongPlayer = $SongPlayer
@onready var _countdown_sfx: AudioStreamPlayer = $CountdownSfx
@onready var _hud: Hud = $HUD
@onready var _dancer: Dancer = $Background/Dancer
@onready var _health: Health = $Health


func _ready() -> void:
	var song := SongLibrary.selected_song
	if song == null:
		song = _first_song_for_testing()
		if song == null:
			push_warning("No hay canciones en %s" % SongLibrary.SONGS_DIR)
			return
	_result.song = song
	if song.chart_path:
		_chart = Chart.load_file(song.chart_path)
		if _chart:
			_groups = _group_hits(_chart.notes)
			_assign_windows(_chart.notes)
			_offset = song.offset
			# Las trampas no cuentan. Una nota sostenida cuenta dos veces: al tocarla y al
			# soltarla a tiempo.
			for note in _chart.notes:
				if note.type == Chart.NoteType.NORMAL:
					_result.total += 2 if note.hold > 0.0 else 1
	else:
		push_warning("'%s' no tiene chart.json; se toca sin notas" % song.id)
	_player.play_song(song, LEAD_IN)


## Junta en una sola nota los golpes de cada figura (los que comparten `group`), sin pasar
## de ChartMapper.MAX_FIGURE_HITS aunque el chart traiga más. Entre los golpes de una figura
## puede caer una trampa en otro carril, así que se agrupan por `group` y no por vecindad.
func _group_hits(notes: Array[Dictionary]) -> Array[Array]:
	var groups: Array[Array] = []
	var by_id := {}  # group -> sus golpes
	for note in notes:
		var group: Array = by_id.get(note.group, [])
		if group.is_empty() or group.size() >= ChartMapper.MAX_FIGURE_HITS:
			group = [note]
			by_id[note.group] = group
			groups.append(group)
		else:
			group.append(note)
	return groups


## Cada golpe se puede tocar hasta HIT_WINDOW después. Antes (`early` en cada nota), hasta
## HIT_WINDOW pero no más que lo que lo separa del golpe anterior del mismo carril (sin bajar
## de MIN_WINDOW), para que un toque de más justo después de atinar no se lleve el que sigue.
## Los toques de un carril se cuentan en orden, así que quien toca siempre algo tarde atina
## igual a las semicorcheas.
func _assign_windows(notes: Array[Dictionary]) -> void:
	var previous_in_lane := {}  # carril -> último golpe visto
	for note in notes:
		if note.type != Chart.NoteType.NORMAL:
			continue
		note.early = HIT_WINDOW
		var previous: Dictionary = previous_in_lane.get(note.lane, {})
		if not previous.is_empty():
			note.early = clampf(note.time - previous.end_time, MIN_WINDOW, HIT_WINDOW)
		previous_in_lane[note.lane] = note


## Al correr la escena directo no hay canción elegida: usa la primera, de preferencia con notas.
func _first_song_for_testing() -> SongInfo:
	var songs := SongLibrary.load_all()
	for song in songs:
		if song.chart_path:
			return song
	return null if songs.is_empty() else songs[0]


func _process(_delta: float) -> void:
	_update_countdown(_player.song_time())
	if _chart:
		var now := _chart_time()
		var beat := _chart.tempo.beat_at(now)
		_spawn_notes(beat)
		_move_notes(beat)
		_update_holds(now)
		_miss_late_notes(now, beat)
		_update_lanes_enabled(now)


## Los carriles se encienden con el "YA" y se apagan cuando ya no quedan notas.
func _update_lanes_enabled(now: float) -> void:
	var running := now >= 0.0 and (_next_group < _groups.size() or not _active.is_empty())
	if running != _lanes_enabled:
		_lanes_enabled = running
		_hud.set_lanes_enabled(running)


func _update_countdown(now: float) -> void:
	# Tiempo desde que empieza el efecto; su última palabra cae en 0 de la canción.
	var t: float = now + COUNTDOWN_CUES[-1][0]
	# Igual que la canción, arranca antes por la latencia para que la voz se oiga a tiempo.
	var latency := _player.latency()
	if not _countdown_played and t >= -latency:
		_countdown_played = true
		_countdown_sfx.play(maxf(t + latency, 0.0))
	var text := ""
	if t <= COUNTDOWN_CUES[-1][0] + GO_TIME:
		for cue in COUNTDOWN_CUES:
			if t >= cue[0]:
				text = cue[1]
	_hud.show_countdown(text)


## Crea las notas un tiempo antes de que se vean, para que entren saltando desde arriba.
func _spawn_notes(beat: float) -> void:
	while _next_group < _groups.size() \
			and _groups[_next_group][0].beat - beat <= LOOKAHEAD_BEATS + 1.0:
		var note := LaneNote.new()
		note.hits.assign(_groups[_next_group])
		_hud.add_note(note)
		_active.append(note)
		_next_group += 1


func _move_notes(beat: float) -> void:
	var hit_y := _hud.hit_y()
	var beat_px := (hit_y - TOP_MARGIN) / LOOKAHEAD_BEATS
	for note in _active:
		note.place(beat, hit_y, beat_px)


func _miss_late_notes(now: float, beat: float) -> void:
	for note in _active.duplicate():
		if note.is_trap():
			if now > note.target().time + TRAP_WINDOW:  # pasó sin que la tocaran
				note.pass_by()
				_active.erase(note)
			continue
		if note.is_holding():
			continue
		while now > note.target().time + HIT_WINDOW:
			_miss()
			if note.is_hold():
				_count_miss()  # sin cabeza tampoco hay cola
			if not note.miss(beat):
				_active.erase(note)
				break


## Una nota sostenida se completa al llegar a su final con el dedo puesto. Soltarla con más
## de RELEASE_WINDOW de anticipación la falla.
func _update_holds(now: float) -> void:
	for note in _active.duplicate():
		if not note.is_holding():
			continue
		if now >= note.end_time():
			_finish_hold(note, true)
		elif not _hud.is_lane_pressed(note.lane()):
			_finish_hold(note, now >= note.end_time() - RELEASE_WINDOW)
		else:
			_dancer.keep_pose()


func _finish_hold(note: LaneNote, completed: bool) -> void:
	note.release(completed)
	_active.erase(note)
	if completed:
		_count_hit()
	else:
		_miss()


## Tiempo de la canción para las notas: el del audio, recorrido por el `offset` de la canción.
func _chart_time() -> float:
	return _player.song_time() - _offset


func _on_hud_lane_pressed(lane: ChartMapper.Lane) -> void:
	_dancer.pose(lane)
	var now := _chart_time()
	# El primer golpe pendiente del carril dentro de su tolerancia.
	var closest: LaneNote = null
	for note in _active:
		if note.lane() != lane or note.is_holding() or note.is_trap():
			continue
		var target := note.target()
		var error: float = now - target.time
		if error >= -target.early and error <= HIT_WINDOW \
				and (closest == null or target.time < closest.target().time):
			closest = note
	if closest == null:
		_press_trap(lane, now)
		return
	var error := absf(now - closest.target().time)
	if not closest.hit(_chart.tempo.beat_at(now)):
		_active.erase(closest)
	_player.set_lead_muted(false)
	_count_hit()
	for judgement in JUDGEMENTS:
		if error <= judgement[0] or judgement == JUDGEMENTS[-1]:
			_hud.show_judgement(judgement[1], judgement[2])
			break


## Tocar una trampa del carril: una hostil daña según Health.hostile_punishment y una
## fantasma cuenta como fallo.
func _press_trap(lane: ChartMapper.Lane, now: float) -> void:
	for note in _active:
		if note.lane() == lane and note.is_trap() and absf(now - note.target().time) <= TRAP_WINDOW:
			note.trigger()
			_active.erase(note)
			if note.note_type() == Chart.NoteType.HOSTILE:
				_player.set_lead_muted(true)
				_count_miss()
				_hud.show_judgement(HOSTILE_TEXT, HOSTILE_COLOR)
				_health.hostile()
			else:
				_miss()
			return


## Un golpe fallado: baja la melodía, corta el combo y quita vida.
func _miss() -> void:
	_player.set_lead_muted(true)
	_count_miss()
	_hud.show_judgement(MISS_TEXT, MISS_COLOR)
	_health.miss()


func _count_hit() -> void:
	_health.hit()
	_result.hits += 1
	_combo += 1
	_result.max_combo = maxi(_result.max_combo, _combo)
	_hud.show_combo(_combo)


func _count_miss() -> void:
	_result.misses += 1
	_combo = 0
	_hud.show_combo(_combo)


func _pause() -> void:
	if get_tree().paused or _ended:
		return
	get_tree().paused = true
	_hud.show_pause_menu(true)


## Sale de la pausa después de una cuenta regresiva, para que el jugador se prepare.
func _resume() -> void:
	if _resuming or _dead:
		return
	_resuming = true
	_hud.show_pause_menu(false)
	for seconds_left in range(RESUME_COUNT, 0, -1):
		_hud.show_countdown(str(seconds_left))
		await get_tree().create_timer(1.0).timeout  # corre aunque el juego esté en pausa
	_hud.show_countdown("")
	_resuming = false
	get_tree().paused = false


## Se acabó la vida: se detiene todo y solo queda reintentar o salir.
func _on_health_died() -> void:
	if _ended:
		return
	_ended = true
	_dead = true
	_player.set_lead_muted(true)
	get_tree().paused = true
	_hud.show_game_over()


func _leave(scene: String) -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(scene)


func _on_hud_pause_requested() -> void:
	_pause()


func _on_hud_resume_requested() -> void:
	_resume()


func _on_hud_retry_requested() -> void:
	_leave(scene_file_path)


func _on_hud_quit_requested() -> void:
	_leave(SONG_SELECT_SCENE)


func _on_song_player_finished() -> void:
	_ended = true
	await get_tree().create_timer(END_DELAY).timeout
	SongResult.last = _result
	get_tree().change_scene_to_file(RESULTS_SCENE)


func _notification(what: int) -> void:
	# El botón/gesto "atrás" de Android pausa, y con el menú abierto continúa.
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if _dead:
			_leave(SONG_SELECT_SCENE)
		elif not get_tree().paused:
			_pause()
		elif _hud.is_pause_menu_shown():
			_resume()
	# La app pasó a segundo plano (llamada, cambio de app).
	elif what == NOTIFICATION_APPLICATION_PAUSED:
		_pause()
