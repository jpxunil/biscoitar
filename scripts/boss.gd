extends Node3D
## Boss placeholder feito de primitivas. A ideia final é uma ilustração
## enorme (Sprite3D / AnimatedSprite3D) parada aqui no fundo da arena.

var casting := false
var six_seven := false  # gesto do Esmagar: uma mão sobe enquanto a outra desce
var hair_color := Color(1.0, 0.38, 0.66)
var t := 0.0
var rage_t := 0.0
## -1 = mão esquerda levantada e brilhando (vai bater no lado esquerdo), +1 = direita, 0 = nenhuma.
var cleave_hand := 0
## 0..1: Fúria chegando. Vai ficando vermelha e tremendo.
var enrage_k := 0.0
var look := "girl"
var hand_mats: Array[StandardMaterial3D] = []
var _dress_base := Color(0.16, 0.08, 0.3)
var _rage_off := Vector3.ZERO
const RAGE_TIME := 0.9
var halo: MeshInstance3D
var hands: Array[MeshInstance3D] = []
var eye_mat: StandardMaterial3D
var dress_mat: StandardMaterial3D
var shield: MeshInstance3D
var core: Node3D


func _ready() -> void:
	core = Node3D.new()
	add_child(core)
	if look == "cookie":
		_build_cookie()
		return
	if look == "dummy":
		_build_dummy()
		return
	var skin := Fx.mat(Color(0.95, 0.8, 0.74))
	var hair := Fx.mat(hair_color, 0.35)
	dress_mat = Fx.mat(Color(0.16, 0.08, 0.3), 0.5)

	Fx.inst(core, Fx.cyl(0.9, 3.5, 6.6), dress_mat, Vector3(0, 3.3, 0))
	Fx.inst(core, Fx.torus(3.3, 3.6), Fx.mat(Color(1.0, 0.5, 0.8), 2.0), Vector3(0, 0.25, 0))
	Fx.inst(core, Fx.cyl(1.05, 0.85, 2.3), Fx.mat(Color(0.8, 0.78, 0.92)), Vector3(0, 7.5, 0))
	Fx.inst(core, Fx.sphere(0.5), Fx.mat(Color(1.0, 0.3, 0.5), 2.5), Vector3(0, 7.9, 0.95))
	Fx.inst(core, Fx.sphere(1.25), skin, Vector3(0, 9.7, 0))
	var back_hair := Fx.inst(core, Fx.sphere(1.45), hair, Vector3(0, 9.95, -0.35))
	back_hair.scale = Vector3(1.0, 1.0, 0.95)
	for s in [-1.0, 1.0]:
		var tail := Fx.inst(core, Fx.capsule(0.48, 4.6), hair, Vector3(s * 2.1, 8.3, -0.3))
		tail.rotation.z = s * 0.38
		Fx.inst(core, Fx.sphere(0.34), Fx.mat(Color(1.0, 0.9, 0.3), 2.0), Vector3(s * 1.35, 10.5, 0.0))

	eye_mat = Fx.mat(Color(0.3, 0.95, 1.0), 3.0)
	for s in [-1.0, 1.0]:
		var eye := Fx.inst(core, Fx.sphere(0.2), eye_mat, Vector3(s * 0.47, 9.7, 1.12))
		eye.scale = Vector3(1.0, 1.6, 0.4)
		var hm := Fx.mat(Color(0.95, 0.8, 0.74))
		var hand := Fx.inst(core, Fx.sphere(0.62), hm, Vector3(s * 4.0, 6.4, 1.6))
		hands.append(hand)
		hand_mats.append(hm)

	halo = Fx.inst(core, Fx.torus(1.35, 1.55), Fx.mat(Color(1.0, 0.85, 0.35), 3.0), Vector3(0, 11.8, 0))
	halo.rotation.x = 0.25

	shield = Fx.inst(self, Fx.sphere(7.2), Fx.mat(Color(0.35, 0.9, 1.0, 0.16), 1.2), Vector3(0, 6.0, 0))
	shield.visible = false


