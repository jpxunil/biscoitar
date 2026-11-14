class_name HeroModels
extends RefCounted
## Os bonecos low-poly dos heróis (estilo papel recortado, ver LowPoly). Cada função monta o boneco
## dentro de `u.visual`, de frente pra -Z, com os pés em y = 0 e uns 2,4 de altura com o cabelo.
## Heróis sem função aqui continuam com o boneco de cápsula de unit.gd.

static func has(key: String) -> bool:
	return key == "assassina"


static func build(u: Unit) -> void:
	match u.key:
		"assassina": _assassina(u)


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
