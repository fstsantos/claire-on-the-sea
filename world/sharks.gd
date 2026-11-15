extends Node3D
## Tubarões de várias espécies nadando em volta da ilha. São mansos: só vagam,
## desviam do raso e da Claire, e nunca atacam. Malhas geradas por código.

signal spotted(species_name: String)

const SharkShader := preload("res://world/shark.gdshader")

## Fração do comprimento ocupada pelo corpo; o resto é a nadadeira da cauda.
const BODY := 0.86
const RINGS := 30
const SIDES := 16
## Raio máximo (a partir do centro da ilha) em que os tubarões circulam.
const RANGE := 222.0

## len: comprimento (m) · girth: raio/comprimento · depth: 0 = superfície, 1 = fundo
const SPECIES := [
	{
		"name": "Tubarão-baleia", "count": 1, "len": 8.5, "girth": 0.085, "wide": 1.25, "tall": 0.95,
		"head_wide": 0.35, "head_flat": 0.3, "nose": 0.33, "peak": 0.3, "ped": 0.13,
		"dorsal": 0.085, "dorsal_u": 0.5, "pect": 0.17, "caud_up": 0.2, "caud_lo": 0.15,
		"top": Color(0.2, 0.27, 0.36), "belly": Color(0.86, 0.88, 0.88), "mark": Color(0.82, 0.88, 0.9),
		"spots": 0.9, "speed": 1.1, "depth": 0.3, "amp": 0.035,
	},
	{
		"name": "Tubarão-branco", "count": 2, "len": 4.6, "girth": 0.1, "wide": 1.0, "tall": 1.08,
		"nose": 0.8, "peak": 0.36, "ped": 0.1,
		"dorsal": 0.105, "dorsal_u": 0.36, "pect": 0.17, "caud_up": 0.19, "caud_lo": 0.16,
		"top": Color(0.33, 0.36, 0.4), "belly": Color(0.93, 0.93, 0.91),
		"speed": 2.2, "depth": 0.25, "amp": 0.05,
	},
	{
		"name": "Tubarão-tigre", "count": 2, "len": 3.9, "girth": 0.092, "wide": 1.1, "tall": 1.0,
		"head_wide": 0.25, "nose": 0.4, "peak": 0.3, "ped": 0.09,
		"dorsal": 0.09, "dorsal_u": 0.34, "pect": 0.16, "caud_up": 0.23, "caud_lo": 0.1,
		"top": Color(0.4, 0.43, 0.38), "belly": Color(0.9, 0.89, 0.83), "mark": Color(0.13, 0.15, 0.14),
		"stripes": 1.0, "speed": 1.7, "depth": 0.55, "amp": 0.06,
	},
	{
		"name": "Tubarão-martelo", "count": 3, "len": 3.2, "girth": 0.075, "wide": 0.95, "tall": 1.1,
		"nose": 0.5, "peak": 0.34, "ped": 0.1, "hammer": true,
		"dorsal": 0.14, "dorsal_u": 0.33, "pect": 0.13, "caud_up": 0.24, "caud_lo": 0.1,
		"top": Color(0.45, 0.42, 0.35), "belly": Color(0.92, 0.91, 0.86),
		"speed": 1.9, "depth": 0.5, "amp": 0.065,
	},
	{
		"name": "Tubarão-azul", "count": 2, "len": 2.9, "girth": 0.062, "wide": 1.0, "tall": 1.0,
		"nose": 0.85, "peak": 0.36, "ped": 0.1,
		"dorsal": 0.07, "dorsal_u": 0.42, "pect": 0.23, "caud_up": 0.22, "caud_lo": 0.1,
		"top": Color(0.1, 0.24, 0.55), "belly": Color(0.95, 0.96, 0.97),
		"speed": 2.4, "depth": 0.15, "amp": 0.07,
	},
	{
		"name": "Tubarão-lixa", "count": 2, "len": 2.5, "girth": 0.085, "wide": 1.3, "tall": 0.8,
		"head_wide": 0.3, "head_flat": 0.25, "nose": 0.35, "peak": 0.3, "ped": 0.14,
		"dorsal": 0.075, "dorsal_u": 0.5, "pect": 0.15, "caud_up": 0.1, "caud_lo": 0.02, "caud_long": true,
		"top": Color(0.5, 0.38, 0.24), "belly": Color(0.85, 0.78, 0.64),
		"speed": 0.8, "depth": 1.0, "amp": 0.07,
	},
	{
		"name": "Tubarão-galha-preta", "count": 4, "len": 1.7, "girth": 0.085, "wide": 1.0, "tall": 1.05,
		"nose": 0.55, "peak": 0.35, "ped": 0.1,
		"dorsal": 0.12, "dorsal_u": 0.36, "pect": 0.16, "caud_up": 0.2, "caud_lo": 0.12,
		"top": Color(0.6, 0.52, 0.4), "belly": Color(0.95, 0.94, 0.9),
		"tips": 1.0, "speed": 1.6, "depth": 0.2, "amp": 0.075,
	},
]

