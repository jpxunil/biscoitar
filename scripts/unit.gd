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
var salvo_t := 0.0     # escudo da Salva Astral de pé: só com ele o Ricochete volta nela
var lock_t := 0.0      # presa no lugar e sem agir (supercanhão disparando)
var cannon_bonus := 0.0  # dano da marca do Tiro Perfurante, travado quando o Canhão começou a conjurar
var mercy_frenzy := false  # Golpe de Misericórdia dado em Frenesi: não toma dano e o corte sai mesmo assim
## Malpractice: a seringa gigante (arma) e o escudo médico. São nós próprios, filhos de `visual`: quando
## existir o modelo definitivo dela, é só pendurá-los nas mãos dele. `syringe_liquid` é o sangue dentro
## do cilindro (set_fill enche e esvazia).
var syringe: Node3D
var syringe_liquid: MeshInstance3D
var syringe_mats: Array = []
var med_shield: Node3D
var blood_orbit: Node3D
var party_hp := 0.0    # vida "oficial" durante o Blood Party (cura de fora não entra)
var bath_t := 0.0      # coberto pelo Bloodbath: toma menos dano (qualquer herói)
var bath_free := false # Blood Party acabou de começar: o próximo Bloodbath sai de graça (uma vez só)
var bath_window := 0.0 # Malpractice: tempo que resta pra escolher a habilidade fortalecida pelo Bloodbath
var bath_charges := 0  # ... e quantas ainda saem fortalecidas (1; 3 no Blood Party)
var poke_rush_t := 0.0 # Syringe Poke fortalecido: estocadas ainda mais rápidas enquanto dura
var _party_tws: Array = []  # animações da transformação (canceladas se o Blood Party acabar antes delas)
const SYRINGE_HOME := Vector3(0.52, 1.0, -0.2)
const SHIELD_HOME := Vector3(-0.56, 0.95, -0.42)
const SYRINGE_LEN := 1.5
## Assassina: as duas adagas ([esquerda, direita]) e a habilidade bônus que aparece quando o Frenesi acaba.
var daggers: Array[Node3D] = []
var dagger_next := 0
var _dagger_tw: Tween
var frenzy_dmg := 0.0  # dano causado durante o Frenesi: a Última Dança devolve parte dele no corte final
var finisher_t := 0.0  # janela da Última Dança (aberta por FINISH_WINDOW quando o Frenesi termina)
## IA com a carta Rotação: quanto falta pra ela apertar cada habilidade que já voltou (-1 = em recarga).
var ai_ready := [-1.0, -1.0, -1.0, -1.0, -1.0, -1.0]
var haste_t := 0.0     # pressa (nuvem do Apotecário): anda mais rápido enquanto dura
var gun: Node3D        # a pistola arcana (só a Maga tem)
## Soulburner: as duas asas (fechadas nas costas; abrem no Rasante e no Juízo Solar) e o que a Lança
## Serafim travou quando começou a ser conjurada.
var wings: Array[Node3D] = []
var _wing_tw: Tween
var lance_amount := 0.0
var lance_marked := false
var dash_next := false    # bala amarela: o próximo Disparo dá um dash pra trás
var ricochet_t := 0.0
var ricochet_tick := 0.0
var ricochet_out := true
# Ringstar: sequência Jab -> Direto -> Gancho (0 = começo, 1 = Direto fortalecido, 2 = Gancho fortalecido)
var chain := 0
var count_t := 0.0     # Contagem Regressiva
# Valsa
var waltz_step := 0    # compasso do Passo de Valsa: 0 e 1 são passos; em 2, o próximo é o Giro
var waltz_side := 0    # pra que lado sai o próximo passo (alterna)
var embalo := 0        # 0..EMBALO_MAX: abre a saia (alcance e força do bônus da party)
var embalo_t := 0.0    # quanto falta pro Embalo começar a cair
var partner: Unit      # Par de Dança: recebe o bônus de qualquer lugar e acompanha os Giros
var twirl_t := 0.0     # Pirueta: enquanto gira, os golpes passam por ela
var twirl_hit := false # ... e já rendeu o BRAVO desta Pirueta
var crescendo_t := 0.0
var petal_t := 0.0     # Chuva de Pétalas caindo
var petal_tick := 0.0
var ball_t := 0.0      # Grande Baile
var ai_waltz := 0.0    # IA sem a carta Rotação: tempo dançando ao alcance da boss (rende Embalo sozinho)
## O boneco dela: o suporte que gira (rig), a saia, os cachos e as mãos. `skirt_kick` é o quanto a saia
## está aberta A MAIS por causa de um giro (as animações mexem nele); `skirt_open` segue o Embalo.
var rig: Node3D
var skirt: Node3D
## Andar dela é patinar: `glide` (0..1) é o quanto está deslizando agora, `glide_foot` a perna de apoio
## (a outra estende pra trás) e `glide_swap` quanto falta pra trocar de pé. `pose` inclina o corpo todo.
var pose: Node3D
var legs: Array[Node3D] = []
var leg_k := [0.0, 0.0]
var glide := 0.0
var glide_foot := 0
var glide_swap := 1.2
var _last_pos := Vector3.ZERO
var curls: Array[Node3D] = []
var skirt_kick := 0.0
var skirt_open := 0.78
var _waltz_tw: Tween
## A roseta no chão (até onde o bônus alcança) e as rosas do Embalo, que orbitam a cintura.
var aura: MeshInstance3D
var aura_mat: ShaderMaterial
var aura_spin := 0.0
var rose_orbit: Node3D
# Apotecário
var vestiges := 0      # Vestígios (0..3): renovar a Decomposição na hora certa
var patient: Unit      # Paciente: último aliado que recebeu Sutura
var patient_t := 0.0
var mend_t := 0.0      # regeneração da Tanatopraxia
var mend_rate := 0.0
# Sleepwalker
var asleep := false    # Modo Dormindo: imóvel, gasta Torpor
var torpor_hold := 0.0 # Torpor acabou de encher: uns segundos sem perder nada
var silence_t := 0.0   # punição de quem acordou mal: anda, mas não ataca nem usa habilidade
var cast_perfect := false  # a conjuração em curso começou dentro da janela da sequência
# Ringstar no ar (salto do Nocaute Final): passa por cima de ataque baixo (hazard com "low")
var air_t := 0.0
## Pulo (tecla própria): fica no ar por hop_t, passando por cima de ataques rentes ao chão.
var hop_t := 0.0
var hop_cd := 0.0
var _hop_tw: Tween
var fan_safe_t := 0.0   # acabou de tomar um raio do ventilador: não toma outro por um instante
var fan_cross_t := 0.0  # acabou de passar por cima de um raio (pra não contar duas vezes)
## IA no ventilador de raios: já decidiu o que fazer com o raio que vem, quando vai pular, e se corre.
var ai_fan_decided := false
var ai_hop_at := -1.0
var ai_run := false
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
## Ringstar: as duas luvas (as mãos dela). [esquerda, direita]; vazio nos outros heróis.
var gloves: Array[Node3D] = []
var _glove_tw: Tween
var body_mat: StandardMaterial3D
## Cor normal do material do corpo: a do herói no boneco de cápsula, branco no boneco low-poly
## (lá as cores vêm dos vértices e o material só multiplica).
var body_tint := Color.WHITE
## Boneco low-poly (HeroModels): os braços, que seguem as mãos (`hands`). Vazio no boneco de cápsula.
var arms: Array[Node3D] = []
var hands: Array[Node3D] = []
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
	body_tint = color
	if HeroModels.has(key):
		# boneco low-poly de papel recortado (scripts/hero_models.gd)
		HeroModels.build(self)
	else:
		body_mat = Fx.mat(color, 0.25)
		Fx.inst(visual, Fx.capsule(0.38, 1.3), body_mat, Vector3(0, 0.7, 0))
		Fx.inst(visual, Fx.sphere(0.3), Fx.mat(Color(1.0, 0.88, 0.8)), Vector3(0, 1.62, 0))
		# faixa pra dar "frente" ao boneco
		Fx.inst(visual, Fx.sphere(0.12), Fx.mat(Color.WHITE, 1.5), Vector3(0, 1.0, -0.36))
	if key == "nurse":
		_build_syringe()
		_build_med_shield()
		# gotas de sangue flutuando em volta dela (giram em game._tick_blood)
		blood_orbit = Node3D.new()
		blood_orbit.position = Vector3(0, 1.3, 0)
		visual.add_child(blood_orbit)
		for n in 3:
			var a := n * TAU / 3.0
			var drop := Fx.inst(blood_orbit, Fx.sphere(0.07), Fx.mat(Color(1.6, 0.1, 0.25), 0.0, true), Vector3(cos(a) * 0.95, sin(a * 2.0) * 0.25, sin(a) * 0.95))
			drop.scale = Vector3(1.0, 1.5, 1.0)
	if key == "burner":
		# asas de fogo celestial: duas lâminas verde-marinho nas costas, fechadas até a hora de abrir
		for s in [-1.0, 1.0]:
			var pivot := Node3D.new()
			pivot.position = Vector3(s * 0.18, 1.25, 0.3)
			visual.add_child(pivot)
			for k in 3:
				var feather := BoxMesh.new()
				feather.size = Vector3(1.5 - k * 0.3, 0.34, 0.05)
				var fm := Fx.inst(pivot, feather, Fx.mat(Color(0.2, 0.92, 0.8, 0.85).lerp(Color(0.85, 1.0, 0.95, 0.85), k * 0.3), 3.0, true),
					Vector3(s * (0.7 - k * 0.12), 0.25 - k * 0.3, 0))
				fm.rotation.z = s * (0.5 - k * 0.3)
			pivot.scale = Vector3(0.25, 0.6, 1.0)
			pivot.rotation.y = s * -1.1
			wings.append(pivot)
	if key == "maga":
		# pistola arcana pequena na mão direita, de cristal azulado translúcido. Recua a cada disparo (kick).
		gun = Node3D.new()
		gun.position = Vector3(0.42, 1.05, -0.38)
		visual.add_child(gun)
		var glass := Color(0.45, 0.82, 1.0, 0.55)
		var body := BoxMesh.new()
		body.size = Vector3(0.15, 0.2, 0.6)
		Fx.inst(gun, body, Fx.mat(glass, 1.6))
		var barrel := Fx.inst(gun, Fx.cyl(0.055, 0.055, 0.3), Fx.mat(Color(0.7, 0.95, 1.0, 0.7), 2.2), Vector3(0, 0.03, -0.42))
		barrel.rotation.x = PI / 2.0
		var grip := BoxMesh.new()
		grip.size = Vector3(0.12, 0.28, 0.15)
		Fx.inst(gun, grip, Fx.mat(Color(0.4, 0.7, 1.0, 0.6), 1.2), Vector3(0, -0.2, 0.18))
		# o núcleo de energia, visível por dentro do cristal
		Fx.inst(gun, Fx.sphere(0.08), Fx.mat(Color(0.85, 1.0, 1.0), 5.0, true), Vector3(0, 0.02, -0.05))
	if key == "ringstar":
		# luvas de boxe: as mãos dela. Ficam em guarda na frente do corpo e batem com as habilidades.
		for s in [-1.0, 1.0]:
			var hand := Node3D.new()
			hand.position = _glove_home(s)
			visual.add_child(hand)
			var gm := Fx.inst(hand, Fx.sphere(0.27), Fx.mat(Color(1.0, 0.35, 0.72), 1.4))
			gm.scale = Vector3(1.0, 0.95, 1.2)
			Fx.inst(hand, Fx.sphere(0.12), Fx.mat(Color(1.0, 0.35, 0.72), 1.4), Vector3(s * -0.2, 0.05, -0.08))
			var cuff := Fx.inst(hand, Fx.cyl(0.17, 0.17, 0.16), Fx.mat(Color(0.95, 0.94, 1.0), 0.6), Vector3(0, 0, 0.3))
			cuff.rotation.x = PI / 2.0
			gloves.append(hand)

	if key == "valsa":
		# a roseta da saia no chão: mostra até onde o bônus dela alcança (quem liga e escala é o game.gd)
		var plane := PlaneMesh.new()
		plane.size = Vector2(2.0, 2.0)
		aura_mat = ShaderMaterial.new()
		aura_mat.shader = load("res://shaders/valsa_aura.gdshader")
		aura = Fx.inst(self, plane, aura_mat, Vector3(0, 0.035, 0))
		aura.visible = false
		# uma rosa dourada por ponto de Embalo, orbitando a cintura
		rose_orbit = Node3D.new()
		rose_orbit.position = Vector3(0, 1.05, 0)
		rose_orbit.visible = false
		add_child(rose_orbit)
		for n in 5:
			var a := n * TAU / 5.0
			var holder := Node3D.new()
			holder.position = Vector3(cos(a), 0, sin(a)) * 0.95
			rose_orbit.add_child(holder)
			var flower := Fx.rose(holder, 0.13)
			flower.rotation.z = 0.5

	ring = Fx.inst(self, Fx.torus(0.62, 0.74), Fx.mat(Color(1, 1, 1), 2.5, true), Vector3(0, 0.04, 0))
	ring.visible = false

	# anel vermelho no chão = o boss está batendo neste personagem
	target_ring = Fx.inst(self, Fx.torus(0.92, 1.0), Fx.mat(Color(1.0, 0.12, 0.32), 3.0, true), Vector3(0, 0.05, 0))
	target_ring.visible = false
	# anel ciano fino = alvo escolhido pras suas curas
	# círculo em volta de quem está em foco (clique no card ou no boneco), como no lobby
	chosen_ring = Fx.inst(self, Fx.torus(0.96, 1.12), Fx.mat(Color(0.3, 0.95, 1.0), 0.0, true), Vector3(0, 0.07, 0))
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
	# boneco low-poly: cada braço vai do ombro até a mão, onde quer que a animação a tenha levado
	if skirt != null:
		_tick_skirt(delta)
	for n in arms.size():
		var reach: Vector3 = hands[n].position - arms[n].position
		var len := reach.length()
		if len > 0.05:
			var up := Vector3.UP if absf(reach.normalized().y) < 0.95 else Vector3.BACK
			arms[n].basis = Basis.looking_at(reach / len, up) * Basis.from_scale(Vector3(1, 1, len))
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
		body_mat.albedo_color = Color(0.62, 0.12, 0.95) if arms.is_empty() else Color(0.9, 0.6, 1.3)
	elif frenzy_was:
		body_mat.albedo_color = body_tint
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


