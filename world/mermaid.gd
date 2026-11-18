extends Node3D
## Sereia: o mesmo modelo da Claire (Kenney Mini Characters, CC0) com outras
## cores, as pernas recolhidas e uma cauda de escamas no lugar, cabelo ruivo
## comprido flutuando na água. Ela boia na frente da casa dela e, quando a
## Claire chega perto, gira de alegria e acena. A frente deste nó é o +Z.

signal found

const ModelScene := preload("res://player/claire/character-female-f.glb")
const RecolorShader := preload("res://player/claire/recolor.gdshader")
const Palette := preload("res://player/claire/Textures/colormap.png")
const TailShader := preload("res://world/mermaid_tail.gdshader")

const MODEL_SCALE := 2.0
const FIND_DISTANCE := 6.5
const HAIR := Color(0.78, 0.17, 0.1)

## Nó que ela observa (a Claire); quem cria a sereia preenche.
var player: Node3D
var is_found := false

var _model: Node3D
var _skeleton: Skeleton3D
var _bone := {}
var _tail: Node3D
var _fin: Node3D
var _hair: Array[Node3D] = []
var _base_y := 0.0
var _t := 0.0
var _party := 0.0
var _fish: Node3D
var _fish_tail: Node3D


func _ready() -> void:
	_base_y = position.y
	_t = randf() * 10.0
	_model = ModelScene.instantiate()
	_model.scale = Vector3.ONE * MODEL_SCALE
	add_child(_model)
	_skeleton = _model.find_child("Skeleton3D", true, false)
	for n in ["torso", "head", "arm-left", "arm-right", "leg-left", "leg-right"]:
		_bone[n] = _skeleton.find_bone(n)
	# Pernas recolhidas: a cauda ocupa o lugar delas.
	for n in ["leg-left", "leg-right"]:
		_skeleton.set_bone_pose_scale(_bone[n], Vector3.ONE * 0.01)

	for mi in _model.find_children("*", "MeshInstance3D", true, false):
		var mat := ShaderMaterial.new()
		mat.shader = RecolorShader
		mat.set_shader_parameter("palette", Palette)
		mat.set_shader_parameter("is_head", String(mi.name).begins_with("head"))
		mat.set_shader_parameter("hair", Vector3(HAIR.r, HAIR.g, HAIR.b))
		mat.set_shader_parameter("skin", Vector3(0.98, 0.8, 0.68))
		mat.set_shader_parameter("shirt", Vector3(0.62, 0.36, 0.86))
		mat.set_shader_parameter("skirt", Vector3(0.1, 0.62, 0.6))
		(mi as MeshInstance3D).material_override = mat

	_build_tail()
	_build_hair()
	_build_crown()
	_build_fish()


# --- cauda ---

## Ponto do eixo da cauda (unidades do modelo) para t de 0 (quadril) a 1 (ponta).
func _tail_point(t: float) -> Vector3:
	return Vector3(0.0, 0.2 - 0.36 * t, -0.03 - 0.2 * t * t)


func _tail_radius(t: float) -> float:
	return 0.115 * (1.0 - 0.78 * pow(t, 1.4)) * (1.0 + 0.12 * sin(t * PI))


func _build_tail() -> void:
	var mat := ShaderMaterial.new()
	mat.shader = TailShader
	_tail = Node3D.new()
	_tail.position = Vector3(0.0, 0.2, -0.03)
	_model.add_child(_tail)

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var around := 18
	var along := 16
	var origin := _tail_point(0.0)
	var rings := []
	for j in along + 1:
		var t := float(j) / along
		var c := _tail_point(t) - origin
		var tangent := (_tail_point(minf(t + 0.01, 1.0)) - _tail_point(maxf(t - 0.01, 0.0))).normalized()
		var side := Vector3.RIGHT
		var back := tangent.cross(side).normalized()
		var r := _tail_radius(t)
		var ring := []
		for i in around + 1:
			var a := TAU * float(i) / around
			ring.append(c + side * cos(a) * r * 1.1 + back * sin(a) * r * 0.85)
		rings.append(ring)
	for j in along:
		for i in around:
			var uv00 := Vector2(float(i) / around, float(j) / along)
			var uv10 := Vector2(float(i + 1) / around, float(j) / along)
			var uv01 := Vector2(float(i) / around, float(j + 1) / along)
			var uv11 := Vector2(float(i + 1) / around, float(j + 1) / along)
			for pair in [[rings[j][i], uv00], [rings[j + 1][i], uv01], [rings[j + 1][i + 1], uv11],
					[rings[j][i], uv00], [rings[j + 1][i + 1], uv11], [rings[j][i + 1], uv10]]:
				st.set_uv(pair[1])
				st.add_vertex(pair[0])
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	_tail.add_child(mi)

	# Nadadeira em leque na ponta, em nó próprio para bater com atraso.
	_fin = Node3D.new()
	_fin.position = _tail_point(1.0) - origin
	_tail.add_child(_fin)
	var fin_mat := ShaderMaterial.new()
	fin_mat.shader = TailShader
	fin_mat.set_shader_parameter("is_fin", true)
	var tip_dir := (_tail_point(1.0) - _tail_point(0.92)).normalized()
	var fs := SurfaceTool.new()
	fs.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 24
	var prev := Vector3.ZERO
	var prev_u := 0.0
	for i in n + 1:
		var u := float(i) / n
		var x := lerpf(-1.0, 1.0, u)
		# Dois lóbulos com um entalhe no meio.
		var reach := 0.05 + 0.16 * pow(absf(x), 0.7) - 0.02 * (1.0 - absf(x))
		var p := Vector3.RIGHT * x * 0.26 + tip_dir * reach * 1.3 + Vector3.UP * 0.02 * x * x
		if i > 0:
			for v in [[Vector3.ZERO, Vector2((u + prev_u) * 0.5, 0.0)], [prev, Vector2(prev_u, 1.0)], [p, Vector2(u, 1.0)]]:
				fs.set_uv(v[1])
				fs.add_vertex(v[0])
		prev = p
		prev_u = u
	fs.generate_normals()
	var fin := MeshInstance3D.new()
	fin.mesh = fs.commit()
	fin.material_override = fin_mat
	_fin.add_child(fin)


