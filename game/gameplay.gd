extends Node2D

## Toca la canción elegida en el selector después de una cuenta regresiva.

const SONG_SELECT_SCENE := "res://song_select/screen_song_select.tscn"
const LEAD_IN := 3.0  # segundos para que el jugador se prepare
## Cuándo dice cada palabra `cuenta_regresiva.wav`, en segundos desde que empieza.
## La canción arranca con la última.
const COUNTDOWN_CUES := [[0.12, "3"], [0.85, "2"], [1.61, "1"], [2.49, "YA"]]
const GO_TIME := 0.6  # segundos que se queda el "YA" en pantalla

var _countdown_played := false

@onready var _player: SongPlayer = $SongPlayer
@onready var _countdown_sfx: AudioStreamPlayer = $CountdownSfx
@onready var _hud: Hud = $HUD


func _ready() -> void:
	var song := SongLibrary.selected_song
	if song == null:
		# Al correr la escena directo no hay canción elegida: usa la primera.
		var songs := SongLibrary.load_all()
		if songs.is_empty():
			push_warning("No hay canciones en %s" % SongLibrary.SONGS_DIR)
			return
		song = songs[0]
	_player.play_song(song, LEAD_IN)


func _process(_delta: float) -> void:
	# Tiempo desde que empieza el efecto; su última palabra cae en 0 de la canción.
	var t := _player.song_time() + COUNTDOWN_CUES[-1][0]
	if not _countdown_played and t >= 0.0:
		_countdown_played = true
		_countdown_sfx.play(t)
	_hud.show_countdown(_countdown_text(t))


func _countdown_text(t: float) -> String:
	if t > COUNTDOWN_CUES[-1][0] + GO_TIME:
		return ""
	var text := ""
	for cue in COUNTDOWN_CUES:
		if t >= cue[0]:
			text = cue[1]
	return text


func _notification(what: int) -> void:
	# Botón/gesto "atrás" de Android.
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		get_tree().change_scene_to_file(SONG_SELECT_SCENE)
