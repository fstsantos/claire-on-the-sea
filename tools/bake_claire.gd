extends SceneTree
## Esculpe a Claire por código e salva a malha pronta em player/claire/.
##
## Cada parte (pele, camiseta, saia, cabelo) é um campo de distância: formas
## simples unidas com suavização, convertidas em malha lisa ("surface nets").
## Os vértices recebem pesos dos ossos do esqueleto da Universal Animation
## Library, para a malha acompanhar as animações dela.
##
## Para refazer:  godot --headless --path . --script tools/bake_claire.gd

const CELL := 0.011
const COARSE := 4
const OUT_MESH := "res://player/claire/claire_mesh.res"
const OUT_SKIN := "res://player/claire/claire_skin.res"

const HEAD_C := Vector3(0.0, 1.73, 0.02)
const HEAD_R := Vector3(0.2, 0.205, 0.195)
# articulações do lado esquerdo (+X); o lado direito é espelhado
const UA := Vector3(0.192, 1.441, -0.065)
const FA := Vector3(0.466, 1.441, -0.070)
const HA := Vector3(0.739, 1.441, -0.065)
const TH := Vector3(0.089, 0.932, 0.001)
const SH := Vector3(0.089, 0.532, -0.001)
const FT := Vector3(0.089, 0.104, -0.036)
const TOE := Vector3(0.089, 0.015, 0.113)
const SKIRT_TOP := 1.02
const SKIRT_BOTTOM := 0.66

var _skeleton: Skeleton3D
var _segs: Array = []
var _mesh := ArrayMesh.new()
var _done := false


func _process(_delta: float) -> bool:
	if not _done:
		_done = true
		_bake()
	return true


# ---------- campos de distância ----------

func _capsule(p: Vector3, a: Vector3, b: Vector3, r: float) -> float:
	var pa := p - a
	var ba := b - a
	var h := clampf(pa.dot(ba) / ba.length_squared(), 0.0, 1.0)
	return (pa - ba * h).length() - r


func _ellipsoid(p: Vector3, c: Vector3, r: Vector3) -> float:
	return (((p - c) / r).length() - 1.0) * minf(r.x, minf(r.y, r.z))


func _smin(a: float, b: float, k: float) -> float:
	var h := clampf(0.5 + 0.5 * (b - a) / k, 0.0, 1.0)
	return lerpf(b, a, h) - k * h * (1.0 - h)


func _skin(p: Vector3) -> float:
	var q := Vector3(absf(p.x), p.y, p.z)
	if p.y > 1.42 and q.x < 0.3:
		var d := _ellipsoid(p, HEAD_C, HEAD_R)
		d = _smin(d, _ellipsoid(p, Vector3(0.0, 1.7, 0.212), Vector3(0.024, 0.02, 0.024)), 0.02)
		d = _smin(d, _ellipsoid(q, Vector3(0.198, 1.72, 0.0), Vector3(0.028, 0.045, 0.03)), 0.01)
		d = _smin(d, _capsule(p, Vector3(0.0, 1.44, -0.012), Vector3(0.0, 1.6, 0.0), 0.048), 0.02)
		return d
	if p.y > 1.2:
		var d := _capsule(q, UA, FA, 0.05)
		d = _smin(d, _capsule(q, FA, HA, 0.043), 0.02)
		d = _smin(d, _ellipsoid(q, HA + Vector3(0.07, 0.0, 0.005), Vector3(0.078, 0.033, 0.053)), 0.025)
		d = _smin(d, _capsule(q, HA + Vector3(0.03, 0.0, 0.04), HA + Vector3(0.075, -0.005, 0.085), 0.02), 0.015)
		return d
	var d := _capsule(q, TH + Vector3(0.0, 0.04, 0.0), SH, 0.074)
	d = _smin(d, _capsule(q, SH, FT, 0.056), 0.03)
	d = _smin(d, _capsule(q, FT + Vector3(0.0, -0.045, 0.02), TOE + Vector3(0.0, 0.025, 0.03), 0.05), 0.03)
	return d


func _shirt(p: Vector3) -> float:
	var q := Vector3(absf(p.x), p.y, p.z)
	var s := Vector3(p.x / 1.3, p.y, p.z)
	var d := _capsule(s, Vector3(0.0, 1.03, -0.015), Vector3(0.0, 1.36, -0.01), 0.125)
	d = _smin(d, _capsule(p, Vector3(-0.15, 1.425, -0.04), Vector3(0.15, 1.425, -0.04), 0.07), 0.04)
	d = _smin(d, _capsule(q, Vector3(0.17, 1.44, -0.06), UA.lerp(FA, 0.5), 0.066), 0.03)
	d = maxf(d, 0.975 - p.y)
	d = maxf(d, q.x - 0.315)
	d = maxf(d, -_capsule(p, Vector3(0.0, 1.5, 0.0), Vector3(0.0, 1.62, 0.005), 0.064))
	return d


