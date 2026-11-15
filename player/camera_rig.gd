extends Node3D
## Câmera orbital em terceira pessoa.
## Este nó fica na altura da cabeça e gira no eixo Y (yaw).
## O SpringArm3D filho gira no eixo X (pitch) e encurta ao colidir,
## para a câmera não atravessar o terreno e as pedras.

@export var mouse_sensitivity := 0.004
## Velocidade de giro pelo analógico direito, em rad/s.
@export var stick_sensitivity := 3.6
@export_range(-89.0, 0.0) var min_pitch_deg := -70.0
@export_range(0.0, 89.0) var max_pitch_deg := 40.0
@export var min_distance := 2.0
@export var max_distance := 9.0
@export var zoom_step := 0.5
## Suavização do zoom (maior = mais rápido).
@export var zoom_smoothing := 10.0

@onready var arm: SpringArm3D = $SpringArm3D
@onready var camera: Camera3D = $SpringArm3D/Camera3D

var _target_distance: float
var _capture := true


func _ready() -> void:
	_target_distance = arm.spring_length
	var body := get_parent() as CollisionObject3D
	if body:
		arm.add_excluded_object(body.get_rid())
	_capture = not OS.get_cmdline_user_args().has("--no-capture")
	if _capture:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	var captured := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED

	if event is InputEventMouseMotion and captured:
		_rotate(event.relative * mouse_sensitivity)
	elif event is InputEventMouseButton and event.pressed:
		if not captured and _capture:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_target_distance = maxf(_target_distance - zoom_step, min_distance)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_target_distance = minf(_target_distance + zoom_step, max_distance)
	elif event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F11:
		var full := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if full else DisplayServer.WINDOW_MODE_FULLSCREEN)


func _process(delta: float) -> void:
	var look := Input.get_vector("look_left", "look_right", "look_up", "look_down")
	if look != Vector2.ZERO:
		_rotate(look * stick_sensitivity * delta)

	arm.spring_length = lerpf(arm.spring_length, _target_distance, minf(zoom_smoothing * delta, 1.0))


## amount.x > 0 gira para a direita; amount.y > 0 olha para baixo.
func _rotate(amount: Vector2) -> void:
	rotation.y = wrapf(rotation.y - amount.x, -PI, PI)
	arm.rotation.x = clampf(arm.rotation.x - amount.y, deg_to_rad(min_pitch_deg), deg_to_rad(max_pitch_deg))
