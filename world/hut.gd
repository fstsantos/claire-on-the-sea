extends RefCounted
## Cabana de náufrago no estilo "Lagoa Azul": palafitas e piso de madeira,
## paredes de palha trançada com moldura de bambu, telhado alto coberto de
## folhas de palmeira, varanda coberta e rampa até o chão. Tudo por código.
##
## Eixos locais: a cumeeira corre em Z; a porta e a varanda ficam em +Z.

const Props := preload("res://world/props.gd")

const HALF_W := 2.5          # meia largura do quarto (X)
const BACK_Z := -2.0         # parede do fundo
const FRONT_Z := 2.0         # parede da frente (porta)
const PORCH_Z := 4.2         # borda da varanda
const FLOOR_LIFT := 1.25     # altura do piso acima do ponto mais alto do chão
const WALL_H := 2.4
const EAVE_X := 3.3          # beiral do telhado
const EAVE_H := 2.0          # altura do beiral acima do piso
const RIDGE_H := 4.3         # altura da cumeeira acima do piso
const ROOF_Z0 := -2.8
const ROOF_Z1 := 4.7
const DOOR_W := 1.15
const DOOR_H := 1.95

var _terrain
var _origin: Vector3
var _yaw := 0.0
var _floor_y := 0.0          # altura do piso, local (origem do nó na altura 0 do mundo)
var _body: StaticBody3D
var _rng := RandomNumberGenerator.new()

var _wood: StandardMaterial3D
var _plank: StandardMaterial3D
var _plank_dark: StandardMaterial3D
var _bamboo: StandardMaterial3D
var _weave: StandardMaterial3D
var _thatch: StandardMaterial3D
var _leaf: StandardMaterial3D


## Monta a cabana em (x, z) e devolve o corpo com colisão.
## A altura do piso é escolhida a partir do terreno embaixo dela.
func build(terrain, x: float, z: float, yaw := 0.0) -> StaticBody3D:
	_terrain = terrain
	_origin = Vector3(x, 0.0, z)
	_yaw = yaw
	_rng.seed = 4242
	_make_materials()

	var top := -INF
	for gx in range(-3, 4):
		for gz in range(-3, 5):
			top = maxf(top, _ground(Vector3(gx, 0.0, gz)))
	_floor_y = top + FLOOR_LIFT

	_body = StaticBody3D.new()
	_body.name = "Cabana"
	_body.position = _origin
	_body.rotation.y = yaw

	_build_stilts()
	_build_floor()
	_build_walls()
	_build_porch()
	_build_ramp()
	_build_roof()
	_build_interior()
	return _body


## Ponto na frente da rampa, para teleporte e para a câmera.
func entrance() -> Vector3:
	var p := _to_world(Vector3(0.0, 0.0, _ramp_end_z + 1.2))
	p.y = _terrain.height(p.x, p.z)
	return p


## Altura do piso no mundo.
func floor_height() -> float:
	return _floor_y


# --- utilidades ---

var _ramp_end_z := PORCH_Z + 3.0


func _to_world(local: Vector3) -> Vector3:
	return _origin + Basis(Vector3.UP, _yaw) * local


func _ground(local: Vector3) -> float:
	var w := _to_world(local)
	return _terrain.height(w.x, w.z)


func _make_materials() -> void:
	_wood = Props.rough_material(Color(0.36, 0.27, 0.19), Vector3(1.2, 4.0, 1.2), 1.6, 0.95)
	_plank = Props.rough_material(Color(0.55, 0.44, 0.31), Vector3(3.0, 0.8, 0.8), 1.2)
	_plank_dark = Props.rough_material(Color(0.43, 0.34, 0.24), Vector3(3.0, 0.8, 0.8), 1.2)
	_bamboo = Props.rough_material(Color(0.66, 0.58, 0.36), Vector3(1.0, 6.0, 1.0), 0.8, 0.6)
	# Paredes de taquara: ruído esticado na vertical, como ripas lado a lado.
	_weave = Props.rough_material(Color(0.66, 0.56, 0.36), Vector3(9.0, 0.9, 9.0), 2.2, 0.95)
	# Palha do telhado: ruído esticado na direção da água escorrer.
	_thatch = Props.rough_material(Color(0.42, 0.35, 0.21), Vector3(9.0, 0.6, 0.6), 2.0, 1.0)
	_leaf = StandardMaterial3D.new()
	_leaf.vertex_color_use_as_albedo = true
	_leaf.cull_mode = BaseMaterial3D.CULL_DISABLED
	_leaf.roughness = 0.85
	_leaf.albedo_texture = Props.noise_texture(0.05, false, 31)
	_leaf.uv1_scale = Vector3(1.0, 1.0, 1.0)


