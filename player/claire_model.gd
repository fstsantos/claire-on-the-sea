extends Node3D
## Claire: modelo 3D pronto (Kenney Mini Characters, CC0) recolorido para o avatar
## dela. Em terra usa as animações do próprio modelo; na água, como o pacote não
## tem nado, as poses de crawl e de boiar são aplicadas por código no esqueleto.
## A frente deste nó é o -Z (o modelo original olha para +Z e é girado aqui).

signal stepped

const ModelScene := preload("res://player/claire/character-female-f.glb")
const RecolorShader := preload("res://player/claire/recolor.gdshader")
const Palette := preload("res://player/claire/Textures/colormap.png")

## O modelo original tem 0,78 m; com esta escala fica com uns 1,35 m.
const MODEL_SCALE := 1.75
## Altura do ponto em torno do qual o corpo deita para nadar.
const PIVOT_HEIGHT := 0.75

var _pivot: Node3D
var _skeleton: Skeleton3D
var _anim: AnimationPlayer
var _bone := {}
var _phase := 0.0
var _current := ""
var _was_swimming := false
var _last_cycle := 0.0


func _ready() -> void:
	_pivot = Node3D.new()
	_pivot.position.y = PIVOT_HEIGHT
	add_child(_pivot)

	var inst: Node3D = ModelScene.instantiate()
	inst.rotation.y = PI
	inst.scale = Vector3.ONE * MODEL_SCALE
	inst.position.y = -PIVOT_HEIGHT
	_pivot.add_child(inst)

	_skeleton = inst.find_child("Skeleton3D", true, false)
	_anim = inst.find_child("AnimationPlayer", true, false)
	for n in ["idle", "walk", "sprint"]:
		_anim.get_animation(n).loop_mode = Animation.LOOP_LINEAR
	for n in ["root", "torso", "head", "arm-left", "arm-right", "leg-left", "leg-right"]:
		_bone[n] = _skeleton.find_bone(n)

	for mi in inst.find_children("*", "MeshInstance3D", true, false):
		var mat := ShaderMaterial.new()
		mat.shader = RecolorShader
		mat.set_shader_parameter("palette", Palette)
		mat.set_shader_parameter("is_head", String(mi.name).begins_with("head"))
		(mi as MeshInstance3D).material_override = mat

	_add_love_label()
	_play("idle", 1.0)


## "love" no peito, preso ao osso do tronco para acompanhar as animações.
func _add_love_label() -> void:
	var attach := BoneAttachment3D.new()
	attach.bone_name = "torso"
	_skeleton.add_child(attach)
	var label := Label3D.new()
	label.text = "love"
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Segoe Script", "Brush Script MT", "Comic Sans MS", "cursive"])
	font.font_italic = true
	font.font_weight = 700
	label.font = font
	label.font_size = 64
	label.pixel_size = 0.0007
	label.outline_size = 0
	label.modulate = Color(1, 1, 1)
	label.shaded = true
	label.double_sided = false
	label.position = Vector3(0.0, 0.1, 0.152)
	attach.add_child(label)


func _play(anim_name: String, speed: float) -> void:
	if _current != anim_name:
		_current = anim_name
		_anim.play(anim_name, 0.12)
		_last_cycle = 0.0
	_anim.speed_scale = speed


func _pose(bone_name: String, target: Quaternion, k: float) -> void:
	var idx: int = _bone[bone_name]
	_skeleton.set_bone_pose_rotation(idx, _skeleton.get_bone_pose_rotation(idx).slerp(target, k))


## speed: velocidade horizontal em m/s. vertical_speed: usada no pulo e no mergulho.
func animate(delta: float, speed: float, on_floor: bool, swimming: bool, vertical_speed: float) -> void:
	var k := 1.0 - exp(-8.0 * delta)
	if swimming:
		_swim_pose(delta, speed, vertical_speed, k)
		_was_swimming = true
		return

	if _was_swimming:
		_was_swimming = false
		_skeleton.reset_bone_poses()
		_current = ""
	_pivot.rotation.x = lerp_angle(_pivot.rotation.x, 0.0, k)
	_pivot.rotation.z = lerp_angle(_pivot.rotation.z, 0.0, k)

	if not on_floor:
		_play("jump" if vertical_speed > 0.5 else "fall", 1.0)
	elif speed < 0.5:
		_play("idle", 1.0)
	elif speed < 6.8:
		_play("walk", clampf(speed / 3.6, 0.7, 1.9))
	else:
		_play("sprint", clampf(speed / 7.5, 0.8, 1.5))

	# um passo a cada meia volta da animação de andar ou correr
	if on_floor and (_current == "walk" or _current == "sprint") and _anim.current_animation_length > 0.0:
		var cycle := _anim.current_animation_position / _anim.current_animation_length
		if floorf(cycle * 2.0) != floorf(_last_cycle * 2.0):
			stepped.emit()
		_last_cycle = cycle


func _swim_pose(delta: float, speed: float, vertical_speed: float, k: float) -> void:
	if not _was_swimming:
		_anim.pause()
		_current = ""
	var moving := clampf(speed / 1.5, 0.0, 1.0)
	_phase += delta * lerpf(2.6, 4.5 + speed * 0.95, moving)
	var p := _phase

	var pitch := lerpf(-0.12, -1.3, moving) + clampf(vertical_speed * 0.22, -0.55, 0.55)
	_pivot.rotation.x = lerp_angle(_pivot.rotation.x, pitch, 1.0 - exp(-7.0 * delta))
	_pivot.rotation.z = lerp_angle(_pivot.rotation.z, sin(p) * 0.12 * moving, k)

	var x := Vector3.RIGHT
	var y := Vector3.UP
	var z := Vector3.BACK
	_pose("root", Quaternion.IDENTITY, k)
	_pose("torso", Quaternion.IDENTITY, k)
	if moving > 0.5:
		# crawl: os braços apontam para a frente e giram em círculos alternados
		_pose("arm-left", Quaternion(x, p) * Quaternion(z, PI * 0.5), 1.0)
		_pose("arm-right", Quaternion(x, p + PI) * Quaternion(z, -PI * 0.5), 1.0)
		_pose("leg-left", Quaternion(x, sin(p * 2.0) * 0.4), k)
		_pose("leg-right", Quaternion(x, -sin(p * 2.0) * 0.4), k)
		_pose("head", Quaternion(x, -1.0), k)
	else:
		# boiando: braços abertos remando, pernas pedalando
		_pose("arm-left", Quaternion(y, sin(p) * 0.45) * Quaternion(z, -0.35), k)
		_pose("arm-right", Quaternion(y, -sin(p) * 0.45) * Quaternion(z, 0.35), k)
		_pose("leg-left", Quaternion(x, sin(p) * 0.45), k)
		_pose("leg-right", Quaternion(x, -sin(p) * 0.45), k)
		_pose("head", Quaternion(x, -0.2), k)
