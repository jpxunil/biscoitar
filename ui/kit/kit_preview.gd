extends Control
## Cena de conferência do kit (F6): painéis, botões e os estados da carta.

func _ready() -> void:
	Knowledge.persist = false
	add_child(InkBackdrop.new())
	var p := Ink.panel(Ink.NAVY, 4)
	p.position = Vector2(40, 40)
	p.size = Vector2(520, 110)
	add_child(p)
	var t := Ink.title("CARTAS", 54)
	t.position = Vector2(30, 18)
	p.add_child(t)
	var b := Ink.button("READY FOR BATTLE", Ink.COIN, Ink.OUT, 30, 5)
	b.position = Vector2(620, 50)
	b.size = Vector2(420, 84)
	add_child(b)
	var b2 := Ink.button("BUY", Ink.GRAPE, Ink.CREAM, 30, 8)
	b2.position = Vector2(1070, 56)
	b2.size = Vector2(170, 74)
	add_child(b2)
	var x := 50.0
	for spec in [["dodge", "face"], ["mitigate", "face"], ["revive", "face"], ["potion", "face"], ["sharpen", "dim"], ["stack", "back"], ["eshield", "face"]]:
		var c := CardView.make(spec[0], spec[1])
		c.position = Vector2(x, 220)
		if spec[0] == "stack":
			c.progress = 2
		if spec[0] == "eshield":
			c.price_tag = "220"
			c.selected = true
		add_child(c)
		x += 128.0
	for k in ["purple", "gold", "white", "item"]:
		var e := CardView.empty(k)
		e.position = Vector2(x, 220)
		add_child(e)
		x += 128.0
	var cream := Ink.panel(Ink.CREAM, 9)
	cream.position = Vector2(50, 430)
	cream.size = Vector2(560, 150)
	add_child(cream)
	var d := Ink.text("Texto corrido em cima de painel creme, com a tinta escura.", 18, Ink.OUT)
	d.position = Vector2(26, 24)
	cream.add_child(d)
	await get_tree().create_timer(0.6).timeout
	if OS.get_cmdline_user_args().has("--shot"):
		get_viewport().get_texture().get_image().save_png("user://kit.png")
		get_tree().quit()
