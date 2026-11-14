class_name LowPoly
extends RefCounted
## Bonecos low-poly de "papel recortado": peças angulosas, cor chapada em dois ou três tons e contorno
## de tinta. Tudo é montado em código, sem arquivo de modelo.
##   loft()  — um sólido feito de anéis empilhados (pernas, tronco, cabeça, botas);
##   plate() — um recorte plano com espessura (cabelo, chifres, orelhas, lâminas);
##   build() — transforma as faces numa MeshInstance3D com o contorno já junto.
## A frente do boneco é -Z (como em unit.gd). A "luz" é pintada nas faces (cor por vértice): o material
## é sem sombreamento, então o boneco tem a mesma cara em qualquer lugar da arena.

const INK := Color(0.07, 0.05, 0.12)
const LIGHT := Vector3(-0.4, 0.8, -0.5)
const OUTLINE := 0.028


## Material das peças: sem sombreamento, a cor vem dos vértices. `albedo_color` multiplica tudo
## (é por ele que o boneco pisca branco, fica roxo ou cinza).
static func paint() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true  # as cores das peças são escritas como na arte (sRGB)
	return m


static func ink() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = INK
	m.cull_mode = BaseMaterial3D.CULL_FRONT
	return m


## Anéis empilhados. Cada anel: [y, largura, profundidade, x := 0, z := 0]. `sides` 4 = retângulo;
## mais que isso, um polígono em elipse. Devolve as faces.
static func loft(rings: Array, sides := 4) -> Array:
	var loops: Array = []
	var mid := Vector3.ZERO
	for r in rings:
		var c := Vector3(r[3] if r.size() > 3 else 0.0, r[0], r[4] if r.size() > 4 else 0.0)
		mid += c / rings.size()
		var loop := PackedVector3Array()
		if sides == 4:
			for k in [[-1, -1], [1, -1], [1, 1], [-1, 1]]:
				loop.append(c + Vector3(k[0] * r[1] * 0.5, 0, k[1] * r[2] * 0.5))
		else:
			for k in sides:
				var a := (k + 0.5) * TAU / sides
				loop.append(c + Vector3(cos(a) * r[1] * 0.5, 0, sin(a) * r[2] * 0.5))
		loops.append(loop)
	var faces: Array = []
	for n in loops.size() - 1:
		var a: PackedVector3Array = loops[n]
		var b: PackedVector3Array = loops[n + 1]
		for k in sides:
			var j := (k + 1) % sides
			var quad := PackedVector3Array([a[k], a[j], b[j], b[k]])
			var center := (a[k] + a[j] + b[j] + b[k]) / 4.0
			var axis := Vector3(mid.x, center.y, mid.z)
			faces.append([quad, center - axis])
	faces.append([loops[0], Vector3.DOWN])
	faces.append([loops[-1], Vector3.UP])
	return faces


## Recorte plano (pontos em XY) com espessura `thick` no eixo Z, centrado em z = 0.
static func plate(pts: PackedVector2Array, thick: float) -> Array:
	var poly := pts
	if Geometry2D.is_polygon_clockwise(poly):
		poly = poly.duplicate()
		poly.reverse()
	var faces: Array = []
	var tris := Geometry2D.triangulate_polygon(poly)
	for side in [-1.0, 1.0]:
		for t in range(0, tris.size(), 3):
			var tri := PackedVector3Array()
			for k in 3:
				var p: Vector2 = poly[tris[t + k]]
				tri.append(Vector3(p.x, p.y, side * thick * 0.5))
			faces.append([tri, Vector3(0, 0, side)])
	for k in poly.size():
		var a: Vector2 = poly[k]
		var b: Vector2 = poly[(k + 1) % poly.size()]
		var out := Vector2(b.y - a.y, a.x - b.x)
		faces.append([PackedVector3Array([
			Vector3(a.x, a.y, -thick * 0.5), Vector3(b.x, b.y, -thick * 0.5),
			Vector3(b.x, b.y, thick * 0.5), Vector3(a.x, a.y, thick * 0.5)]), Vector3(out.x, out.y, 0)])
	return faces


## Monta as faces ([polígono convexo, pra que lado é "fora"]) numa peça pintada de `col`, com contorno.
static func build(parent: Node, faces: Array, col: Color, mat: Material, pos := Vector3.ZERO, outline := OUTLINE) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var light := LIGHT.normalized()
	var sums := {}
	var flat: Array = []
	for f in faces:
		var poly: PackedVector3Array = f[0]
		if poly.size() < 3:
			continue
		var cross := (poly[1] - poly[0]).cross(poly[2] - poly[0])
		if cross.length() < 0.000001:
			continue
		# no Godot a frente é o sentido horário: a normal de fora é o contrário do produto vetorial
		if cross.dot(f[1]) > 0.0:
			poly = poly.duplicate()
			poly.reverse()
			cross = -cross
		var n := -cross.normalized()
		var lit := n.dot(light)
		var tone := 1.0 if lit > 0.2 else (0.84 if lit > -0.35 else 0.68)
		st.set_color(Color(col.r * tone, col.g * tone, col.b * tone, col.a))
		st.set_normal(n)
		for k in range(1, poly.size() - 1):
			for v in [poly[0], poly[k], poly[k + 1]]:
				st.add_vertex(v)
		for v in poly:
			var key := v.snappedf(0.0005)
			sums[key] = sums.get(key, Vector3.ZERO) + n
		flat.append(poly)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	if outline > 0.0:
		# contorno: a mesma peça, inflada pelas normais médias, mostrando só as faces de trás
		var so := SurfaceTool.new()
		so.begin(Mesh.PRIMITIVE_TRIANGLES)
		for poly in flat:
			for k in range(1, poly.size() - 1):
				for v in [poly[0], poly[k], poly[k + 1]]:
					var push: Vector3 = sums[v.snappedf(0.0005)]
					so.add_vertex(v + push.normalized() * outline)
		var line := MeshInstance3D.new()
		line.mesh = so.commit()
		line.material_override = ink()
		line.name = "Ink"
		mi.add_child(line)
	return mi


## Um quadro com textura (o rosto), virado pra frente (-Z).
static func decal(parent: Node, tex: Texture2D, size: Vector2, pos: Vector3) -> MeshInstance3D:
	var q := QuadMesh.new()
	q.size = size
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_texture = tex
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var mi := MeshInstance3D.new()
	mi.mesh = q
	mi.material_override = m
	mi.position = pos
	mi.rotation.y = PI  # o QuadMesh olha pra +Z; a frente do boneco é -Z
	parent.add_child(mi)
	return mi
