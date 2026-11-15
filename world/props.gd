extends RefCounted
## Construtores de malhas do cenário (palmeiras, pedras, nuvens...), tudo por código.


static func noise_texture(frequency: float, normal_map: bool, noise_seed := 0, bump := 6.0, octaves := 4, full_range := false) -> NoiseTexture2D:
	var noise := FastNoiseLite.new()
	noise.seed = noise_seed
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = frequency
	noise.fractal_octaves = octaves
	var tex := NoiseTexture2D.new()
	tex.width = 512
	tex.height = 512
	tex.seamless = true
	tex.as_normal_map = normal_map
	tex.bump_strength = bump
	tex.generate_mipmaps = true
	tex.noise = noise
	if not normal_map and not full_range:
		var ramp := Gradient.new()
		ramp.set_color(0, Color(0.55, 0.55, 0.55))
		ramp.set_color(1, Color(1, 1, 1))
		tex.color_ramp = ramp
	return tex


## Material com textura e relevo de ruído projetados em 3 eixos (pedra, casca, areia).
static func rough_material(color: Color, scale: Vector3, bump := 1.0, roughness := 0.9) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.albedo_texture = noise_texture(0.012, false, 11)
	m.normal_enabled = true
	m.normal_texture = noise_texture(0.02, true, 12, 9.0)
	m.normal_scale = bump
	m.uv1_triplanar = true
	m.uv1_scale = scale
	m.roughness = roughness
	m.metallic_specular = 0.3
	return m


static func material(color: Color, roughness := 0.85) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	return m


static var _trunk_mat: StandardMaterial3D
static var _leaf_mat: ShaderMaterial


static func trunk_material() -> StandardMaterial3D:
	if _trunk_mat == null:
		_trunk_mat = rough_material(Color(0.42, 0.33, 0.24), Vector3(1.5, 5.0, 1.5), 1.6, 0.95)
	return _trunk_mat


static func leaf_material() -> ShaderMaterial:
	if _leaf_mat == null:
		_leaf_mat = ShaderMaterial.new()
		_leaf_mat.shader = preload("res://world/leaf.gdshader")
	return _leaf_mat


## Palmeira: tronco curvo (superfície 0) e folhas arqueadas (superfície 1).
static func palm_mesh(rng: RandomNumberGenerator) -> ArrayMesh:
	var trunk := SurfaceTool.new()
	trunk.begin(Mesh.PRIMITIVE_TRIANGLES)
	var total_h := rng.randf_range(5.0, 7.5)
	var segments := 8
	var seg_h := total_h / segments
	var lean := rng.randf_range(0.15, 0.5)
	var p := Vector3.ZERO
	var b := Basis.IDENTITY
	for i in segments:
		var f0 := float(i) / segments
		var f1 := float(i + 1) / segments
		var cyl := CylinderMesh.new()
		cyl.bottom_radius = lerpf(0.24, 0.13, f0) * 1.1
		cyl.top_radius = lerpf(0.24, 0.13, f1)
		cyl.height = seg_h * 1.04
		cyl.radial_segments = 8
		cyl.rings = 1
		b = Basis(Vector3.FORWARD, lean * pow(f1, 1.4))
		trunk.append_from(cyl, 0, Transform3D(b, p + b.y * seg_h * 0.5))
		p += b.y * seg_h
	for i in 3:
		var nut := SphereMesh.new()
		nut.radius = 0.14
		nut.height = 0.28
		nut.radial_segments = 8
		nut.rings = 4
		var a := i * TAU / 3.0 + rng.randf()
		trunk.append_from(nut, 0, Transform3D(Basis.IDENTITY, p + Vector3(cos(a) * 0.2, -0.22, sin(a) * 0.2)))
	var mesh := trunk.commit()

	var leaves := SurfaceTool.new()
	leaves.begin(Mesh.PRIMITIVE_TRIANGLES)
	var fronds := 15
	for k in fronds:
		var yaw := k * TAU / fronds + rng.randf_range(-0.2, 0.2)
		var dir := Vector3(cos(yaw), 0.0, sin(yaw))
		var side := Vector3(-dir.z, 0.0, dir.x)
		var length := rng.randf_range(2.4, 3.3)
		var rise := rng.randf_range(0.3, 1.1)
		var droop := rng.randf_range(1.3, 2.2)
		var steps := 9
		var prev := []
		for s in steps + 1:
			var f := float(s) / steps
			var center := p + dir * (length * f) + Vector3.UP * (rise * sin(f * PI * 0.8) - droop * f * f)
			var width := 0.8 * sin(PI * clampf(f * 0.9 + 0.1, 0.0, 1.0))
			var sag := Vector3.UP * (-0.35 * width)
			var row := [center - side * width + sag, center, center + side * width + sag]
			if s > 0:
				var f_prev := float(s - 1) / steps
				for q in 2:
					var order := [[prev[q], q, f_prev], [row[q], q, f], [row[q + 1], q + 1, f], [prev[q], q, f_prev], [row[q + 1], q + 1, f], [prev[q + 1], q + 1, f_prev]]
					for v in order:
						leaves.set_uv(Vector2(v[1] * 0.5, v[2]))
						leaves.add_vertex(v[0])
			prev = row
	leaves.generate_normals()
	leaves.commit(mesh)

	mesh.surface_set_material(0, trunk_material())
	mesh.surface_set_material(1, leaf_material())
	return mesh


