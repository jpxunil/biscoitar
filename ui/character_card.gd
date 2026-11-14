@tool
class_name CharacterCard
extends Control
## Card de personagem (flat, estilo JRPG). O layout mora em character_card.tscn;
## este script só aplica os dados. Mude as propriedades no Inspector pra testar estados.

const INK := Color(0.07, 0.08, 0.16)
const PAPER := Color(0.97, 0.96, 0.9)
const HP_OK := Color(0.33, 0.87, 0.52)
const HP_MID := Color(1.0, 0.8, 0.25)
const HP_LOW := Color(1.0, 0.33, 0.36)
const STATE_COLORS := [Color(0.62, 0.65, 0.8), Color(0.3, 0.9, 1.0), Color(1.0, 0.8, 0.25)]

@export var index := 1: set = set_index
@export var char_name := "Tank": set = set_char_name
@export var accent := Color(0.3, 0.5, 1.0): set = set_accent
@export var face: Texture2D: set = set_face
@export var hp := 100.0: set = set_hp
@export var max_hp := 100.0: set = set_max_hp
@export var has_element := false: set = set_has_element
@export var element_color := Color(1.0, 0.35, 0.12): set = set_element_color
@export var state_text := "": set = set_state_text
## 0 normal · 1 seguindo protocolo · 2 confuso
@export_range(0, 2) var state_kind := 0: set = set_state_kind
@export var dps := 0: set = set_dps
## Fraqueza (metade do dano) depois de ser revivido
@export var weak := false: set = set_weak
## o boss está batendo neste personagem
@export var targeted := false: set = set_targeted
## alvo escolhido pras habilidades de suporte
@export var chosen := false: set = set_chosen
@export var selected := false: set = set_selected
@export var dead := false: set = set_dead
## Troca em recarga: não dá pra assumir este herói agora.
@export var locked := false: set = set_locked
## Quanto falta da recarga de troca (1 = acabou de trocar, 0 = liberado).
@export_range(0.0, 1.0) var lock_ratio := 0.0
## Escudo, como fração da vida máxima: linha fina azul em cima da barra de vida.
@export_range(0.0, 1.0) var shield_ratio := 0.0
var _shield_bar: ColorRect
var _cd_bar: ColorRect
const CD_LEFT := -8.0
const CD_WIDTH := 274.0

var _hp_width := 0.0
var _base_x := 0.0
var _intro_x := 0.0
var _shake := 0.0
var _shake_t := 0.0
var _ghost := 1.0
var _ghost_tween: Tween

const SHAKE_TIME := 0.2


func _ready() -> void:
	_hp_width = $Body/HpBack.size.x
	# barra de recarga da troca: fora do Body pra não escurecer junto com o card
	_cd_bar = ColorRect.new()
	_cd_bar.color = PAPER
	_cd_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cd_bar.position = Vector2(CD_LEFT, 74.0)
	_cd_bar.size = Vector2(CD_WIDTH, 4.0)
	_cd_bar.visible = false
	add_child(_cd_bar)
	_shield_bar = ColorRect.new()
	_shield_bar.color = Color(0.45, 0.9, 1.0)
	_shield_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shield_bar.position = $Body/HpBack.position + Vector2(0, -5)
	_shield_bar.size = Vector2(0, 3)
	$Body.add_child(_shield_bar)
	_ghost = clampf(hp / maxf(max_hp, 1.0), 0.0, 1.0)
	refresh()
	$Body.position.x = _base_x


func _process(delta: float) -> void:
	var body: Control = $Body
	if _shield_bar != null:
		_shield_bar.visible = shield_ratio > 0.0 and not dead
		_shield_bar.size.x = _hp_width * shield_ratio
	if _cd_bar != null:
		_cd_bar.visible = locked and not selected and not dead
		_cd_bar.size.x = CD_WIDTH * lock_ratio
	if Engine.is_editor_hint():
		body.position = Vector2(_base_x, 0)
		return
	# o card selecionado desliza até a posição em vez de pular
	var x := lerpf(body.position.x - _last_offset.x, _base_x + _intro_x, minf(1.0, delta * 20.0))
	_last_offset = Vector2.ZERO
	if _shake_t > 0.0:
		_shake_t -= delta
		var k := maxf(0.0, _shake_t / SHAKE_TIME)
		# tremida curta, mais horizontal que vertical, que morre sozinha
		_last_offset = Vector2(randf_range(-1.0, 1.0), randf_range(-0.35, 0.35)) * _shake * k
	body.position = Vector2(x, 0) + _last_offset
	$Body/HpGhost.size.x = _hp_width * _ghost

var _last_offset := Vector2.ZERO


## Entrada do card: vem da esquerda com fade.
func play_intro(delay: float) -> void:
	var body: Control = $Body
	body.modulate.a = 0.0
	_intro_x = -80.0
	body.position.x = _base_x + _intro_x
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "_intro_x", 0.0, 0.32).set_delay(delay).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(body, "modulate:a", 1.0, 0.2).set_delay(delay)


