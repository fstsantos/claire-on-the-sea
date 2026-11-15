extends Node3D
## Monta o mundo inteiro por código: céu, sol, ilha, mar, vegetação, pedras,
## píer, conchas, animais, sons, interface e a Claire.

const Terrain := preload("res://world/terrain.gd")
const Props := preload("res://world/props.gd")
const ShellScript := preload("res://world/shell.gd")
const Wildlife := preload("res://world/wildlife.gd")
const Sharks := preload("res://world/sharks.gd")
const AudioGen := preload("res://world/audio_gen.gd")
const Hud := preload("res://ui/hud.gd")
const Console := preload("res://ui/console.gd")
const PlayerScene := preload("res://player/player.tscn")
const WaterShader := preload("res://world/water.gdshader")
const SkyShader := preload("res://world/sky.gdshader")
const GrassShader := preload("res://world/grass.gdshader")

## Raio a partir do qual a correnteza devolve a Claire para a ilha.
const SEA_LIMIT := 215.0
const TIDE_BASE := 0.07
const TIDE_RANGE := 0.07

var terrain: StaticBody3D
var water: MeshInstance3D
var player: CharacterBody3D
var hud: CanvasLayer
var env: Environment

var sharks: Node3D
var wildlife: Node3D
var sun: DirectionalLight3D
var console: CanvasLayer
## Contagem do cenário fixo (palmeiras, pedras...), mostrada no /status.
var counts := {}
## Lugares com nome para o /tp.
var places := {}
var tide_base := TIDE_BASE
var fog_scale := 1.0
var play_time := 0.0

var shells_total := 0
var shells_found := 0

var _rng := RandomNumberGenerator.new()
var _used: Array[Vector3] = []
var _shell_spots: Array[Vector3] = []
var _solids: StaticBody3D
var _time := 0.0
var _was_underwater := false
var _limit_warned := 0.0
var _ocean: AudioStreamPlayer
var _chime: AudioStreamPlayer
var _splash_sound: AudioStreamPlayer
var _step: AudioStreamPlayer
var _splash: CPUParticles3D
var _wake: CPUParticles3D


func _ready() -> void:
	_rng.seed = 20261114
	_build_sky()
	terrain = Terrain.new()
	terrain.name = "Terrain"
	add_child(terrain)
	terrain.build()
	_build_water()

	_solids = StaticBody3D.new()
	_solids.name = "Solids"
	add_child(_solids)

	var spawn := _beach_point(0.0, 1.0)
	_used.append(spawn)
	var pier_start := _build_pier(0.45)
	places = {
		"inicio": spawn, "pier": pier_start,
		"ilhota": Vector3(Terrain.ISLET_POS.x, terrain.height(Terrain.ISLET_POS.x, Terrain.ISLET_POS.y), Terrain.ISLET_POS.y),
		"centro": Vector3(0.0, terrain.height(0.0, 0.0), 0.0),
	}
	counts["Píer"] = 1
	counts["Guarda-sol"] = 1
	_build_umbrella(spawn)
	_build_palms()
	_build_rocks()
	_build_bushes()
	_build_corals()
	_build_grass()
	_build_wildlife()
	_build_audio()
	_build_particles()

	hud = Hud.new()
	add_child(hud)

	_build_shells(pier_start)
	hud.set_shells(0, shells_total)
	hud.show_message("Explore a ilha e encontre as %d conchas" % shells_total, 6.0)

	player = PlayerScene.instantiate()
	player.world = self
	player.position = spawn + Vector3(0, 0.1, 0)
	player.spawn_point = player.position
	add_child(player)
	player.get_node("CameraRig").rotation.y = PI
	player.get_node("Model").rotation.y = PI
	player.splashed.connect(_on_splash)
	player.get_node("Model").stepped.connect(_on_step)

	console = Console.new()
	console.world = self
	add_child(console)


# --- consultas usadas pela Claire ---

func water_level() -> float:
	return water.position.y


func ground_height(pos: Vector3) -> float:
	return terrain.height(pos.x, pos.z)


# --- construção ---

