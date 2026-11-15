extends Area3D
## Concha colecionável: gira, flutua e tem um facho de luz para ser vista de longe.

signal collected(shell: Area3D)

var _t := 0.0
var _visual: Node3D


func _ready() -> void:
	_t = randf() * TAU
	var col := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.85
	col.shape = shape
	add_child(col)

	_visual = Node3D.new()
	add_child(_visual)

	var shell_mat := StandardMaterial3D.new()
	shell_mat.albedo_color = Color(1.0, 0.8, 0.76)
	shell_mat.roughness = 0.35
	shell_mat.emission_enabled = true
	shell_mat.emission = Color(1.0, 0.55, 0.45)
	shell_mat.emission_energy_multiplier = 0.5

	# Concha em leque: gomos saindo de uma base.
	for i in 7:
		var rib := MeshInstance3D.new()
		var m := CapsuleMesh.new()
		m.radius = 0.035
		m.height = 0.26
		m.radial_segments = 8
		m.rings = 3
		m.material = shell_mat
		rib.mesh = m
		var a := (i - 3) * 0.3
		rib.position = Vector3(sin(a) * 0.12, cos(a) * 0.12, 0.0)
		rib.rotation.z = -a
		rib.scale = Vector3(1.0, 1.0, 0.6)
		_visual.add_child(rib)
	var base := MeshInstance3D.new()
	var bm := SphereMesh.new()
	bm.radius = 0.06
	bm.height = 0.12
	bm.radial_segments = 10
	bm.rings = 5
	bm.material = shell_mat
	base.mesh = bm
	_visual.add_child(base)
	_visual.rotation.x = -0.35

	var beam := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.3
	cm.bottom_radius = 0.05
	cm.height = 7.0
	cm.radial_segments = 10
	cm.rings = 1
	cm.cap_top = false
	cm.cap_bottom = false
	var beam_mat := StandardMaterial3D.new()
	beam_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	beam_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	beam_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	beam_mat.albedo_color = Color(1.0, 0.85, 0.6, 0.13)
	beam_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	beam_mat.disable_fog = true
	cm.material = beam_mat
	beam.mesh = cm
	beam.position.y = 3.5
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(beam)

	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	_t += delta
	_visual.rotation.y = _t * 1.5
	_visual.position.y = sin(_t * 2.0) * 0.08


func _on_body_entered(body: Node3D) -> void:
	if body is CharacterBody3D:
		collected.emit(self)
		queue_free()