var world: Node3D
var terrain: Node3D
## Multiplicador de velocidade de todos os tubarões (console).
var speed_scale := 1.0

var _sharks: Array = []
var _seen := {}
var _meshes := {}
var _rng := RandomNumberGenerator.new()
var _t := 0.0


func populate(p_world: Node3D, p_terrain: Node3D, rng: RandomNumberGenerator) -> void:
	world = p_world
	terrain = p_terrain
	_rng = rng
	for i in SPECIES.size():
		for k in SPECIES[i].count:
			spawn(i)


## Índice da espécie cujo nome contém o texto (sem acentos), ou -1.
func species_index(query: String) -> int:
	for i in SPECIES.size():
		if _plain(SPECIES[i].name).contains(_plain(query)):
			return i
	return -1


static func _plain(text: String) -> String:
	text = text.to_lower()
	var from := "áàâãéêíóôõúç"
	var to := "aaaaeeiooouc"
	for i in from.length():
		text = text.replace(from[i], to[i])
	return text


func all() -> Array:
	return _sharks


## Cria um tubarão da espécie; perto de `around` se der, senão em qualquer ponto fundo.
func spawn(index: int, around := Vector3.INF, radius := 40.0) -> bool:
	var sp: Dictionary = SPECIES[index]
	var hh: float = sp.len * sp.girth * sp.tall
	var need := hh * 2.6 + 0.6
	var pos := Vector3.INF
	for attempt in 140:
		var a := _rng.randf() * TAU
		var x := 0.0
		var z := 0.0
		if around.is_finite() and attempt < 70:
			var r := _rng.randf_range(8.0, radius)
			x = around.x + cos(a) * r
			z = around.z + sin(a) * r
		else:
			var r := _rng.randf_range(95.0, RANGE - 15.0)
			x = cos(a) * r
			z = sin(a) * r
		if Vector2(x, z).length() < RANGE - 5.0 and terrain.height(x, z) < -need - 0.4:
			pos = Vector3(x, -need * 0.5, z)
			break
	if not pos.is_finite():
		return false
	if not _meshes.has(index):
		_meshes[index] = _build_mesh(sp)
	var mi := MeshInstance3D.new()
	mi.mesh = _meshes[index]
	mi.set_instance_shader_parameter("phase", _rng.randf() * TAU)
	mi.position = pos
	add_child(mi)
	_sharks.append({
		"node": mi, "name": sp.name, "species": index, "len": sp.len, "hh": hh, "need": need,
		"pos": pos, "yaw": _rng.randf() * TAU, "yaw_rate": 0.0, "pitch": 0.0,
		"speed": sp.speed * _rng.randf_range(0.85, 1.15), "depth": sp.depth,
		"seed": _rng.randf() * 100.0, "avoid": 0.0,
	})
	return true


