class_name Unit
extends Node3D
## Um integrante da party. A decisão do que fazer mora em game.gd;
## aqui fica só estado + visual placeholder (troque por Sprite3D depois).

var idx := 0
var unit_name := ""
var color := Color.WHITE
var max_hp := 100.0
var hp := 100.0
var alive := true
var melee := false
var ai_dps := 5.0
var hit_dmg := 8.0
var speed := 6.5

var element := -1
var controlled := false
var hold_pos = null  # Vector3 ou null

var action_text := ""
var action_kind := 0  # 0 normal, 1 protocolo, 2 confuso

var invuln := 0.0
var dash_t := 0.0
var dash_dir := Vector3.ZERO
var dash_cd := 0.0
var atk_cd := 0.0
var combo := 0
var dmg_acc := 0.0
var dmg_timer := 0.0
var dmg_total := 0.0
var dmg_bucket := 0.0
var dmg_buckets: Array[float] = []
var dps := 0.0
var key := ""
var skill_cd := [0.0, 0.0, 0.0, 0.0, 0.0, 0.0]  # um por slot da barra (Binds.SKILL_SLOTS)
var atk_range := 4.8
var cast_target: Unit
var cast_ai := false
var guard_t := 0.0
var regen_t := 0.0     # Égide (Paladino): regenerando vida
var wall_t := 0.0      # Muralha da Fé (Paladino): a party toda toma menos dano
var aegis: MeshInstance3D
# Assassina
var side_need := 1     # Talho Relâmpago: lado da boss que está valendo (1 = direita, -1 = esquerda)
var side_left := 3     # ... e quantos golpes fortalecidos faltam desse lado
var frenzy_t := 0.0    # Frenesi da Fera
var parry_t := 0.0     # Golpe de Misericórdia: janela em que o golpe vira parry
var parry_hit := false
var frenzy_ring: MeshInstance3D
# Maga: balas Rainbow (passiva). Cada bala é um índice em game.BULLETS; a próxima a sair é a [0].
var bullets: Array = []
var bullet_t := 0.0
var power_t := 0.0     # bala vermelha: mais dano
var ward_t := 0.0      # bala azul: toma menos dano
var pierce_next := false  # depois de uma bala, o próximo Disparo Rúnico sai fortalecido
var dash_next := false    # bala amarela: o próximo Disparo dá um dash pra trás
var ricochet_t := 0.0
var ricochet_tick := 0.0
var ricochet_out := true
# Ringstar: sequência Jab -> Direto -> Gancho (0 = começo, 1 = Direto fortalecido, 2 = Gancho fortalecido)
var chain := 0
var count_t := 0.0     # Contagem Regressiva
# Apotecário
var vestiges := 0      # Vestígios (0..3): renovar a Decomposição na hora certa
var patient: Unit      # Paciente: último aliado que recebeu Sutura
var patient_t := 0.0
var mend_t := 0.0      # regeneração da Tanatopraxia
var mend_rate := 0.0
# Sleepwalker
var asleep := false    # Modo Dormindo: imóvel, gasta Torpor
var silence_t := 0.0   # punição de quem acordou mal: anda, mas não ataca nem usa habilidade
var cast_perfect := false  # a conjuração em curso começou dentro da janela da sequência
# Ringstar no ar (salto do Nocaute Final): passa por cima de ataque baixo (hazard com "low")
var air_t := 0.0
var torpor := 0.0      # 0..100
var dream_step := 0    # qual habilidade da sequência Dormindo é a próxima (0..4)
var window_slot := -1  # Acordado: slot que está na janela de 1 s (-1 = nenhuma)
var window_t := 0.0
var crumbs := false    # Migalhas Oníricas (deixadas pelos Visitantes na janela)
var pillow_full := false  # Travesseiro Cheio
var near_t := 0.0      # Perto do Sonho: todas as recargas -1 s
var wake_t := 0.0      # acordando sozinho por falta de Torpor
var bite_cd := 0.0     # recarga da Mordida dos Mil, guardada enquanto está acordado
var awake_cd := [0.0, 0.0, 0.0, 0.0, 0.0]  # recargas do Modo Acordado, que continuam correndo enquanto dorme
var frenzy_was := false
var wall_ring: MeshInstance3D
## Índice do herói em Knowledge.HEROES (baralho dele) e se é quem segura a boss.
var hero := 0
var tank := false
## Enfermeira Gótica: acúmulos do Blood Party, janela do Blood Taste e o Blood Party em si.
var base_hp := 100.0   # vida máxima normal (max_hp sobe durante o Blood Taste)
var stacks := 0
var taste_t := 0.0
var taste_prev := 0.0
var taste_hit := false
var party_t := 0.0
var party_tick := 0.0
var targeted := false
var chosen := false
## Pra onde está fugindo de um ataque vermelho. Fica guardado até sair da área,
## senão o ponto seguro troca de lado a cada frame e o personagem fica indo e voltando.
var dodge_goal = null
## Escudo da Healer: absorve dano antes da vida.
var shield_hp := 0.0
var shield_t := 0.0
## Cast interrompido: o HUD mostra a barra em vermelho por um instante.
var cancel_t := 0.0
var cancel_ratio := 0.0
## Conjurador sem a carta Cautela: fica preso terminando o cast quando o vermelho aparece.
var in_red := false
var stuck_t := 0.0
var enmity := 0.0
## Cartas e itens de uso único por luta.
var phoenix_used := false
var potion_used := false
var weak_t := 0.0      # Fraqueza: revivido pelo Reviver comum dá metade do dano
var immortal_t := 0.0  # Limit Break do Tank
var pillar: MeshInstance3D
var pillar_mat: StandardMaterial3D
var immortal_ring: MeshInstance3D
var channel_t := 0.0
var channel_total := 1.0
var channel_slot := 0
var chosen_ring: MeshInstance3D
var channel_ring: MeshInstance3D
var guard_ring: MeshInstance3D
var target_ring: MeshInstance3D