## Caixa visível + colisão igual.
func _solid(size: Vector3, pos: Vector3, mat: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := Props.box(_body, size, pos, mat)
	mi.rotation = rot
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	col.position = pos
	col.rotation = rot
	_body.add_child(col)
	return mi


## Vara (bambu ou tronco) entre dois pontos locais.
func _pole(a: Vector3, b: Vector3, radius: float, mat: Material) -> MeshInstance3D:
	var mi := Props.cylinder(_body, radius, radius * 1.08, a.distance_to(b), (a + b) * 0.5, mat)
	var dir := (b - a).normalized()
	if absf(dir.dot(Vector3.UP)) < 0.999:
		var axis := Vector3.UP.cross(dir).normalized()
		mi.basis = Basis(axis, Vector3.UP.angle_to(dir))
	(mi.mesh as CylinderMesh).radial_segments = 8
	return mi


# --- partes ---

func _build_stilts() -> void:
	var xs := [-2.7, 0.0, 2.7]
	var zs := [BACK_Z - 0.2, 0.0, FRONT_Z, PORCH_Z - 0.2]
	var shape := CylinderShape3D.new()
	shape.radius = 0.16
	for x in xs:
		for z in zs:
			var g := _ground(Vector3(x, 0.0, z))
			var a := Vector3(x, g - 0.4, z)
			var b := Vector3(x, _floor_y - 0.05, z)
			_pole(a, b, 0.13 + _rng.randf() * 0.03, _wood)
			shape.height = b.y - a.y
			var col := CollisionShape3D.new()
			col.shape = shape.duplicate()
			col.position = (a + b) * 0.5
			_body.add_child(col)
			# Mão-francesa em X nas palafitas externas, como amarrações de cipó.
			if absf(x) > 1.0 and _floor_y - g > 0.9:
				var side := -signf(x)
				_pole(Vector3(x, g + 0.2, z), Vector3(x + side * 0.9, _floor_y - 0.25, z), 0.05, _wood)
	# Vigas embaixo do piso, ao longo de Z.
	for x in xs:
		_pole(Vector3(x, _floor_y - 0.2, BACK_Z - 0.4), Vector3(x, _floor_y - 0.2, PORCH_Z), 0.12, _wood)


func _build_floor() -> void:
	var z := BACK_Z - 0.4
	var i := 0
	while z < PORCH_Z - 0.01:
		var w := minf(0.3, PORCH_Z - z)
		var mat := _plank if i % 4 != 1 else _plank_dark
		var jitter := _rng.randf_range(-0.08, 0.08)
		Props.box(_body, Vector3(2.0 * (HALF_W + 0.4) + jitter, 0.08, w - 0.025), Vector3(jitter * 0.5, _floor_y - 0.04, z + w * 0.5), mat)
		z += w
		i += 1
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.0 * (HALF_W + 0.4), 0.3, PORCH_Z - BACK_Z + 0.4)
	col.shape = shape
	col.position = Vector3(0.0, _floor_y - 0.15, (BACK_Z - 0.4 + PORCH_Z) * 0.5)
	_body.add_child(col)


