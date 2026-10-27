extends VBoxContainer

## Pantalla de resultados: muestra SongResult.last y deja reintentar o volver a las canciones.

const SONG_SELECT_SCENE := "res://song_select/screen_song_select.tscn"
const GAMEPLAY_SCENE := "res://game/gameplay_scene.tscn"
const RANK_COLORS := {
	"S": Color(1.0, 0.85, 0.3),
	"A": Color(0.45, 0.85, 0.35),
	"B": Color(0.35, 0.6, 0.95),
	"C": Color(0.95, 0.6, 0.25),
	"D": Color(0.9, 0.3, 0.3),
	"-": Color(0.85, 0.85, 0.85),
}

@onready var _song_title: Label = %song_title
@onready var _song_artist: Label = %song_artist
@onready var _rank: Label = %rank
@onready var _hits: Label = %hits_value
@onready var _misses: Label = %misses_value
@onready var _accuracy: Label = %accuracy_value
@onready var _max_combo: Label = %max_combo_value


func _ready() -> void:
	var result := SongResult.last
	if result == null:
		result = SongResult.new()  # al correr la escena directo
	if result.song:
		_song_title.text = result.song.title
		_song_artist.text = result.song.artist
	_rank.text = result.rank()
	_rank.label_settings = _rank.label_settings.duplicate()
	_rank.label_settings.font_color = RANK_COLORS[result.rank()]
	_hits.text = "%d / %d" % [result.hits, result.total]
	_misses.text = str(result.misses)
	_accuracy.text = "%.1f%%" % (result.accuracy() * 100.0) if result.total > 0 else "-"
	_max_combo.text = str(result.max_combo)


func _notification(what: int) -> void:
	# Botón/gesto "atrás" de Android.
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_on_songs_button_pressed()


func _on_songs_button_pressed() -> void:
	get_tree().change_scene_to_file(SONG_SELECT_SCENE)


func _on_retry_button_pressed() -> void:
	# SongLibrary.selected_song sigue siendo la misma canción.
	get_tree().change_scene_to_file(GAMEPLAY_SCENE)