func _build_sky() -> void:
	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = SkyShader
	sky_mat.set_shader_parameter("noise_a", Props.noise_texture(0.004, false, 31, 6.0, 5, true))
	sky_mat.set_shader_parameter("noise_b", Props.noise_texture(0.007, false, 77, 6.0, 5, true))
	var sky := Sky.new()
	sky.sky_material = sky_mat

	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.9
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.05
	env.tonemap_white = 6.0
	env.ssao_enabled = true
	env.ssao_radius = 1.2
	env.ssao_intensity = 2.2
	env.glow_enabled = true
	env.glow_intensity = 0.55
	env.glow_bloom = 0.08
	env.glow_hdr_threshold = 1.1
	# Correção de cor: menos saturação e mais contraste, para um ar mais cru e realista.
	env.adjustment_enabled = true
	env.adjustment_saturation = 0.84
	env.adjustment_contrast = 1.1
	_set_fog(false)
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	sun = DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-27.0, -62.0, 0.0)
	sun.light_color = Color(1.0, 0.88, 0.7)
	sun.light_energy = 1.7
	sun.shadow_enabled = true
	sun.shadow_blur = 1.4
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = 170.0
	add_child(sun)


func _set_fog(underwater: bool) -> void:
	env.fog_enabled = true
	if underwater:
		env.fog_light_color = Color(0.03, 0.26, 0.3)
		env.fog_density = 0.075 * fog_scale
		env.fog_aerial_perspective = 0.0
		env.fog_sky_affect = 1.0
		env.fog_sun_scatter = 0.0
	else:
		env.fog_light_color = Color(0.72, 0.74, 0.7)
		env.fog_density = 0.0014 * fog_scale
		env.fog_aerial_perspective = 0.35
		env.fog_sky_affect = 0.0
		env.fog_sun_scatter = 0.15


func _noise_texture(frequency: float, normal_map: bool) -> NoiseTexture2D:
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = frequency
	noise.fractal_octaves = 3
	var tex := NoiseTexture2D.new()
	tex.width = 256
	tex.height = 256
	tex.seamless = true
	tex.as_normal_map = normal_map
	tex.bump_strength = 5.0
	tex.generate_mipmaps = true
	tex.noise = noise
	return tex


func _build_water() -> void:
	var mat := ShaderMaterial.new()
	mat.shader = WaterShader
	mat.set_shader_parameter("height_tex", terrain.height_texture)
	mat.set_shader_parameter("height_origin", -Terrain.SIZE * 0.5)
	mat.set_shader_parameter("height_step", Terrain.SIZE / Terrain.CELLS)
	mat.set_shader_parameter("height_n", float(Terrain.CELLS + 1))
	mat.set_shader_parameter("normal_tex", _noise_texture(0.03, true))
	mat.set_shader_parameter("foam_tex", _noise_texture(0.02, false))
	var plane := PlaneMesh.new()
	plane.size = Vector2(6000.0, 6000.0)
	plane.material = mat
	water = MeshInstance3D.new()
	water.name = "Water"
	water.mesh = plane
	water.position.y = TIDE_BASE
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(water)


## Ponto da praia na direção `angle` (0 = +Z) onde o terreno tem a altura pedida.
func _beach_point(angle: float, target_height: float) -> Vector3:
	var dir := Vector3(sin(angle), 0.0, cos(angle))
	var r := 135.0
	while r > 0.0:
		var p := dir * r
		if terrain.height(p.x, p.z) >= target_height:
			return Vector3(p.x, terrain.height(p.x, p.z), p.z)
		r -= 0.25
	return Vector3.ZERO


func _build_pier(angle: float) -> Vector3:
	var deck_y := 0.95
	var start := _beach_point(angle, deck_y + 0.05)
	var length := 46.0
	var pier := Props.pier(length, deck_y)
	pier.name = "Pier"
	pier.position = Vector3(start.x, 0.0, start.z)
	pier.rotation.y = angle
	add_child(pier)
	var dir := Vector3(sin(angle), 0.0, cos(angle))
	var i := 0.0
	while i < length:
		_used.append(start + dir * i)
		i += 4.0
	return start + dir * (length - 1.5) + Vector3(0, deck_y - start.y, 0)