## Remove os tubarões da espécie (ou todos, com -1) e devolve quantos saíram.
func remove(index := -1) -> int:
	var kept: Array = []
	var n := 0
	for s in _sharks:
		if index < 0 or s.species == index:
			s.node.queue_free()
			n += 1
		else:
			kept.append(s)
	_sharks = kept
	return n


func _process(delta: float) -> void:
	_t += delta
	var wl: float = world.water_level()
	var player: Node3D = world.player
	for s in _sharks:
		var pos: Vector3 = s.pos
		var yaw: float = s.yaw
		var seed: float = s.seed
		var fwd := Vector3(-sin(yaw), 0.0, -cos(yaw))

		# vagar: curvas lentas e irregulares
		var want := sin(_t * 0.13 + seed) * 0.22 + sin(_t * 0.31 + seed * 2.7) * 0.14

		# desviar do raso e do limite do mar
		var look: float = s.len * 1.5 + 6.0
		if _score(pos + fwd * look, s.need) < 0.0:
			if s.avoid == 0.0:
				var left := _score(pos + fwd.rotated(Vector3.UP, 1.0) * look, s.need)
				var right := _score(pos + fwd.rotated(Vector3.UP, -1.0) * look, s.need)
				s.avoid = 1.0 if left >= right else -1.0
			want = s.avoid * 1.1
		else:
			s.avoid = 0.0

		# manso: abre caminho quando a Claire chega perto
		if player != null:
			var to_p := player.global_position - pos
			var near: float = s.len * 0.6 + 3.0
			if to_p.length() < near and to_p.dot(fwd) > 0.0:
				want += (-1.0 if fwd.cross(to_p).y > 0.0 else 1.0) * 0.9
			if not _seen.has(s.name) and to_p.length() < s.len + 9.0:
				_seen[s.name] = true
				spotted.emit(s.name)

		s.yaw_rate = lerpf(s.yaw_rate, want, 1.0 - exp(-delta * 2.0))
		yaw += s.yaw_rate * delta * maxf(speed_scale, 1.0)
		pos += fwd * s.speed * speed_scale * delta

		# profundidade preferida, entre o fundo e a superfície
		var lo: float = terrain.height(pos.x, pos.z) + s.hh * 1.2 + 0.3
		var hi: float = wl - s.hh - 0.12
		var frac := clampf(s.depth + sin(_t * 0.07 + seed) * 0.25, 0.0, 1.0)
		var target := hi if lo > hi else lerpf(hi, lo, frac)
		var new_y := lerpf(pos.y, target, 1.0 - exp(-delta * 0.7))
		var climb := (new_y - pos.y) / maxf(delta, 0.0001)
		pos.y = new_y
		s.pitch = lerpf(s.pitch, clampf(atan2(climb, s.speed), -0.5, 0.5), 1.0 - exp(-delta * 3.0))

		s.pos = pos
		s.yaw = yaw
		var node: Node3D = s.node
		node.position = pos
		node.rotation = Vector3(s.pitch, yaw, s.yaw_rate * 0.35)


## Positivo quando o ponto é fundo o bastante e está dentro do limite do mar.
func _score(p: Vector3, need: float) -> float:
	var out := maxf(Vector2(p.x, p.z).length() - RANGE, 0.0)
	return -terrain.height(p.x, p.z) - need - out


# --- malha ---

func _radius(sp: Dictionary, u: float) -> float:
	var p: float = sp.peak
	if u < p:
		var k := 1.0 - u / p
		return pow(maxf(1.0 - k * k, 0.0), sp.nose)
	var v := (u - p) / (1.0 - p)
	return sp.ped + (1.0 - sp.ped) * (0.5 + 0.5 * cos(PI * v))


## Meia largura e meia altura do corpo na posição u (0 = focinho, 1 = base da cauda).
func _half(sp: Dictionary, u: float) -> Vector2:
	var r: float = _radius(sp, u) * sp.len * sp.girth
	var head := 1.0 - smoothstep(0.0, 0.4, u)
	var w: float = r * sp.wide * (1.0 + sp.get("head_wide", 0.0) * head) * lerpf(1.0, 0.6, smoothstep(0.6, 1.0, u))
	var h: float = r * sp.tall * (1.0 - sp.get("head_flat", 0.0) * head)
	return Vector2(w, h)


