class_name ShopScreen
extends Control
## A loja: um lugar só, com dois balcões. O da Shopkeeper vende cartas (por moedas; as roxas por
## ticket, que vem do ranking SSS) e o da vendedora de itens vende equipamentos e consumíveis.
## O botão BtnSwap (ou TAB) troca de um pro outro. Toda compra passa por Knowledge.buy.
## Visual: kit de papel (Paper). Cada balcão tem cor, expositor e vendedora próprios: as cartas
## ficam penduradas num varal, os itens em pé nas prateleiras da oficina. O que já foi comprado
## continua exposto, com o carimbo de VENDIDA. A tela inteira é montada aqui, em _ready.
##   setas escolhem · ENTER compra · TAB troca de balcão · ESC volta

signal back_pressed

const ShopItem := preload("res://ui/kit/shop_item.gd")
const ShopShelf := preload("res://ui/kit/shop_shelf.gd")
const ShopBackdrop := preload("res://ui/kit/shop_backdrop.gd")

const LINES := {
	"hello": ["Oi... pode olhar. Só não amassa as cartas.", "Zzz... ah, cliente. Fica à vontade.", "Carta boa, preço justo. Mais ou menos justo.", "Bem-vindo... eu acho. Tá tudo no varal."],
	"attack": ["Essa aí bate. Bate bastante.", "Pra quem gosta de ver número grande."],
	"defense": ["Apanhar menos também é estratégia.", "Segura a onda, essa."],
	"utility": ["Não parece muito, mas faz falta.", "As discretas são as que salvam."],
	"special": ["Opa. Essa eu guardo no fundo da gaveta.", "Carta de gente que joga sério."],
	"ticket": ["Roxa é só com ticket. Tira SSS numa boss e volta aqui.", "Moeda não compra essa. Ticket roxo, do ranking SSS."],
	"poor": ["Tá faltando moeda aí, hein.", "Volta quando juntar mais um pouco.", "Fiado não. Dá preguiça de anotar."],
	"owned": ["Essa você já levou.", "Vendi pra você mesmo, lembra?"],
	"bought": ["Boa escolha! Vai lá equipar.", "Vendido! Usa com carinho.", "Isso, leva. Depois me conta se funcionou.", "Vendido. Agora posso cochilar em paz."],
	"hover": ["Hm? Essa?", "Olhar é de graça.", "Pode pegar. Com cuidado.", "Tá de olho nessa, né."],
	"idle": ["Zzz...", "...ainda tá aí?", "Sem pressa. Eu também não tenho.", "Se eu dormir, me acorda com moedas."],
	"cancel": ["Mudou de ideia? Tudo bem, eu nem tinha levantado.", "Ok. Ela fica aí pendurada te esperando."],
	"empty": ["Dessa não tem hoje.", "Varal vazio. Menos coisa pra eu arrumar."],
	"soldout": ["Você levou tudo. Posso fechar mais cedo?", "Não sobrou nada. Que dia produtivo... pra você."],
}

## Falas do balcão de itens (mode "gear"): a vendedora de equipamentos e consumíveis.
const LINES_GEAR := {
	"hello": ["Equipamento não ensina nada. Só deixa o que você já sabe mais forte.", "Tudo aqui é pra vestir, calçar ou beber.", "Oficina aberta. Olhe à vontade, mexa com cuidado."],
	"attack": ["Esse faz o número subir.", "Bate igual, dói mais."],
	"defense": ["Pra aguentar mais um golpe.", "Quem fica de pé ganha a luta."],
	"utility": ["Pequeno, mas você sente a diferença.", "Coisa de quem pensa em tudo."],
	"special": ["Esse é do fundo da oficina.", "Peça rara. Cuida bem."],
	"ticket": ["Esse eu só troco por ticket roxo. Tira SSS numa boss.", "Moeda não paga esse aqui."],
	"poor": ["Faltou moeda. Volta depois.", "Junta mais um pouco que eu guardo pra você.", "A conta não fecha. Refaça."],
	"owned": ["Esse já é seu.", "Você já levou um desses."],
	"bought": ["Fechado! Vai lá no GEAR equipar.", "Boa. Põe num slot e sente a diferença.", "Negócio exato. É assim que eu gosto."],
	"hover": ["Pode examinar. Não derruba.", "Esse eu calibrei ontem.", "Mão limpa, por favor.", "Bom olho."],
	"idle": ["Cada peça no seu lugar.", "Tempo é engrenagem. Não desperdice o meu.", "Estou ajustando uma mola. Pode olhar.", "Se for testar, teste lá fora."],
	"cancel": ["Decisão adiada não é decisão.", "Como quiser. A peça continua na prateleira."],
	"empty": ["Nada nessa seção. Estoque é estoque.", "Prateleira vazia. Anotado."],
	"soldout": ["Estoque zerado. Trabalho bem feito.", "Não tenho mais nada pra você. Por enquanto."],
}

