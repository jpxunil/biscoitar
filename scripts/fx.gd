class_name Fx
## Ajudantes pra montar a geometria placeholder em código.


static func mat(c: Color, emission := 0.0, unshaded := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.55
	if c.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	if unshaded:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if emission > 0.0:
		m.emission_enabled = true
		m.emission = Color(c.r, c.g, c.b)
		m.emission_energy_multiplier = emission
	return m


static func inst(parent: Node, mesh: Mesh, material: Material, pos := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = material
	mi.position = pos
	parent.add_child(mi)
	return mi


static func sphere(r: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	return s


static func disc(r: float, h := 0.02) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = r
	c.bottom_radius = r
	c.height = h
	c.radial_segments = 48
	return c


static func cyl(top: float, bottom: float, h: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = h
	c.radial_segments = 32
	return c


static func capsule(r: float, h: float) -> CapsuleMesh:
	var c := CapsuleMesh.new()
	c.radius = r
	c.height = h
	return c


static func torus(inner: float, outer: float) -> TorusMesh:
	var t := TorusMesh.new()
	t.inner_radius = inner
	t.outer_radius = outer
	t.rings = 48
	return t


static func label(parent: Node, text: String, pos: Vector3, size := 40) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.position = pos
	l.font_size = size
	l.pixel_size = 0.008
	l.outline_size = 10
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.shaded = false
	parent.add_child(l)
	return l


static var _spiral: ArrayMesh
static var _petal: ArrayMesh
static var _hex: CylinderMesh


## Fita em espiral (a voluta dourada da Valsa), deitada no plano XY e virada pra Z: sai do miolo e
## abre até o raio 1, afinando na ponta. Uma malha só, reaproveitada: quem usa só muda escala e giro.
static func spiral_mesh() -> ArrayMesh:
	if _spiral != null:
		return _spiral
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var steps := 56
	var turns := 2.3
	var prev: Array = []
	for i in steps + 1:
		var k := float(i) / steps
		var a := k * turns * TAU
		var r := 0.07 + 0.93 * k
		var w := 0.03 + 0.085 * sin(k * PI) + 0.03 * (1.0 - k)
		var dir := Vector3(cos(a), sin(a), 0)
		var cur := [dir * (r - w), dir * (r + w)]
		if not prev.is_empty():
			for v in [prev[0], prev[1], cur[1], prev[0], cur[1], cur[0]]:
				st.add_vertex(v)
		prev = cur
	_spiral = st.commit()
	return _spiral


## Pétala: um losango fino, deitado no plano XZ.
static func petal_mesh() -> ArrayMesh:
	if _petal != null:
		return _petal
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var p := [Vector3(0, 0, -0.17), Vector3(0.1, 0.02, -0.02), Vector3(0, 0, 0.13), Vector3(-0.1, 0.02, -0.02)]
	for v in [p[0], p[1], p[2], p[0], p[2], p[3]]:
		st.add_vertex(v)
	_petal = st.commit()
	return _petal


## Material sem sombreamento, visível dos dois lados (fitas, pétalas, recortes finos).
static func flat(c: Color) -> StandardMaterial3D:
	var m := mat(c, 0.0, true)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


## Rosa dourada de papel: três recortes de seis lados empilhados, cada um menor, mais claro e girado.
## `size` é o raio da pétala de fora. A rosa fica deitada (olhando pra cima); quem usa gira como quiser.
static func rose(parent: Node, size: float, col := Color(1.0, 0.76, 0.22)) -> Node3D:
	if _hex == null:
		_hex = CylinderMesh.new()
		_hex.top_radius = 0.82
		_hex.bottom_radius = 1.0
		_hex.height = 0.3
		_hex.radial_segments = 6
		_hex.rings = 1
	var root := Node3D.new()
	parent.add_child(root)
	for k in 3:
		var tone := col.lightened(k * 0.22)
		var layer := inst(root, _hex, mat(Color(tone.r * 1.25, tone.g * 1.25, tone.b * 1.25), 0.0, true), Vector3(0, k * 0.2, 0))
		layer.scale = Vector3.ONE * (1.0 - k * 0.3)
		layer.rotation.y = k * 0.52
	root.scale = Vector3.ONE * size
	return root
