extends Control

## Menú de pausa. Funciona con el juego en pausa (process_mode = Siempre) y solo avisa
## qué se eligió; la pausa la maneja gameplay.

signal resumed
signal retried
signal quit


func _on_resume_button_pressed() -> void:
	resumed.emit()


func _on_retry_button_pressed() -> void:
	retried.emit()


func _on_quit_button_pressed() -> void:
	quit.emit()