## Parede no plano X (ao longo de X, em z fixo) ou no plano Z (ao longo de Z, em x fixo),
## com um vão retangular opcional [centro, largura, base, topo].
func _wall(along_x: bool, fixed: float, from: float, to: float, hole := []) -> void:
	var t := 0.1
	var y0 := _floor_y
	var pieces := []   # [início, fim, base, topo] ao longo da parede
	if hole.is_empty():
		pieces.append([from, to, 0.0, WALL_H])
	else:
		var c: float = hole[0]
		var hw: float = hole[1] * 0.5
		pieces.append([from, c - hw, 0.0, WALL_H])
		pieces.append([c + hw, to, 0.0, WALL_H])
		pieces.append([c - hw, c + hw, hole[3], WALL_H])
		if hole[2] > 0.0:
			pieces.append([c - hw, c + hw, 0.0, hole[2]])
	for p in pieces:
		var len: float = p[1] - p[0]
		var h: float = p[3] - p[2]
		if len <= 0.01 or h <= 0.01:
			continue
		var mid: float = (p[0] + p[1]) * 0.5
		var y: float = y0 + (p[2] + p[3]) * 0.5
		if along_x:
			_solid(Vector3(len, h, t), Vector3(mid, y, fixed), _weave)
		else:
			_solid(Vector3(t, h, len), Vector3(fixed, y, mid), _weave)
	# Moldura de bambu: travessas horizontais por fora e montantes nas pontas.
	var out := 0.08 * signf(fixed) if fixed != 0.0 else 0.08
	for rail_y in [0.15, 1.15, WALL_H - 0.1]:
		var segs := [[from, to]]
		if not hole.is_empty() and rail_y > hole[2] and rail_y < hole[3]:
			segs = [[from, hole[0] - hole[1] * 0.5], [hole[0] + hole[1] * 0.5, to]]
		for s in segs:
			if s[1] - s[0] < 0.05:
				continue
			if along_x:
				_pole(Vector3(s[0], y0 + rail_y, fixed + out), Vector3(s[1], y0 + rail_y, fixed + out), 0.045, _bamboo)
			else:
				_pole(Vector3(fixed + out, y0 + rail_y, s[0]), Vector3(fixed + out, y0 + rail_y, s[1]), 0.045, _bamboo)
	if not hole.is_empty():
		# Batentes do vão.
		for e in [hole[0] - hole[1] * 0.5, hole[0] + hole[1] * 0.5]:
			if along_x:
				_pole(Vector3(e, y0, fixed + out), Vector3(e, y0 + hole[3] + 0.05, fixed + out), 0.05, _bamboo)
			else:
				_pole(Vector3(fixed + out, y0, e), Vector3(fixed + out, y0 + hole[3] + 0.05, e), 0.05, _bamboo)
		var top_y: float = y0 + hole[3]
		if along_x:
			_pole(Vector3(hole[0] - hole[1] * 0.5 - 0.1, top_y, fixed + out), Vector3(hole[0] + hole[1] * 0.5 + 0.1, top_y, fixed + out), 0.05, _bamboo)
		else:
			_pole(Vector3(fixed + out, top_y, hole[0] - hole[1] * 0.5 - 0.1), Vector3(fixed + out, top_y, hole[0] + hole[1] * 0.5 + 0.1), 0.05, _bamboo)
		if hole[2] > 0.0:
			var sill_y: float = y0 + hole[2]
			if along_x:
				_pole(Vector3(hole[0] - hole[1] * 0.5 - 0.1, sill_y, fixed + out), Vector3(hole[0] + hole[1] * 0.5 + 0.1, sill_y, fixed + out), 0.05, _bamboo)
			else:
				_pole(Vector3(fixed + out, sill_y, hole[0] - hole[1] * 0.5 - 0.1), Vector3(fixed + out, sill_y, hole[0] + hole[1] * 0.5 + 0.1), 0.05, _bamboo)