func _build_umbrella(spawn: Vector3) -> void:
	var u := Props.umbrella()
	var p := spawn + Vector3(-4.0, 0.0, -3.0)
	p.y = terrain.height(p.x, p.z)
	u.position = p
	u.rotation.y = 0.4
	add_child(u)
	_used.append(p)


func _spot(min_h: float, max_h: float, spacing: float, max_r := 190.0, center := Vector2.ZERO) -> Vector3:
	for i in 400:
		var a := _rng.randf() * TAU
		var r := sqrt(_rng.randf()) * max_r
		var x := center.x + cos(a) * r
		var z := center.y + sin(a) * r
		var h: float = terrain.height(x, z)
		if h < min_h or h > max_h:
			continue
		var ok := true
		for q in _used:
			if Vector2(q.x - x, q.z - z).length() < spacing:
				ok = false
				break
		if ok:
			var p := Vector3(x, h, z)
			_used.append(p)
			return p
	return Vector3.INF


func _add_collider(shape: Shape3D, xform: Transform3D) -> void:
	var col := CollisionShape3D.new()
	col.shape = shape
	col.transform = xform
	_solids.add_child(col)


func _build_palms() -> void:
	var variants: Array[ArrayMesh] = []
	for i in 4:
		variants.append(Props.palm_mesh(_rng))
	var trunk_shape := CylinderShape3D.new()
	trunk_shape.radius = 0.24
	trunk_shape.height = 3.0
	var spots: Array[Vector3] = []
	for i in 60:
		spots.append(_spot(1.1, 5.0, 5.0, 110.0))
	for i in 4:
		spots.append(_spot(0.55, 5.0, 4.0, 14.0, Terrain.ISLET_POS))
	for p in spots:
		if not p.is_finite():
			continue
		var mi := MeshInstance3D.new()
		mi.mesh = variants[_rng.randi() % variants.size()]
		mi.position = p - Vector3(0, 0.15, 0)
		mi.rotation.y = _rng.randf() * TAU
		var s := _rng.randf_range(0.85, 1.25)
		mi.scale = Vector3(s, s, s)
		add_child(mi)
		_tally("Palmeiras")
		_add_collider(trunk_shape, Transform3D(Basis.IDENTITY, p + Vector3(0, 1.5, 0)))


func _add_rock(mesh: ArrayMesh, p: Vector3, size: float) -> void:
	var scl := Vector3(size, size * _rng.randf_range(0.7, 1.2), size * _rng.randf_range(0.8, 1.3))
	var basis := Basis(Vector3.UP, _rng.randf() * TAU)
	var pos := p - Vector3(0, size * 0.2, 0)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.transform = Transform3D(basis.scaled_local(scl), pos)
	add_child(mi)
	_tally("Pedras")
	var verts: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var points := PackedVector3Array()
	for i in range(0, verts.size(), 11):
		points.append(verts[i] * scl)
	var shape := ConvexPolygonShape3D.new()
	shape.points = points
	_add_collider(shape, Transform3D(basis, pos))


func _build_rocks() -> void:
	var grey: Array[ArrayMesh] = []
	for i in 5:
		var tone := _rng.randf_range(0.3, 0.44)
		grey.append(Props.rock_mesh(_rng, Color(tone, tone * 0.97, tone * 0.93)))
	for i in 30:
		var p := _spot(-1.3, 0.9, 3.0)
		if p.is_finite():
			_add_rock(grey[_rng.randi() % grey.size()], p, _rng.randf_range(0.4, 1.7))
	for i in 12:
		var p := _spot(3.0, 20.0, 5.0)
		if p.is_finite():
			_add_rock(grey[_rng.randi() % grey.size()], p, _rng.randf_range(0.6, 2.2))
	for i in 26:
		var p := _spot(-11.0, -2.0, 6.0)
		if p.is_finite():
			_add_rock(grey[_rng.randi() % grey.size()], p, _rng.randf_range(0.8, 2.8))


