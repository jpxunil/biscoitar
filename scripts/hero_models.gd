class_name HeroModels
extends RefCounted
## Os bonecos low-poly dos heróis (estilo papel recortado, ver LowPoly). Cada função monta o boneco
## dentro de `u.visual`, de frente pra -Z, com os pés em y = 0 e uns 2,4 de altura com o cabelo.
## Heróis sem função aqui continuam com o boneco de cápsula de unit.gd.

static func has(key: String) -> bool:
	return key == "assassina" or key == "valsa"


static func build(u: Unit) -> void:
	match u.key:
		"assassina": _assassina(u)
		"valsa": _valsa(u)


static func _v2(list: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in list:
		out.append(Vector2(p[0], p[1]))
	return out


# ---------------------------------------------------------------- Assassina

const A_SKIN := Color(0.82, 0.14, 0.24)
const A_SHORTS := Color(0.68, 0.09, 0.19)
const A_BLACK := Color(0.15, 0.12, 0.17)
const A_HAIR := Color(0.72, 0.98, 0.76)
const A_GOLD := Color(1.0, 0.78, 0.3)
const A_BLADE := Color(0.72, 0.9, 1.0)
const A_SHRINK := 2.3
const A_SHOULDER := Vector3(0.2, 1.48, 0.0)


static func _assassina(u: Unit) -> void:
	# o boneco inteiro (corpo, braços e mãos com as adagas) fica num suporte reduzido: A_SHRINK vezes menor
	var v := Node3D.new()
	v.name = "Rig"
	v.scale = Vector3.ONE / A_SHRINK
	u.visual.add_child(v)
	var m := LowPoly.paint()
	u.body_mat = m
	u.body_tint = Color.WHITE
	# botas enormes em sino (largas no pé, finas no joelho, com o cano aberto) e as pernas finas
	for s in [-1.0, 1.0]:
		var x: float = s * 0.2
		LowPoly.build(v, LowPoly.loft([[0.0, 0.4, 0.58, x, -0.08], [0.12, 0.4, 0.54, x, -0.07], [0.46, 0.23, 0.26, x, 0.0], [0.72, 0.25, 0.27, x, 0.0]]), A_BLACK, m)
		LowPoly.build(v, LowPoly.loft([[0.7, 0.26, 0.28, x, 0.0], [0.82, 0.37, 0.37, x + s * 0.02, 0.02]]), A_BLACK, m)
		LowPoly.build(v, LowPoly.loft([[0.68, 0.12, 0.13, x, 0.0], [1.04, 0.16, 0.17, x * 0.8, 0.0]]), A_SKIN, m)
	var up := Vector3(0, 0.1, 0)
	# short, cinto, barriga e o top preto
	LowPoly.build(v, LowPoly.loft([[0.88, 0.52, 0.32], [0.98, 0.52, 0.33], [1.1, 0.36, 0.25]]), A_SHORTS, m, up)
	LowPoly.build(v, LowPoly.loft([[1.08, 0.39, 0.28], [1.13, 0.39, 0.28]]), A_BLACK, m, up)
	LowPoly.build(v, LowPoly.loft([[1.13, 0.25, 0.18], [1.22, 0.25, 0.18]]), A_SKIN, m, up)
	LowPoly.build(v, LowPoly.loft([[1.2, 0.28, 0.2], [1.42, 0.38, 0.23], [1.46, 0.3, 0.2]]), A_BLACK, m, up)
	# o laço do cinto, nas costas (é o que a câmera mais vê)
	for s in [-1.0, 1.0]:
		var bow := LowPoly.build(v, LowPoly.plate(_v2([[0, 0], [s * 0.26, 0.13], [s * 0.28, -0.15]]), 0.05), A_SHORTS, m, up + Vector3(0, 1.08, 0.17))
		bow.rotation.x = 0.25
	# pescoço e cabeça: grande, larga nas bochechas, queixo fino, com a frente plana pro rosto
	LowPoly.build(v, LowPoly.loft([[1.42, 0.13, 0.13], [1.52, 0.13, 0.13]]), A_SKIN, m, up)
	var head := Node3D.new()
	head.name = "Head"
	head.position = up
	v.add_child(head)
	LowPoly.build(head, LowPoly.loft([[1.46, 0.32, 0.4, 0, 0.0], [1.68, 0.84, 0.6, 0, 0.0], [2.0, 0.88, 0.62, 0, 0.0], [2.16, 0.6, 0.48, 0, 0.0]]), A_SKIN, m)
	LowPoly.decal(head, load("res://assets/models/assassina_face.png"), Vector2(0.86, 0.66), Vector3(0, 1.83, -0.318))
	# orelhas pontudas
	for s in [-1.0, 1.0]:
		var ear := LowPoly.build(head, LowPoly.plate(_v2([[0, -0.1], [s * 0.32, 0.12], [0, 0.12]]), 0.05), A_SKIN, m, Vector3(s * 0.42, 1.76, -0.06))
		ear.rotation.y = s * -0.35
	# o cabelo: uma nuvem verde enorme, recortada em pontas, atrás e em volta da cabeça
	var cloud := [[-0.36, 1.5], [-0.72, 1.34], [-0.9, 1.56], [-1.18, 1.6], [-1.1, 1.92], [-1.3, 2.16], [-1.04, 2.4], [-0.98, 2.66],
		[-0.6, 2.64], [-0.38, 2.86], [0.0, 2.72], [0.38, 2.86], [0.6, 2.64], [0.98, 2.66], [1.04, 2.4], [1.3, 2.16], [1.1, 1.92],
		[1.18, 1.6], [0.9, 1.56], [0.72, 1.34], [0.36, 1.5], [0.0, 1.66]]
	LowPoly.build(head, LowPoly.plate(_v2(cloud), 0.44), A_HAIR, m, Vector3(0, 0, 0.26))
	# segunda camada, menor e mais pra trás, pra dar volume de lado
	var back := [[-0.56, 1.66], [-0.94, 1.84], [-0.98, 2.22], [-0.68, 2.52], [0.0, 2.6], [0.68, 2.52], [0.98, 2.22], [0.94, 1.84], [0.56, 1.66], [0.0, 1.58]]
	LowPoly.build(head, LowPoly.plate(_v2(back), 0.3), A_HAIR, m, Vector3(0, 0, 0.56))
	# dois tufos na frente, um de cada lado do rosto
	for s in [-1.0, 1.0]:
		var tuft := [[s * 0.44, 2.22], [s * 0.8, 2.3], [s * 0.94, 1.96], [s * 0.78, 1.62], [s * 0.6, 1.5], [s * 0.5, 1.72]]
		LowPoly.build(head, LowPoly.plate(_v2(tuft), 0.12), A_HAIR, m, Vector3(0, 0, -0.06))
	# chifrinhos
	for s in [-1.0, 1.0]:
		var horn := LowPoly.build(head, LowPoly.plate(_v2([[0, 0], [s * 0.22, 0.04], [s * 0.34, 0.34], [s * 0.1, 0.18]]), 0.08), A_SKIN, m, Vector3(s * 0.6, 2.58, 0.14))
		horn.rotation.y = s * 0.2
	# braços: saem do ombro e seguem a mão (que anda com a adaga). Medem 1 no eixo -Z e são esticados.
	for s in [-1.0, 1.0]:
		var arm := Node3D.new()
		arm.position = Vector3(s * A_SHOULDER.x, A_SHOULDER.y, A_SHOULDER.z)
		v.add_child(arm)
		var limb := LowPoly.build(arm, LowPoly.loft([[0.0, 0.11, 0.11], [1.0, 0.08, 0.08]]), A_SKIN, m)
		limb.rotation.x = -PI / 2.0
		u.arms.append(arm)
	# mãos: luva preta com punho, e a adaga curva (lâmina clara, guarda dourada, argola no pomo)
	for s in [-1.0, 1.0]:
		var hand := Node3D.new()
		hand.position = u._dagger_home(s)
		v.add_child(hand)
		LowPoly.build(hand, LowPoly.loft([[-0.09, 0.17, 0.17], [0.07, 0.19, 0.19]]), A_BLACK, m)
		LowPoly.build(hand, LowPoly.loft([[0.05, 0.23, 0.23], [0.12, 0.23, 0.23]]), A_BLACK, m)
		# a lâmina fica deitada (plano YZ), apontando pra frente e curvando pra cima
		var blade_pts := [[0.0, -0.05], [0.3, -0.07], [0.56, 0.02], [0.74, 0.2], [0.8, 0.4], [0.62, 0.22], [0.42, 0.1], [0.2, 0.06], [0.0, 0.06]]
		# a arma fica num suporte aberto pra fora e caído, como ela segura na arte
		var grip := Node3D.new()
		grip.rotation = Vector3(-0.35, s * -0.75, 0)
		hand.add_child(grip)
		var blade := LowPoly.build(grip, LowPoly.plate(_v2(blade_pts), 0.035), A_BLADE, m, Vector3(0, -0.02, -0.2))
		blade.rotation.y = PI / 2.0
		var guard := LowPoly.build(grip, LowPoly.plate(_v2([[-0.05, -0.16], [0.05, -0.1], [0.05, 0.14], [-0.05, 0.2]]), 0.06), A_GOLD, m, Vector3(0, -0.02, -0.17))
		guard.rotation.y = PI / 2.0
		var ring_pts: Array = []
		for k in 6:
			var a := k * TAU / 6.0
			ring_pts.append([cos(a) * 0.09, sin(a) * 0.09])
		var pommel := LowPoly.build(grip, LowPoly.plate(_v2(ring_pts), 0.04), A_GOLD, m, Vector3(0, -0.02, 0.2))
		pommel.rotation.y = PI / 2.0
		u.daggers.append(hand)
		u.hands.append(hand)


# ---------------------------------------------------------------- Valsa

const V_SKIN := Color(0.47, 0.23, 0.16)
const V_WHITE := Color(0.93, 0.91, 1.0)
const V_HAIR := Color(0.86, 0.83, 0.99)
const V_LILAC := Color(0.8, 0.7, 1.0)
const V_DEEP := Color(0.6, 0.47, 0.95)
const V_GOLD := Color(1.0, 0.76, 0.22)
const V_SHRINK := 2.0
const V_SHOULDER := Vector3(0.22, 2.02, 0.0)
## Onde a saia prende (a cintura) e onde as pernas giram (o quadril), em unidades do boneco.
const V_WAIST := 1.6
const V_HIP := 1.48


## A dançarina: pernas compridas, saia enorme em dois babados (é um nó à parte, `u.skirt`: unit.gd abre
## e gira conforme o Embalo), corpete branco, e os dois coques com cachos em mola (`u.curls`, que voam
## pra fora quando ela gira). Rosas douradas no cabelo, no peito, na cintura e nos pulsos.
static func _valsa(u: Unit) -> void:
	# `pose` é o corpo inteiro inclinando quando ela desliza; `rig`, dentro dele, é o que gira na dança
	var pose := Node3D.new()
	pose.name = "Pose"
	u.visual.add_child(pose)
	u.pose = pose
	var v := Node3D.new()
	v.name = "Rig"
	v.scale = Vector3.ONE / V_SHRINK
	pose.add_child(v)
	u.rig = v
	var m := LowPoly.paint()
	u.body_mat = m
	u.body_tint = Color.WHITE
	# sapatilhas claras e as pernas finas. Cada perna é um nó preso no quadril (`u.legs`): quando ela
	# desliza, a de trás estende como a de uma patinadora (unit.gd)
	for s in [-1.0, 1.0]:
		var x: float = s * 0.14
		var leg := Node3D.new()
		leg.position = Vector3(x, V_HIP, 0)
		v.add_child(leg)
		u.legs.append(leg)
		var off := Vector3(-x, -V_HIP, 0)
		LowPoly.build(leg, LowPoly.loft([[0.0, 0.2, 0.46, x, -0.08], [0.12, 0.19, 0.4, x, -0.06], [0.22, 0.15, 0.2, x, 0.0]]), V_WHITE, m, off)
		LowPoly.build(leg, LowPoly.loft([[0.2, 0.13, 0.14, x, 0.0], [0.85, 0.17, 0.18, x, 0.0], [1.5, 0.21, 0.21, x * 0.9, 0.0]]), V_SKIN, m, off)
		if s > 0.0:
			# a renda da meia, numa coxa só
			LowPoly.build(leg, LowPoly.loft([[1.1, 0.24, 0.24, x, 0.0], [1.24, 0.25, 0.25, x, 0.0]]), V_WHITE, m, off)
	# calção e corpete brancos
	LowPoly.build(v, LowPoly.loft([[1.38, 0.42, 0.3], [1.6, 0.34, 0.26]]), V_WHITE, m)
	LowPoly.build(v, LowPoly.loft([[1.58, 0.3, 0.22], [1.82, 0.3, 0.22], [2.04, 0.46, 0.26], [2.1, 0.34, 0.22]]), V_WHITE, m)
	# a saia: anágua mais escura e maior por baixo, girada meio gomo, e a saia clara por cima
	var skirt := Node3D.new()
	skirt.name = "Skirt"
	skirt.position = Vector3(0, V_WAIST, 0)
	v.add_child(skirt)
	u.skirt = skirt
	var under := LowPoly.build(skirt, LowPoly.loft([[-0.64, 2.55, 2.55], [-0.32, 1.55, 1.55], [-0.02, 0.4, 0.4]], 10), V_DEEP, m)
	under.rotation.y = TAU / 20.0
	LowPoly.build(skirt, LowPoly.loft([[-0.5, 2.2, 2.2], [-0.22, 1.36, 1.36], [0.05, 0.42, 0.42]], 10), V_LILAC, m)
	# rosa na cintura (frente e costas: a câmera vê as costas) e no peito
	for z in [-1.0, 1.0]:
		var waist := Fx.rose(v, 0.13, V_GOLD)
		waist.position = Vector3(0.0, V_WAIST + 0.02, z * 0.2)
		waist.rotation.x = z * PI / 2.0
	var chest := Fx.rose(v, 0.12, V_GOLD)
	chest.position = Vector3(-0.08, 1.98, -0.15)
	chest.rotation.x = -PI / 2.0
	# pescoço e cabeça
	LowPoly.build(v, LowPoly.loft([[2.08, 0.13, 0.13], [2.2, 0.13, 0.13]]), V_SKIN, m)
	var head := Node3D.new()
	head.name = "Head"
	v.add_child(head)
	LowPoly.build(head, LowPoly.loft([[2.14, 0.32, 0.4, 0, 0.0], [2.36, 0.8, 0.6, 0, 0.0], [2.66, 0.84, 0.62, 0, 0.0], [2.8, 0.58, 0.48, 0, 0.0]]), V_SKIN, m)
	LowPoly.decal(head, load("res://assets/models/valsa_face.png"), Vector2(0.78, 0.6), Vector3(0, 2.49, -0.318))
	for s in [-1.0, 1.0]:
		var ear := LowPoly.build(head, LowPoly.plate(_v2([[0, -0.08], [s * 0.26, 0.1], [0, 0.1]]), 0.05), V_SKIN, m, Vector3(s * 0.4, 2.44, -0.04))
		ear.rotation.y = s * -0.35
	# cabelo branco: a parte de trás, o topo, a franja em pontas e uma mecha de cada lado do rosto
	var back := [[-0.5, 2.16], [-0.66, 2.5], [-0.54, 2.9], [0.0, 3.04], [0.54, 2.9], [0.66, 2.5], [0.5, 2.16], [0.2, 2.04], [-0.2, 2.04]]
	LowPoly.build(head, LowPoly.plate(_v2(back), 0.42), V_HAIR, m, Vector3(0, 0, 0.2))
	LowPoly.build(head, LowPoly.loft([[2.72, 0.92, 0.72, 0, 0.03], [2.9, 0.76, 0.6, 0, 0.05], [3.0, 0.34, 0.3, 0, 0.06]]), V_HAIR, m)
	var fringe := [[-0.46, 2.86], [-0.47, 2.58], [-0.3, 2.7], [-0.15, 2.56], [0.02, 2.74], [0.2, 2.58], [0.33, 2.7], [0.47, 2.58], [0.46, 2.86], [0.0, 2.94]]
	LowPoly.build(head, LowPoly.plate(_v2(fringe), 0.08), V_HAIR, m, Vector3(0, 0, -0.33))
	for s in [-1.0, 1.0]:
		var lock := [[s * 0.38, 2.72], [s * 0.54, 2.3], [s * 0.46, 1.96], [s * 0.34, 2.3]]
		LowPoly.build(head, LowPoly.plate(_v2(lock), 0.1), V_HAIR, m, Vector3(0, 0, -0.2))
	# os dois coques, cada um com o cacho em mola pendurado do lado de fora
	for s in [-1.0, 1.0]:
		var curl := Node3D.new()
		curl.position = Vector3(s * 0.92, 3.0, 0.1)
		curl.scale = Vector3.ONE * 0.9
		head.add_child(curl)
		LowPoly.build(curl, LowPoly.loft([[-0.5, 0.36, 0.36], [-0.3, 0.86, 0.8], [0.0, 1.02, 0.94], [0.3, 0.86, 0.8], [0.5, 0.36, 0.36]], 6), V_HAIR, m)
		var spring := [[0.0, 0.12, 0.12], [0.14, 0.36, 0.36], [0.26, 0.24, 0.24], [0.42, 0.52, 0.52], [0.56, 0.36, 0.36],
			[0.74, 0.68, 0.68], [0.9, 0.48, 0.48], [1.1, 0.8, 0.8], [1.26, 0.6, 0.6], [1.46, 0.84, 0.84]]
		var tail := LowPoly.build(curl, LowPoly.loft(spring, 6), V_HAIR, m, Vector3(s * 0.72, -1.2, 0.06))
		tail.rotation.z = s * 0.5
		tail.scale = Vector3.ONE * 0.82
		u.curls.append(curl)
		# rosa dourada na frente de cada coque
		var flower := Fx.rose(head, 0.17, V_GOLD)
		flower.position = Vector3(s * 0.5, 2.94, -0.36)
		flower.rotation = Vector3(-PI / 2.0 + 0.3, 0, s * -0.4)
	# braços: do ombro até a mão, onde quer que a dança a leve
	for s in [-1.0, 1.0]:
		var arm := Node3D.new()
		arm.position = Vector3(s * V_SHOULDER.x, V_SHOULDER.y, V_SHOULDER.z)
		v.add_child(arm)
		var limb := LowPoly.build(arm, LowPoly.loft([[0.0, 0.1, 0.1], [1.0, 0.075, 0.075]]), V_SKIN, m)
		limb.rotation.x = -PI / 2.0
		u.arms.append(arm)
	# mãos, cada uma com a pulseira dourada (e uma rosa no pulso esquerdo)
	for s in [-1.0, 1.0]:
		var hand := Node3D.new()
		hand.position = u._hand_home(s)
		v.add_child(hand)
		LowPoly.build(hand, LowPoly.loft([[-0.09, 0.15, 0.15], [0.07, 0.17, 0.17]]), V_SKIN, m)
		LowPoly.build(hand, LowPoly.loft([[0.07, 0.23, 0.23], [0.13, 0.23, 0.23]]), V_GOLD, m)
		if s < 0.0:
			Fx.rose(hand, 0.1, V_GOLD).position = Vector3(0, 0.14, 0)
		u.hands.append(hand)