## Cores de cada balcão (bg/bg2 fundo · deep/deep2 expositor · slab atrás da vendedora · acc destaque).
const THEMES := {
	"cards": {"bg": Color("4a22a8"), "bg2": Color("6a35d6"), "deep": Color("1e1650"), "deep2": Color("2a2070"),
		"slab": Color("ff5999"), "slab2": Color("ff86b5"), "acc": Color("ff5999")},
	"gear": {"bg": Color("c9561e"), "bg2": Color("ef8a3a"), "deep": Color("2b1509"), "deep2": Color("4a2612"),
		"slab": Color("ffc233"), "slab2": Color("ffd970"), "acc": Color("3ff2e0")},
}
const INFO := {
	"cards": {"title": "LOJA", "sub": "BALCÃO DE CARTAS", "swap": "LOJA DE ITENS  ›", "who": "SHOPKEEPER", "board": "NO VARAL HOJE",
		"sold": "VENDIDA", "mine": "JÁ É SUA", "note": "Carta ROXA só sai por TICKET.\nTicket vem do ranking SSS."},
	"gear": {"title": "ITENS", "sub": "OFICINA DE ITENS", "swap": "LOJA DE CARTAS  ›", "who": "VENDEDORA DE ITENS", "board": "NA PRATELEIRA",
		"sold": "VENDIDO", "mine": "JÁ É SEU", "note": "Comprou? Equipa na tela GEAR.\nRoxo só sai por TICKET."},
}
const NIGHT := Color("160c33")
const DANGER := Color("ff5559")
const TICKET := Color("c9a2ff")
const BROWN_T := Color("5c3a29")
const PER_PAGE := 8
const BOARD_POS := Vector2(398, 168)
const BOARD_SIZE := Vector2(504, 470)
const DETAILS_POS := Vector2(916, 100)
const TABS_POS := Vector2(402, 104)

## "cards": a loja de cartas da Shopkeeper. "gear": o balcão de itens (equipamentos e consumíveis).
var mode := "cards"
var cat := ""
var sel := ""
var _dialog: Control
var _bg: Control
var _board: Control
var _tabs: Control
var _details: Control
var _sub: Chip
var _board_tag: Chip
var _pocket: Chip
var _pager: Control
var _page_label: Label
var _note: Control
var _note_text: Label
var _empty: Control
var _who_box: Control
var _chips: Control
var _hint: Chip
var _ids: Array = []
var _items := {}
var _page := 0
var _cols := 1
var _coins_shown := 0.0
var _quiet_until := 0
var _idle_t := 0.0
var _swap_tw: Tween
var _faces := {}


func _ready() -> void:
	if _bg == null:
		_build()
	if get_tree().current_scene == self:
		Knowledge.persist = false
		Knowledge.money = 500
		Knowledge.tickets = 1
		open()


# ---------------------------------------------------------------- montagem

