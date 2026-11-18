extends RefCounted
## Mansão da sereia no fundo do mar. Por fora: pedestal de pedra clara, salão
## principal com cúpula de madrepérola e torre em espiral de concha, duas alas
## laterais com cúpulas menores, quatro torres, pórtico de colunas sob uma
## vieira gigante, corais, algas, caminho de pérolas e uma coluna de bolhas
## subindo até a superfície (a única pista de onde ela está).
## Por dentro (as cúpulas são ocas, dá para entrar nadando): salão com
## piso de mosaico, colunas, lustre de pérolas, trono de vieira e espelho;
## ala esquerda com o quarto (cama de concha) e ala direita com a sala do
## tesouro. A porta fica em +Z local.

const Props := preload("res://world/props.gd")
const Mermaid := preload("res://world/mermaid.gd")

const BASE_R := 15.0
const HALL_R := 7.0
const HALL_H := 8.0
const WING_X := 9.8
const WING_R := 4.2
const WING_H := 5.0
const DOOR_H := 4.4
const ARCH_H := 3.2

var mermaid: Node3D
var root: Node3D

var _body: StaticBody3D
var _rng := RandomNumberGenerator.new()
var _top := 0.0
var _gold: StandardMaterial3D


## Monta a mansão em p (no chão do mar), com a porta virada para o ângulo yaw.
func build(terrain, p: Vector3, yaw: float, surface_y: float, seed_value: int) -> Node3D:
	_rng.seed = seed_value
	var lowest := INF
	var highest := -INF
	for k in 24:
		var a := TAU * k / 24.0
		for r in [0.0, BASE_R * 0.33, BASE_R * 0.66, BASE_R]:
			var h: float = terrain.height(p.x + cos(a) * r, p.z + sin(a) * r)
			lowest = minf(lowest, h)
			highest = maxf(highest, h)

	root = Node3D.new()
	root.name = "CasaDaSereia"
	root.position = Vector3(p.x, 0.0, p.z)
	root.rotation.y = yaw
	_body = StaticBody3D.new()
	root.add_child(_body)
	_top = highest + 0.5
	_gold = _pearl(Color(1.0, 0.8, 0.45))
	_gold.metallic = 0.7

	_build_base(lowest)
	_build_domes()
	_build_spire(Vector3(0.0, _top + HALL_H - 0.4, 0.0), 2.0, 5.0)
	for s in [-1.0, 1.0]:
		_build_spire(Vector3(s * WING_X, _top + WING_H - 0.3, 0.0), 1.1, 2.6)
		for zs in [-1.0, 1.0]:
			_build_turret(Vector3(s * 5.3, _top, zs * 6.6), s * zs)
	_build_portico()
	_build_windows()
	_build_hall()
	_build_bedroom(Vector3(-WING_X, _top, 0.0))
	_build_treasury(Vector3(WING_X, _top, 0.0))
	_build_garden(terrain, p, yaw)
	_build_bubbles(surface_y)

	_light(Vector3(0.0, _top + 4.0, 13.0), Color(0.55, 0.9, 1.0), 2.4, 16.0)

	mermaid = Mermaid.new()
	mermaid.name = "Sereia"
	mermaid.position = Vector3(0.0, _top + 0.9, 12.2)
	root.add_child(mermaid)
	return root


# --- materiais e peças básicas ---