func _gable(z: float) -> void:
	var prism := PrismMesh.new()
	var rise := RIDGE_H - WALL_H - 0.12
	# Largura na base: onde o telhado passa na altura do topo da parede.
	var base_half := EAVE_X * (RIDGE_H - WALL_H) / (RIDGE_H - EAVE_H) - 0.15
	prism.size = Vector3(2.0 * base_half, rise, 0.1)
	prism.material = _weave
	var mi := MeshInstance3D.new()
	mi.mesh = prism
	mi.position = Vector3(0.0, _floor_y + WALL_H + rise * 0.5, z)
	_body.add_child(mi)
	# Varas verticais decorativas no oitão.
	var x := -base_half + 0.4
	while x < base_half - 0.3:
		var h := rise * (1.0 - absf(x) / base_half)
		if h > 0.15:
			_pole(Vector3(x, _floor_y + WALL_H, z + 0.07 * signf(z)), Vector3(x, _floor_y + WALL_H + h, z + 0.07 * signf(z)), 0.03, _bamboo)
		x += 0.45


func _build_walls() -> void:
	# Fundo, com janelinha.
	_wall(true, BACK_Z, -HALF_W, HALF_W, [1.1, 0.9, 1.0, 1.7])
	# Laterais com janela.
	_wall(false, -HALF_W, BACK_Z, FRONT_Z, [0.0, 1.1, 0.95, 1.7])
	_wall(false, HALF_W, BACK_Z, FRONT_Z, [0.0, 1.1, 0.95, 1.7])
	# Frente com a porta.
	_wall(true, FRONT_Z, -HALF_W, HALF_W, [0.0, DOOR_W, 0.0, DOOR_H])
	_gable(BACK_Z)
	_gable(FRONT_Z)
	# Esteios de canto, troncos mais grossos que sobem até o telhado.
	for x in [-HALF_W, HALF_W]:
		for z in [BACK_Z, FRONT_Z]:
			_pole(Vector3(x, _floor_y, z), Vector3(x, _floor_y + _roof_height(absf(x)) - 0.05, z), 0.1, _wood)
	# Cortina de folhas meio enrolada na porta.
	var curtain := _leaf_strip_mesh(DOOR_W * 0.5, 0.55, 14, Color(0.5, 0.45, 0.25))
	var mi := MeshInstance3D.new()
	mi.mesh = curtain
	mi.material_override = _leaf
	mi.position = Vector3(-DOOR_W * 0.5 + 0.05, _floor_y + DOOR_H, FRONT_Z + 0.14)
	_body.add_child(mi)


## Altura do telhado (acima do piso) a uma distância |x| da cumeeira.
func _roof_height(ax: float) -> float:
	return RIDGE_H - (RIDGE_H - EAVE_H) * ax / EAVE_X


func _build_porch() -> void:
	# Esteios da varanda segurando o beiral.
	for x in [-2.7, 2.7]:
		_pole(Vector3(x, _floor_y, PORCH_Z - 0.2), Vector3(x, _floor_y + _roof_height(2.7), PORCH_Z - 0.2), 0.1, _wood)
	# Guarda-corpo de bambu nas laterais e na frente (com abertura para a rampa).
	var rail_h := 0.9
	for x in [-2.75, 2.75]:
		for y in [0.45, rail_h]:
			_pole(Vector3(x, _floor_y + y, FRONT_Z), Vector3(x, _floor_y + y, PORCH_Z - 0.2), 0.04, _bamboo)
		_solid(Vector3(0.1, rail_h, PORCH_Z - FRONT_Z), Vector3(x, _floor_y + rail_h * 0.5, (FRONT_Z + PORCH_Z) * 0.5), _invisible())
		var z := FRONT_Z + 0.5
		while z < PORCH_Z - 0.3:
			_pole(Vector3(x, _floor_y, z), Vector3(x, _floor_y + rail_h, z), 0.03, _bamboo)
			z += 0.5
	for s in [-1.0, 1.0]:
		var a := Vector3(s * 0.75, 0.0, PORCH_Z - 0.2)
		var b := Vector3(s * 2.75, 0.0, PORCH_Z - 0.2)
		for y in [0.45, rail_h]:
			_pole(a + Vector3(0, _floor_y + y, 0), b + Vector3(0, _floor_y + y, 0), 0.04, _bamboo)
		_pole(a + Vector3(0, _floor_y, 0), a + Vector3(0, _floor_y + rail_h + 0.1, 0), 0.06, _bamboo)
		_solid(Vector3(2.0, rail_h, 0.1), Vector3(s * 1.75, _floor_y + rail_h * 0.5, PORCH_Z - 0.2), _invisible())
	# Rede (cama de balanço) entre o esteio da varanda e a parede.
	_hammock(Vector3(-2.55, _floor_y + 1.35, PORCH_Z - 0.3), Vector3(-2.3, _floor_y + 1.35, FRONT_Z + 0.15))