func _build_corals() -> void:
	var colors := [Color(1.0, 0.45, 0.5), Color(1.0, 0.62, 0.25), Color(0.7, 0.4, 0.9), Color(0.95, 0.85, 0.35), Color(0.3, 0.8, 0.7)]
	var variants: Array[ArrayMesh] = []
	for c in colors:
		variants.append(Props.rock_mesh(_rng, c, 1.0, 0.75, false))
	var weed_mat := Props.material(Color(0.1, 0.32, 0.16), 0.8)
	for i in 34:
		var center := _spot(-9.0, -1.8, 5.0, 175.0)
		if not center.is_finite():
			continue
		for k in _rng.randi_range(3, 6):
			var off := Vector3(_rng.randf_range(-1.6, 1.6), 0.0, _rng.randf_range(-1.6, 1.6))
			var p := center + off
			p.y = terrain.height(p.x, p.z)
			var mi := MeshInstance3D.new()
			mi.mesh = variants[_rng.randi() % variants.size()]
			var s := _rng.randf_range(0.25, 0.7)
			mi.transform = Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled_local(Vector3(s, s * _rng.randf_range(0.8, 1.8), s)), p + Vector3(0, s * 0.3, 0))
			add_child(mi)
			_tally("Corais")
		for k in _rng.randi_range(2, 5):
			var off := Vector3(_rng.randf_range(-2.2, 2.2), 0.0, _rng.randf_range(-2.2, 2.2))
			var p := center + off
			p.y = terrain.height(p.x, p.z)
			var h := _rng.randf_range(0.8, 2.0)
			_tally("Algas")
			var weed := Props.cylinder(self, 0.01, 0.07, h, p + Vector3(0, h * 0.5, 0), weed_mat)
			weed.rotation = Vector3(_rng.randf_range(-0.2, 0.2), 0.0, _rng.randf_range(-0.2, 0.2))


func _build_bushes() -> void:
	var variants: Array[ArrayMesh] = []
	for i in 3:
		variants.append(Props.rock_mesh(_rng, Color(0.13, _rng.randf_range(0.24, 0.34), 0.09), 0.75, 0.35))
	for i in 70:
		var p := _spot(1.9, 20.0, 2.5, 100.0)
		if not p.is_finite():
			continue
		var mi := MeshInstance3D.new()
		mi.mesh = variants[_rng.randi() % variants.size()]
		var s := _rng.randf_range(0.5, 1.3)
		mi.transform = Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled_local(Vector3(s, s * 0.9, s)), p + Vector3(0, s * 0.25, 0))
		add_child(mi)
		_tally("Arbustos")


## Capim nas colinas e tufos esparsos na parte alta da praia, num único MultiMesh.
func _build_grass() -> void:
	var mesh := Props.grass_mesh(_rng)
	var mat := ShaderMaterial.new()
	mat.shader = GrassShader
	mesh.surface_set_material(0, mat)
	var xforms: Array[Transform3D] = []
	var centers := [[Vector2.ZERO, 108.0, 150000], [Terrain.ISLET_POS, 16.0, 2500]]
	for c in centers:
		var center: Vector2 = c[0]
		var radius: float = c[1]
		for i in c[2]:
			var a := _rng.randf() * TAU
			var r := sqrt(_rng.randf()) * radius
			var x := center.x + cos(a) * r
			var z := center.y + sin(a) * r
			var h: float = terrain.height(x, z)
			if h < 1.1:
				continue
			var chance := 0.015 + 0.985 * smoothstep(1.8, 2.9, h)
			if _rng.randf() > chance:
				continue
			var s := _rng.randf_range(0.7, 1.5)
			var basis := Basis(Vector3.UP, _rng.randf() * TAU).scaled_local(Vector3(s, s * _rng.randf_range(0.7, 1.4), s))
			xforms.append(Transform3D(basis, Vector3(x, h - 0.03, z)))
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	counts["Tufos de capim"] = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Grass"
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)


