extends Button

## Botón de pausa: dibuja el ícono de dos barras encima de su estilo.

const BAR_SIZE := Vector2(0.14, 0.45)  # fracción del botón
const BAR_GAP := 0.12


func _draw() -> void:
	var bar := size * BAR_SIZE
	var top := (size.y - bar.y) / 2.0
	var gap := size.x * BAR_GAP
	draw_rect(Rect2(size.x / 2.0 - gap / 2.0 - bar.x, top, bar.x, bar.y), Color.WHITE)
	draw_rect(Rect2(size.x / 2.0 + gap / 2.0, top, bar.x, bar.y), Color.WHITE)