# --- cabelo e tiara ---

func _build_hair() -> void:
	var attach := BoneAttachment3D.new()
	attach.bone_name = "head"
	_skeleton.add_child(attach)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = HAIR
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.roughness = 0.6
	mat.emission_enabled = true
	mat.emission = HAIR * 0.35
	var count := 9
	for k in count:
		var u := float(k) / (count - 1)
		var x := lerpf(-0.17, 0.17, u)
		var strand := Node3D.new()
		strand.position = Vector3(x, 0.3 - absf(x) * 0.4, -0.15 + absf(x) * 0.25)
		attach.add_child(strand)
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var length := 0.38 + 0.08 * sin(u * PI)
		var segs := 8
		var pl := Vector3.ZERO
		var pr := Vector3.ZERO
		for j in segs + 1:
			var t := float(j) / segs
			var c := Vector3(x * 0.4 * t, -length * t, -0.12 * t * t)
			var w := 0.075 * (1.0 - t * 0.6)
			var l := c - Vector3.RIGHT * w * 0.5
			var r := c + Vector3.RIGHT * w * 0.5
			if j > 0:
				for v in [pl, pr, r, pl, r, l]:
					st.add_vertex(v)
			pl = l
			pr = r
		st.generate_normals()
		var mi := MeshInstance3D.new()
		mi.mesh = st.commit()
		mi.material_override = mat
		strand.add_child(mi)
		_hair.append(strand)


func _build_crown() -> void:
	var attach := BoneAttachment3D.new()
	attach.bone_name = "head"
	_skeleton.add_child(attach)
	var gold := StandardMaterial3D.new()
	gold.albedo_color = Color(1.0, 0.82, 0.45)
	gold.metallic = 0.8
	gold.roughness = 0.25
	var pearl := StandardMaterial3D.new()
	pearl.albedo_color = Color(1.0, 0.95, 0.97)
	pearl.emission_enabled = true
	pearl.emission = Color(0.9, 0.85, 1.0)
	pearl.emission_energy_multiplier = 0.4
	pearl.roughness = 0.15
	for k in 7:
		var a := lerpf(-1.2, 1.2, k / 6.0)
		var spike := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.0
		cm.bottom_radius = 0.018
		cm.height = 0.07 if k % 2 == 0 else 0.045
		cm.material = gold
		spike.mesh = cm
		spike.position = Vector3(sin(a) * 0.17, 0.34 + cm.height * 0.5, cos(a) * 0.12 - 0.02)
		attach.add_child(spike)
	var p := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.022
	sm.height = 0.044
	sm.material = pearl
	p.mesh = sm
	p.position = Vector3(0.0, 0.42, 0.1)
	attach.add_child(p)


# --- peixinho ---