func _process(delta: float) -> void:
	t += delta
	core.position.y = sin(t * 1.2) * 0.22
	halo.rotate_y(delta * (5.0 if casting else 1.0))
	for i in hands.size():
		var s := -1.0 if i == 0 else 1.0
		var lift := 2.2 if casting or rage_t > 0.0 else 0.0
		var target := Vector3(s * (4.0 - lift * 0.4), 6.4 + lift + sin(t * 1.6 + i * 2.0) * 0.35, 1.6)
		var follow := 4.0
		if six_seven:
			# mãos na frente do corpo, balançando em oposição
			target = Vector3(s * 2.6, 6.6 + s * sin(t * 9.0) * 1.3, 2.4)
			follow = 14.0
		# golpe de meia arena: a mão do lado que vai apanhar sobe, cresce e brilha
		var raised: bool = cleave_hand != 0 and signf(cleave_hand) == s
		if raised:
			target = Vector3(s * 5.4, 10.2 + sin(t * 18.0) * 0.15, 2.6)
			follow = 9.0
		hands[i].position = hands[i].position.lerp(target, delta * follow)
		hands[i].scale = hands[i].scale.lerp(Vector3.ONE * (1.9 if raised else 1.0), delta * 10.0)
		if i < hand_mats.size():
			var hm: StandardMaterial3D = hand_mats[i]
			hm.emission_enabled = raised
			if raised:
				hm.emission = Color(1.0, 0.3, 0.45)
				hm.emission_energy_multiplier = 3.0 + sin(t * 20.0) * 1.2
	if shield.visible:
		shield.rotate_y(delta * 0.6)
	# raiva (foi provocada): treme forte e vai acalmando
	position -= _rage_off
	_rage_off = Vector3.ZERO
	if rage_t > 0.0:
		rage_t -= delta
		var k := clampf(rage_t / RAGE_TIME, 0.0, 1.0)
		_rage_off = Vector3(randf_range(-1.0, 1.0), randf_range(-0.3, 0.3), 0.0) * 0.28 * k
		dress_mat.emission_energy_multiplier = 0.5 + 2.5 * k
	if enrage_k > 0.0:
		_rage_off += Vector3(randf_range(-1.0, 1.0), randf_range(-0.4, 0.4), 0.0) * 0.3 * enrage_k
		dress_mat.albedo_color = _dress_base.lerp(Color(0.9, 0.08, 0.12), enrage_k)
		dress_mat.emission = Color(1.0, 0.1, 0.15)
		dress_mat.emission_energy_multiplier = maxf(dress_mat.emission_energy_multiplier, 0.5 + 3.0 * enrage_k)
	position += _rage_off


## Mini boss: um biscoitão de olho arregalado e bracinhos curtos. Mais esquisito que assustador.
func _build_cookie() -> void:
	_dress_base = Color(0.82, 0.56, 0.28)
	dress_mat = Fx.mat(_dress_base, 0.25)
	var body := Fx.inst(core, Fx.cyl(4.2, 4.0, 1.3), dress_mat, Vector3(0, 5.6, 0))
	body.rotation.x = PI / 2.0
	var chip := Fx.mat(Color(0.25, 0.13, 0.07))
	for p in [Vector3(-2.4, 7.6, 0.75), Vector3(2.6, 7.0, 0.75), Vector3(-2.9, 4.2, 0.75), Vector3(2.2, 3.6, 0.75), Vector3(0.4, 8.6, 0.75), Vector3(-0.8, 2.6, 0.75)]:
		Fx.inst(core, Fx.sphere(0.42), chip, p)
	eye_mat = Fx.mat(Color(0.1, 0.08, 0.1), 0.0)
	var white := Fx.mat(Color(1, 1, 1), 0.6)
	for s in [-1.0, 1.0]:
		# um olho maior que o outro
		var r := 0.95 if s < 0.0 else 0.7
		Fx.inst(core, Fx.sphere(r), white, Vector3(s * 1.3, 6.3 + (0.2 if s > 0.0 else 0.0), 0.7))
		Fx.inst(core, Fx.sphere(r * 0.42), eye_mat, Vector3(s * 1.3 + 0.15, 6.2, 0.7 + r * 0.75))
		var hm := Fx.mat(_dress_base.lightened(0.1))
		var hand := Fx.inst(core, Fx.sphere(0.7), hm, Vector3(s * 4.0, 6.4, 1.6))
		hands.append(hand)
		hand_mats.append(hm)
	# boca torta
	var mouth := Fx.inst(core, Fx.capsule(0.22, 1.9), chip, Vector3(0.1, 4.4, 0.8))
	mouth.rotation.z = PI / 2.0 + 0.18
	halo = Fx.inst(core, Fx.torus(0.5, 0.62), Fx.mat(Color(1.0, 0.85, 0.35), 2.0), Vector3(0, 10.6, 0))
	shield = Fx.inst(self, Fx.sphere(7.2), Fx.mat(Color(0.35, 0.9, 1.0, 0.16), 1.2), Vector3(0, 6.0, 0))
	shield.visible = false