func _build() -> void:
	_bg = ShopBackdrop.new()
	_bg.name = "Bg"
	_bg.themes = THEMES
	add_child(_bg)

	var vendor := Vendor.new()
	vendor.name = "Vendor"
	vendor.position = Vector2(14, 205)
	vendor.size = Vector2(380, 520)
	vendor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vendor)

	# balão de fala, com o rabicho apontando pra ela
	var bubble := CutPanel.make(Rect2(28, 108, 356, 102), [[0, .02], [1, 0], [.985, .80], [.60, .82], [.52, 1], [.47, .83], [.015, .85]], Paper.CREAM, 4.0, Vector2(6, 6))
	bubble.name = "Bubble"
	add_child(bubble)
	var bt := Paper.label("...", 16, Paper.INK, Paper.body(700))
	bt.name = "BubbleText"
	bt.position = Vector2(16, 6)
	bt.size = Vector2(326, 72)
	bt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bt.add_theme_constant_override("line_spacing", -4)
	bubble.add_child(bt)
	var speaker := Chip.new()
	speaker.name = "Speaker"
	speaker.px = 11
	speaker.pad = 10.0
	speaker.fill = Paper.INK
	speaker.ink = Paper.CREAM
	speaker.border = 0.0
	speaker.shadow = Vector2.ZERO
	bubble.add_child(speaker)

	var tp := CutPanel.make(Rect2(30, 12, 236, 84), [[0, 0], [1, .08], [.95, 1], [.03, .9]], Paper.CREAM, 5.0, Vector2(7, 7))
	tp.name = "TitlePanel"
	tp.rotation = -0.03
	tp.pivot_offset = tp.size * 0.5
	add_child(tp)
	var title := Paper.label("LOJA", 52, Paper.INK, Paper.display())
	title.name = "Title"
	title.size = tp.size
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tp.add_child(title)
	_sub = Chip.new()
	_sub.px = 15
	_sub.position = Vector2(290, 54)
	_sub.rotation_degrees = -3.0
	add_child(_sub)

	_tabs = Control.new()
	_tabs.name = "Tabs"
	_tabs.position = TABS_POS
	_tabs.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_tabs)

	_board = ShopShelf.new()
	_board.name = "Board"
	_board.position = BOARD_POS
	_board.size = BOARD_SIZE
	add_child(_board)
	_board_tag = Chip.new()
	_board_tag.px = 13
	_board_tag.position = Vector2(18, -13)
	_board_tag.z_index = 2
	_board.add_child(_board_tag)
	# bilhete pregado no expositor (só quando sobra espaço: uma fileira)
	_note = CutPanel.make(Rect2(112, 398, 280, 56), [[0, .06], [1, 0], [.985, .94], [.02, 1]], Paper.CREAM, 3.0, Vector2(5, 5))
	_note.rotation_degrees = 1.5
	_board.add_child(_note)
	_note_text = Paper.label("", 14, Paper.INK, Paper.body(700))
	_note_text.size = Vector2(280, 56)
	_note_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_note_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_note_text.add_theme_constant_override("line_spacing", -5)
	_note.add_child(_note_text)
	var tack := Control.new()
	tack.position = Vector2(140, 2)
	tack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tack.draw.connect(func():
		tack.draw_circle(Vector2(1, 2), 8.0, Paper.INK)
		tack.draw_circle(Vector2.ZERO, 8.0, Paper.INK)
		tack.draw_circle(Vector2.ZERO, 5.0, Paper.RED.lightened(0.25)))
	_note.add_child(tack)
	_empty = CutPanel.make(Rect2(92, 180, 320, 90), [[0, .05], [1, 0], [.98, 1], [.015, .93]], Paper.CREAM, 4.0, Vector2(6, 6))
	_empty.rotation_degrees = -2.0
	_board.add_child(_empty)
	var et := Paper.label("NADA NESSA\nCATEGORIA HOJE", 22, Paper.INK, Paper.display())
	et.size = Vector2(320, 90)
	et.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	et.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	et.add_theme_constant_override("line_spacing", -6)
	_empty.add_child(et)

	# rodapé do expositor: o bolso da coleção (pra onde a compra voa) e as páginas
	_pocket = Chip.new()
	_pocket.px = 14
	_pocket.position = Vector2(412, 658)
	add_child(_pocket)
	_pager = Control.new()
	_pager.position = Vector2(690, 652)
	_pager.size = Vector2(170, 44)
	_pager.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_pager)
	for d in [-1, 1]:
		var step: int = d
		var arrow := _button("", Paper.CREAM, 16)
		arrow.chevron = step
		arrow.skew = 8.0
		arrow.position = Vector2(0 if step < 0 else 126, 2)
		arrow.size = Vector2(44, 40)
		arrow.pressed.connect(func(): _turn_page(step))
		_pager.add_child(arrow)
	var plate := CutPanel.make(Rect2(52, 5, 66, 34), [[.06, 0], [1, 0], [.94, 1], [0, 1]], Paper.INK, 0.0, Vector2.ZERO)
	_pager.add_child(plate)
	_page_label = Paper.label("1/1", 17, Paper.CREAM, Paper.display(0.0))
	_page_label.size = Vector2(66, 34)
	_page_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_page_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	plate.add_child(_page_label)

	_build_details()

	var buy := _button("COMPRAR", Paper.GOLD, 34)
	buy.name = "BtnBuy"
	buy.position = Vector2(922, 584)
	buy.size = Vector2(326, 78)
	buy.border = 5.0
	buy.shadow = Vector2(7, 8)
	buy.pressed.connect(_press_buy)
	add_child(buy)
	_hint = Chip.new()
	_hint.px = 10
	_hint.pad = 10.0
	_hint.fill = Paper.INK
	_hint.ink = Paper.CREAM
	_hint.border = 0.0
	_hint.shadow = Vector2.ZERO
	_hint.skew = 8.0
	_hint.text = "SETAS ESCOLHEM  ·  ENTER COMPRA  ·  TAB TROCA DE BALCÃO"
	_hint.position = Vector2(1248 - _hint.size.x, 684)
	add_child(_hint)

	# carteira
	var wallet := CutPanel.make(Rect2(922, 18, 330, 66), [[.02, 0], [1, .06], [.985, 1], [0, .92]], NIGHT, 5.0, Vector2(7, 7))
	wallet.name = "Wallet"
	wallet.pivot_offset = wallet.size * 0.5
	add_child(wallet)
	var ci := Control.new()
	ci.name = "CoinIcon"
	ci.position = Vector2(40, 33)
	ci.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ci.draw.connect(func(): ShopItem.draw_coin(ci, Vector2.ZERO, 17.0))
	wallet.add_child(ci)
	var coins := Paper.label("0", 30, Paper.GOLD, Paper.display(0.0))
	coins.name = "Coins"
	coins.position = Vector2(66, 8)
	coins.size = Vector2(110, 50)
	coins.pivot_offset = Vector2(20, 25)
	coins.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	wallet.add_child(coins)
	var ti := Control.new()
	ti.name = "TicketIcon"
	ti.position = Vector2(212, 33)
	ti.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ti.draw.connect(func(): ShopItem.draw_ticket(ti, Vector2.ZERO, 16.0))
	wallet.add_child(ti)
	var tickets := Paper.label("0", 30, TICKET, Paper.display(0.0))
	tickets.name = "Tickets"
	tickets.position = Vector2(240, 8)
	tickets.size = Vector2(80, 50)
	tickets.pivot_offset = Vector2(16, 25)
	tickets.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	wallet.add_child(tickets)

	# troca de balcão: da loja de cartas pra de itens e de volta, sem sair da loja
	var swap := _button("", Paper.GOLD, 19)
	swap.name = "BtnSwap"
	swap.position = Vector2(640, 24)
	swap.size = Vector2(262, 56)
	swap.pressed.connect(swap_shop)
	add_child(swap)
	var key := Chip.new()
	key.px = 10
	key.pad = 8.0
	key.fill = Paper.INK
	key.ink = Paper.CREAM
	key.border = 0.0
	key.shadow = Vector2.ZERO
	key.text = "TAB"
	key.position = Vector2(866, 12)
	add_child(key)

	var back := _button("VOLTAR", Paper.CREAM, 22)
	back.name = "BtnBack"
	back.position = Vector2(42, 650)
	back.size = Vector2(176, 50)
	back.pressed.connect(func(): back_pressed.emit())
	add_child(back)