## Peixinho-palhaço que fica sempre ao lado dela. O focinho aponta para -Z.
func _build_fish() -> void:
	_fish = Node3D.new()
	_fish.scale = Vector3.ONE * 1.8
	add_child(_fish)
	var orange := StandardMaterial3D.new()
	orange.albedo_color = Color(1.0, 0.45, 0.08)
	orange.roughness = 0.35
	orange.emission_enabled = true
	orange.emission = Color(1.0, 0.4, 0.05)
	orange.emission_energy_multiplier = 0.25
	var white := StandardMaterial3D.new()
	white.albedo_color = Color(0.98, 0.98, 1.0)
	white.roughness = 0.35
	var black := StandardMaterial3D.new()
	black.albedo_color = Color(0.03, 0.03, 0.05)
	black.roughness = 0.2
	var body := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.1
	sm.height = 0.2
	sm.material = orange
	body.mesh = sm
	body.scale = Vector3(0.75, 1.0, 1.7)
	_fish.add_child(body)
	# Listras brancas com contorno preto.
	for z in [-0.07, 0.05]:
		var stripe := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 0.075 if z < 0.0 else 0.07
		tm.outer_radius = 0.1 if z < 0.0 else 0.094
		tm.rings = 20
		tm.ring_segments = 6
		tm.material = white
		stripe.mesh = tm
		stripe.rotation.x = PI * 0.5
		stripe.position.z = z
		stripe.scale = Vector3(0.78, 1.0, 1.0)
		_fish.add_child(stripe)
	for x in [-0.055, 0.055]:
		var eye := MeshInstance3D.new()
		var em := SphereMesh.new()
		em.radius = 0.022
		em.height = 0.044
		em.material = black
		eye.mesh = em
		eye.position = Vector3(x, 0.025, -0.11)
		_fish.add_child(eye)
	# Nadadeira de cima e cauda (a cauda balança).
	var fin_mat := orange.duplicate()
	fin_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var dorsal := MeshInstance3D.new()
	var pm := PrismMesh.new()
	pm.size = Vector3(0.14, 0.07, 0.012)
	pm.left_to_right = 0.8
	pm.material = fin_mat
	dorsal.mesh = pm
	dorsal.rotation.y = PI * 0.5
	dorsal.position = Vector3(0.0, 0.11, 0.02)
	_fish.add_child(dorsal)
	_fish_tail = Node3D.new()
	_fish_tail.position.z = 0.16
	_fish.add_child(_fish_tail)
	var tail := MeshInstance3D.new()
	var tp := PrismMesh.new()
	tp.size = Vector3(0.15, 0.1, 0.012)
	tp.material = fin_mat
	tail.mesh = tp
	tail.rotation = Vector3(-PI * 0.5, PI * 0.5, 0.0)
	tail.position.z = 0.04
	_fish_tail.add_child(tail)


func _animate_fish() -> void:
	# Fica do lado direito dela, na altura do peito, fazendo um oito devagar;
	# na comemoração dá voltas em torno dela.
	var t := _t * 0.9
	var pos: Vector3
	var ahead: Vector3
	if _party > 0.0:
		var a := _t * 4.0
		pos = Vector3(cos(a) * 1.3, 1.1 + 0.15 * sin(_t * 3.0), sin(a) * 1.3)
		ahead = Vector3(cos(a + 0.2) * 1.3, pos.y, sin(a + 0.2) * 1.3)
	else:
		pos = _fish_path(t)
		ahead = _fish_path(t + 0.08)
	_fish.position = pos
	if ahead.distance_to(pos) > 0.001:
		_fish.look_at(to_global(ahead), Vector3.UP)
	_fish_tail.rotation.y = 0.5 * sin(_t * 14.0)


func _fish_path(t: float) -> Vector3:
	return Vector3(1.15 + 0.3 * sin(t), 1.0 + 0.15 * sin(t * 2.0 + 0.5), 0.35 + 0.4 * sin(t * 2.0))


# --- animação ---

func _pose(bone_name: String, euler: Vector3) -> void:
	_skeleton.set_bone_pose_rotation(_bone[bone_name], Quaternion.from_euler(euler))


func _process(delta: float) -> void:
	_t += delta
	var kick := sin(_t * 2.2)
	position.y = _base_y + 0.18 * sin(_t * 1.1)
	_tail.rotation.x = 0.18 * kick
	_fin.rotation.x = 0.35 * sin(_t * 2.2 - 1.0)
	for i in _hair.size():
		var h := _hair[i]
		h.rotation.x = 0.35 + 0.15 * sin(_t * 1.6 + i * 0.5)
		h.rotation.z = 0.08 * sin(_t * 1.3 + i)
	_pose("torso", Vector3(0.05 * sin(_t * 1.1), 0.0, 0.04 * sin(_t * 0.7)))
	_pose("head", Vector3(0.0, 0.25 * sin(_t * 0.45), 0.08 * sin(_t * 0.9)))

	if _party > 0.0:
		# Comemoração: gira e acena com o braço direito.
		_party -= delta
		# Duas voltas completas nos dois primeiros segundos, terminando de frente.
		_model.rotation.y = TAU * 2.0 * smoothstep(0.0, 1.0, (4.0 - _party) / 2.0)
		_pose("arm-right", Vector3(0.0, 0.0, 2.6 + 0.35 * sin(_t * 9.0)))
		_pose("arm-left", Vector3(0.0, 0.0, -0.4))
		if _party <= 0.0:
			_model.rotation.y = 0.0
	else:
		_pose("arm-right", Vector3(0.15 * sin(_t * 1.4), 0.0, 0.35 + 0.15 * sin(_t * 1.4)))
		_pose("arm-left", Vector3(0.15 * sin(_t * 1.4 + 1.0), 0.0, -0.35 - 0.15 * sin(_t * 1.4 + 1.0)))

	_animate_fish()

	if not is_found and player and player.global_position.distance_to(global_position) < FIND_DISTANCE:
		is_found = true
		_party = 4.0
		found.emit()
