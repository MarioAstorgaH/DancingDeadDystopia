class_name SongCard
extends Button

## Una fila de la lista del selector de canciones.

var song: SongInfo

@onready var _cover: TextureRect = $content/cover
@onready var _title: Label = $content/info/title
@onready var _artist: Label = $content/info/artist
@onready var _difficulty: Label = $content/stats/difficulty
@onready var _duration: Label = $content/stats/duration


func setup(song_info: SongInfo) -> void:
	song = song_info


func _ready() -> void:
	_title.text = song.title.to_upper()
	_artist.text = song.artist.to_upper()
	_difficulty.text = "DIF %d" % song.difficulty
	_duration.text = song.duration_text()
	if song.cover_path != "" and ResourceLoader.exists(song.cover_path):
		_cover.texture = load(song.cover_path)
	else:
		_cover.hide()