## Seringa gigante da Malpractice, apontando pra frente (-z): cilindro de vidro com o sangue dentro,
## marcações de medida, flanges, êmbolo com cabo e uma agulha comprida de metal.
func _build_syringe() -> void:
	syringe = Node3D.new()
	syringe.position = SYRINGE_HOME
	visual.add_child(syringe)
	var metal := Fx.mat(Color(0.82, 0.85, 0.92), 0.4)
	var glass := Fx.mat(Color(0.75, 0.92, 1.0, 0.32), 0.6)
	var blood := Fx.mat(Color(1.5, 0.08, 0.2), 0.0, true)
	syringe_mats = [blood]
	var along := func(mi: MeshInstance3D) -> MeshInstance3D:
		mi.rotation.x = PI / 2.0
		return mi
	# sangue dentro (o comprimento muda com set_fill)
	syringe_liquid = along.call(Fx.inst(syringe, Fx.cyl(0.17, 0.17, SYRINGE_LEN), blood, Vector3(0, 0, -SYRINGE_LEN * 0.5)))
	# vidro
	along.call(Fx.inst(syringe, Fx.cyl(0.22, 0.22, SYRINGE_LEN + 0.06), glass, Vector3(0, 0, -SYRINGE_LEN * 0.5)))
	# marcações de medida
	for n in 6:
		var tick := BoxMesh.new()
		tick.size = Vector3(0.16 if n % 2 == 0 else 0.1, 0.02, 0.025)
		Fx.inst(syringe, tick, Fx.mat(Color(0.07, 0.08, 0.16)), Vector3(0, 0.225, -0.18 - n * 0.22))
	# bico e agulha
	along.call(Fx.inst(syringe, Fx.cyl(0.07, 0.2, 0.22), metal, Vector3(0, 0, -SYRINGE_LEN - 0.12)))
	along.call(Fx.inst(syringe, Fx.cyl(0.006, 0.035, 1.25), Fx.mat(Color(0.95, 0.96, 1.0), 1.2), Vector3(0, 0, -SYRINGE_LEN - 0.85)))
	# flanges (onde os dedos apoiam) e anel de metal
	var flange := BoxMesh.new()
	flange.size = Vector3(0.78, 0.07, 0.1)
	Fx.inst(syringe, flange, metal, Vector3(0, 0, 0.03))
	along.call(Fx.inst(syringe, Fx.cyl(0.25, 0.25, 0.08), metal, Vector3(0, 0, -0.04)))
	# êmbolo: haste e cabo
	var plunger := Node3D.new()
	plunger.name = "Plunger"
	syringe.add_child(plunger)
	along.call(Fx.inst(plunger, Fx.cyl(0.06, 0.06, 0.8), metal, Vector3(0, 0, 0.42)))
	along.call(Fx.inst(plunger, Fx.cyl(0.24, 0.24, 0.07), Fx.mat(Color(0.8, 0.1, 0.2), 0.5), Vector3(0, 0, 0.84)))
	set_fill(0.35, 0.0)


