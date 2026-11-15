extends Node3D
## Vida ao redor da ilha: gaivotas circulando no céu e cardumes no fundo.

var _gulls: Array = []
var _fish: Array = []
var school_centers: Array[Vector3] = []
var _t := 0.0


func _mat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.6
	return m


func add_gull(center: Vector3, radius: float, speed: float, phase: float) -> void:
	var gull := Node3D.new()
	var white := _mat(Color(0.97, 0.97, 0.97))
	var grey := _mat(Color(0.6, 0.63, 0.68))
	var body := MeshInstance3D.new()
	var bm := SphereMesh.new()
	bm.radius = 0.16
	bm.height = 0.32
	bm.radial_segments = 8
	bm.rings = 4
	bm.material = white
	body.mesh = bm
	body.scale = Vector3(0.8, 0.8, 2.4)
	gull.add_child(body)
	var wings := []
	for side in [-1.0, 1.0]:
		var pivot := Node3D.new()
		pivot.position = Vector3(side * 0.08, 0.05, 0.0)
		var wing := MeshInstance3D.new()
		var wm := BoxMesh.new()
		wm.size = Vector3(0.95, 0.025, 0.3)
		wm.material = grey
		wing.mesh = wm
		wing.position = Vector3(side * 0.47, 0.0, 0.0)
		pivot.add_child(wing)
		gull.add_child(pivot)
		wings.append(pivot)
	add_child(gull)
	_gulls.append({"node": gull, "wings": wings, "center": center, "radius": radius, "speed": speed, "phase": phase})


func add_school(center: Vector3, count: int, color: Color) -> void:
	school_centers.append(center)
	var mat := _mat(color)
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 0.25
	for i in count:
		var fish := Node3D.new()
		var body := MeshInstance3D.new()
		var bm := SphereMesh.new()
		bm.radius = 0.1
		bm.height = 0.2
		bm.radial_segments = 8
		bm.rings = 4
		bm.material = mat
		body.mesh = bm
		body.scale = Vector3(0.45, 0.8, 1.7)
		fish.add_child(body)
		var tail := MeshInstance3D.new()
		var tm := PrismMesh.new()
		tm.size = Vector3(0.16, 0.14, 0.02)
		tm.material = mat
		tail.mesh = tm
		tail.rotation = Vector3(PI * 0.5, 0.0, PI * 0.5)
		tail.position = Vector3(0.0, 0.0, 0.2)
		fish.add_child(tail)
		add_child(fish)
		_fish.append({
			"node": fish, "tail": tail, "center": center,
			"radius": randf_range(1.5, 4.0), "speed": randf_range(0.35, 0.6),
			"phase": randf() * TAU, "height": randf_range(-0.5, 0.6),
		})


func gull_count() -> int:
	return _gulls.size()


func fish_count() -> int:
	return _fish.size()


func gulls() -> Array:
	return _gulls


func clear_gulls() -> int:
	var n := _gulls.size()
	for g in _gulls:
		g.node.queue_free()
	_gulls.clear()
	return n


func clear_fish() -> int:
	var n := _fish.size()
	for f in _fish:
		f.node.queue_free()
	_fish.clear()
	school_centers.clear()
	return n


func _process(delta: float) -> void:
	_t += delta
	for g in _gulls:
		var a: float = g.phase + _t * g.speed
		var c: Vector3 = g.center
		var r: float = g.radius
		var node: Node3D = g.node
		node.position = c + Vector3(cos(a) * r, sin(a * 2.3) * 1.5, sin(a) * r)
		# voa no sentido em que o ângulo cresce; a frente é o -Z
		node.rotation = Vector3(0.0, -a + PI, 0.25)
		var flap := sin(_t * 5.0 + g.phase * 3.0) * 0.45 + 0.1
		g.wings[0].rotation.z = -flap
		g.wings[1].rotation.z = flap
	for f in _fish:
		var a: float = f.phase + _t * f.speed
		var c: Vector3 = f.center
		var r: float = f.radius
		var node: Node3D = f.node
		node.position = c + Vector3(cos(a) * r, f.height + sin(a * 3.0) * 0.15, sin(a) * r)
		node.rotation.y = -a + PI
		f.tail.rotation.y = sin(_t * 9.0 + f.phase) * 0.5
