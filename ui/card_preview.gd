extends Control
## Cena de teste do card. Rode com F6 no editor.

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot="):
			await get_tree().create_timer(float(a.trim_prefix("--shot="))).timeout
			get_viewport().get_texture().get_image().save_png("user://shot.png")
			print("SHOT ", ProjectSettings.globalize_path("user://shot.png"))
			get_tree().quit()
