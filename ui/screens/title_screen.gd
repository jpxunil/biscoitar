class_name TitleScreen
extends Control
## Tela inicial: BOSSES, GEAR e LOJA (a loja abre depois da primeira vitória).
## O layout fica na cena (title_screen.tscn); aqui é só comportamento.

signal bosses_pressed
signal gear_pressed
signal shop_pressed

var _btns: Array = []
var _focus := 0


func _ready() -> void:
	_btns = [$BtnBosses, $BtnGear, $BtnShop]
	$BtnBosses.pressed.connect(func(): bosses_pressed.emit())
	$BtnGear.pressed.connect(func(): gear_pressed.emit())
	$BtnShop.pressed.connect(func(): shop_pressed.emit())
	$Wallet/CoinIcon.draw.connect(func(): Ink.draw_coin($Wallet/CoinIcon, 32))
	$Wallet/TicketIcon.draw.connect(func(): Ink.draw_ticket($Wallet/TicketIcon, 32))
	if get_tree().current_scene == self:
		# aberta sozinha (F6): não mexe no save
		Knowledge.persist = false
		open()


func open() -> void:
	$Wallet/Coins.text = str(Knowledge.money)
	$Wallet/Tickets.text = str(Knowledge.tickets)
	$BtnShop.disabled = not Knowledge.shop_unlocked
	$ShopLock.visible = not Knowledge.shop_unlocked
	_focus = 0
	# o logo "carimba" e os botões entram da direita, um depois do outro
	var logo: Control = $LogoPanel
	logo.pivot_offset = logo.size * 0.5
	logo.scale = Vector2.ONE * 0.7
	logo.create_tween().tween_property(logo, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	for k in _btns.size():
		var b: Control = _btns[k]
		b.modulate.a = 0.0
		var tw := b.create_tween()
		tw.tween_interval(0.08 + k * 0.07)
		tw.tween_property(b, "modulate:a", 1.0, 0.16)
	_mark_focus()


func _mark_focus() -> void:
	for k in _btns.size():
		_btns[k].outline = Ink.CREAM if k == _focus else Ink.OUT
		_btns[k].queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree() or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	match event.physical_keycode:
		KEY_W, KEY_UP:
			_focus = posmod(_focus - 1, _btns.size())
			_mark_focus()
		KEY_S, KEY_DOWN:
			_focus = posmod(_focus + 1, _btns.size())
			_mark_focus()
		KEY_ENTER, KEY_KP_ENTER:
			if not _btns[_focus].disabled:
				_btns[_focus].pressed.emit()