## Treino livre: boneco de palha num poste, com um alvo pintado no peito. Não tem mãos nem ataca.
func _build_dummy() -> void:
	_dress_base = Color(0.86, 0.72, 0.42)
	dress_mat = Fx.mat(_dress_base, 0.2)
	var wood := Fx.mat(Color(0.42, 0.27, 0.16))
	var rope := Fx.mat(Color(0.3, 0.2, 0.12))
	Fx.inst(core, Fx.cyl(1.7, 2.1, 0.5), wood, Vector3(0, 0.25, 0))
	Fx.inst(core, Fx.cyl(0.38, 0.38, 9.0), wood, Vector3(0, 4.5, 0))
	Fx.inst(core, Fx.cyl(1.9, 1.5, 4.4), dress_mat, Vector3(0, 5.4, 0))
	for y in [3.6, 7.2]:
		Fx.inst(core, Fx.torus(1.55, 1.85), rope, Vector3(0, y, 0))
	var arm := Fx.inst(core, Fx.capsule(0.42, 8.4), dress_mat, Vector3(0, 6.7, 0))
	arm.rotation.z = PI / 2.0
	Fx.inst(core, Fx.sphere(1.35), dress_mat, Vector3(0, 9.2, 0))
	# alvo no peito: discos deitados de frente pra arena
	var rings := [[1.3, Color(0.95, 0.94, 0.88)], [0.9, Color(0.86, 0.16, 0.22)], [0.5, Color(0.95, 0.94, 0.88)], [0.2, Color(0.86, 0.16, 0.22)]]
	for k in rings.size():
		var d := Fx.inst(core, Fx.disc(rings[k][0], 0.04), Fx.mat(rings[k][1], 0.4), Vector3(0, 5.6, 1.78 + k * 0.03))
		d.rotation.x = PI / 2.0
	eye_mat = Fx.mat(Color(0.1, 0.08, 0.1), 0.0)
	for s in [-1.0, 1.0]:
		# olhos de botão, em X
		for r in [-1.0, 1.0]:
			var x := Fx.inst(core, Fx.capsule(0.07, 0.6), eye_mat, Vector3(s * 0.5, 9.4, 1.28))
			x.rotation.z = r * PI / 4.0
	halo = Fx.inst(core, Fx.torus(0.9, 1.05), rope, Vector3(0, 10.3, 0))
	shield = Fx.inst(self, Fx.sphere(7.2), Fx.mat(Color(0.35, 0.9, 1.0, 0.16), 1.2), Vector3(0, 6.0, 0))
	shield.visible = false


## Provocada pelo Bora Biscoitar: treme de raiva, com os punhos fechados pra cima.
func rage() -> void:
	rage_t = RAGE_TIME


func set_tint(c: Color) -> void:
	eye_mat.albedo_color = c
	eye_mat.emission = c


func set_shield(on: bool) -> void:
	shield.visible = on


func hit_flash() -> void:
	if look == "dummy":
		# o boneco balança no poste a cada golpe
		core.rotation.x = -0.09
		core.create_tween().tween_property(core, "rotation:x", 0.0, 0.25).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	dress_mat.emission_energy_multiplier = 2.5
	var tw := create_tween()
	tw.tween_property(dress_mat, "emission_energy_multiplier", 0.5, 0.12)