func _build_wildlife() -> void:
	var life := Wildlife.new()
	wildlife = life
	life.name = "Wildlife"
	add_child(life)
	for i in 7:
		var a := _rng.randf() * TAU
		var c := Vector3(cos(a) * 70.0, _rng.randf_range(14.0, 26.0), sin(a) * 70.0)
		life.add_gull(c, _rng.randf_range(18.0, 45.0), _rng.randf_range(0.18, 0.3) * (1.0 if i % 2 == 0 else -1.0), _rng.randf() * TAU)
	var colors := [Color(1.0, 0.55, 0.15), Color(0.95, 0.85, 0.2), Color(0.3, 0.7, 1.0), Color(1.0, 0.4, 0.55)]
	for i in 8:
		var p := _spot(-9.0, -2.5, 12.0, 170.0)
		if p.is_finite():
			life.add_school(p + Vector3(0, 1.2, 0), 9, colors[i % colors.size()])

	sharks = Sharks.new()
	sharks.name = "Sharks"
	add_child(sharks)
	var shark_rng := RandomNumberGenerator.new()
	shark_rng.seed = 77
	sharks.populate(self, terrain, shark_rng)
	sharks.spotted.connect(func(species: String) -> void: hud.show_message("%s — é manso, só está passeando" % species, 4.0))


func _build_audio() -> void:
	_ocean = AudioStreamPlayer.new()
	_ocean.stream = AudioGen.ocean()
	_ocean.volume_db = -9.0
	add_child(_ocean)
	_ocean.play()
	_chime = AudioStreamPlayer.new()
	_chime.stream = AudioGen.chime()
	_chime.volume_db = -6.0
	add_child(_chime)
	_splash_sound = AudioStreamPlayer.new()
	_splash_sound.stream = AudioGen.splash()
	_splash_sound.volume_db = -4.0
	add_child(_splash_sound)
	_step = AudioStreamPlayer.new()
	_step.stream = AudioGen.step()
	_step.volume_db = -16.0
	add_child(_step)


func _drop_mesh(radius: float) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = radius
	m.height = radius * 2.0
	m.radial_segments = 6
	m.rings = 3
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.92, 0.98, 1.0)
	m.material = mat
	return m


func _build_particles() -> void:
	_splash = CPUParticles3D.new()
	_splash.emitting = false
	_splash.one_shot = true
	_splash.amount = 60
	_splash.lifetime = 1.0
	_splash.explosiveness = 0.95
	_splash.direction = Vector3.UP
	_splash.spread = 38.0
	_splash.initial_velocity_min = 2.0
	_splash.initial_velocity_max = 5.5
	_splash.gravity = Vector3(0, -9.8, 0)
	_splash.scale_amount_min = 0.5
	_splash.scale_amount_max = 1.6
	_splash.mesh = _drop_mesh(0.045)
	add_child(_splash)

	_wake = CPUParticles3D.new()
	_wake.emitting = false
	_wake.amount = 40
	_wake.lifetime = 1.1
	_wake.direction = Vector3.UP
	_wake.spread = 80.0
	_wake.initial_velocity_min = 0.5
	_wake.initial_velocity_max = 1.6
	_wake.gravity = Vector3(0, -6.0, 0)
	_wake.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_wake.emission_sphere_radius = 0.35
	_wake.scale_amount_min = 0.4
	_wake.scale_amount_max = 1.0
	_wake.mesh = _drop_mesh(0.035)
	add_child(_wake)


func _add_shell(p: Vector3) -> void:
	var shell := Area3D.new()
	shell.set_script(ShellScript)
	shell.position = p + Vector3(0, 0.55, 0)
	shell.add_to_group("shells")
	add_child(shell)
	shell.collected.connect(_on_shell_collected)
	shells_total += 1


func _shell_spot(min_h: float, max_h: float, max_r: float, apart: float, center := Vector2.ZERO) -> Vector3:
	for attempt in 60:
		var p := _spot(min_h, max_h, 2.0, max_r, center)
		if not p.is_finite():
			break
		var ok := true
		for q in _shell_spots:
			if q.distance_to(p) < apart:
				ok = false
				break
		if ok:
			_shell_spots.append(p)
			return p
		_used.pop_back()
	return Vector3.INF


func _build_shells(pier_end: Vector3) -> void:
	var plan := [
		# [quantidade, altura mínima, altura máxima, raio, distância entre conchas, centro]
		[8, 0.25, 1.7, 120.0, 22.0, Vector2.ZERO],
		[4, 2.8, 20.0, 80.0, 18.0, Vector2.ZERO],
		[5, -6.5, -2.0, 150.0, 30.0, Vector2.ZERO],
		[2, 0.3, 5.0, 13.0, 7.0, Terrain.ISLET_POS],
	]
	for group in plan:
		for i in group[0]:
			var p := _shell_spot(group[1], group[2], group[3], group[4], group[5])
			if p.is_finite():
				_add_shell(p)
	_add_shell(pier_end)