var _invisible_mat: StandardMaterial3D


## Material de caixas que só servem de colisão (o guarda-corpo visível é de varas).
func _invisible() -> StandardMaterial3D:
	if _invisible_mat == null:
		_invisible_mat = StandardMaterial3D.new()
		_invisible_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_invisible_mat.albedo_color = Color(0, 0, 0, 0)
		_invisible_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return _invisible_mat


func _hammock(a: Vector3, b: Vector3) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 12
	var side := (b - a).cross(Vector3.UP).normalized() * 0.4
	var cloth := Color(0.78, 0.7, 0.52)
	for i in n:
		var t0 := float(i) / n
		var t1 := float(i + 1) / n
		var p0 := a.lerp(b, t0) + Vector3.DOWN * sin(t0 * PI) * 0.6
		var p1 := a.lerp(b, t1) + Vector3.DOWN * sin(t1 * PI) * 0.6
		var w0 := side * sin(t0 * PI)
		var w1 := side * sin(t1 * PI)
		for v in [p0 - w0, p0 + w0, p1 + w1, p0 - w0, p1 + w1, p1 - w1]:
			st.set_color(cloth)
			st.set_uv(Vector2(v.x, v.z))
			st.add_vertex(v)
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = _leaf
	_body.add_child(mi)


func _build_ramp() -> void:
	var start := Vector3(0.0, _floor_y, PORCH_Z)
	# Procura o comprimento que dá uma inclinação confortável até o chão.
	var length := 2.0
	var drop := 0.0
	for i in 60:
		var g := _ground(Vector3(0.0, 0.0, PORCH_Z + length))
		drop = _floor_y - g
		if drop / length <= tan(deg_to_rad(27.0)):
			break
		length += 0.25
	_ramp_end_z = PORCH_Z + length
	var slope_len := sqrt(length * length + drop * drop)
	var angle := atan2(drop, length)
	var center := start + Vector3(0.0, -drop * 0.5, length * 0.5)
	# Duas longarinas de tronco.
	for x in [-0.6, 0.6]:
		_pole(Vector3(x, _floor_y - 0.08, PORCH_Z - 0.1), Vector3(x, _floor_y - drop - 0.25, PORCH_Z + length + 0.15), 0.08, _wood)
	# Degraus de tábua sobre a rampa.
	var steps := int(slope_len / 0.32)
	for i in steps:
		var t := (i + 0.5) / steps
		var p := start.lerp(start + Vector3(0.0, -drop, length), t)
		var mi := Props.box(_body, Vector3(1.3, 0.06, 0.26), p + Vector3(0.0, 0.02, 0.0), _plank if i % 2 == 0 else _plank_dark)
		mi.rotation.x = angle * 0.5
	# Colisão: uma prancha lisa inclinada (a Claire sobe andando).
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.3, 0.12, slope_len + 0.2)
	col.shape = shape
	col.position = center + Vector3(0.0, -0.04, 0.0)
	col.rotation.x = angle
	_body.add_child(col)


