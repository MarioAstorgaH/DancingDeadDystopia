class_name PauseMenu
extends Control

## Menú de pausa. Funciona con el juego en pausa (process_mode = Siempre) y solo avisa
## qué se eligió; la pausa la maneja gameplay. Al morir se usa como pantalla de fin
## (show_game_over), sin poder continuar.

signal resumed
signal retried
signal quit

const GAME_OVER_TEXT := "MORISTE"

@onready var _title: Label = $center/menu/title
@onready var _resume_button: Button = $center/menu/resume_button


func show_game_over() -> void:
	_title.text = GAME_OVER_TEXT
	_resume_button.hide()


func _on_resume_button_pressed() -> void:
	resumed.emit()


func _on_retry_button_pressed() -> void:
	retried.emit()


func _on_quit_button_pressed() -> void:
	quit.emit()