## Pedra: uma esfera deformada por ruído em várias escalas, com textura e relevo.
## Com `textured` falso vira um volume liso de cor chapada (arbustos, corais).
static func rock_mesh(rng: RandomNumberGenerator, color: Color, flatten := 0.7, bump := 0.45, textured := true) -> ArrayMesh:
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 22
	sphere.rings = 12
	var arrays := sphere.get_mesh_arrays()
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var noise := FastNoiseLite.new()
	noise.seed = rng.randi()
	noise.frequency = 0.6
	noise.fractal_octaves = 3
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in indices:
		var v := verts[i].normalized()
		var d := 1.0 + noise.get_noise_3dv(v * 1.4) * bump
		st.add_vertex(v * d * Vector3(1.0, flatten, 1.0))
	st.generate_normals()
	var mesh := st.commit()
	if textured:
		mesh.surface_set_material(0, rough_material(color, Vector3(0.6, 0.6, 0.6), 1.4))
	else:
		mesh.surface_set_material(0, material(color, 0.85))
	return mesh


## Tufo de capim: várias lâminas finas (um triângulo cada). UV.y vai da base (0) à ponta (1).
static func grass_mesh(rng: RandomNumberGenerator) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 12:
		var yaw := rng.randf() * TAU
		var dir := Vector3(cos(yaw), 0.0, sin(yaw))
		var side := Vector3(-dir.z, 0.0, dir.x)
		var base := Vector3(rng.randf_range(-0.28, 0.28), 0.0, rng.randf_range(-0.28, 0.28))
		var h := rng.randf_range(0.22, 0.5)
		var w := rng.randf_range(0.012, 0.022)
		var tip := base + Vector3.UP * h + dir * rng.randf_range(0.05, 0.22)
		for v in [[base - side * w, 0.0], [tip, 1.0], [base + side * w, 0.0]]:
			st.set_uv(Vector2(0.5, v[1]))
			st.add_vertex(v[0])
	st.generate_normals()
	return st.commit()


static func cloud_mesh(rng: RandomNumberGenerator) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var puffs := rng.randi_range(4, 7)
	for i in puffs:
		var s := SphereMesh.new()
		var r := rng.randf_range(9.0, 18.0)
		s.radius = r
		s.height = r * 1.1
		s.radial_segments = 12
		s.rings = 6
		var pos := Vector3(rng.randf_range(-26.0, 26.0), rng.randf_range(-2.0, 3.0), rng.randf_range(-10.0, 10.0))
		st.append_from(s, 0, Transform3D(Basis.IDENTITY, pos))
	var mesh := st.commit()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1, 1, 1)
	mat.disable_fog = true
	mesh.surface_set_material(0, mat)
	return mesh


static func box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := BoxMesh.new()
	m.size = size
	m.material = mat
	mi.mesh = m
	mi.position = pos
	parent.add_child(mi)
	return mi


static func cylinder(parent: Node3D, top: float, bottom: float, height: float, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := CylinderMesh.new()
	m.top_radius = top
	m.bottom_radius = bottom
	m.height = height
	m.radial_segments = 12
	m.rings = 1
	m.material = mat
	mi.mesh = m
	mi.position = pos
	parent.add_child(mi)
	return mi


## Píer de madeira com colisão. O +Z local aponta para o mar.
static func pier(length: float, deck_y: float) -> StaticBody3D:
	var body := StaticBody3D.new()
	var wood := rough_material(Color(0.5, 0.43, 0.34), Vector3(0.8, 0.8, 3.0), 1.2)
	var dark := rough_material(Color(0.3, 0.25, 0.2), Vector3(0.8, 0.8, 3.0), 1.2)
	var width := 2.6
	var plank := 0.5
	var count := int(length / plank)
	for i in count:
		var shade := wood if i % 3 != 0 else dark
		box(body, Vector3(width, 0.1, plank - 0.04), Vector3(0.0, deck_y - 0.05, (i + 0.5) * plank), shade)
	for side in [-1.0, 1.0]:
		box(body, Vector3(0.14, 0.14, length), Vector3(side * (width * 0.5 - 0.1), deck_y - 0.17, length * 0.5), dark)
		var z := 1.0
		while z < length + 0.1:
			cylinder(body, 0.11, 0.13, 7.0, Vector3(side * (width * 0.5 - 0.05), deck_y - 3.1, z), dark)
			z += 5.0
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(width, 0.3, length)
	col.shape = shape
	col.position = Vector3(0.0, deck_y - 0.15, length * 0.5)
	body.add_child(col)
	return body


static func umbrella() -> Node3D:
	var root := Node3D.new()
	cylinder(root, 0.025, 0.025, 2.3, Vector3(0, 1.15, 0), material(Color(0.9, 0.9, 0.88)))
	var canopy := cylinder(root, 0.02, 1.5, 0.5, Vector3(0, 2.2, 0), material(Color(0.62, 0.22, 0.18)))
	(canopy.mesh as CylinderMesh).radial_segments = 10
	canopy.rotation.z = 0.12
	box(root, Vector3(0.95, 0.03, 1.9), Vector3(0.9, 0.02, 0.3), material(Color(0.2, 0.36, 0.5)))
	box(root, Vector3(0.95, 0.032, 0.25), Vector3(0.9, 0.02, 0.3), material(Color(0.97, 0.97, 0.95)))
	return root
