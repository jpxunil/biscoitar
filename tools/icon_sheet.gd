extends SceneTree
## Folha de conferência dos ícones de habilidade (assets/skills/*.svg).
## Rasteriza cada SVG do mesmo jeito que o jogo e monta um PNG com todos, em tamanho grande (96)
## e no tamanho da barra de luta (40), sobre fundo escuro.
##   godot --headless --path . --script res://tools/icon_sheet.gd -- <prefixo> <saida.png>
## <prefixo> filtra pelo começo do nome do arquivo ("tank", "sleepwalker_s"); "all" pega todos.

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var prefix: String = args[0] if args.size() > 0 else "all"
	var out: String = args[1] if args.size() > 1 else "user://icon_sheet.png"
	var names: Array = []
	for f in DirAccess.get_files_at("res://assets/skills"):
		if f.ends_with(".svg") and (prefix == "all" or f.begins_with(prefix)):
			names.append(f)
	names.sort()
	var cols := 6
	var rows := int(ceil(names.size() / float(cols)))
	var cell := Vector2i(150, 124)
	var sheet := Image.create(maxi(cols * cell.x, 1), maxi(rows * cell.y, 1), false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.1, 0.1, 0.2))
	var bad := 0
	for k in names.size():
		var bytes := FileAccess.get_file_as_bytes("res://assets/skills/" + names[k])
		var at := Vector2i((k % cols) * cell.x + 6, (k / cols) * cell.y + 6)
		for spec in [[96, Vector2i(0, 0)], [40, Vector2i(102, 0)]]:
			var img := Image.new()
			var err := img.load_svg_from_buffer(bytes, spec[0] / 128.0)
			if err != OK or img.is_empty():
				bad += 1
				print("ERRO ao ler ", names[k], " (", err, ")")
				break
			img.convert(Image.FORMAT_RGBA8)
			sheet.blend_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), at + spec[1])
		print(k, "  linha ", k / cols + 1, " coluna ", k % cols + 1, "  ", names[k])
	sheet.save_png(out)
	print("folha: ", ProjectSettings.globalize_path(out) if out.begins_with("user://") else out, "  icones: ", names.size(), "  com erro: ", bad)
	quit(1 if bad > 0 else 0)