func _build_details() -> void:
	_details = CutPanel.make(Rect2(DETAILS_POS, Vector2(336, 462)), [[0, .012], [1, 0], [.985, .985], [.02, 1]], Paper.CREAM, 5.0, Vector2(9, 9))
	_details.name = "Details"
	_details.pivot_offset = Vector2(168, 231)
	add_child(_details)
	var nm := Paper.label("", 22, Paper.INK, Paper.display())
	nm.name = "CardName"
	nm.position = Vector2(20, 12)
	nm.size = Vector2(300, 62)
	nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nm.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	nm.add_theme_constant_override("line_spacing", -6)
	_details.add_child(nm)
	var spot := Control.new()
	spot.name = "CardSpot"
	spot.position = Vector2(22, 84)
	spot.size = Vector2(140, 198)
	spot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_details.add_child(spot)
	_chips = Control.new()
	_chips.position = Vector2(184, 90)
	_chips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_details.add_child(_chips)
	var wl := Paper.label("QUEM USA", 13, BROWN_T, Paper.body(800))
	wl.position = Vector2(180, 164)
	wl.size = Vector2(140, 18)
	_details.add_child(wl)
	_who_box = Control.new()
	_who_box.position = Vector2(180, 186)
	_who_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_details.add_child(_who_box)
	var who := Paper.label("", 14, Paper.INK, Paper.body(800))
	who.name = "CardWho"
	who.position = Vector2(180, 240)
	who.size = Vector2(146, 44)
	who.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	who.add_theme_constant_override("line_spacing", -5)
	_details.add_child(who)
	var desc := Paper.label("", 15, Paper.INK, Paper.body(700))
	desc.name = "CardDesc"
	desc.position = Vector2(20, 290)
	desc.size = Vector2(300, 100)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	desc.add_theme_constant_override("line_spacing", -4)
	_details.add_child(desc)
	# etiqueta de preço grande, saindo pela borda do painel
	var tag := CutPanel.make(Rect2(-4, 392, 346, 62), [[.03, 0], [1, .04], [.97, 1], [0, .94]], Paper.INK, 0.0, Vector2(6, 7))
	tag.name = "PriceTag"
	tag.outline = Paper.INK
	tag.rotation_degrees = -1.5
	tag.pivot_offset = Vector2(178, 31)
	_details.add_child(tag)
	var icon := Control.new()
	icon.name = "PriceIcon"
	icon.position = Vector2(44, 31)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.draw.connect(_draw_price_icon)
	tag.add_child(icon)
	var price := Paper.label("", 34, Paper.GOLD, Paper.display(0.0))
	price.name = "Price"
	price.position = Vector2(72, 4)
	price.size = Vector2(170, 54)
	price.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tag.add_child(price)
	var left := Paper.label("", 13, Paper.CREAM, Paper.body(800))
	left.name = "PriceNote"
	left.position = Vector2(196, 6)
	left.size = Vector2(142, 50)
	left.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	left.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	left.add_theme_constant_override("line_spacing", -5)
	tag.add_child(left)


func _button(text: String, fill: Color, px: int) -> ShineButton:
	var b := ShineButton.new()
	b.text = text
	b.fill = fill
	b.fg = Paper.INK
	b.font_px = px
	b.skew = 10.0
	b.border = 3.0 if px < 20 else 4.0
	b.shadow = Vector2(3, 4) if px < 20 else Vector2(5, 6)
	b.auto_hover = true
	b.hover_scale = 1.04
	return b


# ---------------------------------------------------------------- abrir e trocar de balcão

func open(shop_mode := "cards") -> void:
	_enter(shop_mode, false)


## Vai pro outro balcão (cartas <-> itens). Dá pra ficar trocando à vontade.
func swap_shop() -> void:
	_enter("cards" if mode == "gear" else "gear", true)


func _enter(shop_mode: String, walk: bool) -> void:
	if _bg == null:
		_build()  # open() chamado antes de entrar na árvore
	mode = shop_mode
	cat = ""
	sel = ""
	_page = 0
	var th: Dictionary = THEMES[mode]
	var info: Dictionary = INFO[mode]
	_bg.show_theme(mode, walk)
	$TitlePanel/Title.text = info["title"]
	$TitlePanel.fill = th["acc"]
	_sub.text = info["sub"]
	# o mesmo lugar, outro balcão e outra vendedora
	$Vendor.who = mode
	$BtnSwap.text = info["swap"]
	$BtnBuy.fill = th["acc"]
	$Bubble/Speaker.text = info["who"]
	$Bubble/Speaker.position = Vector2(350 - $Bubble/Speaker.size.x, -12)
	_board.style = mode
	_board.deep = th["deep"]
	_board.deep2 = th["deep2"]
	_board_tag.fill = th["acc"]
	_board_tag.text = info["board"]
	_note_text.text = info["note"]
	_close_dialog()
	_build_tabs()
	_build_grid()
	_refresh_wallet()
	_refresh_pocket()
	if not _ids.is_empty():
		_select(_ids[0])
	_say("soldout" if _all_sold() else "hello")
	if walk:
		_walk_in(1.0 if mode == "gear" else -1.0)


