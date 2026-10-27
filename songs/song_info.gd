class_name SongInfo
extends RefCounted

## Datos de una canción, leídos de `Assets/Songs/<id>/song.json`.

var id := ""
var title := ""
var artist := ""
var difficulty := 1
var duration := 0.0  # segundos, calculado del audio
var audio_path := ""
var cover_path := ""  # vacío si la canción no tiene portada
var lead_path := ""  # melodía original separada; vacío si la canción no la tiene
var chart_path := ""  # notas del juego; vacío si todavía no se generó el chart.json
var offset := 0.0  # segundos que se recorren las notas: positivo = más tarde, negativo = antes


func duration_text() -> String:
	var seconds := int(round(duration))
	return "%d:%02d" % [seconds / 60, seconds % 60]
