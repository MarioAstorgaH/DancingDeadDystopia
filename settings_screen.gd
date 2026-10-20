extends VBoxContainer

const MAIN_MENU_SCENE := "res://screen_main_menu.tscn"


func _notification(what: int) -> void:
	# Botón/gesto "atrás" de Android.
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_on_back_button_pressed()


func _on_back_button_pressed() -> void:
	AudioSettings.save()
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)
