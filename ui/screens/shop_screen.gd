class_name ShopScreen
extends Control
## A loja: um lugar só, com dois balcões. O da Shopkeeper vende cartas (por moedas; as roxas por
## ticket, que vem do ranking SSS) e o da vendedora de itens vende equipamentos e consumíveis.
## O botão BtnSwap (ou TAB) troca de um pro outro. Toda compra passa por Knowledge.buy.
## O layout fica na cena (shop_screen.tscn).

signal back_pressed

const LINES := {
	"hello": ["Oi... pode olhar. Só não amassa as cartas.", "Zzz... ah, cliente. Fica à vontade.", "Carta boa, preço justo. Mais ou menos justo."],
	"attack": ["Essa aí bate. Bate bastante.", "Pra quem gosta de ver número grande."],
	"defense": ["Apanhar menos também é estratégia.", "Segura a onda, essa."],
	"utility": ["Não parece muito, mas faz falta.", "As discretas são as que salvam."],
	"special": ["Opa. Essa eu guardo no fundo da gaveta.", "Carta de gente que joga sério."],
	"ticket": ["Roxa é só com ticket. Tira SSS numa boss e volta aqui.", "Moeda não compra essa. Ticket roxo, do ranking SSS."],
	"poor": ["Tá faltando moeda aí, hein.", "Volta quando juntar mais um pouco."],
	"owned": ["Essa você já levou.", "Vendi pra você mesmo, lembra?"],
	"bought": ["Boa escolha! Vai lá equipar.", "Vendido! Usa com carinho.", "Isso, leva. Depois me conta se funcionou."],
}

## Falas do balcão de itens (mode "gear"): a vendedora de equipamentos e consumíveis.
const LINES_GEAR := {
	"hello": ["Equipamento não ensina nada. Só deixa o que você já sabe mais forte.", "Tudo aqui é pra vestir, calçar ou beber."],
	"attack": ["Esse faz o número subir.", "Bate igual, dói mais."],
	"defense": ["Pra aguentar mais um golpe.", "Quem fica de pé ganha a luta."],
	"utility": ["Pequeno, mas você sente a diferença.", "Coisa de quem pensa em tudo."],
	"special": ["Esse é do fundo da oficina.", "Peça rara. Cuida bem."],
	"ticket": ["Esse eu só troco por ticket roxo. Tira SSS numa boss.", "Moeda não paga esse aqui."],
	"poor": ["Faltou moeda. Volta depois.", "Junta mais um pouco que eu guardo pra você."],
	"owned": ["Esse já é seu.", "Você já levou um desses."],
	"bought": ["Fechado! Vai lá no GEAR equipar.", "Boa. Põe num slot e sente a diferença."],
}

## "cards": a loja de cartas da Shopkeeper. "gear": o balcão de itens (equipamentos e consumíveis).
var mode := "cards"
var cat := ""
var sel := ""
var _dialog: Control


func _ready() -> void:
	$BtnBack.pressed.connect(func(): back_pressed.emit())
	$BtnBuy.pressed.connect(_press_buy)
	for pair in [[$Wallet/CoinIcon, true], [$Wallet/TicketIcon, false]]:
		var icon: Control = pair[0]
		icon.draw.connect(func():
			if pair[1]:
				Ink.draw_coin(icon, 32)
			else:
				Ink.draw_ticket(icon, 32))
	$Details/PriceTag/PriceIcon.draw.connect(_draw_price_icon)
	# troca de balcão, à direita: da loja de cartas pra de itens e de volta, sem sair da loja
	var swap := Ink.button("", Ink.COIN, Ink.OUT, 20, 27)
	swap.name = "BtnSwap"
	swap.position = Vector2(650, 30)
	swap.size = Vector2(262, 60)
	swap.pressed.connect(swap_shop)
	add_child(swap)
	if get_tree().current_scene == self:
		Knowledge.persist = false
		Knowledge.money = 500
		Knowledge.tickets = 1
		open()


func open(shop_mode := "cards") -> void:
	mode = shop_mode
	cat = ""
	sel = ""
	$TitlePanel/Title.text = "ITENS" if mode == "gear" else "LOJA"
	# o mesmo balcão, outra vendedora
	$Vendor.who = mode
	$BtnSwap.text = "LOJA DE CARTAS  ›" if mode == "gear" else "LOJA DE ITENS  ›"
	_close_dialog()
	_build_tabs()
	_build_grid()
	_refresh_wallet()
	var all := Knowledge.shop_list("", mode)
	if not all.is_empty():
		_select(all[0])
	_say("hello")


