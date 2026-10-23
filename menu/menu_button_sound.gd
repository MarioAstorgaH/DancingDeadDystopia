class_name MainMenuButton
extends Button

## Botón de menú que reproduce `sound` en el bus `Effects` al pulsarlo.

signal sound_finished

@export var sound: AudioStream = preload("res://Assets/Audio/audio perron/boton_menu_presionado.wav")

var _player := AudioStreamPlayer.new()


func _ready() -> void:
	_player.stream = sound
	_player.bus = "Effects"
	_player.finished.connect(sound_finished.emit)
	add_child(_player)
	pressed.connect(play_sound)


func play_sound() -> void:
	_player.play()


## Espera a que termine el sonido del botón; sin `sound` regresa de inmediato.
func wait_for_sound() -> void:
	if sound:
		await sound_finished
