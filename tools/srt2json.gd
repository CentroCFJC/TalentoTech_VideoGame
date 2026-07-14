@tool
extends EditorScript

func _run():
	var dir := DirAccess.open("res://assets/videos")
	if not dir:
		print("Error: No se pudo abrir res://assets/videos/")
		return

	dir.list_dir_begin()
	var file_name := dir.get_next()
	var converted := 0
	while file_name != "":
		if file_name.ends_with(".srt"):
			var src := "res://assets/videos/" + file_name
			var dst := src.get_basename() + ".json"
			if _convert(src, dst):
				converted += 1
		file_name = dir.get_next()
	dir.list_dir_end()
	print("Conversion completa: ", converted, " archivos .srt convertidos a .json")

func _convert(src: String, dst: String) -> bool:
	var f := FileAccess.open(src, FileAccess.READ)
	if not f:
		push_error("No se pudo abrir: ", src)
		return false

	var text := f.get_as_text()
	f.close()
	text = text.replace("\r\n", "\n").replace("\r", "\n")

	var entries: Array[Dictionary] = []
	var blocks := text.strip_edges().split("\n\n")
	for block in blocks:
		var e := _parse_block(block.strip_edges())
		if not e.is_empty():
			entries.append(e)

	if entries.is_empty():
		push_warning("No se encontraron entradas en: ", src)
		return false

	var out := FileAccess.open(dst, FileAccess.WRITE)
	if not out:
		push_error("No se pudo escribir: ", dst)
		return false
	out.store_string(JSON.stringify(entries, "\t") + "\n")
	out.close()
	print("  ", src.get_file(), " -> ", dst.get_file(), " (", entries.size(), " entradas)")
	return true

func _parse_block(block: String) -> Dictionary:
	var lines := block.split("\n")
	if lines.size() < 2:
		return {}

	var ts_idx := -1
	for i in lines.size():
		if "-->" in lines[i]:
			ts_idx = i
			break
	if ts_idx < 0:
		return {}

	var parts := lines[ts_idx].split("-->")
	if parts.size() != 2:
		return {}

	var start := _parse_ts(parts[0].strip_edges())
	var end := _parse_ts(parts[1].strip_edges())
	if start < 0 or end < 0:
		return {}

	var txt: PackedStringArray = []
	for i in range(ts_idx + 1, lines.size()):
		var l := lines[i].strip_edges()
		if not l.is_empty():
			txt.append(l)
	if txt.is_empty():
		return {}

	return {"start": start, "end": end, "text": "\n".join(txt)}

func _parse_ts(s: String) -> float:
	s = s.replace(",", ".")
	var p := s.split(":")
	if p.size() != 3:
		return -1.0
	var sp := p[2].split(".")
	var ms := 0
	if sp.size() > 1:
		ms = sp[1].to_int()
	return float(p[0].to_int() * 3600 + p[1].to_int() * 60 + sp[0].to_int()) + float(ms) / 1000.0