func _build_roof() -> void:
	var rise := RIDGE_H - EAVE_H
	var slope_len := sqrt(EAVE_X * EAVE_X + rise * rise) + 0.15
	var angle := atan2(rise, EAVE_X)
	var length := ROOF_Z1 - ROOF_Z0
	var zc := (ROOF_Z0 + ROOF_Z1) * 0.5
	for s in [-1.0, 1.0]:
		var pos := Vector3(s * EAVE_X * 0.5, _floor_y + (RIDGE_H + EAVE_H) * 0.5 + 0.05, zc)
		_solid(Vector3(slope_len, 0.16, length), pos, _thatch, Vector3(0.0, 0.0, -s * angle))
		# Caibros de bambu por baixo.
		var z := ROOF_Z0 + 0.3
		while z < ROOF_Z1:
			_pole(Vector3(0.0, _floor_y + RIDGE_H - 0.1, z), Vector3(s * EAVE_X, _floor_y + EAVE_H - 0.1, z), 0.045, _bamboo)
			z += 0.9
	# Cumeeira: um tronco atravessando e um feixe de palha por cima.
	_pole(Vector3(0.0, _floor_y + RIDGE_H - 0.05, ROOF_Z0 - 0.2), Vector3(0.0, _floor_y + RIDGE_H - 0.05, ROOF_Z1 + 0.2), 0.12, _wood)
	# Folhas de palmeira em camadas por cima da palha.
	var mi := MeshInstance3D.new()
	mi.mesh = _roof_leaves(angle, slope_len)
	mi.material_override = _leaf
	_body.add_child(mi)


