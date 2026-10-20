extends VBoxContainer

const MAIN_MENU_SCENE := "res://screen_main_menu.tscn"
const GAMEPLAY_SCENE := "res://gameplay_scene.tscn"
const SONG_CARD_SCENE := preload("res://song_card.tscn")

var _songs: Array[SongInfo] = []
var _sort_key := SongLibrary.SortKey.TITLE
var _ascending := true
var _card_group := ButtonGroup.new()

@onready var _song_list: VBoxContainer = %song_list
@onready var _empty_label: Label = %empty_label
@onready var _order_label: Label = %order_label
@onready var _play_button: Button = %play_button
@onready var _sort_buttons := {
	SongLibrary.SortKey.DIFFICULTY: %sort_difficulty,
	SongLibrary.SortKey.TITLE: %sort_title,
	SongLibrary.SortKey.ARTIST: %sort_artist,
	SongLibrary.SortKey.DURATION: %sort_duration,
}


func _ready() -> void:
	_songs = SongLibrary.load_all()
	_empty_label.visible = _songs.is_empty()
	_play_button.disabled = true
	_refresh()


func _notification(what: int) -> void:
	# Botón/gesto "atrás" de Android.
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_on_back_button_pressed()


func _refresh() -> void:
	SongLibrary.sort(_songs, _sort_key, _ascending)
	for key in _sort_buttons:
		_sort_buttons[key].button_pressed = key == _sort_key
	_order_label.text = "MENOR A MAYOR" if _ascending else "MAYOR A MENOR"

	var selected := _selected_song()
	for card in _song_list.get_children():
		_song_list.remove_child(card)
		card.queue_free()
	for song in _songs:
		var card: SongCard = SONG_CARD_SCENE.instantiate()
		card.setup(song)
		card.button_group = _card_group
		card.button_pressed = song == selected
		card.pressed.connect(_on_song_card_pressed)
		_song_list.add_child(card)


func _selected_song() -> SongInfo:
	var card := _card_group.get_pressed_button() as SongCard
	return card.song if card else null


func _sort_by(key: SongLibrary.SortKey) -> void:
	# Tocar el mismo botón otra vez invierte el orden.
	_ascending = not _ascending if key == _sort_key else true
	_sort_key = key
	_refresh()


func _on_sort_difficulty_pressed() -> void:
	_sort_by(SongLibrary.SortKey.DIFFICULTY)


func _on_sort_title_pressed() -> void:
	_sort_by(SongLibrary.SortKey.TITLE)


func _on_sort_artist_pressed() -> void:
	_sort_by(SongLibrary.SortKey.ARTIST)


func _on_sort_duration_pressed() -> void:
	_sort_by(SongLibrary.SortKey.DURATION)


func _on_song_card_pressed() -> void:
	_play_button.disabled = _selected_song() == null


func _on_play_button_pressed() -> void:
	SongLibrary.selected_song = _selected_song()
	get_tree().change_scene_to_file(GAMEPLAY_SCENE)


func _on_back_button_pressed() -> void:
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)