func _pearl(color: Color, glow := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = 0.25
	m.roughness = 0.22
	m.clearcoat_enabled = true
	m.rim_enabled = true
	m.rim = 0.6
	m.rim_tint = 0.8
	if glow > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = glow
	return m


func _glow(color: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	return m


func _light(pos: Vector3, color: Color, energy: float, reach: float) -> void:
	var l := OmniLight3D.new()
	l.light_color = color
	l.light_energy = energy
	l.omni_range = reach
	l.position = pos
	root.add_child(l)


func _shape(shape: Shape3D, pos: Vector3, rot := Vector3.ZERO) -> void:
	var col := CollisionShape3D.new()
	col.shape = shape
	col.position = pos
	col.rotation = rot
	_body.add_child(col)


func _solid_box(size: Vector3, pos: Vector3, mat: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := Props.box(_body, size, pos, mat)
	mi.rotation = rot
	var shape := BoxShape3D.new()
	shape.size = size
	_shape(shape, pos, rot)
	return mi


func _column(pos: Vector3, height: float, radius: float, mat: Material) -> void:
	var c := Props.cylinder(_body, radius, radius * 1.1, height, pos + Vector3(0.0, height * 0.5, 0.0), mat)
	(c.mesh as CylinderMesh).radial_segments = 16
	_torus(_body, radius * 0.6, radius * 1.45, pos + Vector3(0.0, 0.12, 0.0), _gold)
	_torus(_body, radius * 0.6, radius * 1.45, pos + Vector3(0.0, height - 0.12, 0.0), _gold)
	var shape := CylinderShape3D.new()
	shape.radius = radius * 1.1
	shape.height = height
	_shape(shape, pos + Vector3(0.0, height * 0.5, 0.0))


func _sphere(parent: Node3D, radius: float, pos: Vector3, mat: Material, squash := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = radius
	sm.height = radius * 2.0
	sm.radial_segments = 16
	sm.rings = 8
	sm.material = mat
	mi.mesh = sm
	mi.position = pos
	mi.scale = squash
	parent.add_child(mi)
	return mi


func _torus(parent: Node3D, inner: float, outer: float, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = inner
	tm.outer_radius = outer
	tm.rings = 32
	tm.ring_segments = 10
	tm.material = mat
	mi.mesh = tm
	mi.position = pos
	parent.add_child(mi)
	return mi


## Vieira em leque: gomos alongados abertos a partir de um ponto.
func _scallop(parent: Node3D, pos: Vector3, size: float, mat: Material, facing := 0.0) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	n.rotation.y = facing
	parent.add_child(n)
	for k in 11:
		var a := lerpf(-1.25, 1.25, k / 10.0)
		var lobe := _sphere(n, size, Vector3(sin(a) * size * 1.1, cos(a) * size * 1.1, 0.0), mat, Vector3(0.26, 1.0, 0.22))
		lobe.rotation.z = -a
	return n


# --- cúpula oca com aberturas ---

## Cúpula (meio elipsoide) oca, visível dos dois lados e com colisão nos dois
## lados. Cada abertura é [ângulo, meia-abertura em rad, base, topo]; o ângulo
## 0 aponta para +Z. As aberturas têm topo em arco.
## carve: outras cúpulas [centro, raio, altura]; o que cair dentro delas é
## removido, para que as cúpulas se juntem sem paredes sobrando por dentro.
func _dome(center: Vector3, radius: float, height: float, mat: Material, openings: Array, carve := []) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var seg := 160
	var rings := 40
	for j in rings:
		var e0 := (PI * 0.5) * j / rings
		var e1 := (PI * 0.5) * (j + 1) / rings
		var y_mid := height * sin((e0 + e1) * 0.5)
		for i in seg:
			var a0 := TAU * i / seg
			var a1 := TAU * (i + 1) / seg
			var am := (a0 + a1) * 0.5
			var skip := false
			for o in openings:
				var d := absf(wrapf(am - o[0], -PI, PI))
				if d >= o[1]:
					continue
				var bottom: float = o[2]
				var top: float = o[3]
				var rect := bottom + (top - bottom) * 0.72
				var limit := rect + (top - rect) * sqrt(maxf(1.0 - pow(d / o[1], 2.0), 0.0))
				if y_mid >= bottom and y_mid <= limit:
					skip = true
					break
			if not skip and not carve.is_empty():
				var q := center + _dome_point(radius, height, am, (e0 + e1) * 0.5)
				for c in carve:
					var dc: Vector3 = q - c[0]
					var r2: float = c[1] * c[1]
					var h2: float = c[2] * c[2]
					if (dc.x * dc.x + dc.z * dc.z) / r2 + dc.y * dc.y / h2 < 1.0:
						skip = true
						break
			if skip:
				continue
			var p00 := _dome_point(radius, height, a0, e0)
			var p10 := _dome_point(radius, height, a1, e0)
			var p01 := _dome_point(radius, height, a0, e1)
			var p11 := _dome_point(radius, height, a1, e1)
			var uv00 := Vector2(a0 / TAU * 8.0, e0 / (PI * 0.5) * 3.0)
			var uv10 := Vector2(a1 / TAU * 8.0, e0 / (PI * 0.5) * 3.0)
			var uv01 := Vector2(a0 / TAU * 8.0, e1 / (PI * 0.5) * 3.0)
			var uv11 := Vector2(a1 / TAU * 8.0, e1 / (PI * 0.5) * 3.0)
			for v in [[p00, uv00], [p01, uv01], [p11, uv11], [p00, uv00], [p11, uv11], [p10, uv10]]:
				st.set_uv(v[1])
				st.add_vertex(v[0])
	st.generate_normals()
	var mesh := st.commit()
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = center
	_body.add_child(mi)
	var shape := mesh.create_trimesh_shape()
	shape.backface_collision = true
	_shape(shape, center)
	# Gomos dourados por fora, como as estrias de uma concha (só no alto,
	# acima das portas e janelas).
	for k in 8:
		var a := TAU * k / 8.0 + PI / 8.0
		var pts: Array[Vector3] = []
		for t in 7:
			var e := lerpf(0.75, PI * 0.5, t / 6.0)
			pts.append(center + _dome_point(radius + 0.06, height + 0.06, a, e))
		for t in 6:
			_rod(pts[t], pts[t + 1], 0.07, _gold)


func _dome_point(radius: float, height: float, a: float, e: float) -> Vector3:
	return Vector3(sin(a) * cos(e) * radius, sin(e) * height, cos(a) * cos(e) * radius)


func _rod(a: Vector3, b: Vector3, radius: float, mat: Material) -> MeshInstance3D:
	var mi := Props.cylinder(_body, radius, radius, a.distance_to(b) + radius, (a + b) * 0.5, mat)
	(mi.mesh as CylinderMesh).radial_segments = 8
	var dir := (b - a).normalized()
	if absf(dir.dot(Vector3.UP)) < 0.999:
		mi.basis = Basis(Vector3.UP.cross(dir).normalized(), Vector3.UP.angle_to(dir))
	return mi


# --- exterior ---

func _build_base(lowest: float) -> void:
	var stone := Props.rough_material(Color(0.86, 0.79, 0.74), Vector3(1.0, 1.0, 1.0), 1.4, 0.8)
	var h := _top - lowest + 0.6
	var base := Props.cylinder(_body, BASE_R, BASE_R + 0.6, h, Vector3(0.0, _top - h * 0.5, 0.0), stone)
	(base.mesh as CylinderMesh).radial_segments = 48
	_torus(_body, BASE_R - 0.15, BASE_R + 0.15, Vector3(0.0, _top, 0.0), _gold)
	var shape := CylinderShape3D.new()
	shape.radius = BASE_R + 0.3
	shape.height = h
	_shape(shape, Vector3(0.0, _top - h * 0.5, 0.0))
	# Escadaria na frente.
	for i in 4:
		var w := 6.0 - i * 0.6
		_solid_box(Vector3(w, 0.3, 0.8), Vector3(0.0, _top - 0.15 - i * 0.3, BASE_R + 0.3 + i * 0.75), stone)


func _build_domes() -> void:
	var shell := _pearl(Color(0.98, 0.84, 0.9))
	shell.cull_mode = BaseMaterial3D.CULL_DISABLED
	var wing_shell := _pearl(Color(0.86, 0.84, 1.0))
	wing_shell.cull_mode = BaseMaterial3D.CULL_DISABLED
	var hall_open := [[0.0, 1.5 / HALL_R, -0.5, DOOR_H]]
	for a in [0.75, -0.75, 2.35, -2.35, PI]:
		hall_open.append([a, 0.07, 3.3, 4.9])
	# Salão e alas se encontram: cada cúpula perde a parte que fica dentro da
	# outra, e a passagem entre elas fica aberta.
	var hall := [Vector3(0.0, _top, 0.0), HALL_R, HALL_H]
	var wings := []
	for s in [-1.0, 1.0]:
		wings.append([Vector3(s * WING_X, _top, 0.0), WING_R, WING_H])
	_dome(Vector3(0.0, _top, 0.0), HALL_R, HALL_H, shell, hall_open, wings)
	for s in [-1.0, 1.0]:
		var wing_open := []
		for a in [0.0, PI, PI * 0.5 * s]:
			wing_open.append([a, 0.13, 1.6, 3.0])
		_dome(Vector3(s * WING_X, _top, 0.0), WING_R, WING_H, wing_shell, wing_open, [hall])
		# Arco dourado na junção das duas cúpulas (≈ x 6,5 m; 2,6 m de meia
		# largura e 3 m de altura), escondendo a borda do recorte.
		var collar := _torus(_body, 2.45, 2.95, Vector3(s * 6.48, _top, 0.0), _gold)
		collar.rotation.z = PI * 0.5
		collar.scale = Vector3(3.05 / 2.7, 1.0, 1.0)
	# Faixa de conchinhas em volta do salão.
	var tones := [Color(1.0, 0.7, 0.75), Color(0.75, 0.6, 0.95), Color(0.6, 0.9, 0.9), Color(1.0, 0.92, 0.75)]
	for k in 44:
		var a := TAU * k / 44.0
		var gap := false
		for o in [0.0, PI * 0.5, -PI * 0.5]:
			if absf(wrapf(a - o, -PI, PI)) < 0.3:
				gap = true
		if gap:
			continue
		var pos := Vector3(sin(a) * (HALL_R + 0.1), _top + 0.2, cos(a) * (HALL_R + 0.1))
		_sphere(_body, 0.25, pos, _pearl(tones[k % tones.size()]), Vector3(1.0, 0.7, 0.6)).rotation.y = a


## Torre em espiral de concha (no alto das cúpulas).
func _build_spire(base: Vector3, radius: float, height: float) -> void:
	var n := 12
	for i in n:
		var t := float(i) / (n - 1)
		var r := lerpf(radius, radius * 0.12, t)
		var off := Vector3(cos(t * 9.0), 0.0, sin(t * 9.0)) * 0.08 * radius * (1.0 - t)
		var color := Color(1.0, 0.78, 0.84).lerp(Color(1.0, 0.95, 0.88), t)
		var ring := _torus(_body, r * 0.45, r, base + Vector3(0.0, t * height, 0.0) + off, _pearl(color))
		ring.scale = Vector3(1.0, 1.6, 1.0)
		ring.rotation = Vector3(0.08 * sin(t * 7.0), 0.0, 0.08 * cos(t * 7.0))
	Props.cylinder(_body, 0.0, radius * 0.16, height * 0.22, base + Vector3(0.0, height * 1.1, 0.0), _pearl(Color(1.0, 0.95, 0.9)))
	_sphere(_body, radius * 0.12, base + Vector3(0.0, height * 1.24, 0.0), _glow(Color(0.85, 0.95, 1.0), 2.5))
	var shape := CylinderShape3D.new()
	shape.radius = radius * 0.8
	shape.height = height
	_shape(shape, base + Vector3(0.0, height * 0.5, 0.0))


func _build_turret(pos: Vector3, tone: float) -> void:
	var color := Color(0.62, 0.9, 0.88) if tone < 0.0 else Color(0.8, 0.7, 0.98)
	var h := 6.0
	var body := Props.cylinder(_body, 0.85, 1.0, h, pos + Vector3(0.0, h * 0.5, 0.0), _pearl(color))
	(body.mesh as CylinderMesh).radial_segments = 20
	var shape := CylinderShape3D.new()
	shape.radius = 1.0
	shape.height = h + 2.5
	_shape(shape, pos + Vector3(0.0, (h + 2.5) * 0.5, 0.0))
	for i in 7:
		var ring := _torus(_body, 0.88, 1.03, pos + Vector3(0.0, 0.4 + i * 0.85, 0.0), _gold)
		ring.rotation.z = 0.12 * tone
	var roof := Props.cylinder(_body, 0.0, 1.25, 2.6, pos + Vector3(0.0, h + 1.3, 0.0), _pearl(color.lightened(0.25)))
	(roof.mesh as CylinderMesh).radial_segments = 24
	_torus(_body, 1.05, 1.28, pos + Vector3(0.0, h + 0.02, 0.0), _gold)
	_sphere(_body, 0.16, pos + Vector3(0.0, h + 2.75, 0.0), _glow(Color(1.0, 0.9, 0.7), 2.5))
	var out := Vector3(pos.x, 0.0, pos.z).normalized()
	for y in [2.2, 4.2]:
		var w := _sphere(_body, 0.28, pos + Vector3(0.0, y, 0.0) + out * 0.95, _glow(Color(1.0, 0.82, 0.5), 2.0), Vector3(1.0, 1.3, 0.35))
		w.look_at_from_position(w.position, w.position + out, Vector3.UP)


func _build_portico() -> void:
	var white := _pearl(Color(0.97, 0.94, 0.95))
	for x in [-2.4, 2.4]:
		for z in [7.6, 10.0]:
			_column(Vector3(x, _top, z), 4.6, 0.32, white)
	# Teto do pórtico e frontão de vieira.
	_solid_box(Vector3(6.2, 0.4, 3.6), Vector3(0.0, _top + 4.8, 8.8), white)
	_scallop(_body, Vector3(0.0, _top + 5.0, 10.4), 1.5, _pearl(Color(1.0, 0.72, 0.78)))
	_sphere(_body, 0.32, Vector3(0.0, _top + 5.3, 10.75), _glow(Color(1.0, 0.97, 0.95), 1.8))
	# Lanternas de pérola nas colunas da frente.
	for x in [-2.4, 2.4]:
		_sphere(_body, 0.22, Vector3(x, _top + 3.6, 10.45), _glow(Color(1.0, 0.85, 0.6), 2.5))


func _build_windows() -> void:
	# Molduras das janelas do salão (os vãos estão abertos na cúpula).
	for a in [0.75, -0.75, 2.35, -2.35, PI]:
		var dir := Vector3(sin(a), 0.0, cos(a))
		var e := asin(4.1 / HALL_H)
		var pos := Vector3(0.0, _top, 0.0) + _dome_point(HALL_R + 0.05, HALL_H + 0.05, a, e)
		var f := _torus(_body, 0.62, 0.78, pos, _gold)
		f.look_at_from_position(pos, pos + dir + Vector3.UP * 0.5, Vector3.UP)
		f.rotate_object_local(Vector3.RIGHT, PI * 0.5)


# --- interior ---

func _build_hall() -> void:
	var y := _top
	# Piso de mosaico: disco claro com anéis coloridos.
	var marble := Props.rough_material(Color(0.93, 0.9, 0.88), Vector3(0.6, 0.6, 0.6), 0.6, 0.35)
	var floor_disc := Props.cylinder(_body, HALL_R - 0.1, HALL_R - 0.1, 0.06, Vector3(0.0, y + 0.03, 0.0), marble)
	(floor_disc.mesh as CylinderMesh).radial_segments = 48
	var ring_colors := [Color(0.35, 0.75, 0.8), Color(1.0, 0.8, 0.45), Color(0.9, 0.55, 0.7), Color(0.55, 0.45, 0.85)]
	for k in 4:
		var r := 1.2 + k * 1.3
		var ring := _torus(_body, r - 0.12, r + 0.12, Vector3(0.0, y + 0.06, 0.0), _pearl(ring_colors[k]))
		ring.scale = Vector3(1.0, 0.15, 1.0)
	_sphere(_body, 0.6, Vector3(0.0, y + 0.06, 0.0), _pearl(Color(0.35, 0.75, 0.8)), Vector3(1.0, 0.08, 1.0))
	# Colunas internas.
	var white := _pearl(Color(0.97, 0.94, 0.95))
	for a in [PI * 0.25, -PI * 0.25, PI * 0.75, -PI * 0.75]:
		var p := Vector3(sin(a) * 4.6, y, cos(a) * 4.6)
		var h := HALL_H * sqrt(1.0 - pow(4.6 / HALL_R, 2.0)) - 0.1
		_column(p, h, 0.3, white)
	# Lustre de pérolas.
	var cy := y + 6.0
	_rod(Vector3(0.0, cy, 0.0), Vector3(0.0, y + HALL_H, 0.0), 0.04, _gold)
	_torus(_body, 1.1, 1.25, Vector3(0.0, cy, 0.0), _gold)
	_torus(_body, 0.55, 0.66, Vector3(0.0, cy - 0.45, 0.0), _gold)
	var bead := _glow(Color(1.0, 0.95, 0.88), 2.2)
	for k in 14:
		var a := TAU * k / 14.0
		_sphere(_body, 0.11, Vector3(sin(a) * 1.18, cy - 0.15, cos(a) * 1.18), bead)
		_rod(Vector3(sin(a) * 1.18, cy - 0.15, cos(a) * 1.18), Vector3(sin(a) * 0.6, cy - 0.45, cos(a) * 0.6), 0.015, _gold)
	_sphere(_body, 0.28, Vector3(0.0, cy - 0.75, 0.0), _glow(Color(1.0, 0.9, 0.95), 2.6))
	_light(Vector3(0.0, cy - 1.0, 0.0), Color(1.0, 0.86, 0.75), 2.6, 11.0)
	# Trono de vieira no fundo, sobre um tablado.
	var dais := _pearl(Color(0.95, 0.88, 0.92))
	_solid_box(Vector3(3.6, 0.3, 2.0), Vector3(0.0, y + 0.15, -4.9), dais)
	_solid_box(Vector3(2.8, 0.3, 1.4), Vector3(0.0, y + 0.45, -5.0), dais)
	_scallop(_body, Vector3(0.0, y + 0.8, -5.5), 1.25, _pearl(Color(1.0, 0.7, 0.78)))
	_solid_box(Vector3(1.4, 0.4, 0.9), Vector3(0.0, y + 0.8, -4.95), _pearl(Color(0.55, 0.3, 0.75)))
	_sphere(_body, 0.5, Vector3(0.0, y + 1.05, -4.95), _pearl(Color(0.85, 0.45, 0.65)), Vector3(1.2, 0.3, 0.75))
	# Espelho oval de pé, ao lado do trono.
	var mirror_mat := StandardMaterial3D.new()
	mirror_mat.albedo_color = Color(0.85, 0.92, 0.95)
	mirror_mat.metallic = 1.0
	mirror_mat.roughness = 0.04
	var mpos := Vector3(3.3, y + 1.5, -3.6)
	var mirror := _sphere(_body, 0.6, mpos, mirror_mat, Vector3(1.0, 1.5, 0.08))
	mirror.rotation.y = -0.7
	var mframe := _torus(_body, 0.58, 0.7, mpos, _gold)
	mframe.rotation = Vector3(PI * 0.5, -0.7, 0.0)
	mframe.scale = Vector3(1.0, 1.0, 1.5)
	_rod(Vector3(mpos.x, y, mpos.z), Vector3(mpos.x, mpos.y - 0.85, mpos.z), 0.05, _gold)
	# Vasos com algas.
	for a in [PI * 0.62, -PI * 0.62]:
		_vase(Vector3(sin(a) * 5.6, y, cos(a) * 5.6))
	# Tapete redondo na entrada.
	var rug := Props.cylinder(_body, 1.6, 1.6, 0.04, Vector3(0.0, y + 0.08, 4.4), _pearl(Color(0.75, 0.25, 0.45)))
	(rug.mesh as CylinderMesh).radial_segments = 32
	_torus(_body, 1.45, 1.6, Vector3(0.0, y + 0.1, 4.4), _gold).scale = Vector3(1.0, 0.2, 1.0)


func _vase(p: Vector3) -> void:
	var mat := _pearl(Color(0.3, 0.7, 0.75))
	_sphere(_body, 0.45, p + Vector3(0.0, 0.5, 0.0), mat, Vector3(1.0, 1.15, 1.0))
	Props.cylinder(_body, 0.22, 0.18, 0.4, p + Vector3(0.0, 1.15, 0.0), mat)
	_torus(_body, 0.18, 0.27, p + Vector3(0.0, 1.35, 0.0), _gold)
	var weed := Props.material(Color(0.15, 0.5, 0.25), 0.7)
	for k in 4:
		var h := _rng.randf_range(0.8, 1.5)
		var w := Props.cylinder(_body, 0.01, 0.05, h, p + Vector3(0.0, 1.3 + h * 0.5, 0.0), weed)
		w.rotation = Vector3(_rng.randf_range(-0.35, 0.35), 0.0, _rng.randf_range(-0.35, 0.35))
	var shape := CylinderShape3D.new()
	shape.radius = 0.45
	shape.height = 1.4
	_shape(shape, p + Vector3(0.0, 0.7, 0.0))


## Ala esquerda: quarto com cama de concha gigante e penteadeira com espelho.
func _build_bedroom(c: Vector3) -> void:
	var out := -1.0 if c.x < 0.0 else 1.0
	var bed := c + Vector3(out * 1.2, 0.0, -0.6)
	var shell := _pearl(Color(1.0, 0.75, 0.82))
	# Metade de baixo da concha (a cama) e a tampa aberta atrás, em leque.
	var lower := MeshInstance3D.new()
	var lm := SphereMesh.new()
	lm.radius = 1.4
	lm.height = 1.4
	lm.is_hemisphere = true
	lm.material = shell
	lower.mesh = lm
	lower.position = bed + Vector3(0.0, 0.7, 0.0)
	lower.rotation.x = PI
	lower.scale = Vector3(1.0, 0.5, 1.0)
	_body.add_child(lower)
	_scallop(_body, bed + Vector3(0.0, 0.75, -0.9), 1.0, shell)
	var shape := CylinderShape3D.new()
	shape.radius = 1.4
	shape.height = 0.75
	_shape(shape, bed + Vector3(0.0, 0.38, 0.0))
	# Colchão, travesseiro e uma pérola acesa.
	_sphere(_body, 1.25, bed + Vector3(0.0, 0.72, 0.05), _pearl(Color(0.55, 0.78, 0.95)), Vector3(1.0, 0.1, 1.0))
	_sphere(_body, 0.4, bed + Vector3(0.0, 0.9, -0.75), _pearl(Color(1.0, 0.95, 0.97)), Vector3(1.3, 0.35, 0.6))
	_sphere(_body, 0.2, bed + Vector3(0.6, 0.95, 0.5), _glow(Color(1.0, 0.95, 1.0), 1.4))
	# Penteadeira com espelho redondo.
	var desk := c + Vector3(-out * 0.3, 0.0, 2.3)
	_solid_box(Vector3(1.4, 0.08, 0.6), desk + Vector3(0.0, 0.85, 0.0), _gold)
	for dx in [-0.6, 0.6]:
		_rod(desk + Vector3(dx, 0.0, 0.0), desk + Vector3(dx, 0.85, 0.0), 0.04, _gold)
	var mirror_mat := StandardMaterial3D.new()
	mirror_mat.albedo_color = Color(0.85, 0.92, 0.95)
	mirror_mat.metallic = 1.0
	mirror_mat.roughness = 0.04
	_sphere(_body, 0.45, desk + Vector3(0.0, 1.5, 0.25), mirror_mat, Vector3(1.0, 1.0, 0.08))
	var ring := _torus(_body, 0.43, 0.53, desk + Vector3(0.0, 1.5, 0.25), _gold)
	ring.rotation.x = PI * 0.5
	var tints := [Color(1, 0.6, 0.7), Color(0.6, 0.8, 1), Color(1, 0.9, 0.5)]
	for k in 3:
		_sphere(_body, 0.08, desk + Vector3(-0.4 + k * 0.4, 0.95, -0.1), _pearl(tints[k]))
	_light(c + Vector3(0.0, 3.2, 0.0), Color(1.0, 0.7, 0.85), 1.8, 7.0)


## Ala direita: sala do tesouro com baú aberto, montes de moedas e uma coroa.
func _build_treasury(c: Vector3) -> void:
	var out := -1.0 if c.x < 0.0 else 1.0
	var coin := _glow(Color(1.0, 0.78, 0.3), 0.6)
	coin.metallic = 0.9
	coin.roughness = 0.25
	var wood := Props.rough_material(Color(0.4, 0.24, 0.14), Vector3(2, 2, 2), 1.2)
	var chest := c + Vector3(out * 1.5, 0.0, -0.4)
	_solid_box(Vector3(1.3, 0.75, 0.85), chest + Vector3(0.0, 0.38, 0.0), wood)
	for dx in [-0.5, 0.5]:
		Props.box(_body, Vector3(0.08, 0.78, 0.88), chest + Vector3(dx, 0.39, 0.0), _gold)
	var lid := Props.box(_body, Vector3(1.3, 0.12, 0.85), chest + Vector3(0.0, 1.0, -0.62), wood)
	lid.rotation.x = -1.2
	_sphere(_body, 0.55, chest + Vector3(0.0, 0.75, 0.0), coin, Vector3(1.0, 0.35, 0.7))
	# Montes de moedas pelo chão.
	for k in 3:
		var pile := c + Vector3(_rng.randf_range(-1.4, 1.0) * out, 0.0, _rng.randf_range(-1.8, 1.8))
		_sphere(_body, _rng.randf_range(0.35, 0.6), pile, coin, Vector3(1.0, 0.45, 1.0))
		for i in 8:
			var cpos := pile + Vector3(_rng.randf_range(-0.7, 0.7), 0.03, _rng.randf_range(-0.7, 0.7))
			var cm := Props.cylinder(_body, 0.09, 0.09, 0.02, cpos, coin)
			cm.rotation = Vector3(_rng.randf_range(-0.3, 0.3), 0.0, _rng.randf_range(-0.3, 0.3))
	# Pedestal com coroa.
	var ped := c + Vector3(-out * 0.5, 0.0, 2.2)
	_column(ped, 1.0, 0.35, _pearl(Color(0.97, 0.94, 0.95)))
	_torus(_body, 0.2, 0.3, ped + Vector3(0.0, 1.15, 0.0), _gold)
	for k in 6:
		var a := TAU * k / 6.0
		var spike := Props.cylinder(_body, 0.0, 0.06, 0.25, ped + Vector3(sin(a) * 0.25, 1.32, cos(a) * 0.25), _gold)
		(spike.mesh as CylinderMesh).radial_segments = 6
	_sphere(_body, 0.08, ped + Vector3(0.0, 1.25, 0.28), _glow(Color(0.3, 0.6, 1.0), 2.0))
	# Cálices.
	for k in 2:
		var g := c + Vector3(out * (0.2 + k * 0.5), 0.0, -2.4)
		Props.cylinder(_body, 0.12, 0.04, 0.3, g + Vector3(0.0, 0.15, 0.0), _gold)
		Props.cylinder(_body, 0.15, 0.08, 0.25, g + Vector3(0.0, 0.42, 0.0), _gold)
	_light(c + Vector3(0.0, 3.2, 0.0), Color(1.0, 0.85, 0.5), 2.0, 7.0)


# --- jardim e bolhas ---

func _build_garden(terrain, p: Vector3, yaw: float) -> void:
	var basis := Basis(Vector3.UP, yaw)
	var ground := func(local: Vector3) -> float:
		var w := p + basis * local
		return terrain.height(w.x, w.z)
	# Caminho de pérolas acesas até a escadaria.
	var pearl := _glow(Color(0.95, 0.95, 1.0), 1.6)
	for i in 9:
		for s in [-1.0, 1.0]:
			var local := Vector3(s * 2.6, 0.0, BASE_R + 3.8 + i * 1.3)
			local.y = ground.call(local) + 0.12
			_sphere(root, 0.16, local, pearl)
	var colors := [Color(1.0, 0.45, 0.55), Color(1.0, 0.62, 0.25), Color(0.7, 0.4, 0.95), Color(0.95, 0.85, 0.35), Color(0.3, 0.85, 0.75)]
	var variants: Array[ArrayMesh] = []
	for c in colors:
		variants.append(Props.rock_mesh(_rng, c, 1.0, 0.75, false))
	for k in 60:
		var a := _rng.randf() * TAU
		if _in_front(a):
			continue
		var r := BASE_R + _rng.randf_range(0.8, 4.5)
		var local := Vector3(cos(a) * r, 0.0, sin(a) * r)
		local.y = ground.call(local)
		var mi := MeshInstance3D.new()
		mi.mesh = variants[_rng.randi() % variants.size()]
		var s := _rng.randf_range(0.4, 1.1)
		mi.transform = Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled_local(Vector3(s, s * _rng.randf_range(0.9, 2.0), s)), local + Vector3(0, s * 0.3, 0))
		root.add_child(mi)
	for k in 18:
		var a := _rng.randf() * TAU
		if _in_front(a):
			continue
		var local := Vector3(cos(a), 0.0, sin(a)) * (BASE_R + _rng.randf_range(1.0, 4.0))
		local.y = ground.call(local)
		_branch_coral(local, _pearl(colors[_rng.randi() % colors.size()]))
	var weed := Props.material(Color(0.12, 0.45, 0.22), 0.7)
	for k in 70:
		var a := _rng.randf() * TAU
		if _in_front(a):
			continue
		var local := Vector3(cos(a), 0.0, sin(a)) * (BASE_R + _rng.randf_range(0.5, 6.0))
		local.y = ground.call(local)
		var h := _rng.randf_range(2.0, 5.5)
		var w := Props.cylinder(root, 0.015, 0.09, h, local + Vector3(0.0, h * 0.5, 0.0), weed)
		w.rotation = Vector3(_rng.randf_range(-0.2, 0.2), 0.0, _rng.randf_range(-0.2, 0.2))


## Ângulo (medido a partir de +X, como no jardim) que cai na frente da porta.
func _in_front(a: float) -> bool:
	return absf(wrapf(a - PI * 0.5, -PI, PI)) < 0.35


func _branch_coral(base: Vector3, mat: Material) -> void:
	var trunk_h := _rng.randf_range(0.6, 1.2)
	Props.cylinder(root, 0.06, 0.1, trunk_h, base + Vector3(0.0, trunk_h * 0.5, 0.0), mat)
	for k in 5:
		var a := TAU * k / 5.0 + _rng.randf() * 0.5
		var tilt := _rng.randf_range(0.4, 0.8)
		var len := _rng.randf_range(0.5, 1.0)
		var dir := Vector3(cos(a) * sin(tilt), cos(tilt), sin(a) * sin(tilt))
		var start := base + Vector3(0.0, trunk_h * _rng.randf_range(0.6, 1.0), 0.0)
		var mi := Props.cylinder(root, 0.03, 0.06, len, start + dir * len * 0.5, mat)
		mi.basis = Basis(Vector3.UP.cross(dir).normalized(), Vector3.UP.angle_to(dir))
		_sphere(root, 0.06, start + dir * len, mat)


func _build_bubbles(surface_y: float) -> void:
	var bubbles := CPUParticles3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.08
	mesh.height = 0.16
	mesh.radial_segments = 8
	mesh.rings = 4
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.85, 0.97, 1.0, 0.55)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(0.6, 0.85, 0.95)
	mat.emission_energy_multiplier = 0.4
	mat.roughness = 0.1
	mesh.material = mat
	bubbles.mesh = mesh
	var start_y := _top + HALL_H - 0.4 + 6.2
	bubbles.position = Vector3(0.0, start_y, 0.0)
	var rise := maxf(surface_y - start_y, 1.0)
	var speed := 1.6
	bubbles.amount = 40
	bubbles.lifetime = rise / speed
	bubbles.direction = Vector3.UP
	bubbles.spread = 4.0
	bubbles.gravity = Vector3.ZERO
	bubbles.initial_velocity_min = speed
	bubbles.initial_velocity_max = speed
	bubbles.scale_amount_min = 0.5
	bubbles.scale_amount_max = 1.6
	bubbles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	bubbles.emission_sphere_radius = 0.3
	bubbles.preprocess = bubbles.lifetime
	root.add_child(bubbles)