func _z(sp: Dictionary, u: float) -> float:
	return (-0.5 + u * BODY) * sp.len


func _vert(st: SurfaceTool, sp: Dictionary, p: Vector3, v: float, color: Color) -> void:
	st.set_color(color)
	st.set_uv(Vector2(v, p.z / sp.len + 0.5))
	st.add_vertex(p)


## Nadadeira plana: leque de triângulos a partir de pts[0].
func _fin(st: SurfaceTool, sp: Dictionary, pts: Array, tip: Array) -> void:
	for i in range(1, pts.size() - 1):
		for k in [0, i, i + 1]:
			_vert(st, sp, pts[k], 1.0, Color(0.0, tip[k], 0.0, 1.0))


## Nadadeira no plano central (dorsal: side = 1, anal: side = -1).
func _mid_fin(st: SurfaceTool, sp: Dictionary, u1: float, span: float, height: float, side: float) -> void:
	var l: float = sp.len
	var u2 := u1 + span
	var y1 := _half(sp, u1).y * 0.85 * side
	var y2 := _half(sp, u2).y * side
	var y3 := _half(sp, u2 + span * 0.25).y * 0.8 * side
	_fin(st, sp, [
		Vector3(0, y1, _z(sp, u1)),
		Vector3(0, y2 + height * side, _z(sp, u2) + 0.02 * l),
		Vector3(0, y2 + height * 0.25 * side, _z(sp, u2) + 0.004 * l),
		Vector3(0, y3, _z(sp, u2 + span * 0.25)),
	], [0.0, 1.0, 0.3, 0.0])


## Par de nadadeiras laterais (peitorais, pélvicas).
func _side_fins(st: SurfaceTool, sp: Dictionary, u1: float, span: float, length: float) -> void:
	var u2 := u1 + span
	var h1 := _half(sp, u1)
	var h2 := _half(sp, u2)
	for side in [-1.0, 1.0]:
		var a := Vector3(side * h1.x * 0.75, -h1.y * 0.5, _z(sp, u1))
		var b := Vector3(side * h2.x * 0.75, -h2.y * 0.5, _z(sp, u2))
		var t := Vector3(side * (h1.x + length * 0.85), -h1.y * 0.5 - length * 0.38, _z(sp, u2) + length * 0.5)
		var n := b.lerp(t, 0.4).lerp(a, 0.12)
		_fin(st, sp, [a, t, n, b], [0.0, 1.0, 0.3, 0.0])


func _eye(st: SurfaceTool, sp: Dictionary, c: Vector3, r: float) -> void:
	var col := Color(0, 0, 0, 0)
	var seg := 6
	var rings := 4
	for j in rings:
		for i in seg:
			var q := []
			for d in [[0, 0], [1, 0], [1, 1], [0, 1]]:
				var lat := PI * float(j + d[1]) / rings
				var lon := TAU * float(i + d[0]) / seg
				q.append(c + Vector3(sin(lat) * cos(lon), cos(lat), sin(lat) * sin(lon)) * r)
			for k in [0, 1, 2, 0, 2, 3]:
				_vert(st, sp, q[k], 1.0, col)


## Tubo fechado a partir de anéis de pontos (cada anel: Array de [Vector3, v]).
func _loft(st: SurfaceTool, sp: Dictionary, rings: Array) -> void:
	var body := Color(1, 0, 0, 1)
	for i in rings.size() - 1:
		var ra: Array = rings[i]
		var rb: Array = rings[i + 1]
		var m := ra.size()
		for j in m:
			var j2 := (j + 1) % m
			var q := [ra[j], rb[j], rb[j2], ra[j2]]
			for k in [0, 1, 2, 0, 2, 3]:
				_vert(st, sp, q[k][0], q[k][1], body)


