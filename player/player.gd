extends CharacterBody3D
## Claire em terceira pessoa: anda e corre na areia, entra na água
## andando e passa a nadar quando fica fundo. Na água, mergulha e sobe.
## O corpo nunca gira: só o Model vira para a direção do movimento.

signal splashed(strength: float)

## Profundidade (pés abaixo da superfície) em que ela começa a nadar.
const SWIM_ENTER := 0.95
## Profundidade do fundo em que ela volta a ficar em pé.
const SWIM_EXIT := 0.7
## Distância entre os pés e a superfície enquanto boia.
const SWIM_FLOAT := 0.72

@export var walk_speed := 5.2
@export var sprint_speed := 9.0
@export var swim_speed := 3.8
@export var swim_sprint_speed := 6.0
@export var acceleration := 70.0
@export var air_acceleration := 35.0
@export var jump_velocity := 7.4
## Gravidade na subida e na queda: cair mais rápido deixa o pulo seco.
@export var rise_gravity := 26.0
@export var fall_gravity := 40.0
@export var turn_speed := 18.0
## Tolerâncias do pulo: logo após sair do chão e pouco antes de tocar nele.
@export var coyote_time := 0.12
@export var jump_buffer := 0.12

@onready var model: Node3D = $Model
@onready var camera_rig: Node3D = $CameraRig

## O mundo (world.gd) fornece water_level() e ground_height().
var world: Node
var swimming := false
var underwater := false
var spawn_point := Vector3.ZERO
## Usados pelo console: trava os controles enquanto ele está aberto, modo de voo
## e multiplicadores de velocidade e de pulo.
var controls_locked := false
var flying := false
var speed_mult := 1.0
var jump_mult := 1.0

var _air_time := 0.0
var _jump_wanted := 0.0


func _physics_process(delta: float) -> void:
	var input := Vector2.ZERO if controls_locked else Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := Basis(Vector3.UP, camera_rig.rotation.y) * Vector3(input.x, 0.0, input.y)
	if direction.length_squared() > 1.0:
		direction = direction.normalized()

	var surface := -1000.0
	var ground := -1000.0
	if world:
		surface = world.water_level()
		ground = world.ground_height(global_position)
	var depth := surface - global_position.y

	if not swimming and depth > SWIM_ENTER:
		swimming = true
		if velocity.y < -2.5:
			splashed.emit(clampf(-velocity.y / 8.0, 0.3, 1.0))
	elif swimming and (ground > surface - SWIM_EXIT or (is_on_floor() and depth < SWIM_EXIT)):
		swimming = false
		underwater = false

	if flying:
		_fly(direction)
	elif swimming:
		_swim(delta, direction, surface)
	else:
		_walk(delta, direction, depth)

	if direction.length_squared() > 0.001:
		var target_yaw := atan2(-direction.x, -direction.z)
		model.rotation.y = lerp_angle(model.rotation.y, target_yaw, minf(turn_speed * delta, 1.0))

	move_and_slide()

	var h_speed := Vector2(velocity.x, velocity.z).length()
	model.animate(delta, 0.0 if flying else h_speed, is_on_floor(), swimming, 0.0 if flying else velocity.y)

	if global_position.y < -40.0:
		global_position = spawn_point
		velocity = Vector3.ZERO


func _held(action: String) -> bool:
	return not controls_locked and Input.is_action_pressed(action)


## Modo de voo do console: sem gravidade; Espaço sobe e Ctrl desce.
func _fly(direction: Vector3) -> void:
	swimming = false
	underwater = false
	var speed := (32.0 if _held("sprint") else 14.0) * speed_mult
	var lift := 0.0
	if _held("jump"):
		lift = 1.0
	elif _held("dive"):
		lift = -1.0
	velocity = direction * speed + Vector3.UP * lift * speed * 0.7


func _walk(delta: float, direction: Vector3, depth: float) -> void:
	var wade := clampf(depth / SWIM_ENTER, 0.0, 1.0)
	_air_time = 0.0 if is_on_floor() else _air_time + delta
	_jump_wanted -= delta
	if not controls_locked and Input.is_action_just_pressed("jump"):
		_jump_wanted = jump_buffer

	if not is_on_floor():
		var rising := velocity.y > 0.0 and _held("jump")
		velocity.y -= (rise_gravity if rising else fall_gravity) * delta
	if _jump_wanted > 0.0 and _air_time <= coyote_time and velocity.y <= 0.1 and depth < 0.6:
		velocity.y = jump_velocity * jump_mult
		_jump_wanted = 0.0
		_air_time = coyote_time + 1.0

	var speed := (sprint_speed if _held("sprint") else walk_speed) * speed_mult
	speed *= lerpf(1.0, 0.55, wade)
	var accel := acceleration if is_on_floor() else air_acceleration
	var horizontal := Vector3(velocity.x, 0.0, velocity.z).move_toward(direction * speed, accel * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z


func _swim(delta: float, direction: Vector3, surface: float) -> void:
	var speed := (swim_sprint_speed if _held("sprint") else swim_speed) * speed_mult
	var horizontal := Vector3(velocity.x, 0.0, velocity.z).move_toward(direction * speed, 16.0 * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z

	# below > 0: ela está abaixo da linha em que boia.
	var below := surface - SWIM_FLOAT - global_position.y
	var target := 0.5
	if _held("dive"):
		target = -4.2
	elif _held("jump"):
		target = 4.6
	if target > 0.0 and below < 0.25:
		target = below * 5.0
	velocity.y = lerpf(velocity.y, target, 1.0 - exp(-9.0 * delta))
	if below < 0.0 and velocity.y > below * 8.0:
		velocity.y = below * 8.0
	underwater = below > 0.6
