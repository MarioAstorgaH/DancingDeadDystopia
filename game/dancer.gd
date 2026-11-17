class_name Dancer
extends TextureRect

## El zombie que baila de fondo: cambia de pose con cada botón que toca el jugador y
## vuelve a la pose de reposo poco después.

const POSE_TIME := 0.3  # segundos que se queda la pose antes de volver al reposo
const POP := 1.06  # cuánto crece al cambiar de pose

@export var idle: Texture2D
## Una pose por carril, en el orden de ChartMapper.Lane (verde, rojo, amarillo, azul).
@export var poses: Array[Texture2D] = []

var _pose_left := 0.0  # segundos que faltan para volver al reposo
var _pop: Tween


func _ready() -> void:
	texture = idle


func pose(lane: ChartMapper.Lane) -> void:
	texture = poses[lane]
	_pose_left = POSE_TIME
	pivot_offset = Vector2(size.x / 2.0, size.y)  # crece desde los pies
	if _pop:
		_pop.kill()
	scale = Vector2.ONE * POP
	_pop = create_tween()
	_pop.tween_property(self, "scale", Vector2.ONE, 0.15)


## Mantiene la pose actual (mientras se sostiene una nota).
func keep_pose() -> void:
	_pose_left = POSE_TIME


func _process(delta: float) -> void:
	if _pose_left > 0.0:
		_pose_left -= delta
		if _pose_left <= 0.0:
			texture = idle