func _skirt(p: Vector3) -> float:
	var t := clampf((SKIRT_TOP - p.y) / (SKIRT_TOP - SKIRT_BOTTOM), 0.0, 1.0)
	var r := lerpf(0.15, 0.27, t)
	var rad := Vector2(p.x, p.z * 1.12 + 0.01).length() - r
	return maxf(rad, maxf(p.y - SKIRT_TOP, SKIRT_BOTTOM - p.y)) - 0.008


func _hair(p: Vector3) -> float:
	var d := _ellipsoid(p, Vector3(0.0, 1.755, -0.012), Vector3(0.224, 0.218, 0.228))
	d = _smin(d, _ellipsoid(p, Vector3(0.0, 1.655, -0.03), Vector3(0.238, 0.17, 0.205)), 0.04)
	# abertura do rosto, inclinada para a franja cair de lado
	var c := Vector3(0.0, 1.655, 0.235)
	var rel := (p - c).rotated(Vector3.BACK, 0.2)
	d = maxf(d, -_ellipsoid(rel, Vector3.ZERO, Vector3(0.168, 0.19, 0.21)))
	return d


# ---------- malha a partir do campo (surface nets) ----------

func _build(f: Callable, lo: Vector3, hi: Vector3) -> Dictionary:
	var size := (hi - lo) / CELL
	var sx := int(ceil(size.x)) + 1
	var sy := int(ceil(size.y)) + 1
	var sz := int(ceil(size.z)) + 1
	var vals := PackedFloat32Array()
	vals.resize(sx * sy * sz)

	# Passo grosso: blocos longe da superfície recebem um valor constante.
	for ck in range(0, sz, COARSE):
		for cj in range(0, sy, COARSE):
			for ci in range(0, sx, COARSE):
				var center := lo + Vector3(ci + COARSE * 0.5, cj + COARSE * 0.5, ck + COARSE * 0.5) * CELL
				var dc: float = f.call(center)
				var far := absf(dc) > COARSE * CELL * 1.9
				for k in range(ck, mini(ck + COARSE, sz)):
					for j in range(cj, mini(cj + COARSE, sy)):
						var row := sx * (j + sy * k)
						for i in range(ci, mini(ci + COARSE, sx)):
							vals[row + i] = dc if far else f.call(lo + Vector3(i, j, k) * CELL)

	var cx := sx - 1
	var cy := sy - 1
	var cz := sz - 1
	var cell_vert := PackedInt32Array()
	cell_vert.resize(cx * cy * cz)
	cell_vert.fill(-1)
	var verts := PackedVector3Array()
	var corner := [Vector3(0, 0, 0), Vector3(1, 0, 0), Vector3(0, 1, 0), Vector3(1, 1, 0), Vector3(0, 0, 1), Vector3(1, 0, 1), Vector3(0, 1, 1), Vector3(1, 1, 1)]
	var edges := [[0, 1], [2, 3], [4, 5], [6, 7], [0, 2], [1, 3], [4, 6], [5, 7], [0, 4], [1, 5], [2, 6], [3, 7]]
	var off := [0, 1, sx, sx + 1, sx * sy, sx * sy + 1, sx * sy + sx, sx * sy + sx + 1]
	var v := [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
	for k in cz:
		for j in cy:
			for i in cx:
				var base := i + sx * (j + sy * k)
				var neg := 0
				for c in 8:
					v[c] = vals[base + off[c]]
					if v[c] < 0.0:
						neg += 1
				if neg == 0 or neg == 8:
					continue
				var acc := Vector3.ZERO
				var cnt := 0
				for e in edges:
					var a: float = v[e[0]]
					var b: float = v[e[1]]
					if (a < 0.0) != (b < 0.0):
						acc += (corner[e[0]] as Vector3).lerp(corner[e[1]], a / (a - b))
						cnt += 1
				cell_vert[i + cx * (j + cy * k)] = verts.size()
				verts.append(lo + (Vector3(i, j, k) + acc / cnt) * CELL)

	# normais pelo gradiente do campo
	var normals := PackedVector3Array()
	normals.resize(verts.size())
	var e := CELL * 0.5
	for n in verts.size():
		var p := verts[n]
		var g := Vector3(
			f.call(p + Vector3(e, 0, 0)) - f.call(p - Vector3(e, 0, 0)),
			f.call(p + Vector3(0, e, 0)) - f.call(p - Vector3(0, e, 0)),
			f.call(p + Vector3(0, 0, e)) - f.call(p - Vector3(0, 0, e)))
		normals[n] = g.normalized() if g.length_squared() > 0.0 else Vector3.UP

	# um quadrilátero para cada aresta da grade que cruza a superfície
	var indices := PackedInt32Array()
	for k in range(1, cz):
		for j in range(1, cy):
			for i in range(1, cx):
				var base := i + sx * (j + sy * k)
				var v0 := vals[base]
				var quads := []
				if (v0 < 0.0) != (vals[base + 1] < 0.0):
					quads.append([[i, j - 1, k - 1], [i, j, k - 1], [i, j, k], [i, j - 1, k]])
				if (v0 < 0.0) != (vals[base + sx] < 0.0):
					quads.append([[i - 1, j, k - 1], [i, j, k - 1], [i, j, k], [i - 1, j, k]])
				if (v0 < 0.0) != (vals[base + sx * sy] < 0.0):
					quads.append([[i - 1, j - 1, k], [i, j - 1, k], [i, j, k], [i - 1, j, k]])
				for quad in quads:
					var id := []
					for c in quad:
						id.append(cell_vert[c[0] + cx * (c[1] + cy * c[2])])
					if id.has(-1):
						continue
					for tri in [[id[0], id[1], id[2]], [id[0], id[2], id[3]]]:
						var a := verts[tri[0]]
						var b := verts[tri[1]]
						var c := verts[tri[2]]
						# o Godot usa faces no sentido horário
						if (c - a).cross(b - a).dot(normals[tri[0]] + normals[tri[1]] + normals[tri[2]]) >= 0.0:
							indices.append_array([tri[0], tri[1], tri[2]])
						else:
							indices.append_array([tri[0], tri[2], tri[1]])
	return {"verts": verts, "normals": normals, "indices": indices}


## Elipsoide simples (olhos, sobrancelhas, boca), somado a uma superfície já existente.
func _add_ellipsoid(surf: Dictionary, c: Vector3, r: Vector3, roll := 0.0, yaw := 0.0) -> void:
	var verts: PackedVector3Array = surf.verts
	var normals: PackedVector3Array = surf.normals
	var indices: PackedInt32Array = surf.indices
	var start := verts.size()
	var rings := 10
	var segs := 16
	var basis := Basis(Vector3.UP, yaw) * Basis(Vector3.BACK, roll)
	for i in rings + 1:
		var lat := PI * i / rings
		for j in segs + 1:
			var lon := TAU * j / segs
			var n := Vector3(sin(lat) * cos(lon), cos(lat), sin(lat) * sin(lon))
			verts.append(c + basis * (n * r))
			normals.append((basis * (n / r)).normalized())
	for i in rings:
		for j in segs:
			var a := start + i * (segs + 1) + j
			var b := a + segs + 1
			indices.append_array([a, a + 1, b, a + 1, b + 1, b])
	surf.verts = verts
	surf.normals = normals
	surf.indices = indices


func _empty() -> Dictionary:
	return {"verts": PackedVector3Array(), "normals": PackedVector3Array(), "indices": PackedInt32Array()}


# ---------- pesos dos ossos ----------

func _bone(bone_name: String) -> int:
	return _skeleton.find_bone(bone_name)


func _pos(bone_name: String) -> Vector3:
	return _skeleton.get_bone_global_rest(_bone(bone_name)).origin


func _setup_segments() -> void:
	var chain := [
		["DEF-hips", "DEF-spine.001", "torso"], ["DEF-spine.001", "DEF-spine.002", "torso"],
		["DEF-spine.002", "DEF-spine.003", "torso"], ["DEF-spine.003", "DEF-neck", "torso"],
		["DEF-neck", "DEF-head", "neck"],
	]
	for c in chain:
		_segs.append({"bone": _bone(c[0]), "a": _pos(c[0]), "b": _pos(c[1]), "side": 0, "group": c[2]})
	_segs.append({"bone": _bone("DEF-head"), "a": _pos("DEF-head"), "b": _pos("DEF-head") + Vector3(0, 0.2, 0), "side": 0, "group": "neck"})
	for side in [["L", 1], ["R", -1]]:
		var s: String = side[0]
		var limb := [
			["DEF-shoulder." + s, "DEF-upper_arm." + s, "arm"], ["DEF-upper_arm." + s, "DEF-forearm." + s, "arm"],
			["DEF-forearm." + s, "DEF-hand." + s, "arm"], ["DEF-thigh." + s, "DEF-shin." + s, "leg"],
			["DEF-shin." + s, "DEF-foot." + s, "leg"], ["DEF-foot." + s, "DEF-toe." + s, "leg"],
		]
		for c in limb:
			_segs.append({"bone": _bone(c[0]), "a": _pos(c[0]), "b": _pos(c[1]), "side": side[1], "group": c[2]})
		var hand := _pos("DEF-hand." + s)
		_segs.append({"bone": _bone("DEF-hand." + s), "a": hand, "b": hand + Vector3(0.13 * side[1], 0, 0), "side": side[1], "group": "arm"})
		var toe := _pos("DEF-toe." + s)
		_segs.append({"bone": _bone("DEF-toe." + s), "a": toe, "b": toe + Vector3(0, 0, 0.07), "side": side[1], "group": "leg"})


## Pesos por proximidade aos ossos dos grupos permitidos (até 4 por vértice).
func _weights_near(p: Vector3, groups: Array) -> Array:
	var found := []
	for s in _segs:
		if not groups.has(s.group):
			continue
		if (s.side == 1 and p.x < -0.02) or (s.side == -1 and p.x > 0.02):
			continue
		var d := _capsule(p, s.a, s.b, 0.0)
		found.append([1.0 / pow(d * d + 0.00002, 2.0), s.bone])
	found.sort_custom(func(a, b): return a[0] > b[0])
	var out := []
	var total := 0.0
	for i in mini(4, found.size()):
		total += found[i][0]
	for i in mini(4, found.size()):
		out.append([found[i][1], found[i][0] / total])
	return out


func _w_skin(p: Vector3) -> Array:
	if p.y > 1.62 and absf(p.x) < 0.3:
		return [[_bone("DEF-head"), 1.0]]
	if p.y > 1.42 and absf(p.x) < 0.12:
		return _weights_near(p, ["neck", "torso"])
	if p.y > 1.2:
		return _weights_near(p, ["arm"])
	return _weights_near(p, ["leg"])


func _w_shirt(p: Vector3) -> Array:
	return _weights_near(p, ["torso", "arm"])


func _w_skirt(p: Vector3) -> Array:
	var t := clampf((SKIRT_TOP - p.y) / (SKIRT_TOP - SKIRT_BOTTOM), 0.0, 1.0)
	var wl := 0.6 * t * smoothstep(-0.03, 0.07, p.x)
	var wr := 0.6 * t * smoothstep(-0.03, 0.07, -p.x)
	return [[_bone("DEF-hips"), 1.0 - wl - wr], [_bone("DEF-thigh.L"), wl], [_bone("DEF-thigh.R"), wr]]


func _w_head(_p: Vector3) -> Array:
	return [[_bone("DEF-head"), 1.0]]


func _commit(surf: Dictionary, weights: Callable, color: Color, roughness: float, surface_name: String) -> void:
	var verts: PackedVector3Array = surf.verts
	var bones := PackedInt32Array()
	var wts := PackedFloat32Array()
	bones.resize(verts.size() * 4)
	wts.resize(verts.size() * 4)
	for n in verts.size():
		var w: Array = weights.call(verts[n])
		for i in 4:
			bones[n * 4 + i] = w[i][0] if i < w.size() else 0
			wts[n * 4 + i] = w[i][1] if i < w.size() else 0.0
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = surf.normals
	arrays[Mesh.ARRAY_INDEX] = surf.indices
	arrays[Mesh.ARRAY_BONES] = bones
	arrays[Mesh.ARRAY_WEIGHTS] = wts
	_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	mat.metallic_specular = 0.35
	mat.resource_name = surface_name
	_mesh.surface_set_material(_mesh.get_surface_count() - 1, mat)
	print("  ", surface_name, ": ", verts.size(), " vértices, ", surf.indices.size() / 3, " triângulos")


# ---------- montagem ----------

## Profundidade (z) da superfície do rosto num ponto (x, y).
func _face_z(x: float, y: float) -> float:
	var dx := (x - HEAD_C.x) / HEAD_R.x
	var dy := (y - HEAD_C.y) / HEAD_R.y
	return HEAD_C.z + HEAD_R.z * sqrt(maxf(1.0 - dx * dx - dy * dy, 0.0))


func _bake() -> void:
	var t0 := Time.get_ticks_msec()
	var scene: Node3D = load("res://player/claire/ual.glb").instantiate()
	root.add_child(scene)
	_skeleton = scene.find_child("Skeleton3D", true, false)
	_setup_segments()

	print("esculpindo...")
	var skin := _build(_skin, Vector3(-0.9, -0.05, -0.2), Vector3(0.9, 1.97, 0.27))
	_commit(skin, _w_skin, Color(0.97, 0.78, 0.65), 0.5, "pele")
	var shirt := _build(_shirt, Vector3(-0.36, 0.94, -0.2), Vector3(0.36, 1.54, 0.16))
	_commit(shirt, _w_shirt, Color(0.8, 0.11, 0.47), 0.75, "camiseta")
	var skirt := _build(_skirt, Vector3(-0.32, 0.62, -0.3), Vector3(0.32, 1.06, 0.3))
	_commit(skirt, _w_skirt, Color(0.87, 0.42, 0.63), 0.75, "saia")
	var hair := _build(_hair, Vector3(-0.27, 1.45, -0.27), Vector3(0.27, 2.0, 0.25))
	_commit(hair, _w_head, Color(0.35, 0.21, 0.14), 0.4, "cabelo")

	# rosto: olhos grandes castanhos, sobrancelhas, sorriso com dentes, bochechas
	var white := _empty()
	var iris := _empty()
	var dark := _empty()
	var brow := _empty()
	var lips := _empty()
	var blush := _empty()
	for side in [-1.0, 1.0]:
		var ex: float = side * 0.078
		var ey := 1.722
		var ez := _face_z(ex, ey)
		var yaw: float = side * 0.33
		_add_ellipsoid(white, Vector3(ex, ey, ez - 0.006), Vector3(0.05, 0.058, 0.016), 0.0, yaw)
		_add_ellipsoid(iris, Vector3(ex - side * 0.004, ey - 0.002, ez + 0.004), Vector3(0.034, 0.037, 0.009), 0.0, yaw)
		_add_ellipsoid(dark, Vector3(ex - side * 0.004, ey - 0.002, ez + 0.01), Vector3(0.018, 0.02, 0.005), 0.0, yaw)
		_add_ellipsoid(white, Vector3(ex - side * 0.004 + 0.011, ey + 0.012, ez + 0.014), Vector3(0.007, 0.007, 0.003), 0.0, yaw)
		var by := 1.797
		_add_ellipsoid(brow, Vector3(ex + side * 0.004, by, _face_z(ex, by) + 0.002), Vector3(0.046, 0.011, 0.008), -side * 0.16, yaw)
		var cx: float = side * 0.125
		_add_ellipsoid(blush, Vector3(cx, 1.66, _face_z(cx, 1.66) - 0.003), Vector3(0.032, 0.02, 0.006), 0.0, side * 0.62)
		# cantos do sorriso, virados para cima
		var mx: float = side * 0.05
		_add_ellipsoid(lips, Vector3(mx, 1.646, _face_z(mx, 1.646) - 0.003), Vector3(0.017, 0.009, 0.006), side * 0.6, side * 0.25)
	var my := 1.632
	_add_ellipsoid(lips, Vector3(0.0, my, _face_z(0.0, my) - 0.005), Vector3(0.056, 0.024, 0.008))
	_add_ellipsoid(white, Vector3(0.0, my + 0.004, _face_z(0.0, my) - 0.003), Vector3(0.045, 0.013, 0.008))
	_commit(white, _w_head, Color(0.98, 0.98, 0.97), 0.25, "branco")
	_commit(iris, _w_head, Color(0.36, 0.2, 0.1), 0.2, "iris")
	_commit(dark, _w_head, Color(0.05, 0.03, 0.03), 0.15, "pupila")
	_commit(brow, _w_head, Color(0.3, 0.18, 0.12), 0.5, "sobrancelha")
	_commit(lips, _w_head, Color(0.74, 0.32, 0.33), 0.45, "boca")
	_commit(blush, _w_head, Color(0.97, 0.66, 0.6), 0.6, "bochecha")

	var skin_res := Skin.new()
	for b in _skeleton.get_bone_count():
		skin_res.add_named_bind(_skeleton.get_bone_name(b), _skeleton.get_bone_global_rest(b).affine_inverse())

	print("salvando: ", ResourceSaver.save(_mesh, OUT_MESH), " ", ResourceSaver.save(skin_res, OUT_SKIN))
	print("pronto em %.1f s" % ((Time.get_ticks_msec() - t0) / 1000.0))
