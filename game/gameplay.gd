extends Node2D

## Toca la canción elegida en el selector después de una cuenta regresiva y hace
## bajar sus notas saltando al ritmo. Atinar sube la melodía y fallar la baja.

const SONG_SELECT_SCENE := "res://song_select/screen_song_select.tscn"
const LEAD_IN := 3.0  # segundos para que el jugador se prepare
## Cuándo dice cada palabra `cuenta_regresiva.wav`, en segundos desde que empieza.
## La canción arranca con la última.
const COUNTDOWN_CUES := [[0.12, "3"], [0.85, "2"], [1.61, "1"], [2.49, "YA"]]
const GO_TIME := 0.6  # segundos que se queda el "YA" en pantalla
const LOOKAHEAD_BEATS := 4.0  # tiempos que tarda una nota en bajar de arriba al botón
const TOP_MARGIN := 120.0  # píxeles libres arriba de donde empiezan a verse las notas
const HIT_WINDOW := 0.12  # segundos de tolerancia antes y después de la nota

var _chart: Chart
var _next_note := 0  # índice en _chart.notes de la siguiente nota por aparecer
var _active: Array[LaneNote] = []  # notas en pantalla sin juzgar, ordenadas por tiempo
var _countdown_played := false
var _lanes_enabled := false

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
	if song.chart_path:
		_chart = Chart.load_file(song.chart_path)
	else:
		push_warning("'%s' no tiene chart.json; se toca sin notas" % song.id)
	_player.play_song(song, LEAD_IN)


## Al correr la escena directo no hay canción elegida: usa la primera, de preferencia con notas.
func _first_song_for_testing() -> SongInfo:
	var songs := SongLibrary.load_all()
	for song in songs:
		if song.chart_path:
			return song
	return null if songs.is_empty() else songs[0]


func _process(_delta: float) -> void:
	var now := _player.song_time()
	_update_countdown(now)
	if _chart:
		var beat := _chart.tempo.beat_at(now)
		_spawn_notes(beat)
		_move_notes(beat)
		_miss_late_notes(now)
		_update_lanes_enabled(now)


## Los carriles se encienden con el "YA" y se apagan cuando ya no quedan notas.
func _update_lanes_enabled(now: float) -> void:
	var running := now >= 0.0 and (_next_note < _chart.notes.size() or not _active.is_empty())
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
	while _next_note < _chart.notes.size() \
			and _chart.notes[_next_note].beat - beat <= LOOKAHEAD_BEATS + 1.0:
		var note := LaneNote.new()
		note.note = _chart.notes[_next_note]
		_hud.add_note(note)
		_active.append(note)
		_next_note += 1


func _move_notes(beat: float) -> void:
	var hit_y := _hud.hit_y()
	var beat_px := (hit_y - TOP_MARGIN) / LOOKAHEAD_BEATS
	for note in _active:
		note.place(beat, hit_y, beat_px)


func _miss_late_notes(now: float) -> void:
	while not _active.is_empty() and now > _active[0].note.time + HIT_WINDOW:
		_active.pop_front().miss()
		_player.set_lead_muted(true)


func _on_hud_lane_pressed(lane: ChartMapper.Lane) -> void:
	var now := _player.song_time()
	# La más próxima del carril dentro de la ventana; las de antes ya se habrían fallado.
	for i in _active.size():
		var note := _active[i]
		if note.note.time - now > HIT_WINDOW:
			break
		if note.note.lane == lane:
			_active.remove_at(i)
			note.hit()
			_player.set_lead_muted(false)
			return


func _notification(what: int) -> void:
	# Botón/gesto "atrás" de Android.
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		get_tree().change_scene_to_file(SONG_SELECT_SCENE)
