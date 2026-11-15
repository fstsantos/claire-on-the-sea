extends CanvasLayer
## Console do jogo: abre com a tecla ~ (a que fica abaixo do Esc) ou F1.
## Os comandos podem ser digitados com ou sem a barra: "/status" ou "status".

const Terrain := preload("res://world/terrain.gd")

const C_TITLE := "#ffd27a"
const C_DIM := "#9fb4c0"
const C_OK := "#9fe8a8"
const C_ERR := "#ff8a80"
const C_CMD := "#8fd3ff"

var world: Node3D
var is_open := false

var _root: Control
var _out: RichTextLabel
var _in: LineEdit
var _cmds := {}
var _order: Array[String] = []
var _history: Array[String] = []
var _hist_pos := 0
var _prev_mouse := Input.MOUSE_MODE_VISIBLE
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	layer = 20
	_rng.randomize()
	_build_ui()
	_register()
	_print("[color=%s]Console da Claire on the Sea[/color] — digite [color=%s]/ajuda[/color] para ver os comandos." % [C_TITLE, C_CMD])


# --- interface ---

func _build_ui() -> void:
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Consolas", "Cascadia Mono", "DejaVu Sans Mono", "Liberation Mono", "monospace"])

	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.visible = false
	add_child(_root)

	var panel := PanelContainer.new()
	panel.anchor_right = 1.0
	panel.anchor_bottom = 0.6
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.02, 0.07, 0.1, 0.95)
	box.border_color = Color(0.3, 0.6, 0.7, 0.9)
	box.border_width_bottom = 2
	box.content_margin_left = 14
	box.content_margin_right = 14
	box.content_margin_top = 10
	box.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", box)
	_root.add_child(panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	panel.add_child(col)

	_out = RichTextLabel.new()
	_out.bbcode_enabled = true
	_out.scroll_following = true
	_out.selection_enabled = true
	_out.focus_mode = Control.FOCUS_NONE
	_out.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for slot in ["normal_font", "bold_font", "mono_font"]:
		_out.add_theme_font_override(slot, font)
	for slot in ["normal_font_size", "bold_font_size", "mono_font_size"]:
		_out.add_theme_font_size_override(slot, 17)
	col.add_child(_out)

	_in = LineEdit.new()
	_in.placeholder_text = "comando...  (/ajuda)"
	_in.add_theme_font_override("font", font)
	_in.add_theme_font_size_override("font_size", 18)
	_in.set("keep_editing_on_text_submit", true)
	_in.text_submitted.connect(_on_submit)
	col.add_child(_in)


func _is_toggle(e: InputEventKey) -> bool:
	return e.physical_keycode == KEY_QUOTELEFT or e.keycode == KEY_QUOTELEFT \
		or e.keycode == KEY_ASCIITILDE or e.unicode == 96 or e.unicode == 126 or e.keycode == KEY_F1


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed:
		return
	var key := event as InputEventKey
	if _is_toggle(key):
		if not key.echo:
			toggle()
		get_viewport().set_input_as_handled()
		return
	if not is_open:
		return
	match key.keycode:
		KEY_ESCAPE:
			toggle()
		KEY_UP:
			_browse(-1)
		KEY_DOWN:
			_browse(1)
		KEY_TAB:
			_complete()
		KEY_PAGEUP:
			_out.get_v_scroll_bar().value -= 200.0
		KEY_PAGEDOWN:
			_out.get_v_scroll_bar().value += 200.0
		_:
			return
	get_viewport().set_input_as_handled()


func toggle() -> void:
	is_open = not is_open
	_root.visible = is_open
	if world and world.player:
		world.player.controls_locked = is_open
	if is_open:
		_prev_mouse = Input.mouse_mode
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_focus.call_deferred()
	else:
		_in.release_focus()
		Input.mouse_mode = _prev_mouse


func _focus() -> void:
	_in.clear()
	_in.grab_focus()
	if _in.has_method("edit"):
		_in.call("edit")


func _browse(step: int) -> void:
	if _history.is_empty():
		return
	_hist_pos = clampi(_hist_pos + step, 0, _history.size())
	_in.text = "" if _hist_pos == _history.size() else _history[_hist_pos]
	_in.caret_column = _in.text.length()


func _complete() -> void:
	var typed := norm(_in.text.strip_edges().trim_prefix("/"))
	if typed.contains(" "):
		return
	var hits: Array[String] = []
	for name in _cmds:
		if name.begins_with(typed):
			hits.append(name)
	if hits.size() == 1:
		_in.text = "/" + hits[0] + " "
		_in.caret_column = _in.text.length()
	elif hits.size() > 1:
		hits.sort()
		_print("[color=%s]%s[/color]" % [C_DIM, "  ".join(hits)])


func _on_submit(text: String) -> void:
	_in.clear()
	_focus.call_deferred()
	run(text)


func _print(text: String) -> void:
	_out.append_text(text + "\n")


func _ok(text: String) -> void:
	_print("[color=%s]%s[/color]" % [C_OK, text])


func _err(text: String) -> void:
	_print("[color=%s]%s[/color]" % [C_ERR, text])


func _title(text: String) -> void:
	_print("[color=%s]== %s ==[/color]" % [C_TITLE, text])


# --- execução ---

## Minúsculas e sem acentos, para aceitar "tubarão" e "tubarao".
static func norm(text: String) -> String:
	text = text.to_lower()
	var from := "áàâãéêíóôõúç"
	var to := "aaaaeeiooouc"
	for i in from.length():
		text = text.replace(from[i], to[i])
	return text


func _reg(names: Array, fn: Callable, usage: String, about: String) -> void:
	var entry := {"fn": fn, "usage": usage, "about": about}
	for n in names:
		_cmds[n] = entry
	_order.append(names[0])


func _register() -> void:
	_reg(["ajuda", "help", "?"], _cmd_help, "/ajuda", "lista os comandos")
	_reg(["status"], _cmd_status, "/status [mundo|claire|conchas|tubaroes|bichos|cenario]", "detalhe de todas as entidades do mundo")
	_reg(["tp"], _cmd_tp, "/tp <x> <z> | <x> <y> <z> | concha [n] | tubarao [espécie] | inicio | pier | ilhota | centro", "teleporta a Claire")
	_reg(["criar", "spawn"], _cmd_spawn, "/criar tubarao <espécie> [n] | concha [n] | gaivota [n] | cardume [n]", "cria entidades perto da Claire")
	_reg(["remover", "remove"], _cmd_remove, "/remover tubaroes [espécie] | conchas | gaivotas | peixes | tudo", "tira entidades do mundo")
	_reg(["coletar"], _cmd_collect, "/coletar [n | todas]", "coleta a concha mais próxima, a de número n ou todas")
	_reg(["velocidade"], _cmd_speed, "/velocidade [claire|tubaroes] <mult>", "multiplica a velocidade (1 = normal)")
	_reg(["pulo"], _cmd_jump, "/pulo <mult>", "multiplica a força do pulo (1 = normal)")
	_reg(["voar"], _cmd_fly, "/voar", "liga/desliga o voo (Espaço sobe, Ctrl desce, Shift acelera)")
	_reg(["sol"], _cmd_sun, "/sol <elevação> [direção]", "posição do sol em graus (27 e -62 = padrão; 0 = pôr do sol)")
	_reg(["mare"], _cmd_tide, "/mare <metros>", "nível do mar (0.07 = padrão)")
	_reg(["nevoa"], _cmd_fog, "/nevoa <mult>", "densidade da névoa (1 = padrão, 0 = sem)")
	_reg(["tempo"], _cmd_time, "/tempo <escala>", "velocidade do jogo (1 = normal, 0.2 = câmera lenta)")
	_reg(["limpar", "clear"], _cmd_clear, "/limpar", "limpa o console")
	_reg(["reiniciar"], _cmd_restart, "/reiniciar", "recomeça o mundo do zero")


func run(line: String) -> void:
	line = line.strip_edges()
	if line.is_empty():
		return
	_print("[color=%s]> %s[/color]" % [C_CMD, line])
	if _history.is_empty() or _history[-1] != line:
		_history.append(line)
	_hist_pos = _history.size()
	var parts := line.trim_prefix("/").split(" ", false)
	if parts.is_empty():
		return
	var name := norm(parts[0])
	if not _cmds.has(name):
		_err("Comando desconhecido: %s — use /ajuda" % parts[0])
		return
	var args: Array[String] = []
	for i in range(1, parts.size()):
		args.append(parts[i])
	_cmds[name].fn.call(args)


func _usage(name: String) -> void:
	_err("Uso: " + _cmds[name].usage)


func _count_arg(a: Array[String], i: int, max_n: int) -> int:
	if a.size() > i and a[i].is_valid_int():
		return clampi(a[i].to_int(), 1, max_n)
	return 1


func _v(p: Vector3) -> String:
	return "(%7.1f, %5.1f, %7.1f)" % [p.x, p.y, p.z]


func _dist(p: Vector3) -> float:
	return p.distance_to(world.player.global_position)


# --- comandos ---

func _cmd_help(_a: Array[String]) -> void:
	_title("COMANDOS")
	for name in _order:
		_print("[color=%s]%s[/color]\n    [color=%s]%s[/color]" % [C_CMD, _cmds[name].usage, C_DIM, _cmds[name].about])
	_print("[color=%s]~ ou F1 abre/fecha · ↑↓ histórico · Tab completa · PageUp/PageDown rola[/color]" % C_DIM)


func _cmd_clear(_a: Array[String]) -> void:
	_out.clear()


func _cmd_status(a: Array[String]) -> void:
	var what := norm(a[0]) if a.size() > 0 else ""
	var all := what.is_empty()
	var shown := false
	if all or what.begins_with("mundo"):
		_status_world()
		shown = true
	if all or what.begins_with("claire"):
		_status_claire()
		shown = true
	if all or what.begins_with("concha"):
		_status_shells()
		shown = true
	if all or what.begins_with("tubar"):
		_status_sharks()
		shown = true
	if all or what.begins_with("bicho") or what.begins_with("gaivota") or what.begins_with("peixe"):
		_status_wildlife()
		shown = true
	if all or what.begins_with("cenario"):
		_status_scenery()
		shown = true
	if not shown:
		_usage("status")


func _status_world() -> void:
	_title("MUNDO")
	var t := int(world.play_time)
	_print("Tempo de jogo %02d:%02d · %d FPS · escala de tempo %.2fx · %d nós na cena" % [
		t / 60, t % 60, int(Engine.get_frames_per_second()), Engine.time_scale, get_tree().get_node_count()])
	_print("Mar: nível agora %.2f m (base %.2f, maré ±%.2f) · correnteza a partir de %d m do centro" % [
		world.water_level(), world.tide_base, world.TIDE_RANGE, int(world.SEA_LIMIT)])
	var rot: Vector3 = world.sun.rotation_degrees
	_print("Sol: elevação %.0f° · direção %.0f° · luz %.2f · névoa %.2fx" % [-rot.x, rot.y, world.sun.light_energy, world.fog_scale])
	_print("Terreno: %d × %d m · ilha com raio ~%d m · ilhota em (%d, %d)" % [
		int(Terrain.SIZE), int(Terrain.SIZE), int(Terrain.ISLAND_RADIUS), int(Terrain.ISLET_POS.x), int(Terrain.ISLET_POS.y)])


func _status_claire() -> void:
	_title("CLAIRE")
	var p: CharacterBody3D = world.player
	var pos := p.global_position
	var speed := Vector2(p.velocity.x, p.velocity.z).length()
	var state := "parada"
	if p.flying:
		state = "voando"
	elif p.underwater:
		state = "mergulhando"
	elif p.swimming:
		state = "nadando"
	elif not p.is_on_floor():
		state = "no ar"
	elif speed > 6.0:
		state = "correndo"
	elif speed > 0.3:
		state = "andando"
	_print("Posição %s · %s · %.1f m/s" % [_v(pos), state, speed])
	_print("Chão aqui em %.1f m · %.0f m do centro da ilha · velocidade %.1fx · pulo %.1fx" % [
		world.ground_height(pos), Vector2(pos.x, pos.z).length(), p.speed_mult, p.jump_mult])


func _where(p: Vector3) -> String:
	var ground: float = world.ground_height(p)
	if p.y - ground > 1.2:
		return "píer"
	if ground < -0.3:
		return "fundo do mar (%.1f m)" % ground
	if ground < 1.9:
		return "praia"
	return "colina"


func _status_shells() -> void:
	var left: Array = world.shells()
	_title("CONCHAS — %d coletadas de %d · %d restantes" % [world.shells_found, world.shells_total, left.size()])
	if left.is_empty():
		return
	_print("[color=%s]  nº  posição (x, y, z)            distância  onde[/color]" % C_DIM)
	for i in left.size():
		var p: Vector3 = left[i].global_position
		_print("  %2d  %s  %6.0f m   %s" % [i + 1, _v(p), _dist(p), _where(p)])


func _status_sharks() -> void:
	var list: Array = world.sharks.all()
	_title("TUBARÕES — %d · velocidade %.1fx · todos mansos" % [list.size(), world.sharks.speed_scale])
	if list.is_empty():
		return
	var per := {}
	for s in list:
		per[s.name] = per.get(s.name, 0) + 1
	var parts: Array[String] = []
	for name in per:
		parts.append("%s ×%d" % [name, per[name]])
	_print("  " + " · ".join(parts))
	_print("[color=%s]  nº  espécie              tam.   posição (x, y, z)            prof.   veloc.   distância[/color]" % C_DIM)
	for i in list.size():
		var s: Dictionary = list[i]
		var p: Vector3 = s.pos
		_print("  %2d  %-20s %4.1f m  %s  %4.1f m  %3.1f m/s  %6.0f m" % [
			i + 1, s.name, s.len, _v(p), world.water_level() - p.y, s.speed * world.sharks.speed_scale, _dist(p)])


func _status_wildlife() -> void:
	var life: Node3D = world.wildlife
	_title("GAIVOTAS — %d" % life.gull_count())
	var gulls: Array = life.gulls()
	for i in gulls.size():
		var g: Dictionary = gulls[i]
		var p: Vector3 = g.node.position
		_print("  %2d  %s  círculo de %2.0f m  %6.0f m" % [i + 1, _v(p), g.radius, _dist(p)])
	var centers: Array = life.school_centers
	_title("PEIXES — %d em %d cardumes" % [life.fish_count(), centers.size()])
	for i in centers.size():
		var c: Vector3 = centers[i]
		_print("  %2d  %s  %6.0f m" % [i + 1, _v(c), _dist(c)])


func _status_scenery() -> void:
	_title("CENÁRIO")
	var parts: Array[String] = []
	for key in world.counts:
		parts.append("%s %d" % [key, world.counts[key]])
	_print("  " + " · ".join(parts))


func _cmd_tp(a: Array[String]) -> void:
	if a.is_empty():
		_usage("tp")
		return
	var key := norm(a[0])
	var dest := Vector3.INF
	var label := ""
	if a[0].is_valid_float():
		if a.size() >= 3 and a[1].is_valid_float() and a[2].is_valid_float():
			dest = Vector3(a[0].to_float(), a[1].to_float(), a[2].to_float())
		elif a.size() == 2 and a[1].is_valid_float():
			dest = Vector3(a[0].to_float(), -100.0, a[1].to_float())
			dest.y = maxf(world.ground_height(dest), world.water_level() - 0.7)
		else:
			_usage("tp")
			return
		label = "o ponto pedido"
	elif key.begins_with("concha"):
		var left: Array = world.shells()
		if left.is_empty():
			_err("Não há conchas no mundo.")
			return
		var shell: Node3D = _pick_shell(left, a, 1)
		if shell == null:
			_err("Concha inexistente; há %d (veja /status conchas)." % left.size())
			return
		dest = shell.global_position + Vector3(1.8, 0.0, 0.0)
		label = "a concha"
	elif key.begins_with("tubar"):
		var index := -1
		if a.size() > 1:
			index = world.sharks.species_index(a[1])
			if index < 0:
				_err("Espécie desconhecida: %s" % a[1])
				return
		var best := {}
		for s in world.sharks.all():
			if (index < 0 or s.species == index) and (best.is_empty() or _dist(s.pos) < _dist(best.pos)):
				best = s
		if best.is_empty():
			_err("Nenhum tubarão assim no mar.")
			return
		var side: Vector3 = best.node.global_transform.basis.x
		dest = best.pos + Vector3(side.x, 0.0, side.z).normalized() * (best.len * 0.5 + 2.5)
		label = "o " + best.name.to_lower()
	elif world.places.has(key):
		dest = world.places[key]
		label = key
	else:
		_usage("tp")
		return
	dest.x = clampf(dest.x, -230.0, 230.0)
	dest.z = clampf(dest.z, -230.0, 230.0)
	dest.y = maxf(dest.y, world.ground_height(dest)) + 0.25
	world.player.global_position = dest
	world.player.velocity = Vector3.ZERO
	_ok("Claire levada para %s: %s" % [label, _v(dest)])


## Concha de número a[i] (como no /status) ou a mais próxima da Claire.
func _pick_shell(left: Array, a: Array[String], i: int) -> Node3D:
	if a.size() > i and a[i].is_valid_int():
		var n := a[i].to_int()
		return left[n - 1] if n >= 1 and n <= left.size() else null
	var best: Node3D = left[0]
	for s in left:
		if _dist(s.global_position) < _dist(best.global_position):
			best = s
	return best


func _cmd_spawn(a: Array[String]) -> void:
	if a.is_empty():
		_usage("criar")
		return
	var kind := norm(a[0])
	var here: Vector3 = world.player.global_position
	if kind.begins_with("tubar"):
		if a.size() < 2:
			_err("Diga a espécie: baleia, branco, tigre, martelo, azul, lixa ou galha-preta.")
			return
		var index: int = world.sharks.species_index(a[1])
		if index < 0:
			_err("Espécie desconhecida: %s (baleia, branco, tigre, martelo, azul, lixa, galha-preta)" % a[1])
			return
		var made := 0
		for i in _count_arg(a, 2, 50):
			if world.sharks.spawn(index, here):
				made += 1
		if made == 0:
			_err("Não achei água funda o bastante para essa espécie.")
		else:
			var s: Dictionary = world.sharks.all()[-1]
			_ok("%d × %s no mar (o último a %.0f m da Claire). Total: %d tubarões." % [made, s.name, _dist(s.pos), world.sharks.all().size()])
	elif kind.begins_with("concha"):
		var n := _count_arg(a, 1, 100)
		var fwd: Vector3 = -world.player.get_node("Model").global_transform.basis.z
		for i in n:
			var p := here + fwd * 2.5
			if i > 0:
				var ang := _rng.randf() * TAU
				p = here + Vector3(cos(ang), 0.0, sin(ang)) * _rng.randf_range(3.0, 14.0)
			world.add_shell_at(p.x, p.z)
		_ok("%d concha(s) criada(s). Agora são %d no mundo." % [n, world.shells().size()])
	elif kind.begins_with("gaivota"):
		var n := _count_arg(a, 1, 100)
		for i in n:
			var c := Vector3(here.x, maxf(here.y, 0.0) + _rng.randf_range(9.0, 20.0), here.z)
			var dir := 1.0 if _rng.randf() < 0.5 else -1.0
			world.wildlife.add_gull(c, _rng.randf_range(8.0, 26.0), _rng.randf_range(0.2, 0.4) * dir, _rng.randf() * TAU)
		_ok("%d gaivota(s) criada(s). Total: %d." % [n, world.wildlife.gull_count()])
	elif kind.begins_with("cardume") or kind.begins_with("peixe"):
		var ground: float = world.ground_height(here)
		if ground > -1.8:
			_err("Aqui é raso demais para um cardume; vá para onde o fundo passa de 1,8 m.")
			return
		var colors := [Color(1.0, 0.55, 0.15), Color(0.95, 0.85, 0.2), Color(0.3, 0.7, 1.0), Color(1.0, 0.4, 0.55)]
		var n := _count_arg(a, 1, 30)
		for i in n:
			var off := Vector3(_rng.randf_range(-6.0, 6.0), 0.0, _rng.randf_range(-6.0, 6.0)) if i > 0 else Vector3.ZERO
			var p := here + off
			var g: float = world.ground_height(p)
			if g > -1.8:
				p = here
				g = ground
			world.wildlife.add_school(Vector3(p.x, g + 1.2, p.z), 9, colors[_rng.randi() % colors.size()])
		_ok("%d cardume(s) criado(s). Total: %d peixes." % [n, world.wildlife.fish_count()])
	else:
		_usage("criar")


func _cmd_remove(a: Array[String]) -> void:
	if a.is_empty():
		_usage("remover")
		return
	var kind := norm(a[0])
	if kind.begins_with("tubar"):
		var index := -1
		if a.size() > 1:
			index = world.sharks.species_index(a[1])
			if index < 0:
				_err("Espécie desconhecida: %s" % a[1])
				return
		_ok("%d tubarão(ões) removido(s). Restam %d." % [world.sharks.remove(index), world.sharks.all().size()])
	elif kind.begins_with("concha"):
		_ok("%d concha(s) removida(s)." % world.remove_shells())
	elif kind.begins_with("gaivota"):
		_ok("%d gaivota(s) removida(s)." % world.wildlife.clear_gulls())
	elif kind.begins_with("peixe") or kind.begins_with("cardume"):
		_ok("%d peixe(s) removido(s)." % world.wildlife.clear_fish())
	elif kind == "tudo":
		_ok("Removidos: %d tubarões, %d conchas, %d gaivotas, %d peixes." % [
			world.sharks.remove(-1), world.remove_shells(), world.wildlife.clear_gulls(), world.wildlife.clear_fish()])
	else:
		_usage("remover")


func _cmd_collect(a: Array[String]) -> void:
	var left: Array = world.shells()
	if left.is_empty():
		_err("Não há conchas para coletar.")
		return
	if a.size() > 0 and norm(a[0]).begins_with("tod"):
		for s in left:
			world.collect_shell(s)
		_ok("%d concha(s) coletada(s). Total: %d de %d." % [left.size(), world.shells_found, world.shells_total])
		return
	var shell := _pick_shell(left, a, 0)
	if shell == null:
		_err("Concha inexistente; há %d (veja /status conchas)." % left.size())
		return
	world.collect_shell(shell)
	_ok("Concha coletada. Total: %d de %d." % [world.shells_found, world.shells_total])


func _cmd_speed(a: Array[String]) -> void:
	var target := "claire"
	var value := ""
	if a.size() == 1:
		value = a[0]
	elif a.size() >= 2:
		target = norm(a[0])
		value = a[1]
	if not value.is_valid_float():
		_usage("velocidade")
		return
	var mult := clampf(value.to_float(), 0.0, 30.0)
	if target.begins_with("tubar"):
		world.sharks.speed_scale = mult
		_ok("Velocidade dos tubarões: %.1fx" % mult)
	elif target.begins_with("claire"):
		world.player.speed_mult = mult
		_ok("Velocidade da Claire: %.1fx" % mult)
	else:
		_usage("velocidade")


func _cmd_jump(a: Array[String]) -> void:
	if a.is_empty() or not a[0].is_valid_float():
		_usage("pulo")
		return
	world.player.jump_mult = clampf(a[0].to_float(), 0.0, 20.0)
	_ok("Pulo da Claire: %.1fx" % world.player.jump_mult)


func _cmd_fly(_a: Array[String]) -> void:
	world.player.flying = not world.player.flying
	_ok("Voo ligado: Espaço sobe, Ctrl desce, Shift acelera." if world.player.flying else "Voo desligado.")


func _cmd_sun(a: Array[String]) -> void:
	if a.is_empty() or not a[0].is_valid_float():
		_usage("sol")
		return
	var elevation := clampf(a[0].to_float(), -10.0, 90.0)
	var direction: float = world.sun.rotation_degrees.y
	if a.size() > 1 and a[1].is_valid_float():
		direction = a[1].to_float()
	world.set_sun(elevation, direction)
	_ok("Sol a %.0f° de elevação, direção %.0f°." % [elevation, direction])


func _cmd_tide(a: Array[String]) -> void:
	if a.is_empty() or not a[0].is_valid_float():
		_usage("mare")
		return
	world.tide_base = clampf(a[0].to_float(), -4.0, 6.0)
	_ok("Nível do mar: %.2f m." % world.tide_base)


func _cmd_fog(a: Array[String]) -> void:
	if a.is_empty() or not a[0].is_valid_float():
		_usage("nevoa")
		return
	world.fog_scale = clampf(a[0].to_float(), 0.0, 40.0)
	world.refresh_fog()
	_ok("Névoa: %.2fx" % world.fog_scale)


func _cmd_time(a: Array[String]) -> void:
	if a.is_empty() or not a[0].is_valid_float():
		_usage("tempo")
		return
	Engine.time_scale = clampf(a[0].to_float(), 0.05, 10.0)
	_ok("Escala de tempo: %.2fx" % Engine.time_scale)


func _cmd_restart(_a: Array[String]) -> void:
	Engine.time_scale = 1.0
	Input.mouse_mode = _prev_mouse
	get_tree().reload_current_scene()