## A troca de balcão: expositor e painel entram deslizando do lado pra onde o jogador "andou".
func _walk_in(dir: float) -> void:
	if _swap_tw != null:
		_swap_tw.kill()
	_swap_tw = create_tween().set_parallel(true)
	var parts := [[_board, BOARD_POS, 0.0], [_tabs, TABS_POS, 0.03], [_details, DETAILS_POS, 0.06]]
	for p in parts:
		var node: Control = p[0]
		var home: Vector2 = p[1]
		var wait: float = p[2]
		node.position = home + Vector2(90.0 * dir, 0)
		node.modulate.a = 0.0
		_swap_tw.tween_property(node, "position", home, 0.26).set_delay(wait).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_swap_tw.tween_property(node, "modulate:a", 1.0, 0.16).set_delay(wait)
	var tp: Control = $TitlePanel
	tp.scale = Vector2(0.0, 1.0)
	_swap_tw.tween_property(tp, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_sub.modulate.a = 0.0
	_swap_tw.tween_property(_sub, "modulate:a", 1.0, 0.2).set_delay(0.1)


func _all_sold() -> bool:
	var all := Knowledge.shop_list("", mode)
	for id in all:
		if not Knowledge.owned.has(id):
			return false
	return not all.is_empty()


# ---------------------------------------------------------------- vendedora

func _say(key: String, mood := "idle") -> void:
	var opts: Array = (LINES_GEAR if mode == "gear" else LINES)[key]
	var line: String = opts[randi() % opts.size()]
	var label: Label = $Bubble/BubbleText
	if opts.size() > 1 and line == label.text:
		line = opts[(opts.find(line) + 1) % opts.size()]
	label.text = line
	$Vendor.mood = mood
	_quiet_until = Time.get_ticks_msec() + 2200
	_idle_t = 0.0
	# o balão estala a partir do rabicho e o texto vem escrevendo
	var b: Control = $Bubble
	b.pivot_offset = Vector2(b.size.x * 0.52, b.size.y)
	b.scale = Vector2.ONE * 0.88
	label.visible_ratio = 0.0
	var tw := b.create_tween().set_parallel(true)
	tw.tween_property(b, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(label, "visible_ratio", 1.0, clampf(line.length() * 0.012, 0.15, 0.5))


## O mouse passou por cima de uma peça: ela repara, mas sem atropelar a fala anterior.
func _hover_item(id: String) -> void:
	if _dialog != null or id == sel or Time.get_ticks_msec() < _quiet_until:
		return
	_say("owned" if Knowledge.owned.has(id) else "hover", "nod")


func _process(delta: float) -> void:
	if not is_visible_in_tree() or _dialog != null:
		return
	# parada há um tempo, ela puxa assunto
	_idle_t += delta
	if _idle_t > 9.0:
		_say("soldout" if _all_sold() else "idle")


# ---------------------------------------------------------------- carteira e coleção

func _refresh_wallet() -> void:
	_coins_shown = Knowledge.money
	$Wallet/Coins.text = str(Knowledge.money)
	$Wallet/Tickets.text = str(Knowledge.tickets)


func _set_coins_shown(v: float) -> void:
	_coins_shown = v
	$Wallet/Coins.text = str(roundi(v))


## As moedas descem contando e o número que mudou dá um pulo.
func _spend(from_money: int, from_tickets: int) -> void:
	var bumped: Array = []
	if Knowledge.money != from_money:
		var tw := create_tween()
		tw.tween_method(_set_coins_shown, float(from_money), float(Knowledge.money), 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		bumped.append($Wallet/Coins)
	if Knowledge.tickets != from_tickets:
		$Wallet/Tickets.text = str(Knowledge.tickets)
		bumped.append($Wallet/Tickets)
	for n in bumped:
		var label: Control = n
		label.scale = Vector2.ONE * 1.4
		label.create_tween().tween_property(label, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Sem saldo: a carteira treme e um selo vermelho aparece embaixo dela.
func _no_funds(ticket: bool) -> void:
	var w: Control = $Wallet
	var home := Vector2(922, 18)
	var tw := w.create_tween()
	for d in [9.0, -9.0, 6.0, -6.0, 3.0, 0.0]:
		tw.tween_property(w, "position:x", home.x + d, 0.04)
	var label: Control = $Wallet/Tickets if ticket else $Wallet/Coins
	label.modulate = DANGER
	label.create_tween().tween_property(label, "modulate", Color.WHITE, 0.6)
	if has_node("NoFunds"):
		var old := get_node("NoFunds")
		remove_child(old)
		old.queue_free()
	var chip := Chip.new()
	chip.name = "NoFunds"
	chip.px = 17
	chip.fill = DANGER
	chip.ink = Paper.CREAM
	chip.text = "SEM TICKET" if ticket else "SEM SALDO"
	chip.position = Vector2(1236 - chip.size.x, 74)
	chip.pivot_offset = chip.size * 0.5
	chip.rotation_degrees = -4.0
	chip.scale = Vector2.ONE * 1.6
	chip.z_index = 5
	add_child(chip)
	var ct := chip.create_tween()
	ct.tween_property(chip, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	ct.tween_interval(1.1)
	ct.tween_property(chip, "modulate:a", 0.0, 0.2)
	ct.tween_callback(chip.queue_free)


func _refresh_pocket() -> void:
	var all := Knowledge.shop_list("", mode)
	var have := 0
	for id in all:
		if Knowledge.owned.has(id):
			have += 1
	_pocket.text = "SUA COLEÇÃO  %d/%d" % [have, all.size()]
	_pocket.pivot_offset = _pocket.size * 0.5


# ---------------------------------------------------------------- abas e expositor

func _build_tabs() -> void:
	for c in _tabs.get_children():
		_tabs.remove_child(c)
		c.queue_free()
	var entries := [["", "Tudo"]]
	for k in Knowledge.CATS:
		entries.append([k, Knowledge.CAT_NAME[k]])
	var x := 0.0
	for n in entries.size():
		var key: String = entries[n][0]
		var text: String = String(entries[n][1]).to_upper()
		var on := key == cat
		var b := _button(text, Paper.GOLD if on else Paper.CREAM, 14)
		b.size = Vector2(Paper.display().get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x + 30.0, 40)
		b.position = Vector2(x, -4.0 if on else 0.0)
		b.pressed.connect(_set_cat.bind(key))
		_tabs.add_child(b)
		x += b.size.x + 8.0


func _set_cat(key: String) -> void:
	cat = key
	_page = 0
	_build_tabs()
	_build_grid()
	if _ids.is_empty():
		_say("empty")
	elif not _ids.has(sel):
		_select(_ids[0])


func _price_text(id: String) -> String:
	var c: Dictionary = Knowledge.CARDS[id]
	if Knowledge.owned.has(id):
		return INFO[mode]["sold"]
	# o ícone da etiqueta já diz se é moeda ou ticket
	return str(int(c["ticket"] if c.has("ticket") else c["price"]))


func _tilt(id: String) -> float:
	var t := float(hash(id) % 7) - 3.0
	return 1.5 if t == 0.0 else t


## Monta a página atual do expositor. Poucas peças ficam grandes numa fileira só; com mais
## estoque viram duas fileiras, e o que passar de PER_PAGE vai pra outra página.
func _build_grid(animate := true) -> void:
	for it in _items.values():
		_board.remove_child(it)
		it.queue_free()
	_items = {}
	_ids = Knowledge.shop_list(cat, mode)
	var pages := maxi(1, ceili(_ids.size() / float(PER_PAGE)))
	_page = clampi(_page, 0, pages - 1)
	var shown: Array = _ids.slice(_page * PER_PAGE, (_page + 1) * PER_PAGE)
	var n := shown.size()
	var rows := 1 if n <= 3 else 2
	_cols = maxi(1, n if rows == 1 else ceili(n / 2.0))
	var hang := mode == "cards"
	var lines: Array = [70.0] if rows == 1 else [40.0, 250.0]
	if not hang:
		lines = [336.0] if rows == 1 else [200.0, 412.0]
	_board.rows = lines if n > 0 else []
	var cell := (BOARD_SIZE.x - 60.0) / _cols
	var k := minf(1.55 if rows == 1 else 1.0, (cell - 18.0) / CardView.W)
	for i in n:
		var id: String = shown[i]
		var row := 0 if i < _cols else 1
		var in_row := _cols if row == 0 else n - _cols
		var col := i if row == 0 else i - _cols
		# a fileira de baixo, se tiver menos peças, fica centralizada
		var cx := 30.0 + cell * (col + 0.5) + (_cols - in_row) * cell * 0.5
		var it := ShopItem.new()
		it.setup(id, mode, k, _tilt(id))
		var c: Dictionary = Knowledge.CARDS[id]
		it.ticket = c.has("ticket")
		it.sold_text = INFO[mode]["sold"]
		var top: float = _board.string_y(row, cx) + 14.0 if hang else float(lines[row]) - it.size.y + 2.0
		it.home = Vector2(cx - it.size.x * 0.5, top)
		it.position = it.home
		it.picked.connect(_select.bind(id, true))
		it.hovered.connect(_hover_item.bind(id))
		_board.add_child(it)
		_items[id] = it
		if animate:
			# entra balançando, uma depois da outra
			it.modulate.a = 0.0
			it._rot = it.tilt + (16.0 if hang else 0.0) * (1.0 if i % 2 == 0 else -1.0)
			if not hang:
				it.position.y -= 26.0
			var tw := it.create_tween()
			tw.tween_interval(i * 0.04)
			tw.tween_property(it, "modulate:a", 1.0, 0.1)
			tw.tween_callback(it.settle)
	_refresh_items()
	for id in _items:
		_items[id].selected = id == sel
	_note.visible = rows == 1 and n > 0
	_empty.visible = n == 0
	_pager.visible = pages > 1
	_page_label.text = "%d/%d" % [_page + 1, pages]


## Atualiza preço, saldo e carimbo de cada peça exposta, sem remontar o expositor.
func _refresh_items() -> void:
	for id in _items:
		var it = _items[id]
		var owned: bool = Knowledge.owned.has(id)
		it.price_text = _price_text(id)
		it.afford = owned or Knowledge.can_buy(id)
		it.sold = owned


func _turn_page(step: int) -> void:
	var pages := maxi(1, ceili(_ids.size() / float(PER_PAGE)))
	var to := clampi(_page + step, 0, pages - 1)
	if to == _page:
		return
	_page = to
	_build_grid()
	_select(_ids[_page * PER_PAGE], true)


# ---------------------------------------------------------------- escolher e ver detalhes

func _select(id: String, talk := false) -> void:
	sel = id
	var at := _ids.find(id)
	if at >= 0 and floori(at / float(PER_PAGE)) != _page:
		_page = floori(at / float(PER_PAGE))
		_build_grid()
	for k in _items:
		_items[k].selected = k == id
	var c: Dictionary = Knowledge.CARDS[id]
	for old in $Details/CardSpot.get_children():
		$Details/CardSpot.remove_child(old)
		old.queue_free()
	var cv := CardView.make(id)
	cv.position = Vector2(16, 23)
	cv.scale = Vector2.ONE * 1.3
	cv.rotation_degrees = -4.0
	$Details/CardSpot.add_child(cv)
	if talk:
		cv.scale = Vector2.ONE * 1.1
		cv.create_tween().tween_property(cv, "scale", Vector2.ONE * 1.3, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	$Details/CardName.text = c["name"]
	# raridade e categoria como etiquetas
	for old in _chips.get_children():
		_chips.remove_child(old)
		old.queue_free()
	var kind: Dictionary = Paper.KIND.get(c["kind"], Paper.KIND["white"])
	var rarity := Chip.new()
	rarity.px = 15
	rarity.fill = kind["chip"]
	rarity.ink = kind["chip_t"]
	rarity.text = String(Knowledge.KIND_NAME[c["kind"]]).to_upper()
	_chips.add_child(rarity)
	var group := Chip.new()
	group.px = 12
	group.fill = Paper.CREAM2
	group.text = String(Knowledge.CAT_NAME[c["cat"]]).to_upper()
	group.position = Vector2(-2, 38)
	_chips.add_child(group)
	_fill_who(c)
	$Details/CardDesc.text = c["desc"]
	var owned := Knowledge.owned.has(id)
	var ticket: bool = c.has("ticket")
	var price := 0 if owned else int(c["ticket"] if ticket else c["price"])
	var have := Knowledge.tickets if ticket else Knowledge.money
	var price_label: Label = $Details/PriceTag/Price
	price_label.text = INFO[mode]["sold"] if owned else str(price)
	price_label.add_theme_color_override("font_color", Paper.CREAM if owned else (TICKET if ticket else Paper.GOLD))
	price_label.position.x = 30.0 if owned else 72.0
	var note: Label = $Details/PriceTag/PriceNote
	var unit := ("ticket" if price == 1 else "tickets") if ticket else "moedas"
	if owned:
		note.text = "na sua coleção"
	elif have >= price:
		note.text = "%s\nsobra %d" % [unit, have - price]
	else:
		note.text = "%s\nfalta %d" % [unit, price - have]
	note.add_theme_color_override("font_color", Paper.CREAM if (owned or have >= price) else DANGER)
	$Details/PriceTag/PriceIcon.visible = not owned
	$Details/PriceTag/PriceIcon.queue_redraw()
	var buy: ShineButton = $BtnBuy
	buy.disabled = owned
	buy.text = INFO[mode]["mine"] if owned else "COMPRAR"
	# só chama atenção quando dá pra comprar
	buy.idle = not owned and Knowledge.can_buy(id)
	if not buy.idle:
		buy.rotation = 0.0
		buy.scale = Vector2.ONE
	buy.queue_redraw()
	if talk:
		if owned:
			_say("owned")
		elif ticket and Knowledge.tickets < int(c["ticket"]):
			_say("ticket", "wow")
		else:
			_say(c["cat"], "wow" if c["kind"] == "purple" else "nod")


## Quem usa: o rosto de cada herói (ou um selo de TODOS) e os nomes por extenso.
func _fill_who(c: Dictionary) -> void:
	for old in _who_box.get_children():
		_who_box.remove_child(old)
		old.queue_free()
	var who := "Todos"
	if c.has("who"):
		var names: Array = []
		var x := 0.0
		for h in Knowledge.HEROES:
			if not c["who"].has(h["key"]):
				continue
			names.append(h["name"])
			var tex := _face(h["key"])
			if tex == null:
				continue
			var box := Control.new()
			box.position = Vector2(x, 0)
			box.mouse_filter = Control.MOUSE_FILTER_IGNORE
			box.draw.connect(func():
				box.draw_rect(Rect2(3, 4, 40, 48), Paper.INK)
				box.draw_rect(Rect2(0, 0, 40, 48), Paper.INK)
				box.draw_rect(Rect2(3, 3, 34, 42), Paper.CREAM2)
				box.draw_texture_rect(tex, Rect2(3, 3, 34, 42), false))
			_who_box.add_child(box)
			x += 48.0
		who = ", ".join(names)
		$Details/CardWho.position.y = 240.0 if x > 0.0 else 188.0
	else:
		var all := Chip.new()
		all.px = 14
		all.fill = Paper.GREEN
		all.text = "TODOS"
		all.position = Vector2(4, 4)
		_who_box.add_child(all)
		who = "Qualquer herói pode equipar."
		$Details/CardWho.position.y = 226.0
	$Details/CardWho.text = who


func _face(key: String) -> Texture2D:
	if not _faces.has(key):
		var p := "res://assets/portraits/%s_face.png" % key
		_faces[key] = load(p) if ResourceLoader.exists(p) else null
	return _faces[key]


func _draw_price_icon() -> void:
	if sel == "":
		return
	if Knowledge.CARDS[sel].has("ticket"):
		ShopItem.draw_ticket($Details/PriceTag/PriceIcon, Vector2.ZERO, 17.0)
	else:
		ShopItem.draw_coin($Details/PriceTag/PriceIcon, Vector2.ZERO, 19.0)


## Anda com a escolha pelo expositor (setas). Passar da ponta vira a página.
func _move_sel(step: int) -> void:
	if _ids.is_empty():
		return
	var at := _ids.find(sel)
	var to := clampi((at if at >= 0 else 0) + step, 0, _ids.size() - 1)
	if at < 0 or to != at:
		_select(_ids[to], true)


# ---------------------------------------------------------------- comprar

func _press_buy() -> void:
	if sel == "" or Knowledge.owned.has(sel):
		return
	if not Knowledge.can_buy(sel):
		# sem recurso: o botão e a carteira balançam e a vendedora reclama. Nada de diálogo.
		var ticket: bool = Knowledge.CARDS[sel].has("ticket")
		_say("ticket" if ticket else "poor", "sad")
		_no_funds(ticket)
		var b: ShineButton = $BtnBuy
		var home := 922.0
		var tw := b.create_tween()
		for d in [10.0, -10.0, 6.0, -6.0, 0.0]:
			tw.tween_property(b, "position:x", home + d, 0.04)
		return
	_open_dialog()


## Confirmação antes de gastar: painel por cima de um véu escuro.
func _open_dialog() -> void:
	_close_dialog()
	var c: Dictionary = Knowledge.CARDS[sel]
	var ticket: bool = c.has("ticket")
	var price := int(c["ticket"] if ticket else c["price"])
	var have := Knowledge.tickets if ticket else Knowledge.money
	_dialog = ColorRect.new()
	_dialog.color = Color(NIGHT.r, NIGHT.g, NIGHT.b, 0.86)
	_dialog.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dialog.z_index = 10
	add_child(_dialog)
	var p := CutPanel.make(Rect2(350, 186, 580, 340), [[.012, 0], [1, .025], [.988, 1], [0, .975]], Paper.CREAM, 6.0, Vector2(10, 10))
	_dialog.add_child(p)
	var head := Chip.new()
	head.px = 24
	head.fill = THEMES[mode]["acc"]
	head.text = "CONFIRMAR COMPRA"
	head.position = Vector2(-16, -24)
	head.rotation_degrees = -3.0
	p.add_child(head)
	var cv := CardView.make(sel)
	cv.position = Vector2(54, 74)
	cv.scale = Vector2.ONE * 1.3
	cv.rotation_degrees = -4.0
	p.add_child(cv)
	var nm := Paper.label(c["name"], 26, Paper.INK, Paper.display())
	nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nm.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	nm.add_theme_constant_override("line_spacing", -7)
	nm.position = Vector2(214, 40)
	nm.size = Vector2(340, 70)
	p.add_child(nm)
	var tag := CutPanel.make(Rect2(206, 122, 330, 60), [[.03, 0], [1, .05], [.97, 1], [0, .93]], Paper.INK, 0.0, Vector2.ZERO)
	tag.rotation_degrees = -1.5
	p.add_child(tag)
	var icon := Control.new()
	icon.position = Vector2(40, 30)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.draw.connect(func():
		if ticket:
			ShopItem.draw_ticket(icon, Vector2.ZERO, 16.0)
		else:
			ShopItem.draw_coin(icon, Vector2.ZERO, 18.0))
	tag.add_child(icon)
	var unit := ("ticket" if price == 1 else "tickets") if ticket else "moedas"
	var pl := Paper.label("%d %s" % [price, unit], 30, TICKET if ticket else Paper.GOLD, Paper.display(0.0))
	pl.position = Vector2(68, 4)
	pl.size = Vector2(256, 52)
	pl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tag.add_child(pl)
	var rest := Paper.label("Depois da compra sobra: %d %s." % [have - price, ("ticket" if have - price == 1 else "tickets") if ticket else "moedas"], 15, BROWN_T, Paper.body(800))
	rest.position = Vector2(216, 196)
	rest.size = Vector2(340, 24)
	p.add_child(rest)
	var no := _button("CANCELAR", Paper.CREAM2, 22)
	no.position = Vector2(44, 258)
	no.size = Vector2(216, 58)
	no.pressed.connect(_cancel_dialog)
	p.add_child(no)
	var yes := _button("CONFIRMAR", Paper.GOLD, 26)
	yes.position = Vector2(296, 252)
	yes.size = Vector2(250, 68)
	yes.idle = true
	yes.pressed.connect(confirm_buy)
	p.add_child(yes)
	var keys := Paper.label("ENTER confirma  ·  ESC cancela", 12, BROWN_T, Paper.body(700))
	keys.position = Vector2(216, 220)
	keys.size = Vector2(340, 20)
	p.add_child(keys)
	p.pivot_offset = p.size * 0.5
	p.scale = Vector2.ONE * 0.8
	p.create_tween().tween_property(p, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _close_dialog() -> void:
	if _dialog != null:
		_dialog.queue_free()
		_dialog = null


func _cancel_dialog() -> void:
	if _dialog == null:
		return
	_close_dialog()
	_say("cancel")


## A compra de verdade. Devolve true se passou.
func confirm_buy() -> bool:
	_close_dialog()
	var id := sel
	var money := Knowledge.money
	var tickets := Knowledge.tickets
	if not Knowledge.buy(id):
		return false
	_spend(money, tickets)
	_refresh_items()
	_select(id)
	_say("bought", "happy")
	# o carimbo bate na peça exposta e uma cópia dela voa pro bolso da coleção
	var from: Vector2 = $Details.position + $Details/CardSpot.position + Vector2(16, 23)
	var k := 1.3
	if _items.has(id):
		var it = _items[id]
		it.slam()
		from = _board.position + it.home + it.card.position
		k = it.k
	var fly := CardView.make(id)
	fly.position = from
	fly.scale = Vector2.ONE * k
	fly.z_index = 6
	add_child(fly)
	var to := _pocket.position + _pocket.size * 0.5 - Vector2(CardView.W, CardView.H) * 0.5
	var tw: Tween = fly.create_tween()
	tw.tween_property(fly, "scale", Vector2.ONE * k * 1.15, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(fly, "position", to, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(fly, "scale", Vector2.ONE * 0.25, 0.4).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(fly, "rotation_degrees", -22.0, 0.4)
	tw.tween_callback(fly.queue_free)
	tw.tween_callback(_pocket_bump)
	return true


func _pocket_bump() -> void:
	_refresh_pocket()
	_pocket.scale = Vector2.ONE * 1.3
	_pocket.create_tween().tween_property(_pocket, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# ---------------------------------------------------------------- teclado e roda do mouse

func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event is InputEventMouseButton and event.pressed and _dialog == null \
			and Rect2(BOARD_POS, BOARD_SIZE).has_point(get_local_mouse_position()):
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_turn_page(1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_turn_page(-1)
		return
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	match event.physical_keycode:
		KEY_ESCAPE:
			if _dialog != null:
				_cancel_dialog()
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
		KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN:
			if _dialog == null:
				var step := 1
				match event.physical_keycode:
					KEY_LEFT: step = -1
					KEY_UP: step = -_cols
					KEY_DOWN: step = _cols
				_move_sel(step)
