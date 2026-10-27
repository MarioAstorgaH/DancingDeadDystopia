class_name SongLibrary
extends RefCounted

## Busca las canciones en `Assets/Songs/` y las ordena.
## Cada canción es una carpeta con `song.json` y su audio (.ogg o .mp3).

enum SortKey { DIFFICULTY, TITLE, ARTIST, DURATION }

const SONGS_DIR := "res://Assets/Songs/"
const CHART_NAME := "chart.json"

## Canción elegida en el selector; la lee `gameplay_scene`.
static var selected_song: SongInfo


static func load_all() -> Array[SongInfo]:
	var songs: Array[SongInfo] = []
	if not DirAccess.dir_exists_absolute(SONGS_DIR):
		return songs
	for entry in ResourceLoader.list_directory(SONGS_DIR):
		if entry.ends_with("/"):
			var song := _load_song(entry.trim_suffix("/"))
			if song:
				songs.append(song)
	return songs


static func sort(songs: Array[SongInfo], key: SortKey, ascending: bool) -> void:
	songs.sort_custom(func(a: SongInfo, b: SongInfo) -> bool:
		var order := _compare(a, b, key)
		if order == 0:
			order = a.title.naturalnocasecmp_to(b.title)
		return order < 0 if ascending else order > 0)


static func _compare(a: SongInfo, b: SongInfo, key: SortKey) -> int:
	match key:
		SortKey.DIFFICULTY:
			return signi(a.difficulty - b.difficulty)
		SortKey.ARTIST:
			return a.artist.naturalnocasecmp_to(b.artist)
		SortKey.DURATION:
			return int(signf(a.duration - b.duration))
		_:
			return a.title.naturalnocasecmp_to(b.title)


static func _load_song(id: String) -> SongInfo:
	var folder := SONGS_DIR + id + "/"
	var data = JSON.parse_string(FileAccess.get_file_as_string(folder + "song.json"))
	if not data is Dictionary:
		push_warning("Canción '%s': song.json no existe o no es válido" % id)
		return null

	var song := SongInfo.new()
	song.id = id
	song.title = str(data.get("title", id))
	song.artist = str(data.get("artist", ""))
	song.difficulty = int(data.get("difficulty", 1))
	song.audio_path = folder + str(data.get("audio", "song.ogg"))
	if data.has("lead"):
		song.lead_path = folder + str(data["lead"])
		if not ResourceLoader.exists(song.lead_path):
			push_warning("Canción '%s': no existe la melodía %s, se toca sin ella" % [id, song.lead_path])
			song.lead_path = ""
	if FileAccess.file_exists(folder + CHART_NAME):
		song.chart_path = folder + CHART_NAME
	if data.has("cover"):
		song.cover_path = folder + str(data["cover"])

	var stream := load(song.audio_path) as AudioStream if ResourceLoader.exists(song.audio_path) else null
	if stream == null:
		push_warning("Canción '%s': no se pudo cargar el audio %s" % [id, song.audio_path])
		return null
	song.duration = stream.get_length()
	return song
