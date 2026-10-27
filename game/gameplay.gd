extends Node2D

## Toca la canción elegida en el selector después de una cuenta regresiva y hace
## bajar sus notas saltando al ritmo. Atinar sube la melodía y fallar la baja.
## Los golpes de cada figura se juntan en notas especiales que rebotan. Se puede pausar
## y al terminar la canción pasa a la pantalla de resultados.

const SONG_SELECT_SCENE := "res://song_select/screen_song_select.tscn"
const RESULTS_SCENE := "res://results/screen_results.tscn"
const LEAD_IN := 3.0  # segundos para que el jugador se prepare
## Cuándo dice cada palabra `cuenta_regresiva.wav`, en segundos desde que empieza.
## La canción arranca con la última.
const COUNTDOWN_CUES := [[0.12, "3"], [0.85, "2"], [1.61, "1"], [2.49, "YA"]]
const GO_TIME := 0.6  # segundos que se queda el "YA" en pantalla
const LOOKAHEAD_BEATS := 4.0  # tiempos que tarda una nota en bajar de arriba al botón
const TOP_MARGIN := 120.0  # píxeles libres arriba de donde empiezan a verse las notas
const HIT_WINDOW := 0.12  # segundos de tolerancia antes y después de la nota
const RESUME_COUNT := 3  # segundos de cuenta regresiva al salir de la pausa
const END_DELAY := 1.0  # segundos entre el final de la canción y los resultados

var _chart: Chart
var _groups: Array[Array] = []  # los golpes de cada nota, en orden de aparición
var _next_group := 0  # índice en _groups de la siguiente nota por aparecer
var _active: Array[LaneNote] = []  # notas en pantalla con golpes pendientes
var _countdown_played := false
var _offset := 0.0  # el `offset` de song.json
var _lanes_enabled := false
var _result := SongResult.new()
var _combo := 0
var _resuming := false  # corre la cuenta regresiva para salir de la pausa
var _ended := false

@onready var _player: SongPlayer = $SongPlayer
@onready var _countdown_sfx: AudioStreamPlayer = $CountdownSfx
@onready var _hud: Hud = $HUD


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
			_offset = song.offset
			_result.total = _chart.notes.size()
	else:
		push_warning("'%s' no tiene chart.json; se toca sin notas" % song.id)
	_player.play_song(song, LEAD_IN)


## Junta en una sola nota los golpes de cada figura (los que comparten `group`).
func _group_hits(notes: Array[Dictionary]) -> Array[Array]:
	var groups: Array[Array] = []
	for note in notes:
		if not groups.is_empty() and groups[-1][0].group == note.group:
			groups[-1].append(note)
		else:
			groups.append([note])
	return groups


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
	if not _countdown_played and t >= 0.0:
		_countdown_played = true
		_countdown_sfx.play(t)
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
		while now > note.target().time + HIT_WINDOW:
			_player.set_lead_muted(true)
			_count_miss()
			if not note.miss(beat):
				_active.erase(note)
				break


## Tiempo de la canción para las notas: el del audio, recorrido por el `offset` de la canción.
func _chart_time() -> float:
	return _player.song_time() - _offset


func _on_hud_lane_pressed(lane: ChartMapper.Lane) -> void:
	var now := _chart_time()
	# El golpe más próximo del carril dentro de la ventana.
	var closest: LaneNote = null
	for note in _active:
		if note.lane() == lane and absf(note.target().time - now) <= HIT_WINDOW \
				and (closest == null or note.target().time < closest.target().time):
			closest = note
	if closest:
		if not closest.hit(_chart.tempo.beat_at(now)):
			_active.erase(closest)
		_player.set_lead_muted(false)
		_count_hit()


func _count_hit() -> void:
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
	if _resuming:
		return
	_resuming = true
	_hud.show_pause_menu(false)
	for seconds_left in range(RESUME_COUNT, 0, -1):
		_hud.show_countdown(str(seconds_left))
		await get_tree().create_timer(1.0).timeout  # corre aunque el juego esté en pausa
	_hud.show_countdown("")
	_resuming = false
	get_tree().paused = false


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
		if not get_tree().paused:
			_pause()
		elif _hud.is_pause_menu_shown():
			_resume()
	# La app pasó a segundo plano (llamada, cambio de app).
	elif what == NOTIFICATION_APPLICATION_PAUSED:
		_pause()