## Folhas de palmeira sobrepostas como telhas, das duas águas do telhado,
## com a última fileira caindo para fora do beiral como franja.
func _roof_leaves(angle: float, slope_len: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var palette := [
		Color(0.52, 0.45, 0.26), Color(0.47, 0.41, 0.22), Color(0.58, 0.5, 0.3),
		Color(0.38, 0.4, 0.18), Color(0.31, 0.36, 0.15), Color(0.44, 0.37, 0.2),
	]
	for s in [-1.0, 1.0]:
		var down := Vector3(s * cos(angle), -sin(angle), 0.0)        # descendo a água
		var normal := Vector3(s * sin(angle), cos(angle), 0.0)
		var ridge := Vector3(0.0, _floor_y + RIDGE_H + 0.16, 0.0)
		var d := -0.25
		var row := 0
		while d < slope_len + 0.1:
			var z := ROOF_Z0 - 0.15 + _rng.randf() * 0.12
			while z < ROOF_Z1 + 0.15:
				var base := ridge + down * d + normal * (0.05 + row * 0.004) + Vector3(0, 0, z)
				var last := d > slope_len - 0.45
				var length := _rng.randf_range(0.75, 1.05) + (0.35 if last else 0.0)
				var width := _rng.randf_range(0.16, 0.24)
				var droop := _rng.randf_range(0.05, 0.15) + (0.45 if last else 0.0)
				var c: Color = palette[_rng.randi() % palette.size()]
				c = c.lightened(_rng.randf_range(-0.08, 0.08))
				var dir := (down + Vector3(0, 0, _rng.randf_range(-0.15, 0.15))).normalized()
				_blade(st, base, dir, normal, length, width, droop, c)
				z += _rng.randf_range(0.13, 0.19)
			d += 0.3
			row += 1
	# Fileira de folhas cobrindo a cumeeira, uma para cada lado, cruzadas.
	var z2 := ROOF_Z0 - 0.1
	while z2 < ROOF_Z1 + 0.1:
		for s in [-1.0, 1.0]:
			var down := Vector3(s * cos(angle), -sin(angle), 0.0)
			var normal := Vector3(s * sin(angle), cos(angle), 0.0)
			var base := Vector3(-s * 0.06, _floor_y + RIDGE_H + 0.2, z2)
			_blade(st, base, down, normal, 1.0, 0.24, 0.12, palette[_rng.randi() % 3].darkened(0.1))
		z2 += 0.2
	st.generate_normals()
	return st.commit()


## Uma folha: lâmina afinando até a ponta, levemente arqueada e caída.
func _blade(st: SurfaceTool, base: Vector3, dir: Vector3, up: Vector3, length: float, width: float, droop: float, color: Color) -> void:
	var side := dir.cross(up).normalized()
	var segs := 4
	var prev_l := Vector3.ZERO
	var prev_r := Vector3.ZERO
	for i in segs + 1:
		var t := float(i) / segs
		var center := base + dir * length * t + up * (sin(t * PI) * 0.04) - up * droop * t * t
		var w := width * (1.0 - t * 0.85) * (0.6 + 0.4 * sin(minf(t * 3.0, 1.0) * PI * 0.5))
		var l := center - side * w * 0.5
		var r := center + side * w * 0.5
		if i > 0:
			var shade := color.darkened(0.12 * (1.0 - t))
			for v in [prev_l, prev_r, r, prev_l, r, l]:
				st.set_color(shade)
				st.set_uv(Vector2(v.x + v.z, v.y) * 2.0)
				st.add_vertex(v)
		prev_l = l
		prev_r = r


## Faixa de folhas penduradas lado a lado (cortina da porta).
func _leaf_strip_mesh(width: float, length: float, count: int, color: Color) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in count:
		var x := width * float(i) / count
		_blade(st, Vector3(x, 0.0, 0.0), Vector3(_rng.randf_range(-0.1, 0.1), -1.0, 0.0).normalized(), Vector3.BACK, length * _rng.randf_range(0.8, 1.1), 0.12, 0.05, color.lightened(_rng.randf_range(-0.1, 0.1)))
	st.generate_normals()
	return st.commit()


func _build_interior() -> void:
	var y := _floor_y
	# Esteira de palha no chão.
	Props.box(_body, Vector3(2.2, 0.02, 1.6), Vector3(0.3, y + 0.01, 0.2), _weave)
	# Cama: estrado de bambu com colchão de folhas.
	var bx := -1.55
	var bz := -0.6
	for cx in [-0.42, 0.42]:
		for cz in [-0.95, 0.95]:
			_pole(Vector3(bx + cx, y, bz + cz), Vector3(bx + cx, y + 0.4, bz + cz), 0.05, _bamboo)
	_solid(Vector3(0.95, 0.12, 2.0), Vector3(bx, y + 0.42, bz), _bamboo)
	Props.box(_body, Vector3(0.9, 0.12, 1.9), Vector3(bx, y + 0.54, bz), _thatch)
	var pillow := Props.box(_body, Vector3(0.6, 0.12, 0.35), Vector3(bx, y + 0.64, bz - 0.7), Props.material(Color(0.8, 0.74, 0.6)))
	pillow.rotation.y = 0.08
	# Mesa de toco com cuias de coco.
	var tx := 1.4
	var tz := -1.1
	Props.cylinder(_body, 0.32, 0.36, 0.6, Vector3(tx, y + 0.3, tz), _wood)
	Props.cylinder(_body, 0.45, 0.45, 0.07, Vector3(tx, y + 0.63, tz), _plank)
	var shell_mat := Props.rough_material(Color(0.32, 0.22, 0.14), Vector3(4, 4, 4), 1.5)
	for k in 3:
		var bowl := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.11
		sm.height = 0.11
		sm.is_hemisphere = true
		sm.material = shell_mat
		bowl.mesh = sm
		bowl.rotation.x = PI
		bowl.position = Vector3(tx + cos(k * 2.1) * 0.22, y + 0.72, tz + sin(k * 2.1) * 0.22)
		_body.add_child(bowl)
	var col := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 0.45
	shape.height = 0.67
	col.shape = shape
	col.position = Vector3(tx, y + 0.33, tz)
	_body.add_child(col)
	# Cocos num canto.
	var coco_mat := Props.rough_material(Color(0.35, 0.25, 0.15), Vector3(5, 5, 5), 2.0)
	for k in 4:
		var c := MeshInstance3D.new()
		var cm := SphereMesh.new()
		cm.radius = 0.12
		cm.height = 0.22
		cm.radial_segments = 12
		cm.rings = 6
		cm.material = coco_mat
		c.mesh = cm
		c.position = Vector3(2.1 - (k % 2) * 0.24, y + 0.11 + (k / 2) * 0.2, 1.6 - (k % 3) * 0.12)
		_body.add_child(c)
