class_name SongResult
extends RefCounted

## Cómo le fue al jugador en una canción: gameplay lo llena y la pantalla de resultados
## lo muestra.

## Rango mínimo por precisión, del mejor al peor. La S es solo sin fallos.
const RANKS := [[0.9, "A"], [0.75, "B"], [0.6, "C"]]

## El resultado de la última canción terminada; sobrevive al cambio de escena.
static var last: SongResult

var song: SongInfo
var total := 0  # golpes del chart
var hits := 0
var misses := 0
var max_combo := 0


func accuracy() -> float:
	return hits / float(total) if total > 0 else 0.0


## "S", "A", "B", "C" o "D"; "-" si la canción no tiene notas.
func rank() -> String:
	if total == 0:
		return "-"
	if misses == 0 and hits == total:
		return "S"
	for entry in RANKS:
		if accuracy() >= entry[0]:
			return entry[1]
	return "D"
