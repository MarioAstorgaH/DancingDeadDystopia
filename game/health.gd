class_name Health
extends Node

## La vida del jugador, como en Friday Night Funkin': empieza a la mitad, cada fallo quita
## (y los fallos seguidos quitan cada vez más), cada acierto recupera un poco (y las rachas
## recuperan más) y al llegar a 0 se acaba la canción. Los valores se ajustan en el inspector.

signal changed(fraction: float)  ## la vida, de 0 a 1
signal died

## Qué pasa al tocar una nota hostil.
enum HostilePunishment {
	INSTANT_DEATH,  ## mata al instante
	NEAR_DEATH,  ## deja al jugador a `hostile_misses_left` fallos de morir
}

@export var max_health := 100.0
@export var start_health := 50.0

@export_group("Fallos")
## Lo que quita un fallo suelto.
@export var miss_damage := 5.0
## Lo que quita de más cada fallo seguido (el segundo quita miss_damage + esto, etc.).
@export var miss_streak_damage := 2.5
## Lo más que puede quitar un fallo, por larga que sea la racha.
@export var max_miss_damage := 20.0

@export_group("Aciertos")
## Lo que recupera un acierto suelto.
@export var hit_heal := 1.0
## Lo que recupera de más cada acierto seguido.
@export var streak_heal := 0.05
## Lo más que puede recuperar un acierto, por larga que sea la racha.
@export var max_hit_heal := 2.5

@export_group("Notas hostiles")
@export var hostile_punishment := HostilePunishment.NEAR_DEATH
## Con NEAR_DEATH, a cuántos fallos seguidos de morir deja una nota hostil. Si ya estaba
## más abajo, quita lo de un fallo.
@export var hostile_misses_left := 3

var value := 0.0
var _hit_streak := 0
var _miss_streak := 0
var _dead := false


func _ready() -> void:
	_set_value.call_deferred(start_health)  # el HUD todavía no está listo


func fraction() -> float:
	return value / max_health


func is_dead() -> bool:
	return _dead


func hit() -> void:
	_miss_streak = 0
	_hit_streak += 1
	_set_value(value + minf(hit_heal + streak_heal * (_hit_streak - 1), max_hit_heal))


func miss() -> void:
	_hit_streak = 0
	_miss_streak += 1
	_set_value(value - _miss_damage(_miss_streak))


## Se tocó una nota hostil. No cuenta en la racha de fallos.
func hostile() -> void:
	_hit_streak = 0
	if hostile_punishment == HostilePunishment.INSTANT_DEATH:
		_set_value(0.0)
		return
	var left := 0.0  # lo que quitarían los siguientes hostile_misses_left fallos seguidos
	for i in hostile_misses_left:
		left += _miss_damage(_miss_streak + 1 + i)
	_set_value(minf(value - _miss_damage(_miss_streak + 1), left))


## Lo que quita el fallo número `streak` de una racha.
func _miss_damage(streak: int) -> float:
	return minf(miss_damage + miss_streak_damage * (streak - 1), max_miss_damage)


func _set_value(new_value: float) -> void:
	if _dead:
		return
	value = clampf(new_value, 0.0, max_health)
	changed.emit(fraction())
	if value <= 0.001:
		_dead = true
		died.emit()
