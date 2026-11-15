extends StaticBody3D
## Ilha gerada por código: praia, colinas com grama e fundo do mar.
## A mesma função height() é usada pela malha, pela colisão, pela água
## (via textura de alturas) e para espalhar os objetos.

const SIZE := 480.0
const CELLS := 240
const ISLAND_RADIUS := 85.0
const ISLET_POS := Vector2(150.0, 40.0)
const ISLET_RADIUS := 17.0
const SEA_DEPTH := 13.0

var height_texture: ImageTexture

var _shape_noise := FastNoiseLite.new()
var _detail_noise := FastNoiseLite.new()


func _init() -> void:
	_shape_noise.seed = 7
	_shape_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_shape_noise.frequency = 0.012
	_shape_noise.fractal_octaves = 3
	_detail_noise.seed = 21
	_detail_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_detail_noise.frequency = 0.06
	_detail_noise.fractal_octaves = 2


## Distância até a linha da costa: negativa em terra, positiva no mar.
func shore_distance(x: float, z: float) -> float:
	var n := _shape_noise.get_noise_2d(x, z)
	var main := Vector2(x, z).length() - ISLAND_RADIUS + n * 20.0
	var islet := Vector2(x, z).distance_to(ISLET_POS) - ISLET_RADIUS + n * 5.0
	return minf(main, islet)


func height(x: float, z: float) -> float:
	var t := shore_distance(x, z)
	var d := _detail_noise.get_noise_2d(x, z)
	if t < 0.0:
		var b := -t
		var h := 0.075 * minf(b, 26.0) + 0.012 * maxf(b - 26.0, 0.0)
		var hills := smoothstep(24.0, 60.0, b)
		h += hills * (3.5 + 3.5 * _shape_noise.get_noise_2d(x * 2.3 + 100.0, z * 2.3 - 50.0))
		h += d * (0.12 + 0.5 * hills) * smoothstep(0.0, 6.0, b)
		return h
	var s := -SEA_DEPTH * (1.0 - exp(-t * 0.09 / SEA_DEPTH))
	return s + d * 0.3 * smoothstep(4.0, 20.0, t)


func build() -> void:
	var n := CELLS + 1
	var step := SIZE / CELLS
	var half := SIZE * 0.5

	var heights := PackedFloat32Array()
	heights.resize(n * n)
	for j in n:
		for i in n:
			heights[j * n + i] = height(-half + i * step, -half + j * step)

	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	verts.resize(n * n)
	normals.resize(n * n)
	colors.resize(n * n)

	var sand := Color(0.82, 0.76, 0.62)
	var wet := Color(0.56, 0.48, 0.36)
	var seabed := Color(0.8, 0.75, 0.6)
	var grass_a := Color(0.2, 0.3, 0.1)
	var grass_b := Color(0.4, 0.42, 0.18)
	var rock := Color(0.4, 0.38, 0.35)

	for j in n:
		for i in n:
			var k := j * n + i
			var x := -half + i * step
			var z := -half + j * step
			var h := heights[k]
			verts[k] = Vector3(x, h, z)
			var hl := heights[j * n + maxi(i - 1, 0)]
			var hr := heights[j * n + mini(i + 1, n - 1)]
			var hu := heights[maxi(j - 1, 0) * n + i]
			var hd := heights[mini(j + 1, n - 1) * n + i]
			var nrm := Vector3(hl - hr, 2.0 * step, hu - hd).normalized()
			normals[k] = nrm

			var d := _detail_noise.get_noise_2d(x * 3.0, z * 3.0)
			var c: Color
			if h < 0.0:
				c = wet.lerp(seabed, clampf(-h / 1.5, 0.0, 1.0))
			else:
				c = wet.lerp(sand, smoothstep(0.05, 0.5, h))
				var g := smoothstep(2.0, 3.3, h + d * 0.9)
				c = c.lerp(grass_a.lerp(grass_b, clampf(d + 0.5, 0.0, 1.0)), g)
			c = c.lerp(rock, smoothstep(0.2, 0.4, 1.0 - nrm.y))
			c = c * (0.94 + 0.08 * d)
			c.a = 1.0
			colors[k] = c

	var indices := PackedInt32Array()
	indices.resize(CELLS * CELLS * 6)
	var w := 0
	for j in CELLS:
		for i in CELLS:
			var a := j * n + i
			var b := a + 1
			var c2 := a + n
			var d2 := c2 + 1
			indices[w] = a
			indices[w + 1] = b
			indices[w + 2] = d2
			indices[w + 3] = a
			indices[w + 4] = d2
			indices[w + 5] = c2
			w += 6

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	var grain_noise := FastNoiseLite.new()
	grain_noise.frequency = 0.05
	grain_noise.fractal_octaves = 5
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.68, 0.68, 0.68))
	ramp.set_color(1, Color(1, 1, 1))
	var grain := NoiseTexture2D.new()
	grain.width = 512
	grain.height = 512
	grain.seamless = true
	grain.generate_mipmaps = true
	grain.noise = grain_noise
	grain.color_ramp = ramp
	# relevo: ondulações da areia e irregularidade do chão
	var bump_noise := FastNoiseLite.new()
	bump_noise.seed = 4
	bump_noise.frequency = 0.03
	bump_noise.fractal_octaves = 4
	var bump := NoiseTexture2D.new()
	bump.width = 512
	bump.height = 512
	bump.seamless = true
	bump.generate_mipmaps = true
	bump.as_normal_map = true
	bump.bump_strength = 10.0
	bump.noise = bump_noise

	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.albedo_texture = grain
	mat.uv1_triplanar = true
	mat.uv1_scale = Vector3(0.22, 0.22, 0.22)
	mat.normal_enabled = true
	mat.normal_texture = bump
	mat.normal_scale = 1.1
	mat.roughness = 0.92
	mat.metallic_specular = 0.2
	mesh.surface_set_material(0, mat)

	var mi := MeshInstance3D.new()
	mi.name = "TerrainMesh"
	mi.mesh = mesh
	add_child(mi)

	var col := CollisionShape3D.new()
	col.shape = mesh.create_trimesh_shape()
	add_child(col)

	var img := Image.create_from_data(n, n, false, Image.FORMAT_RF, heights.to_byte_array())
	height_texture = ImageTexture.create_from_image(img)
