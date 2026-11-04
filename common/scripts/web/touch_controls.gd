## On-screen gamepad of the browser build on phones and tablets. [br]
## The game only reads keyboards and gamepads, which a phone does not have. Each
## button sends the events mapped to the first local player's actions, so the game
## cannot tell it from a key: the lobby converts it to the right player like any
## other input and remapped controls keep working. [br]
## Action buttons show the same letter as the game's control hints. The bottom one
## also confirms dialogs, as the A button of a gamepad does in the default mapping. [br]
## Menus do not need it: Godot turns touches into mouse clicks there.
extends CanvasLayer

const BUTTON_SIZE := 104.0
const MARGIN := 20.0
const GAP := 6.0
const IDLE_OPACITY := 0.55

class PadButton:
	extends Control

	const ARROWS := {"up": Vector2.UP, "down": Vector2.DOWN, "left": Vector2.LEFT, "right": Vector2.RIGHT}

	var actions: Array
	var label: String
	var sublabel: String
	var is_down := false
	var touches := {}

	func _init(button_actions: Array, text: String, subtext := ""):
		actions = button_actions
		label = text
		sublabel = subtext
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_touch(index: int, touching: bool):
		if touching:
			touches[index] = true
		else:
			touches.erase(index)
		var down := not touches.is_empty()
		if down == is_down:
			return
		is_down = down
		for action in actions:
			var event := _source_event(action)
			if event:
				event.pressed = down
				Input.parse_input_event(event)
		queue_redraw()

	func release():
		touches.clear()
		if is_down:
			touches[-1] = true
			set_touch(-1, false)

	# A copy of the event mapped to the action, so remapped controls still work
	func _source_event(action: String) -> InputEvent:
		if not InputMap.has_action(action):
			return null
		var events := InputMap.action_get_events(action)
		if events.is_empty() or events[0] is InputEventJoypadMotion:
			return null
		return events[0].duplicate()

	func _draw():
		var center := size / 2
		var radius := minf(size.x, size.y) / 2
		draw_circle(center, radius, Color(1, 1, 1, 0.5) if is_down else Color(0.08, 0.08, 0.14, 0.5))
		draw_arc(center, radius - 1, 0, TAU, 48, Color(1, 1, 1, 0.85), 2.5, true)
		if label in ARROWS:
			var direction: Vector2 = ARROWS[label]
			var side := direction.orthogonal() * radius * 0.42
			var tip := center + direction * radius * 0.42
			var base := center - direction * radius * 0.26
			draw_colored_polygon(PackedVector2Array([tip, base + side, base - side]), Color.WHITE)
			return
		var font := ThemeDB.fallback_font
		var font_size := int(radius * 0.72)
		var baseline := center.y + font_size * (0.1 if sublabel else 0.35)
		var text_width := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		draw_string(font, Vector2(center.x - text_width / 2, baseline), label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		if sublabel:
			var small := int(radius * 0.36)
			var small_width := font.get_string_size(sublabel, HORIZONTAL_ALIGNMENT_LEFT, -1, small).x
			draw_string(font, Vector2(center.x - small_width / 2, baseline + small * 1.2), sublabel, HORIZONTAL_ALIGNMENT_LEFT, -1, small)

var _root: Control
var _buttons: Array[PadButton] = []

func _ready():
	# Over everything, and it keeps working while the game is paused
	layer = 128
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not WebPlatform.is_touch_device():
		queue_free()
		return
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.modulate.a = IDLE_OPACITY
	add_child(_root)

	_add_group([
		[["player1_up"], "up", "", Vector2(1, 0)],
		[["player1_left"], "left", "", Vector2(0, 1)],
		[["player1_right"], "right", "", Vector2(2, 1)],
		[["player1_down"], "down", "", Vector2(1, 2)],
	], false)
	# The same places as a gamepad's face buttons in the default mapping
	_add_group([
		[["player1_action4"], _key_name("player1_action4"), "", Vector2(1, 0)],
		[["player1_action3"], _key_name("player1_action3"), "", Vector2(0, 1)],
		[["player1_action2"], _key_name("player1_action2"), "", Vector2(2, 1)],
		[["player1_action1", "player1_ok"], _key_name("player1_action1"), "OK", Vector2(1, 2)],
	], true)
	var pause := _add_button(["player1_pause"], "II", "", Vector2(BUTTON_SIZE, BUTTON_SIZE) * 0.6)
	pause.set_anchors_preset(Control.PRESET_CENTER_TOP)
	pause.position = Vector2(-pause.size.x / 2, MARGIN / 2)

	get_tree().node_added.connect(func(_node): _update_visibility())
	get_tree().node_removed.connect(func(_node): _update_visibility.call_deferred())
	_update_visibility()

func _key_name(action: String) -> String:
	var events := InputMap.action_get_events(action)
	if not events.is_empty() and events[0] is InputEventKey:
		return OS.get_keycode_string(events[0].keycode)
	return action.right(1)

## The pad only makes sense while playing: in the menus it would cover buttons.
## The lobby sets `started` when the game starts, and clears it when it ends.
func _update_visibility():
	if not is_inside_tree() or not _root:
		return
	var game := get_node_or_null("/root/Client/Game")
	var playing: bool = game != null and game.current_lobby != null and game.current_lobby.started
	if _root.visible == playing:
		return
	_root.visible = playing
	if not playing:
		for button in _buttons:
			button.release()

func _add_group(layout: Array, on_right: bool):
	var cell := BUTTON_SIZE + GAP
	for entry in layout:
		var button := _add_button(entry[0], entry[1], entry[2], Vector2(BUTTON_SIZE, BUTTON_SIZE))
		var place: Vector2 = entry[3] * cell
		var y := -MARGIN - cell * 3 + place.y
		if on_right:
			button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
			button.position = Vector2(-MARGIN - cell * 3 + place.x, y)
		else:
			button.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
			button.position = Vector2(MARGIN + place.x, y)

func _add_button(actions: Array, text: String, subtext: String, button_size: Vector2) -> PadButton:
	var button := PadButton.new(actions, text, subtext)
	_root.add_child(button)
	button.size = button_size
	_buttons.append(button)
	return button

func _input(event: InputEvent):
	if not _root or not _root.visible:
		return
	if event is InputEventScreenTouch:
		_release(event.index)
		if event.pressed:
			_press_at(event.index, event.position)
	elif event is InputEventScreenDrag:
		# Sliding a thumb from one direction to the next
		_release(event.index)
		_press_at(event.index, event.position)

func _press_at(index: int, screen_position: Vector2):
	# Touches come in window pixels, while the controls live in the stretched canvas
	var canvas_position: Vector2 = _root.get_viewport().get_screen_transform().affine_inverse() * screen_position
	for button in _buttons:
		if button.get_global_rect().has_point(canvas_position):
			button.set_touch(index, true)
			return

func _release(index: int):
	for button in _buttons:
		if button.touches.has(index):
			button.set_touch(index, false)