var shake_t := 0.0
var shake_amp := 0.0
const SHAKE_TIME := 0.2

var visual: Node3D
var body_mat: StandardMaterial3D
var ring: MeshInstance3D
var orb: MeshInstance3D
var orb_mat: StandardMaterial3D
var tag: Label3D


func setup(i: int, d: Dictionary) -> void:
	idx = i
	unit_name = d["name"]
	key = d["key"]
	atk_range = d["range"]
	color = d["color"]
	max_hp = d["hp"]
	base_hp = max_hp
	tank = d.get("tank", false)
	hp = max_hp
	melee = d["melee"]
	ai_dps = d["ai_dps"]
	hit_dmg = d["hit"]

	visual = Node3D.new()
	add_child(visual)
	body_mat = Fx.mat(color, 0.25)
	Fx.inst(visual, Fx.capsule(0.38, 1.3), body_mat, Vector3(0, 0.7, 0))
	Fx.inst(visual, Fx.sphere(0.3), Fx.mat(Color(1.0, 0.88, 0.8)), Vector3(0, 1.62, 0))
	# faixa pra dar "frente" ao boneco
	Fx.inst(visual, Fx.sphere(0.12), Fx.mat(Color.WHITE, 1.5), Vector3(0, 1.0, -0.36))

	ring = Fx.inst(self, Fx.torus(0.62, 0.74), Fx.mat(Color(1, 1, 1), 2.5, true), Vector3(0, 0.04, 0))
	ring.visible = false

	# anel vermelho no chão = o boss está batendo neste personagem
	target_ring = Fx.inst(self, Fx.torus(0.92, 1.0), Fx.mat(Color(1.0, 0.12, 0.32), 3.0, true), Vector3(0, 0.05, 0))
	target_ring.visible = false
	# anel ciano fino = alvo escolhido pras suas curas
	chosen_ring = Fx.inst(self, Fx.torus(0.8, 0.84), Fx.mat(Color(0.3, 0.9, 1.0), 3.0, true), Vector3(0, 0.06, 0))
	chosen_ring.visible = false
	channel_ring = Fx.inst(self, Fx.torus(0.9, 1.0), Fx.mat(d["color"], 3.0, true), Vector3(0, 0.08, 0))
	channel_ring.visible = false
	# coluna de luz do Limit Break (aparece só durante o cast)
	pillar_mat = Fx.mat(Color(color.r, color.g, color.b, 0.4), 3.5, true)
	pillar = Fx.inst(self, Fx.cyl(0.85, 1.15, 11.0), pillar_mat, Vector3(0, 5.5, 0))
	pillar.visible = false
	immortal_ring = Fx.inst(self, Fx.torus(0.75, 0.9), Fx.mat(Color(1.0, 0.9, 0.5), 4.0, true), Vector3(0, 1.3, 0))
	immortal_ring.visible = false
	guard_ring = Fx.inst(self, Fx.torus(0.7, 0.8), Fx.mat(Color(0.3, 0.9, 1.0), 3.0, true), Vector3(0, 0.9, 0))
	guard_ring.visible = false
	# Égide: barreira dourada enorme na frente do corpo (gira junto com o boneco)
	var wall := BoxMesh.new()
	wall.size = Vector3(2.6, 2.9, 0.14)
	aegis = Fx.inst(visual, wall, Fx.mat(Color(1.0, 0.82, 0.3, 0.5), 2.6, true), Vector3(0, 1.45, -0.95))
	aegis.visible = false
	# Muralha da Fé: anel dourado nos pés de quem está protegido
	wall_ring = Fx.inst(self, Fx.torus(0.95, 1.08), Fx.mat(Color(1.0, 0.85, 0.35), 3.5, true), Vector3(0, 0.07, 0))
	wall_ring.visible = false
	# Frenesi da Fera: aura roxa em volta do corpo
	frenzy_ring = Fx.inst(self, Fx.torus(0.7, 0.92), Fx.mat(Color(0.75, 0.2, 1.0), 4.0, true), Vector3(0, 0.9, 0))
	frenzy_ring.visible = false

	orb_mat = Fx.mat(Color.WHITE, 3.0, true)
	orb = Fx.inst(self, Fx.sphere(0.24), orb_mat, Vector3(0, 2.3, 0))
	orb.visible = false

	tag = Fx.label(self, "", Vector3(0, 2.95, 0), 56)
	tag.outline_size = 18
	tag.outline_modulate = Color(0.07, 0.08, 0.16)
	tag.visible = false