## Vai pro outro balcão (cartas <-> itens). Dá pra ficar trocando à vontade.
func swap_shop() -> void:
	open("cards" if mode == "gear" else "gear")


func _say(key: String, mood := "idle") -> void:
	var opts: Array = (LINES_GEAR if mode == "gear" else LINES)[key]
	$Bubble/BubbleText.text = opts[randi() % opts.size()]
	$Vendor.mood = mood
	var b: Control = $Bubble
	b.pivot_offset = b.size * 0.5
	b.scale = Vector2.ONE * 0.9
	b.create_tween().tween_property(b, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _refresh_wallet() -> void:
	$Wallet/Coins.text = str(Knowledge.money)
	$Wallet/Tickets.text = str(Knowledge.tickets)


func _build_tabs() -> void:
	for c in $Tabs.get_children():
		$Tabs.remove_child(c)
		c.queue_free()
	var entries := [["", "Tudo"]]
	for k in Knowledge.CATS:
		entries.append([k, Knowledge.CAT_NAME[k]])
	for n in entries.size():
		var key: String = entries[n][0]
		var on := key == cat
		var b := Ink.button(entries[n][1], Ink.CREAM if on else Ink.NAVY, Ink.OUT if on else Ink.CREAM, 18, 20 + n)
		b.custom_minimum_size = Vector2(96, 46)
		b.pressed.connect(func():
			cat = key
			_build_tabs()
			_build_grid())
		$Tabs.add_child(b)


func _price_text(id: String) -> String:
	var c: Dictionary = Knowledge.CARDS[id]
	if Knowledge.owned.has(id):
		return "VENDIDA"
	if c.has("ticket"):
		return "%d ticket" % int(c["ticket"])
	return str(int(c["price"]))


func _build_grid() -> void:
	var grid: Control = $GridPanel/Scroll/Grid
	for c in grid.get_children():
		grid.remove_child(c)
		c.queue_free()
	var n := 0
	for id in Knowledge.shop_list(cat, mode):
		var cv := CardView.make(id, "dim" if Knowledge.owned.has(id) else "face")
		cv.price_tag = _price_text(id)
		cv.selected = id == sel
		cv.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		cv.gui_input.connect(func(e: InputEvent):
			if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
				_select(id, true))
		grid.add_child(cv)
		cv.modulate.a = 0.0
		var tw := cv.create_tween()
		tw.tween_interval(n * 0.025)
		tw.tween_property(cv, "modulate:a", 1.0, 0.12)
		n += 1


func _select(id: String, talk := false) -> void:
	sel = id
	for cv in $GridPanel/Scroll/Grid.get_children():
		cv.selected = cv.id == id
	var c: Dictionary = Knowledge.CARDS[id]
	for old in $Details/CardSpot.get_children():
		old.queue_free()
	$Details/CardSpot.add_child(CardView.make(id))
	$Details/CardName.text = c["name"]
	$Details/CardMeta.text = "%s\n%s" % [Knowledge.KIND_NAME[c["kind"]], Knowledge.CAT_NAME[c["cat"]]]
	var who := "Todos"
	if c.has("who"):
		var names: Array = []
		for h in Knowledge.HEROES:
			if c["who"].has(h["key"]):
				names.append(h["name"])
		who = ", ".join(names)
	$Details/CardWho.text = "Quem usa: " + who
	$Details/CardDesc.text = c["desc"]
	var owned := Knowledge.owned.has(id)
	$Details/PriceTag/Price.text = "VENDIDA" if owned else (("%d ticket" % int(c["ticket"])) if c.has("ticket") else str(int(c["price"])))
	$Details/PriceTag/Price.color = Ink.CREAM if owned else (Ink.TICKET if c.has("ticket") else Ink.COIN)
	$Details/PriceTag/PriceIcon.visible = not owned
	$Details/PriceTag/PriceIcon.queue_redraw()
	$BtnBuy.disabled = owned
	$BtnBuy.queue_redraw()
	if talk:
		if owned:
			_say("owned")
		elif c.has("ticket") and Knowledge.tickets < int(c["ticket"]):
			_say("ticket", "wow")
		else:
			_say(c["cat"], "wow" if c["kind"] == "purple" else "idle")


func _draw_price_icon() -> void:
	if sel == "":
		return
	if Knowledge.CARDS[sel].has("ticket"):
		Ink.draw_ticket($Details/PriceTag/PriceIcon, 32)
	else:
		Ink.draw_coin($Details/PriceTag/PriceIcon, 32)


func _press_buy() -> void:
	if sel == "" or Knowledge.owned.has(sel):
		return
	if not Knowledge.can_buy(sel):
		# sem recurso: o botão balança e a vendedora reclama. Nada de diálogo.
		_say("ticket" if Knowledge.CARDS[sel].has("ticket") else "poor", "sad")
		var b: Control = $BtnBuy
		var home := b.position.x
		var tw := b.create_tween()
		for d in [10.0, -10.0, 6.0, -6.0, 0.0]:
			tw.tween_property(b, "position:x", home + d, 0.04)
		return
	_open_dialog()


## Confirmação antes de gastar: painel por cima de um véu escuro.
func _open_dialog() -> void:
	_close_dialog()
	var c: Dictionary = Knowledge.CARDS[sel]
	_dialog = ColorRect.new()
	_dialog.color = Color(0.02, 0.02, 0.06, 0.78)
	_dialog.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_dialog)
	var p := Ink.panel(Ink.NAVY, 31)
	p.size = Vector2(560, 320)
	p.position = Vector2(360, 190)
	_dialog.add_child(p)
	var head := Ink.panel(Ink.GRAPE, 12)
	head.size = Vector2(360, 56)
	head.position = Vector2(-18, -26)
	head.rotation_degrees = -2
	p.add_child(head)
	var ht := Ink.title("CONFIRMAR COMPRA", 26)
	ht.position = Vector2(22, 9)
	head.add_child(ht)
	var cv := CardView.make(sel)
	cv.position = Vector2(34, 56)
	p.add_child(cv)
	var nm := Ink.title(c["name"], 26)
	nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nm.position = Vector2(166, 60)
	nm.size = Vector2(370, 70)
	p.add_child(nm)
	var ticket: bool = c.has("ticket")
	var price := Ink.title(("%d ticket" % int(c["ticket"])) if ticket else ("%d moedas" % int(c["price"])), 30, Ink.TICKET if ticket else Ink.COIN)
	price.position = Vector2(166, 150)
	p.add_child(price)
	var no := Ink.button("CANCELAR", Ink.CREAM, Ink.OUT, 24, 7)
	no.position = Vector2(34, 232)
	no.size = Vector2(220, 66)
	no.pressed.connect(_close_dialog)
	p.add_child(no)
	var yes := Ink.button("CONFIRMAR", Ink.COIN, Ink.OUT, 26, 5)
	yes.position = Vector2(290, 226)
	yes.size = Vector2(240, 76)
	yes.pressed.connect(confirm_buy)
	p.add_child(yes)
	p.pivot_offset = p.size * 0.5
	p.scale = Vector2.ONE * 0.8
	p.create_tween().tween_property(p, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _close_dialog() -> void:
	if _dialog != null:
		_dialog.queue_free()
		_dialog = null


## A compra de verdade. Devolve true se passou.
func confirm_buy() -> bool:
	_close_dialog()
	var id := sel
	if not Knowledge.buy(id):
		return false
	_refresh_wallet()
	_build_grid()
	_select(id)
	_say("bought", "happy")
	# a carta comprada pula do painel e some na direção do saldo
	var fly := CardView.make(id)
	fly.position = $Details.position + $Details/CardSpot.position
	add_child(fly)
	var tw: Tween = fly.create_tween().set_parallel(true)
	tw.tween_property(fly, "position", Vector2(40, 560), 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_property(fly, "scale", Vector2.ONE * 0.3, 0.45)
	tw.tween_property(fly, "rotation_degrees", -25.0, 0.45)
	tw.chain().tween_callback(fly.queue_free)
	return true


func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree() or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	match event.physical_keycode:
		KEY_ESCAPE:
			if _dialog != null:
				_close_dialog()
			else:
				back_pressed.emit()
		KEY_TAB:
			if _dialog == null:
				swap_shop()
		KEY_ENTER, KEY_KP_ENTER:
			if _dialog != null:
				confirm_buy()
			else:
				_press_buy()