## Escudo médico: placa azul-marinho com aro de metal, cruz vermelha no centro e rebites.
func _build_med_shield() -> void:
	med_shield = Node3D.new()
	med_shield.position = SHIELD_HOME
	visual.add_child(med_shield)
	var plate := BoxMesh.new()
	plate.size = Vector3(0.95, 1.4, 0.1)
	Fx.inst(med_shield, plate, Fx.mat(Color(0.12, 0.14, 0.34), 0.2))
	var rim := BoxMesh.new()
	rim.size = Vector3(1.05, 1.5, 0.06)
	Fx.inst(med_shield, rim, Fx.mat(Color(0.8, 0.83, 0.9), 0.4), Vector3(0, 0, 0.03))
	var red := Fx.mat(Color(1.4, 0.1, 0.2), 0.0, true)
	for size in [Vector3(0.2, 0.7, 0.04), Vector3(0.6, 0.2, 0.04)]:
		var bar := BoxMesh.new()
		bar.size = size
		Fx.inst(med_shield, bar, red, Vector3(0, 0.08, -0.07))
	var white := BoxMesh.new()
	white.size = Vector3(0.74, 0.84, 0.03)
	Fx.inst(med_shield, white, Fx.mat(Color(0.95, 0.95, 1.0), 0.3), Vector3(0, 0.08, -0.055))
	for p in [Vector2(-0.38, 0.6), Vector2(0.38, 0.6), Vector2(-0.38, -0.6), Vector2(0.38, -0.6)]:
		Fx.inst(med_shield, Fx.sphere(0.045), Fx.mat(Color(0.85, 0.87, 0.95), 0.5), Vector3(p.x, p.y, -0.06))