func _process(delta: float) -> void:
	if orb.visible:
		orb.position.y = 2.3 + sin(Time.get_ticks_msec() * 0.005 + idx) * 0.08
	if ring.visible:
		ring.rotate_y(delta * 2.0)
	target_ring.visible = targeted and alive
	immortal_ring.visible = immortal_t > 0.0 and alive
	if immortal_ring.visible:
		immortal_ring.rotate_y(delta * 8.0)
	# Limit Break carregando: a coluna engrossa e acende até o disparo
	var lb_cast := channel_slot == -1 and channel_t > 0.0 and alive
	pillar.visible = lb_cast
	if lb_cast:
		var k := 1.0 - channel_t / channel_total
		var pulse := 1.0 + sin(Time.get_ticks_msec() * 0.02) * 0.08
		pillar.scale = Vector3((0.55 + k * 0.6) * pulse, 1.0, (0.55 + k * 0.6) * pulse)
		pillar_mat.albedo_color.a = 0.2 + k * 0.45
		body_mat.emission_energy_multiplier = 1.0 + k * 4.0
	elif body_mat.emission_energy_multiplier > 0.3:
		body_mat.emission_energy_multiplier = 0.25
	chosen_ring.visible = chosen
	channel_ring.visible = channel_t > 0.0 and alive
	if channel_ring.visible:
		# o anel fecha conforme a habilidade carrega
		channel_ring.scale = Vector3.ONE * (1.0 + 1.6 * channel_t / channel_total)
	guard_ring.visible = (guard_t > 0.0 or taste_t > 0.0) and alive
	aegis.visible = guard_t > 0.0 and alive and key == "tank"
	if aegis.visible:
		aegis.scale = Vector3.ONE * (1.0 + 0.04 * sin(Time.get_ticks_msec() * 0.012))
	wall_ring.visible = wall_t > 0.0 and alive
	frenzy_ring.visible = frenzy_t > 0.0 and alive
	if frenzy_ring.visible:
		# o boneco fica roxo e a aura gira rápido
		frenzy_ring.rotate_y(delta * 14.0)
		frenzy_ring.position.y = 0.9 + sin(Time.get_ticks_msec() * 0.02) * 0.35
		body_mat.albedo_color = Color(0.62, 0.12, 0.95)
	elif frenzy_was:
		body_mat.albedo_color = color
	frenzy_was = frenzy_ring.visible
	if wall_ring.visible:
		wall_ring.rotate_y(delta * 3.0)
	if guard_ring.visible:
		guard_ring.rotate_y(delta * 5.0)
	if shake_t > 0.0:
		shake_t -= delta
		var k := maxf(0.0, shake_t / SHAKE_TIME)
		visual.position.x = randf_range(-1.0, 1.0) * shake_amp * k
		visual.position.z = randf_range(-0.5, 0.5) * shake_amp * k
	elif visual.position.x != 0.0 or visual.position.z != 0.0:
		visual.position.x = 0.0
		visual.position.z = 0.0


