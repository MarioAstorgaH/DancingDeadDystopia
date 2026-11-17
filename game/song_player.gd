class_name SongPlayer
extends AudioStreamPlayer

## Toca la canción: el fondo (`audio`) y la melodía original (`lead`) juntos y
## sincronizados. Cuando el jugador falla se baja la melodía hasta que vuelva a atinar.
## El reloj compensa la latencia que reporta Godot más el ajuste del jugador
## (AudioSettings.latency_ms): en Android Godot casi no la reporta y el sonido sale tarde.

const MUTED_DB := -60.0
const FADE := 0.08  # segundos
## El reloj de la canción sigue al audio poco a poco: la posición que da Godot tiembla
## unos milisegundos entre frames y las notas temblarían con ella.
const CLOCK_CORRECTION := 0.05  # fracción del desfase que se corrige por frame
const CLOCK_RESYNC := 0.1  # segundos: con más desfase el reloj salta directo al audio

var _sync: AudioStreamSynchronized
var _lead_db := 0.0
var _fade: Tween
var _origin_usec := 0  # Time.get_ticks_usec() en el que la canción está en 0
var _waiting := false  # hay una canción esperando a que termine la cuenta regresiva
var _paused_usec := -1  # cuándo se pausó el juego; -1 si no está en pausa
## Falso para no usar el ajuste de latencia del jugador: la pantalla de calibración mide
## el desfase completo con el reloj sin ajustar.
var use_calibration := true


func _init() -> void:
	bus = "GameMusic"


## Empieza la canción después de `lead_in` segundos de espera.
func play_song(song: SongInfo, lead_in := 0.0) -> void:
	play_streams(load(song.audio_path), load(song.lead_path) if song.lead_path else null, lead_in)


## Como play_song() pero con el audio ya cargado; `lead` es opcional.
func play_streams(audio: AudioStream, lead: AudioStream = null, lead_in := 0.0) -> void:
	_sync = AudioStreamSynchronized.new()
	_sync.stream_count = 2 if lead else 1
	_sync.set_sync_stream(0, audio)
	if lead:
		_sync.set_sync_stream(1, lead)
	_lead_db = 0.0
	stream = _sync
	_origin_usec = Time.get_ticks_usec() + int(lead_in * 1_000_000.0)
	_waiting = true


## Segundos entre que se manda el audio y que se oye.
func latency() -> float:
	var extra := AudioSettings.latency_ms / 1000.0 if use_calibration else 0.0
	return AudioServer.get_output_latency() + extra


func _process(_delta: float) -> void:
	var latency := latency()
	if _waiting and song_time() >= -latency:
		# Arranca un poco antes para que el sonido salga justo en 0 de la canción.
		_waiting = false
		play(maxf(song_time() + latency, 0.0))
	elif playing:
		_follow_audio(latency)


func _notification(what: int) -> void:
	# Con el juego en pausa el audio se detiene solo; el reloj se congela con él.
	if what == NOTIFICATION_PAUSED:
		_paused_usec = Time.get_ticks_usec()
	elif what == NOTIFICATION_UNPAUSED and _paused_usec >= 0:
		_origin_usec += Time.get_ticks_usec() - _paused_usec
		_paused_usec = -1


## Baja la melodía al fallar y la sube al atinar. Sin `lead` no hace nada.
func set_lead_muted(muted: bool) -> void:
	if _sync == null or _sync.stream_count < 2:
		return
	if _fade:
		_fade.kill()
	_fade = create_tween()
	_fade.tween_method(_set_lead_db, _lead_db, MUTED_DB if muted else 0.0, FADE)


## Posición de la canción en segundos, compensando la latencia del audio.
## Es negativa durante la espera antes de que empiece y no avanza en pausa. Avanza parejo; solo salta
## si el audio se desfasa más de CLOCK_RESYNC.
func song_time() -> float:
	var now := _paused_usec if _paused_usec >= 0 else Time.get_ticks_usec()
	return (now - _origin_usec) / 1_000_000.0


func _follow_audio(latency: float) -> void:
	var audio_time := get_playback_position() + AudioServer.get_time_since_last_mix() - latency
	var drift := song_time() - audio_time
	if absf(drift) < CLOCK_RESYNC:
		drift *= CLOCK_CORRECTION
	_origin_usec += int(drift * 1_000_000.0)


func _set_lead_db(db: float) -> void:
	_lead_db = db
	_sync.set_sync_stream_volume(1, db)
