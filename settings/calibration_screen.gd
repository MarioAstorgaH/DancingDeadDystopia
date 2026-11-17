extends VBoxContainer

## Pantalla de calibración: suena un metrónomo y el jugador toca el cerebro con cada golpe.
## Qué tan tarde toca, en la mediana de sus últimos toques (el sonido que sale tarde más el
## toque que llega tarde), es el ajuste de latencia (AudioSettings.latency_ms) que
## SongPlayer usa para atrasar las notas. El slider permite afinarlo a mano. En la PC
## también se toca con las teclas del juego (D, F, J, K) o la barra espaciadora.

const SETTINGS_SCENE := "res://settings/screen_settings.tscn"
const BPM := 80.0  # lento, para que hasta medio golpe (375 ms) de retraso no se confunda
const BEATS := 32  # golpes del metrónomo antes de volver a empezar
const LEAD_IN := 1.0  # segundos antes del primer golpe
const SAMPLES := 8  # toques recientes que cuentan para el ajuste
const MIN_SAMPLES := 4  # toques antes de cambiar el ajuste
const MIX_RATE := 44100
const CLICK_LENGTH := 0.03  # segundos que dura cada golpe
const STEP_MS := 5.0
const TAP_KEYS := [KEY_D, KEY_F, KEY_J, KEY_K, KEY_SPACE]

var _clicks: AudioStreamWAV
var _errors: Array[float] = []  # segundos de retraso de cada toque reciente

@onready var _player: SongPlayer = %calibration_player
@onready var _slider: HSlider = %latency_slider
@onready var _value_label: Label = %latency_value
@onready var _status: Label = %status_label


func _ready() -> void:
	_player.use_calibration = false  # se mide el desfase completo
	_slider.min_value = AudioSettings.MIN_LATENCY_MS
	_slider.max_value = AudioSettings.MAX_LATENCY_MS
	_slider.step = STEP_MS
	_slider.value = AudioSettings.latency_ms
	_show_value(_slider.value)
	_show_status()
	_clicks = _make_clicks()
	_player.play_streams(_clicks, null, LEAD_IN)


func _on_tap_button_down() -> void:
	var period := 60.0 / BPM
	var now := _player.song_time()
	if now < -period / 2.0:
		return
	_errors.append(now - roundf(now / period) * period)
	if _errors.size() > SAMPLES:
		_errors.pop_front()
	if _errors.size() >= MIN_SAMPLES:
		var sorted := _errors.duplicate()
		sorted.sort()
		_slider.value = snappedf(sorted[sorted.size() / 2] * 1000.0, STEP_MS)
	_show_status()


func _unhandled_key_input(event: InputEvent) -> void:
	var key_event := event as InputEventKey
	if key_event.pressed and not key_event.echo and key_event.physical_keycode in TAP_KEYS:
		_on_tap_button_down()
		get_viewport().set_input_as_handled()


func _on_latency_slider_value_changed(value: float) -> void:
	AudioSettings.latency_ms = value
	_show_value(value)


## El metrónomo vuelve a empezar al terminar.
func _on_calibration_player_finished() -> void:
	_player.play_streams(_clicks)


func _show_value(value: float) -> void:
	_value_label.text = "%d MS" % roundi(value)


func _show_status() -> void:
	if _errors.size() < MIN_SAMPLES:
		_status.text = "TOQUES %d / %d" % [_errors.size(), MIN_SAMPLES]
	else:
		_status.text = "AJUSTADO"


## Un golpe corto por tiempo, más agudo en el primero de cada compás.
func _make_clicks() -> AudioStreamWAV:
	var period := 60.0 / BPM
	var data := PackedByteArray()
	data.resize(int(BEATS * period * MIX_RATE) * 2)
	var click_frames := int(CLICK_LENGTH * MIX_RATE)
	for beat in BEATS:
		var start := int(beat * period * MIX_RATE)
		var frequency := 1600.0 if beat % 4 == 0 else 1000.0
		for i in click_frames:
			var envelope := 1.0 - float(i) / click_frames
			var sample := sin(TAU * frequency * i / MIX_RATE) * envelope * envelope * 0.8
			data.encode_s16((start + i) * 2, int(sample * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.data = data
	return wav


func _notification(what: int) -> void:
	# Botón/gesto "atrás" de Android.
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_on_back_button_pressed()


func _on_back_button_pressed() -> void:
	AudioSettings.save()
	get_tree().change_scene_to_file(SETTINGS_SCENE)
