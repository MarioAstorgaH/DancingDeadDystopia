class_name SongPlayer
extends AudioStreamPlayer

## Toca la canción: el fondo (`audio`) y la melodía original (`lead`) juntos y
## sincronizados. Cuando el jugador falla se baja la melodía hasta que vuelva a atinar.

const MUTED_DB := -60.0
const FADE := 0.08  # segundos

var _sync: AudioStreamSynchronized
var _lead_db := 0.0
var _fade: Tween
var _start_usec := -1  # cuándo empieza el audio; -1 si no hay canción esperando


func _init() -> void:
	bus = "GameMusic"


## Empieza la canción después de `lead_in` segundos de espera.
func play_song(song: SongInfo, lead_in := 0.0) -> void:
	_sync = AudioStreamSynchronized.new()
	_sync.stream_count = 2 if song.lead_path else 1
	_sync.set_sync_stream(0, load(song.audio_path))
	if song.lead_path:
		_sync.set_sync_stream(1, load(song.lead_path))
	_lead_db = 0.0
	stream = _sync
	_start_usec = Time.get_ticks_usec() + int(lead_in * 1000000.0)


func _process(_delta: float) -> void:
	if _start_usec >= 0 and Time.get_ticks_usec() >= _start_usec:
		# Arranca desde lo que ya pasó del frame para que el tiempo no salte hacia atrás.
		var late := (Time.get_ticks_usec() - _start_usec) / 1000000.0
		_start_usec = -1
		play(late)


## Baja la melodía al fallar y la sube al atinar. Sin `lead` no hace nada.
func set_lead_muted(muted: bool) -> void:
	if _sync == null or _sync.stream_count < 2:
		return
	if _fade:
		_fade.kill()
	_fade = create_tween()
	_fade.tween_method(_set_lead_db, _lead_db, MUTED_DB if muted else 0.0, FADE)


## Posición de la canción en segundos, compensando la latencia del audio.
## Es negativa durante la espera antes de que empiece.
func song_time() -> float:
	if _start_usec >= 0:
		return (Time.get_ticks_usec() - _start_usec) / 1000000.0
	return get_playback_position() + AudioServer.get_time_since_last_mix() - AudioServer.get_output_latency()


func _set_lead_db(db: float) -> void:
	_lead_db = db
	_sync.set_sync_stream_volume(1, db)
