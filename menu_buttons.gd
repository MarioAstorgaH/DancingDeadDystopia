extends VBoxContainer

const GAMEPLAY_SCENE := "res://gameplay_scene.tscn"
const SETTINGS_SCENE := "res://screen_settings.tscn"


func _on_play_button_pressed() -> void:
	get_tree().change_scene_to_file(GAMEPLAY_SCENE)


func _on_config_button_pressed() -> void:
	get_tree().change_scene_to_file(SETTINGS_SCENE)


func _on_exit_button_pressed() -> void:
	get_tree().quit()