# --- usado pelo console ---

func _tally(key: String) -> void:
	counts[key] = counts.get(key, 0) + 1


## Conchas ainda não coletadas.
func shells() -> Array:
	var out := []
	for s in get_tree().get_nodes_in_group("shells"):
		if not s.is_queued_for_deletion():
			out.append(s)
	return out


func add_shell_at(x: float, z: float) -> void:
	_add_shell(Vector3(x, terrain.height(x, z), z))
	hud.set_shells(shells_found, shells_total)


func collect_shell(shell: Area3D) -> void:
	shell.collected.emit(shell)
	shell.queue_free()


func remove_shells() -> int:
	var left := shells()
	for s in left:
		s.queue_free()
	shells_total -= left.size()
	hud.set_shells(shells_found, shells_total)
	return left.size()


## Sol: elevação acima do horizonte e direção, em graus. Perto do horizonte a luz cai.
func set_sun(elevation: float, direction: float) -> void:
	sun.rotation_degrees = Vector3(-elevation, direction, 0.0)
	var day := smoothstep(-4.0, 25.0, elevation)
	sun.light_energy = lerpf(0.0, 1.7, day)
	env.ambient_light_energy = lerpf(0.12, 0.9, day)


func refresh_fog() -> void:
	_set_fog(_was_underwater)


# --- eventos ---

func _on_shell_collected(_shell: Area3D) -> void:
	shells_found += 1
	hud.set_shells(shells_found, shells_total)
	_chime.pitch_scale = 1.0 + 0.03 * shells_found
	_chime.play()
	if shells_found >= shells_total:
		hud.show_message("Você encontrou todas as conchas! A ilha é toda sua.", 10.0)
	elif shells_found == 1:
		hud.show_message("Primeira concha! Siga os fachos de luz para achar as outras.", 5.0)


func _on_step() -> void:
	var wet := player.global_position.y < water_level() + 0.05
	_step.pitch_scale = _rng.randf_range(0.85, 1.15) * (0.7 if wet else 1.0)
	_step.volume_db = -11.0 if wet else -16.0
	_step.play()


func _on_splash(strength: float) -> void:
	_splash.position = Vector3(player.global_position.x, water_level() + 0.05, player.global_position.z)
	_splash.amount = int(30 + 50 * strength)
	_splash.restart()
	_splash_sound.volume_db = lerpf(-14.0, -3.0, strength)
	_splash_sound.play()


func _process(delta: float) -> void:
	_time += delta
	play_time += delta
	water.position.y = tide_base + TIDE_RANGE * sin(_time * 0.8)

	var cam := get_viewport().get_camera_3d()
	var under := cam != null and cam.global_position.y < water.position.y - 0.03
	if under != _was_underwater:
		_was_underwater = under
		_set_fog(under)
		hud.set_underwater(under)
		_ocean.volume_db = -22.0 if under else -9.0
		_ocean.pitch_scale = 0.55 if under else 1.0

	if not player:
		return

	# Respingos enquanto ela nada na superfície.
	var speed := Vector2(player.velocity.x, player.velocity.z).length()
	_wake.emitting = player.swimming and not player.underwater and speed > 0.8
	_wake.position = Vector3(player.global_position.x, water.position.y, player.global_position.z)

	# Correnteza: não deixa nadar para longe demais da ilha.
	var flat := Vector2(player.global_position.x, player.global_position.z)
	var dist := flat.length()
	_limit_warned -= delta
	if dist > SEA_LIMIT:
		var push := -flat.normalized() * (dist - SEA_LIMIT) * 0.6 * delta
		player.global_position += Vector3(push.x, 0.0, push.y)
		if _limit_warned <= 0.0:
			_limit_warned = 8.0
			hud.show_message("A correnteza está forte demais... melhor voltar para a ilha.", 4.0)