func _build_mesh(sp: Dictionary) -> ArrayMesh:
	var l: float = sp.len
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	# corpo
	var rings := []
	for i in RINGS + 2:
		var u := minf(float(i) / RINGS, 1.0)
		var half := _half(sp, u)
		var z := _z(sp, u)
		if i > RINGS:
			half *= 0.02
			z += 0.03 * l
		var ring := []
		for j in SIDES:
			var a := TAU * j / SIDES
			var cy := cos(a)
			ring.append([Vector3(sin(a) * half.x, cy * half.y * (1.0 if cy > 0.0 else 0.86), z), cy])
		rings.append(ring)
	_loft(st, sp, rings)

	# olhos e, no martelo, a cabeça larga
	var eye_r := maxf(l * 0.009, 0.022)
	if sp.get("hammer", false):
		var hw := l * 0.15
		var scales := [0.03, 0.75, 1.0, 0.9, 0.82, 0.8, 0.82, 0.9, 1.0, 0.75, 0.03]
		var slab := []
		for i in scales.size():
			var f := float(i) / (scales.size() - 1) * 2.0 - 1.0
			var zc := _z(sp, 0.04) + 0.025 * l * f * f
			var ring := []
			for j in 10:
				var a := TAU * j / 10
				ring.append([Vector3(f * hw, cos(a) * 0.014 * l * scales[i], zc + sin(a) * 0.036 * l * scales[i]), cos(a)])
			slab.append(ring)
		_loft(st, sp, slab)
		for side in [-1.0, 1.0]:
			_eye(st, sp, Vector3(side * hw * 0.99, 0.0, _z(sp, 0.04) + 0.02 * l), eye_r)
	else:
		var eh := _half(sp, 0.1)
		for side in [-1.0, 1.0]:
			_eye(st, sp, Vector3(side * eh.x * 0.9, eh.y * 0.3, _z(sp, 0.1)), eye_r)

	# nadadeiras
	_mid_fin(st, sp, sp.dorsal_u, 0.13, sp.dorsal * l, 1.0)
	_mid_fin(st, sp, 0.76, 0.05, 0.03 * l, 1.0)
	_mid_fin(st, sp, 0.78, 0.045, 0.028 * l, -1.0)
	_side_fins(st, sp, 0.27, 0.11, sp.pect * l)
	_side_fins(st, sp, 0.62, 0.05, 0.05 * l)

	# cauda: lobo de cima maior que o de baixo
	var ph := _half(sp, 0.95).y
	var up: float = sp.caud_up * l
	var down: float = sp.caud_lo * l
	var long_tail: bool = sp.get("caud_long", false)
	var notch := Vector3(0, (up - down) * 0.12, 0.4 * l)
	_fin(st, sp, [
		notch,
		Vector3(0, -down, (0.43 if long_tail else 0.45) * l),
		Vector3(0, -ph, _z(sp, 0.92)),
		Vector3(0, ph, _z(sp, 0.92)),
		Vector3(0, up, 0.5 * l),
	], [0.2, 1.0, 0.0, 0.0, 1.0])

	st.generate_normals()
	var mesh := st.commit()

	var mat := ShaderMaterial.new()
	mat.shader = SharkShader
	mat.set_shader_parameter("top_color", sp.top)
	mat.set_shader_parameter("belly_color", sp.belly)
	mat.set_shader_parameter("mark_color", sp.get("mark", Color(0.1, 0.1, 0.1)))
	mat.set_shader_parameter("stripes", sp.get("stripes", 0.0))
	mat.set_shader_parameter("spots", sp.get("spots", 0.0))
	mat.set_shader_parameter("tips", sp.get("tips", 0.0))
	mat.set_shader_parameter("body_len", l)
	mat.set_shader_parameter("swim_amp", sp.amp)
	mat.set_shader_parameter("swim_rate", 1.2 + sp.speed * 1.6 / sqrt(l))
	mesh.surface_set_material(0, mat)
	return mesh
