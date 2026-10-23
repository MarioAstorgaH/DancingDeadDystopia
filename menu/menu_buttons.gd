extends VBoxContainer

const SONG_SELECT_SCENE := "res://song_select/screen_song_select.tscn"
const SETTINGS_SCENE := "res://settings/screen_settings.tscn"

@onready var _play_button: MainMenuButton = $play_button
@onready var _config_button: MainMenuButton = $config_button
@onready var _exit_button: MainMenuButton = $exit_button


func _on_play_button_pressed() -> void:
	await _play_button.wait_for_sound()
	get_tree().change_scene_to_file(SONG_SELECT_SCENE)


func _on_config_button_pressed() -> void:
	await _config_button.wait_for_sound()
	get_tree().change_scene_to_file(SETTINGS_SCENE)


func _on_exit_button_pressed() -> void:
	await _exit_button.wait_for_sound()
	get_tree().quit()