## Feedback de dano: a tremida escala com o tamanho do golpe, e a parte perdida
## da barra fica um instante visível antes de escoar, pra dar pra ler quanto foi.
func _on_damage(amount: float, old_ratio: float) -> void:
	var frac := clampf(amount / maxf(max_hp, 1.0), 0.0, 1.0)
	if frac < 0.03:
		return
	_shake = 2.0 + frac * 10.0
	_shake_t = SHAKE_TIME
	_ghost = maxf(_ghost, old_ratio)
	if _ghost_tween != null:
		_ghost_tween.kill()
	_ghost_tween = create_tween()
	_ghost_tween.tween_interval(0.3)
	_ghost_tween.tween_property(self, "_ghost", clampf(hp / maxf(max_hp, 1.0), 0.0, 1.0), 0.35).set_ease(Tween.EASE_IN)


func set_index(v: int) -> void:
	index = v
	refresh()

func set_char_name(v: String) -> void:
	char_name = v
	refresh()

func set_face(v: Texture2D) -> void:
	face = v
	refresh()

func set_accent(v: Color) -> void:
	accent = v
	refresh()

func set_hp(v: float) -> void:
	var old := hp
	hp = v
	if is_node_ready() and not Engine.is_editor_hint():
		var ratio := clampf(v / maxf(max_hp, 1.0), 0.0, 1.0)
		if v < old:
			_on_damage(old - v, clampf(old / maxf(max_hp, 1.0), 0.0, 1.0))
		elif _ghost_tween == null or not _ghost_tween.is_running():
			_ghost = ratio
	refresh()

func set_max_hp(v: float) -> void:
	max_hp = v
	refresh()

func set_has_element(v: bool) -> void:
	has_element = v
	refresh()

func set_element_color(v: Color) -> void:
	element_color = v
	refresh()

func set_state_text(v: String) -> void:
	state_text = v
	refresh()

func set_state_kind(v: int) -> void:
	state_kind = v
	refresh()

func set_weak(v: bool) -> void:
	weak = v
	refresh()

func set_dps(v: int) -> void:
	dps = v
	refresh()

func set_targeted(v: bool) -> void:
	targeted = v
	refresh()

func set_chosen(v: bool) -> void:
	chosen = v
	refresh()

func set_selected(v: bool) -> void:
	selected = v
	refresh()

func set_locked(v: bool) -> void:
	locked = v
	refresh()


func set_dead(v: bool) -> void:
	dead = v
	refresh()


func refresh() -> void:
	if not is_node_ready():
		return
	_base_x = 18.0 if selected and not dead else 0.0

	var fg := INK if selected else PAPER
	$Body/Back.self_modulate = PAPER if selected else INK
	$Body/Accent.self_modulate = accent
	$Body/Index.text = str(index)
	$Body/Face.texture = face
	$Body/Name.text = char_name.to_upper()
	$Body/Name.add_theme_color_override("font_color", fg)

	var ratio := clampf(hp / maxf(max_hp, 1.0), 0.0, 1.0)
	$Body/HpFill.size.x = _hp_width * ratio
	$Body/HpFill.visible = ratio > 0.0
	$Body/HpGhost.visible = not dead
	$Body/HpFill.self_modulate = HP_OK if ratio > 0.5 else (HP_MID if ratio > 0.25 else HP_LOW)
	$Body/HpText.text = "%d/%d" % [ceili(hp), ceili(max_hp)]
	$Body/HpText.add_theme_color_override("font_color", fg)
	$Body/HpLabel.add_theme_color_override("font_color", accent.darkened(0.25) if selected else accent.lightened(0.3))

	$Body/Element.visible = has_element and not dead
	$Body/ElementEdge.visible = $Body/Element.visible
	$Body/ElementEdge.color = INK if selected else PAPER
	$Body/Element.color = element_color

	var state: Label = $Body/State
	state.text = "KO" if dead else state_text
	var sc: Color = STATE_COLORS[state_kind]
	state.add_theme_color_override("font_color", sc.darkened(0.45) if selected else sc)

	$Body/Aggro.visible = targeted and not dead
	$Body/Chosen.visible = chosen
	# o DPS saiu do card: agora mora no medidor da luta (ui/kit/dps_meter.gd). Aqui fica só a Fraqueza.
	$Body/Dps.text = "▼ FRACO"
	$Body/Dps.visible = weak and not dead
	var dps_col := INK.lightened(0.25) if selected else Color(0.66, 0.69, 0.84)
	if weak:
		dps_col = HP_LOW.darkened(0.25) if selected else HP_LOW
	$Body/Dps.add_theme_color_override("font_color", dps_col)

	var off := locked and not selected and not dead
	if dead:
		modulate = Color(0.55, 0.55, 0.62, 0.8)
	else:
		modulate = Color.WHITE
	var dim := Color(0.5, 0.5, 0.56) if off else Color.WHITE
	$Body.modulate = Color(dim.r, dim.g, dim.b, $Body.modulate.a)
	if off:
		$Body/HpFill.self_modulate = Color(0.62, 0.62, 0.68)
	$Body/Face.set_instance_shader_parameter("grey", 1.0 if dead or off else 0.0)
