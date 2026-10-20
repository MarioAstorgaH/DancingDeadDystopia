extends VBoxContainer

const SONG_SELECT_SCENE := "res://song_select/screen_song_select.tscn"
const SETTINGS_SCENE := "res://settings/screen_settings.tscn"


func _on_play_button_pressed() -> void:
	get_tree().change_scene_to_file(SONG_SELECT_SCENE)


func _on_config_button_pressed() -> void:
	get_tree().change_scene_to_file(SETTINGS_SCENE)


func _on_exit_button_pressed() -> void:
	get_tree().quit()