func set_controlled(on: bool) -> void:
	var gained := on and not controlled and alive
	controlled = on
	ring.visible = on and alive
	if gained:
		# troca de controle: o anel "pousa" no personagem e ele dá um pulinho
		ring.scale = Vector3.ONE * 2.6
		create_tween().tween_property(ring, "scale", Vector3.ONE, 0.24).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		punch()


func set_element(e: int, col := Color.WHITE) -> void:
	element = e
	orb.visible = e >= 0 and alive
	if e >= 0:
		orb_mat.albedo_color = col
		orb_mat.emission = col


func set_action(text: String, kind := 0) -> void:
	action_text = text
	action_kind = kind
	# Em cima da cabeça só aparece o alerta ("???"); o resto já está no card,
	# senão quatro rótulos se empilham quando a party anda junta.
	tag.visible = kind == 2
	tag.text = text
	match kind:
		1: tag.modulate = Color(0.3, 0.9, 1.0)
		2: tag.modulate = Color(1.0, 0.8, 0.25)
		_: tag.modulate = Color(0.97, 0.96, 0.9)


func face(dir: Vector3) -> void:
	if dir.length() > 0.01:
		visual.rotation.y = atan2(-dir.x, -dir.z)


func punch() -> void:
	var tw := create_tween()
	visual.scale = Vector3(1.25, 0.85, 1.25)
	tw.tween_property(visual, "scale", Vector3.ONE, 0.15)


## Levou dano: pisca branco e treme, com força proporcional ao golpe (frac = dano / vida máxima).
## Esquiva: o corpo achata e fica translúcido enquanto dura a invulnerabilidade.
func dash_fx() -> void:
	visual.scale = Vector3(0.7, 1.25, 0.7)
	body_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	body_mat.albedo_color.a = 0.35
	var tw := create_tween().set_parallel(true)
	tw.tween_property(visual, "scale", Vector3.ONE, 0.4)
	tw.tween_property(body_mat, "albedo_color:a", 1.0, 0.4)


func flash_hit(frac := 0.2) -> void:
	var tw := create_tween()
	body_mat.albedo_color = Color.WHITE
	tw.tween_property(body_mat, "albedo_color", color, 0.25)
	shake_amp = clampf(0.05 + frac * 0.4, 0.05, 0.22)
	shake_t = SHAKE_TIME


func revive(hp_ratio: float) -> void:
	alive = true
	hp = max_hp * hp_ratio
	visual.rotation.x = 0.0
	visual.position = Vector3.ZERO
	body_mat.albedo_color = color
	body_mat.emission_enabled = true
	weak_t = 0.0
	ring.visible = controlled
	punch()


func die() -> void:
	alive = false
	hp = 0.0
	element = -1
	orb.visible = false
	ring.visible = false
	hold_pos = null
	immortal_t = 0.0
	enmity = 0.0  # morrer zera a enmity, como no FFXIV
	guard_t = 0.0
	asleep = false
	silence_t = 0.0
	air_t = 0.0
	torpor = 0.0
	dream_step = 0
	window_slot = -1
	near_t = 0.0
	wake_t = 0.0
	vestiges = 0
	mend_t = 0.0
	chain = 0
	count_t = 0.0
	ricochet_t = 0.0
	power_t = 0.0
	ward_t = 0.0
	frenzy_t = 0.0
	parry_t = 0.0
	regen_t = 0.0
	wall_t = 0.0
	taste_t = 0.0
	party_t = 0.0
	stacks = 0
	max_hp = base_hp
	channel_t = 0.0
	shield_hp = 0.0
	shield_t = 0.0
	cancel_t = 0.0
	visual.rotation.x = -PI / 2.0
	visual.position.y = 0.35
	body_mat.albedo_color = Color(0.25, 0.25, 0.28)
	body_mat.emission_enabled = false
	tag.visible = false