## Enche ou esvazia o reservatório da seringa (0..1) em `time` segundos; o êmbolo acompanha.
func set_fill(v: float, time := 0.2) -> void:
	if syringe == null:
		return
	v = clampf(v, 0.02, 1.0)
	var plunger: Node3D = syringe.get_node("Plunger")
	var back := -SYRINGE_LEN * (1.0 - v)
	if time <= 0.0:
		syringe_liquid.scale.y = v
		syringe_liquid.position.z = -SYRINGE_LEN * (1.0 - v * 0.5)
		plunger.position.z = back
		return
	var tw := syringe.create_tween().set_parallel(true)
	tw.tween_property(syringe_liquid, "scale:y", v, time)
	tw.tween_property(syringe_liquid, "position:z", -SYRINGE_LEN * (1.0 - v * 0.5), time)
	tw.tween_property(plunger, "position:z", back, time)


## Estocada com a seringa: vai `reach` pra frente, segura `hold` e volta.
func syringe_stab(reach := 1.1, hold := 0.0) -> void:
	if syringe == null:
		return
	syringe.rotation = Vector3.ZERO
	syringe.position = SYRINGE_HOME + Vector3(0, 0, 0.3)
	var tw := syringe.create_tween()
	tw.tween_property(syringe, "position", SYRINGE_HOME + Vector3(-0.2, 0.1, -reach), 0.07)
	if hold > 0.0:
		tw.tween_interval(hold)
	tw.tween_property(syringe, "position", SYRINGE_HOME, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _dagger_home(s: float) -> Vector3:
	return Vector3(s * 0.5, 0.95, -0.28)


## Golpe com as adagas da Assassina, no ritmo de cada habilidade. `move`:
##   "cut" um corte com a próxima mão (alterna esquerda e direita) · "both" as duas cruzando ·
##   "claws" três cortes rápidos alternados · "spin" as duas abertas pros lados (Dança Carmesim) ·
##   "raise" as duas erguidas e depois descendo juntas (Golpe de Misericórdia) · "thrust" as duas pra frente.
func dagger_anim(move: String, time := 0.4) -> void:
	if daggers.is_empty():
		return
	if _dagger_tw != null:
		_dagger_tw.kill()
	var l := daggers[0]
	var r := daggers[1]
	var lh := _dagger_home(-1.0)
	var rh := _dagger_home(1.0)
	for d in daggers:
		d.rotation = Vector3.ZERO
		d.scale = Vector3.ONE
	l.position = lh
	r.position = rh
	_dagger_tw = create_tween()
	var tw := _dagger_tw
	match move:
		"cut":
			var d: Node3D = daggers[dagger_next]
			var s := -1.0 if dagger_next == 0 else 1.0
			var home := _dagger_home(s)
			dagger_next = 1 - dagger_next
			d.position = home + Vector3(s * 0.5, 0.5, 0.1)
			d.rotation = Vector3(-0.6, 0, s * -0.9)
			tw.tween_property(d, "position", home + Vector3(s * -0.6, -0.2, -0.9), 0.06)
			tw.parallel().tween_property(d, "rotation", Vector3(0.5, 0, s * 0.9), 0.06)
			tw.tween_property(d, "position", home, 0.12)
			tw.parallel().tween_property(d, "rotation", Vector3.ZERO, 0.12)
		"both":
			tw.tween_property(l, "position", lh + Vector3(0.7, 0.2, -0.9), 0.07)
			tw.parallel().tween_property(r, "position", rh + Vector3(-0.7, 0.2, -0.9), 0.07)
			tw.tween_property(l, "position", lh, 0.16)
			tw.parallel().tween_property(r, "position", rh, 0.16)
		"claws":
			for n in 3:
				var d: Node3D = daggers[n % 2]
				var s := -1.0 if n % 2 == 0 else 1.0
				var home := _dagger_home(s)
				tw.tween_property(d, "position", home + Vector3(s * -0.5, 0.3 - n * 0.3, -1.0), 0.05)
				tw.tween_property(d, "position", home, 0.05)
		"spin":
			tw.tween_property(l, "position", Vector3(-1.3, 1.1, 0), 0.06)
			tw.parallel().tween_property(r, "position", Vector3(1.3, 0.9, 0), 0.06)
			tw.parallel().tween_property(l, "rotation", Vector3(0, PI / 2.0, 0), 0.06)
			tw.parallel().tween_property(r, "rotation", Vector3(0, -PI / 2.0, 0), 0.06)
			tw.parallel().tween_property(l, "scale", Vector3.ONE * 1.6, 0.06)
			tw.parallel().tween_property(r, "scale", Vector3.ONE * 1.6, 0.06)
			tw.tween_interval(time)
			tw.tween_property(l, "position", lh, 0.12)
			tw.parallel().tween_property(r, "position", rh, 0.12)
			tw.parallel().tween_property(l, "rotation", Vector3.ZERO, 0.12)
			tw.parallel().tween_property(r, "rotation", Vector3.ZERO, 0.12)
			tw.parallel().tween_property(l, "scale", Vector3.ONE, 0.12)
			tw.parallel().tween_property(r, "scale", Vector3.ONE, 0.12)
		"raise":
			tw.tween_property(l, "position", Vector3(-0.25, 2.2, -0.1), 0.12)
			tw.parallel().tween_property(r, "position", Vector3(0.25, 2.2, -0.1), 0.12)
			tw.parallel().tween_property(l, "rotation", Vector3(-1.4, 0, 0), 0.12)
			tw.parallel().tween_property(r, "rotation", Vector3(-1.4, 0, 0), 0.12)
			tw.parallel().tween_property(l, "scale", Vector3.ONE * 1.5, 0.12)
			tw.parallel().tween_property(r, "scale", Vector3.ONE * 1.5, 0.12)
			tw.tween_interval(maxf(0.0, time - 0.2))
			tw.tween_property(l, "position", lh + Vector3(0.3, -0.3, -1.0), 0.07)
			tw.parallel().tween_property(r, "position", rh + Vector3(-0.3, -0.3, -1.0), 0.07)
			tw.parallel().tween_property(l, "rotation", Vector3(0.7, 0, 0), 0.07)
			tw.parallel().tween_property(r, "rotation", Vector3(0.7, 0, 0), 0.07)
			tw.tween_interval(0.12)
			tw.tween_property(l, "position", lh, 0.14)
			tw.parallel().tween_property(r, "position", rh, 0.14)
			tw.parallel().tween_property(l, "rotation", Vector3.ZERO, 0.14)
			tw.parallel().tween_property(r, "rotation", Vector3.ZERO, 0.14)
			tw.parallel().tween_property(l, "scale", Vector3.ONE, 0.14)
			tw.parallel().tween_property(r, "scale", Vector3.ONE, 0.14)
		"thrust":
			tw.tween_property(l, "position", lh + Vector3(0.15, 0.1, -1.0), 0.05)
			tw.parallel().tween_property(r, "position", rh + Vector3(-0.15, 0.1, -1.0), 0.05)
			tw.tween_interval(0.1)
			tw.tween_property(l, "position", lh, 0.14)
			tw.parallel().tween_property(r, "position", rh, 0.14)


## Bloodbath: ergue a seringa pro alto (a agulha apontando pro céu) e segura enquanto o sangue chove.
func syringe_raise(hold := 0.9) -> void:
	if syringe == null:
		return
	var tw := syringe.create_tween()
	tw.tween_property(syringe, "rotation", Vector3(PI / 2.0, 0, 0), 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(syringe, "position", Vector3(0.45, 1.9, 0.0), 0.14)
	tw.tween_callback(set_fill.bind(0.05, hold * 0.8))
	tw.tween_interval(hold)
	tw.tween_property(syringe, "rotation", Vector3.ZERO, 0.2)
	tw.parallel().tween_property(syringe, "position", SYRINGE_HOME, 0.2)
	tw.tween_callback(set_fill.bind(0.35, 0.3))


## Blood Party: joga o escudo longe (arremesso em arco, girando), vira a seringa contra si e injeta.
func blood_party_start() -> void:
	if syringe == null:
		return
	for old in _party_tws:
		if old != null:
			old.kill()
	var st := med_shield.create_tween().set_parallel(true)
	st.tween_property(med_shield, "position", SHIELD_HOME + Vector3(-5.0, 0.4, 2.5), 0.5).set_ease(Tween.EASE_OUT)
	st.tween_property(med_shield, "position:y", 3.4, 0.25).set_ease(Tween.EASE_OUT)
	st.tween_property(med_shield, "rotation", Vector3(TAU * 1.5, TAU, 0.6), 0.5)
	st.chain().tween_property(med_shield, "position:y", -0.6, 0.2).set_ease(Tween.EASE_IN)
	st.chain().tween_callback(func(): med_shield.visible = false)
	# a seringa vira e entra no próprio peito
	var sy := syringe.create_tween()
	sy.tween_property(syringe, "rotation", Vector3(0, PI * 0.82, 0), 0.16)
	sy.parallel().tween_property(syringe, "position", Vector3(1.5, 1.25, -0.7), 0.16)
	sy.tween_property(syringe, "position", Vector3(0.85, 1.2, -0.4), 0.08)
	sy.tween_callback(set_fill.bind(0.05, 0.22))
	sy.tween_interval(0.26)
	sy.tween_property(syringe, "rotation", Vector3(-0.2, 0, 0), 0.14)
	sy.parallel().tween_property(syringe, "position", SYRINGE_HOME + Vector3(0.1, 0.15, -0.25), 0.14)
	# postura agressiva e a seringa em brasa
	var pose := create_tween()
	pose.tween_property(visual, "scale", Vector3(1.18, 1.12, 1.18), 0.3).set_delay(0.3)
	_party_tws = [st, sy, pose]
	for m in syringe_mats:
		(m as StandardMaterial3D).albedo_color = Color(3.2, 0.2, 0.4)
	set_fill(1.0, 0.4)


func blood_party_end() -> void:
	if syringe == null:
		return
	for old in _party_tws:
		if old != null:
			old.kill()
	_party_tws = []
	for m in syringe_mats:
		(m as StandardMaterial3D).albedo_color = Color(1.5, 0.08, 0.2)
	visual.scale = Vector3.ONE
	syringe.rotation = Vector3.ZERO
	syringe.position = SYRINGE_HOME
	set_fill(0.35, 0.3)
	med_shield.visible = true
	med_shield.rotation = Vector3.ZERO
	med_shield.position = SHIELD_HOME + Vector3(0, 2.5, 0)
	med_shield.create_tween().tween_property(med_shield, "position", SHIELD_HOME, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Abre (ou fecha) as asas do Soulburner em `time` segundos. Abertas, elas batem de leve.
func wings_open(open: bool, time := 0.2) -> void:
	if wings.is_empty():
		return
	if _wing_tw != null:
		_wing_tw.kill()
	_wing_tw = create_tween().set_parallel(true)
	for k in wings.size():
		var s := -1.0 if k == 0 else 1.0
		_wing_tw.tween_property(wings[k], "scale", Vector3(1.25, 1.2, 1.0) if open else Vector3(0.25, 0.6, 1.0), time).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_wing_tw.tween_property(wings[k], "rotation:y", s * (-0.25 if open else -1.1), time)


## Recuo da pistola da Maga: a arma sobe e volta. `power` 1 = tiro comum; mais = tiro pesado.
func kick(power := 1.0) -> void:
	if gun == null:
		return
	gun.position = Vector3(0.42, 1.05 + 0.1 * power, -0.38 + 0.22 * power)
	gun.rotation.x = 0.35 * power
	var tw := gun.create_tween().set_parallel(true)
	tw.tween_property(gun, "position", Vector3(0.42, 1.05, -0.38), 0.16 + 0.06 * power).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(gun, "rotation:x", 0.0, 0.16 + 0.06 * power)
	visual.position.z = 0.12 * power
	visual.create_tween().tween_property(visual, "position:z", 0.0, 0.14)


func _glove_home(s: float) -> Vector3:
	return Vector3(s * 0.52, 1.02, -0.3)


## Animação das luvas da Ringstar. `move`:
##   "jab" esquerda reta e rápida · "straight" direita reta, mais funda · "hook" direita em gancho,
##   de baixo pra cima · "guard" as duas batem uma na outra (Contagem Regressiva) ·
##   "mic" a direita sobe até a boca e depois aponta pra frente (SUPERSTAR!, 1 s) ·
##   "volley" as duas alternam socos por `time` segundos · "raise" as duas pra cima (Nocaute Final).
func glove_anim(move: String, time := 1.0) -> void:
	if gloves.is_empty():
		return
	if _glove_tw != null:
		_glove_tw.kill()
	var l := gloves[0]
	var r := gloves[1]
	var lh := _glove_home(-1.0)
	var rh := _glove_home(1.0)
	l.scale = Vector3.ONE
	r.scale = Vector3.ONE
	_glove_tw = create_tween()
	var tw := _glove_tw
	match move:
		"jab":
			l.position = lh
			tw.tween_property(l, "position", lh + Vector3(0.12, 0.12, -1.0), 0.06)
			tw.tween_property(l, "position", lh, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		"straight":
			r.position = rh + Vector3(0, 0, 0.25)
			tw.tween_property(r, "position", rh + Vector3(-0.2, 0.15, -1.35), 0.07)
			tw.parallel().tween_property(r, "scale", Vector3.ONE * 1.35, 0.07)
			tw.tween_property(r, "position", rh, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.parallel().tween_property(r, "scale", Vector3.ONE, 0.22)
		"hook":
			r.position = rh + Vector3(0.45, -0.5, 0.1)
			tw.tween_property(r, "position", rh + Vector3(-0.35, 0.95, -0.95), 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tw.parallel().tween_property(r, "scale", Vector3.ONE * 1.6, 0.1)
			tw.tween_interval(0.08)
			tw.tween_property(r, "position", rh, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.parallel().tween_property(r, "scale", Vector3.ONE, 0.24)
		"guard":
			tw.tween_property(l, "position", Vector3(-0.2, 1.25, -0.5), 0.08)
			tw.parallel().tween_property(r, "position", Vector3(0.2, 1.25, -0.5), 0.08)
			tw.tween_property(l, "position", lh, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.parallel().tween_property(r, "position", rh, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		"mic":
			# pega o microfone (mão na boca), segura, e aponta pra boss no fim do tempo
			tw.tween_property(r, "position", Vector3(0.14, 1.58, -0.42), time * 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.parallel().tween_property(l, "position", lh + Vector3(-0.25, 0.25, 0.2), time * 0.22)
			tw.tween_interval(time * 0.5)
			tw.tween_property(r, "position", rh + Vector3(-0.1, 0.5, -1.25), time * 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tw.parallel().tween_property(r, "scale", Vector3.ONE * 1.3, time * 0.2)
		"volley":
			var hits := maxi(2, int(time / 0.125))
			for n in hits:
				var hand: Node3D = l if n % 2 == 0 else r
				var home: Vector3 = lh if n % 2 == 0 else rh
				tw.tween_property(hand, "position", home + Vector3(0, 0.3, -1.2), time / hits * 0.4)
				tw.tween_property(hand, "position", home, time / hits * 0.6)
			tw.tween_property(l, "position", lh, 0.1)
			tw.parallel().tween_property(r, "position", rh, 0.1)
		"raise":
			tw.tween_property(l, "position", Vector3(-0.42, 2.25, -0.1), 0.12)
			tw.parallel().tween_property(r, "position", Vector3(0.42, 2.25, -0.1), 0.12)
			tw.parallel().tween_property(l, "scale", Vector3.ONE * 1.5, 0.12)
			tw.parallel().tween_property(r, "scale", Vector3.ONE * 1.5, 0.12)
			tw.tween_interval(time)
			tw.tween_property(l, "position", lh, 0.18)
			tw.parallel().tween_property(r, "position", rh, 0.18)
			tw.parallel().tween_property(l, "scale", Vector3.ONE, 0.18)
			tw.parallel().tween_property(r, "scale", Vector3.ONE, 0.18)


func _hand_home(s: float) -> Vector3:
	return Vector3(s * 0.5, 1.72, -0.3)


## Valsa, a cada frame: a saia abre com o Embalo (e mais ainda num giro: skirt_kick) e roda devagar,
## os cachos voam pra fora quando ela gira, e as rosas do Embalo orbitam a cintura.
func _tick_skirt(delta: float) -> void:
	var t := Time.get_ticks_msec() * 0.001
	_tick_glide(delta, t)
	skirt_open = lerpf(skirt_open, 0.78 + 0.075 * embalo, minf(1.0, delta * 6.0))
	var open := skirt_open + skirt_kick * 0.42 + glide * 0.2
	skirt.scale = Vector3(open, 1.0 - (open - 0.78) * 0.4, open)
	skirt.rotation.y -= delta * (0.5 + 0.35 * embalo + skirt_kick * 16.0)
	skirt.rotation.x = sin(t * 2.2) * 0.03
	for n in curls.size():
		var s := -1.0 if n == 0 else 1.0
		curls[n].rotation.z = s * (skirt_kick * 0.55 + sin(t * 2.6 + n) * 0.04)
		curls[n].rotation.x = -0.4 * glide  # deslizando, os cachos ficam pra trás
	if rose_orbit != null:
		rose_orbit.visible = alive and embalo > 0
		rose_orbit.rotation.y += delta * (1.2 + 0.4 * embalo + skirt_kick * 5.0)
		for n in rose_orbit.get_child_count():
			var holder: Node3D = rose_orbit.get_child(n)
			holder.visible = n < embalo
			holder.position.y = sin(t * 3.0 + n * 1.3) * 0.12


## Ela não anda: desliza, como patinadora. Em movimento o corpo inclina pra frente, os braços abrem
## (um mais alto que o outro), uma perna estende pra trás e, de tempos em tempos, ela troca o pé de
## apoio. Parada, volta à pose normal. Um passo de dança em curso tem prioridade sobre os braços.
func _tick_glide(delta: float, t: float) -> void:
	var speed := 0.0
	if delta > 0.0 and alive:
		speed = Vector2(position.x - _last_pos.x, position.z - _last_pos.z).length() / delta
	_last_pos = position
	var busy := _waltz_tw != null and _waltz_tw.is_running()
	var want := 0.0 if busy else clampf(speed / 3.0, 0.0, 1.0)
	glide = lerpf(glide, want, minf(1.0, delta * (7.0 if want > glide else 4.0)))
	if glide > 0.3:
		glide_swap -= delta
		if glide_swap <= 0.0:
			glide_swap = randf_range(1.3, 2.4)
			glide_foot = 1 - glide_foot
	var side := -1.0 if glide_foot == 0 else 1.0
	for n in legs.size():
		# a perna livre (a que não é a de apoio) estende pra trás e abre um pouco; a de apoio dobra de leve
		var free: float = glide if n != glide_foot else 0.0
		leg_k[n] = lerpf(leg_k[n], free, minf(1.0, delta * 9.0))
		var k: float = leg_k[n]
		legs[n].rotation.x = -1.3 * k + 0.16 * glide * (1.0 - k)
		legs[n].rotation.z = (-1.0 if n == 0 else 1.0) * 0.14 * k
	if pose != null:
		pose.rotation.x = -0.34 * glide
		pose.rotation.z = lerpf(pose.rotation.z, side * -0.12 * glide, minf(1.0, delta * 6.0))
		pose.position.y = sin(t * 4.0) * 0.03 * glide
	if not busy and hands.size() == 2:
		var lh := _hand_home(-1.0)
		var rh := _hand_home(1.0)
		hands[0].position = lh.lerp(lh + Vector3(-0.9, 0.35 - 0.3 * side, 0.35), glide)
		hands[1].position = rh.lerp(rh + Vector3(0.9, 0.35 + 0.3 * side, 0.35), glide)


## Uma rosa do Embalo acabou de nascer: ela estoura grande e assenta.
func rose_pop(n: int) -> void:
	if rose_orbit == null or n < 0 or n >= rose_orbit.get_child_count():
		return
	var holder: Node3D = rose_orbit.get_child(n)
	holder.scale = Vector3.ONE * 2.6
	holder.create_tween().tween_property(holder, "scale", Vector3.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## A dança da Valsa. O corpo gira no suporte (`rig`), então não briga com face(). `move`:
##   "step" passo pro lado, alternando (os dois primeiros tempos do compasso) ·
##   "giro" uma volta inteira com os braços abertos e a saia no máximo (o terceiro tempo) ·
##   "pirueta" três voltas na ponta do pé, uma mão no alto, durante `time` ·
##   "offer" estende a mão pro par (Passo a Dois) · "toss" joga o buquê pro alto (Chuva de Pétalas) ·
##   "crescendo" os braços sobem em V e ela cresce · "ball" duas voltas lentas, flutuando (Grande Baile) ·
##   "bow" a reverência do fim do baile.
func waltz_anim(move: String, time := 0.4) -> void:
	if rig == null or not alive:
		return
	if _waltz_tw != null:
		_waltz_tw.kill()
	var l := hands[0]
	var r := hands[1]
	var lh := _hand_home(-1.0)
	var rh := _hand_home(1.0)
	l.position = lh
	r.position = rh
	rig.rotation = Vector3.ZERO
	rig.position = Vector3.ZERO
	_waltz_tw = create_tween()
	var tw := _waltz_tw
	match move:
		"step":
			var s := -1.0 if waltz_side == 0 else 1.0
			waltz_side = 1 - waltz_side
			var hand: Node3D = l if s < 0.0 else r
			var home: Vector3 = lh if s < 0.0 else rh
			tw.tween_property(rig, "rotation", Vector3(0, s * -0.5, s * -0.14), 0.09).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			tw.parallel().tween_property(rig, "position:x", s * 0.12, 0.09)
			tw.parallel().tween_property(hand, "position", home + Vector3(s * 0.6, 0.5, -0.45), 0.09)
			tw.parallel().tween_property(self, "skirt_kick", 0.28, 0.09)
			tw.tween_property(rig, "rotation", Vector3.ZERO, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.parallel().tween_property(rig, "position:x", 0.0, 0.24)
			tw.parallel().tween_property(hand, "position", home, 0.24)
			tw.parallel().tween_property(self, "skirt_kick", 0.0, 0.3)
		"giro":
			tw.tween_property(rig, "rotation:y", -TAU, time).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			tw.parallel().tween_property(rig, "position:y", 0.3, time * 0.45).set_ease(Tween.EASE_OUT)
			tw.parallel().tween_property(l, "position", lh + Vector3(-0.8, 0.5, 0.25), time * 0.3)
			tw.parallel().tween_property(r, "position", rh + Vector3(0.8, 0.85, 0.25), time * 0.3)
			tw.parallel().tween_property(self, "skirt_kick", 1.0, time * 0.3).set_ease(Tween.EASE_OUT)
			tw.tween_callback(func(): rig.rotation.y = 0.0)
			tw.tween_property(rig, "position:y", 0.0, 0.12).set_ease(Tween.EASE_IN)
			tw.parallel().tween_property(l, "position", lh, 0.2)
			tw.parallel().tween_property(r, "position", rh, 0.2)
			tw.parallel().tween_property(self, "skirt_kick", 0.0, 0.4)
		"pirueta":
			tw.tween_property(rig, "rotation:y", -TAU * 3.0, time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tw.parallel().tween_property(rig, "position:y", 0.5, time * 0.3).set_ease(Tween.EASE_OUT)
			tw.parallel().tween_property(r, "position", Vector3(0.12, 3.3, -0.05), time * 0.2)
			tw.parallel().tween_property(l, "position", lh + Vector3(-0.85, 0.4, 0.2), time * 0.2)
			tw.parallel().tween_property(self, "skirt_kick", 1.35, time * 0.25).set_ease(Tween.EASE_OUT)
			tw.tween_callback(func(): rig.rotation.y = 0.0)
			tw.tween_property(rig, "position:y", 0.0, 0.14).set_ease(Tween.EASE_IN)
			tw.parallel().tween_property(l, "position", lh, 0.22)
			tw.parallel().tween_property(r, "position", rh, 0.22)
			tw.parallel().tween_property(self, "skirt_kick", 0.0, 0.45)
		"offer":
			tw.tween_property(r, "position", rh + Vector3(0.25, 0.75, -0.95), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.parallel().tween_property(l, "position", lh + Vector3(-0.5, -0.1, 0.3), 0.12)
			tw.parallel().tween_property(rig, "position:y", -0.1, 0.12)
			tw.parallel().tween_property(self, "skirt_kick", 0.45, 0.12)
			tw.tween_interval(0.22)
			tw.tween_property(r, "position", rh, 0.22)
			tw.parallel().tween_property(l, "position", lh, 0.22)
			tw.parallel().tween_property(rig, "position:y", 0.0, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.parallel().tween_property(self, "skirt_kick", 0.0, 0.3)
		"toss":
			l.position = lh + Vector3(0.2, -0.3, -0.2)
			r.position = rh + Vector3(-0.2, -0.3, -0.2)
			tw.tween_property(l, "position", Vector3(-0.3, 3.35, -0.1), 0.12).set_ease(Tween.EASE_OUT)
			tw.parallel().tween_property(r, "position", Vector3(0.3, 3.35, -0.1), 0.12).set_ease(Tween.EASE_OUT)
			tw.parallel().tween_property(rig, "position:y", 0.25, 0.12)
			tw.parallel().tween_property(self, "skirt_kick", 0.6, 0.12)
			tw.tween_interval(0.3)
			tw.tween_property(l, "position", lh, 0.25)
			tw.parallel().tween_property(r, "position", rh, 0.25)
			tw.parallel().tween_property(rig, "position:y", 0.0, 0.2)
			tw.parallel().tween_property(self, "skirt_kick", 0.0, 0.4)
		"crescendo":
			tw.tween_property(l, "position", lh + Vector3(-0.7, -0.2, 0.1), 0.1)
			tw.parallel().tween_property(r, "position", rh + Vector3(0.7, -0.2, 0.1), 0.1)
			tw.parallel().tween_property(rig, "position:y", -0.12, 0.1)
			tw.tween_property(l, "position", Vector3(-0.85, 3.2, 0.0), 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.parallel().tween_property(r, "position", Vector3(0.85, 3.2, 0.0), 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.parallel().tween_property(rig, "position:y", 0.35, 0.3).set_ease(Tween.EASE_OUT)
			tw.parallel().tween_property(self, "skirt_kick", 0.9, 0.3)
			tw.tween_interval(0.3)
			tw.tween_property(l, "position", lh, 0.25)
			tw.parallel().tween_property(r, "position", rh, 0.25)
			tw.parallel().tween_property(rig, "position:y", 0.0, 0.2).set_ease(Tween.EASE_IN)
			tw.parallel().tween_property(self, "skirt_kick", 0.0, 0.5)
		"ball":
			tw.tween_property(rig, "rotation:y", -TAU * 2.0, time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			tw.parallel().tween_property(rig, "position:y", 0.7, time * 0.4).set_ease(Tween.EASE_OUT)
			tw.parallel().tween_property(l, "position", lh + Vector3(-0.9, 0.7, 0.2), time * 0.25)
			tw.parallel().tween_property(r, "position", rh + Vector3(0.9, 0.7, 0.2), time * 0.25)
			tw.parallel().tween_property(self, "skirt_kick", 1.4, time * 0.3).set_ease(Tween.EASE_OUT)
			tw.tween_callback(func(): rig.rotation.y = 0.0)
			tw.tween_property(rig, "position:y", 0.0, 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			tw.parallel().tween_property(l, "position", lh, 0.3)
			tw.parallel().tween_property(r, "position", rh, 0.3)
			tw.parallel().tween_property(self, "skirt_kick", 0.0, 0.6)
		"bow":
			tw.tween_property(rig, "position:y", -0.22, 0.14).set_ease(Tween.EASE_OUT)
			tw.parallel().tween_property(rig, "rotation:x", -0.22, 0.14)
			tw.parallel().tween_property(l, "position", lh + Vector3(-0.75, -0.25, 0.15), 0.14)
			tw.parallel().tween_property(r, "position", rh + Vector3(0.75, -0.25, 0.15), 0.14)
			tw.parallel().tween_property(self, "skirt_kick", 0.8, 0.14)
			tw.tween_interval(time)
			tw.tween_property(rig, "position:y", 0.0, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.parallel().tween_property(rig, "rotation:x", 0.0, 0.2)
			tw.parallel().tween_property(l, "position", lh, 0.2)
			tw.parallel().tween_property(r, "position", rh, 0.2)
			tw.parallel().tween_property(self, "skirt_kick", 0.0, 0.4)


func punch() -> void:
	var tw := create_tween()
	visual.scale = Vector3(1.25, 0.85, 1.25)
	tw.tween_property(visual, "scale", Vector3.ONE, 0.15)


## Levou dano: pisca branco e treme, com força proporcional ao golpe (frac = dano / vida máxima).
## Esquiva: o corpo achata e fica translúcido enquanto dura a invulnerabilidade.
## No ar? (salto de habilidade ou o pulo): ataques rentes ao chão passam por baixo.
func airborne() -> bool:
	return air_t > 0.0 or hop_t > 0.0


## O pulo: sobe e desce em `time`, com um agachar na saída e um amassar na chegada.
func hop(time: float, height: float) -> void:
	if _hop_tw != null:
		_hop_tw.kill()
	_hop_tw = create_tween()
	visual.scale = Vector3(1.15, 0.8, 1.15)
	_hop_tw.tween_property(visual, "position:y", height, time * 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_hop_tw.parallel().tween_property(visual, "scale", Vector3(0.9, 1.15, 0.9), time * 0.3)
	_hop_tw.tween_property(visual, "position:y", 0.0, time * 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_hop_tw.tween_property(visual, "scale", Vector3(1.2, 0.82, 1.2), 0.04)
	_hop_tw.tween_property(visual, "scale", Vector3.ONE, 0.12)


func dash_fx() -> void:
	visual.scale = Vector3(0.7, 1.25, 0.7)
	body_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	body_mat.albedo_color.a = 0.35
	var tw := create_tween().set_parallel(true)
	tw.tween_property(visual, "scale", Vector3.ONE, 0.4)
	tw.tween_property(body_mat, "albedo_color:a", 1.0, 0.4)


func flash_hit(frac := 0.2) -> void:
	var tw := create_tween()
	body_mat.albedo_color = Color.WHITE if arms.is_empty() else Color(2.4, 2.4, 2.4)
	tw.tween_property(body_mat, "albedo_color", body_tint, 0.25)
	shake_amp = clampf(0.05 + frac * 0.4, 0.05, 0.22)
	shake_t = SHAKE_TIME


func revive(hp_ratio: float) -> void:
	alive = true
	hp = max_hp * hp_ratio
	visual.rotation.x = 0.0
	visual.position = Vector3.ZERO
	body_mat.albedo_color = body_tint
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
	lock_t = 0.0
	finisher_t = 0.0
	bath_t = 0.0
	bath_window = 0.0
	bath_free = false
	bath_charges = 0
	poke_rush_t = 0.0
	haste_t = 0.0
	salvo_t = 0.0
	cannon_bonus = 0.0
	torpor_hold = 0.0
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
	waltz_step = 0
	embalo = 0
	embalo_t = 0.0
	twirl_t = 0.0
	crescendo_t = 0.0
	petal_t = 0.0
	ball_t = 0.0
	ai_waltz = 0.0
	if _waltz_tw != null:
		_waltz_tw.kill()
	skirt_kick = 0.0
	if rig != null:
		rig.rotation = Vector3.ZERO
		rig.position = Vector3.ZERO
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
