extends CanvasLayer
## Interface: contador de conchas, dica de controles, mensagens e o tom azul debaixo d'água.

var _shells: Label
var _hint: Label
var _message: Label
var _big: Label
var _big_time := 0.0
var _big_age := 0.0
var _overlay: ColorRect
var _hint_time := 16.0
var _message_time := 0.0


func _ready() -> void:
	_overlay = ColorRect.new()
	_overlay.color = Color(0.0, 0.32, 0.42, 0.3)
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.visible = false
	add_child(_overlay)

	_shells = _label(30)
	_shells.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_shells.position = Vector2(24, 16)

	_hint = _label(18)
	_hint.anchor_left = 0.0
	_hint.anchor_right = 1.0
	_hint.anchor_top = 1.0
	_hint.anchor_bottom = 1.0
	_hint.offset_left = 20
	_hint.offset_right = -20
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_hint.offset_top = -90
	_hint.offset_bottom = -20
	_hint.text = "WASD andar   ·   Mouse olhar   ·   Shift correr   ·   Espaço pular / subir   ·   Ctrl mergulhar   ·   Roda zoom   ·   Esc solta o mouse   ·   ' abre/fecha o console"

	_message = _label(34)
	_message.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_message.anchor_left = 0.0
	_message.anchor_right = 1.0
	_message.offset_left = 0
	_message.offset_right = 0
	_message.offset_top = 90
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.modulate.a = 0.0

	_big = _label(72)
	_big.anchor_left = 0.0
	_big.anchor_right = 1.0
	_big.anchor_top = 0.3
	_big.anchor_bottom = 0.3
	_big.offset_top = -60
	_big.offset_bottom = 60
	_big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_big.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_big.label_settings.font_color = Color(1.0, 0.86, 0.45)
	_big.label_settings.outline_size = 14
	_big.label_settings.outline_color = Color(0.45, 0.1, 0.4, 0.95)
	_big.label_settings.shadow_size = 10
	_big.label_settings.shadow_color = Color(0, 0, 0, 0.45)
	_big.modulate.a = 0.0


func _label(size: int) -> Label:
	var l := Label.new()
	var s := LabelSettings.new()
	s.font_size = size
	s.font_color = Color(1, 1, 1)
	s.outline_size = 6
	s.outline_color = Color(0.05, 0.2, 0.3, 0.9)
	l.label_settings = s
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l


func set_shells(found: int, total: int) -> void:
	_shells.text = "Conchas  %d / %d" % [found, total]


func show_message(text: String, seconds := 4.0) -> void:
	_message.text = text
	_message_time = seconds


## Letreiro grande no meio da tela, com um pulinho ao aparecer.
func show_big(text: String, seconds := 7.0) -> void:
	_big.text = text
	_big_time = seconds
	_big_age = 0.0


func set_underwater(value: bool) -> void:
	_overlay.visible = value


func _process(delta: float) -> void:
	_hint_time -= delta
	_hint.modulate.a = clampf(_hint_time, 0.0, 1.0)
	_message_time -= delta
	_message.modulate.a = move_toward(_message.modulate.a, 1.0 if _message_time > 0.0 else 0.0, delta * 2.0)
	_big_time -= delta
	_big_age += delta
	_big.modulate.a = move_toward(_big.modulate.a, 1.0 if _big_time > 0.0 else 0.0, delta * 2.5)
	_big.pivot_offset = _big.size * 0.5
	var pop := 1.0 + 0.35 * exp(-_big_age * 5.0) * cos(_big_age * 14.0)
	_big.scale = Vector2.ONE * pop * (1.0 + 0.03 * sin(_big_age * 3.0))
