extends Control

signal item_selected(idx)

var _hint: Label
var _spin: Tween
var _spinning: Control

func _ready():
	_hint = ControlHelper.create_hint_label()
	_hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_hint.offset_top = -36
	_hint.offset_bottom = -4
	add_child(_hint)

func select_item(player) -> void:
	# The background is an ItemList, which would take the focus from the items too
	focus_mode = Control.FOCUS_NONE
	var i := 0
	while i < len(player.items):
		var node := get_node("Item%d" % (i + 1))
		var item: Item = player.items[i]
		node.texture_normal = item.icon
		node.focus_mode = Control.FOCUS_ALL

		if node.focus_entered.is_connected(_on_focus_entered):
			node.focus_entered.disconnect(_on_focus_entered)
		if node.focus_exited.is_connected(_on_focus_exited):
			node.focus_exited.disconnect(_on_focus_exited)
		if node.mouse_entered.is_connected(_on_mouse_entered):
			node.mouse_entered.disconnect(_on_mouse_entered)
		if node.mouse_exited.is_connected(_on_mouse_exited):
			node.mouse_exited.disconnect(_on_mouse_exited)
		if node.pressed.is_connected(_on_item_select):
			node.pressed.disconnect(_on_item_select)

		node.focus_entered.connect(_on_focus_entered.bind(node))
		node.focus_exited.connect(_on_focus_exited.bind(node))
		node.mouse_entered.connect(_on_mouse_entered.bind(node))
		node.mouse_exited.connect(_on_mouse_exited.bind(node))
		node.pressed.connect(_on_item_select.bind(i))

		node.material.set_shader_parameter("enable_shader", false)

		i += 1

	# Clear all remaining item slots.
	while i < player.MAX_ITEMS:
		var node = get_node("Item%d" % (i + 1))
		node.texture_normal = null
		# An empty slot is invisible and does nothing when pressed: with the focus
		# on it, the game seems to ignore the player
		node.focus_mode = Control.FOCUS_NONE

		if node.focus_entered.is_connected(_on_focus_entered):
			node.focus_entered.disconnect(_on_focus_entered)
		if node.focus_exited.is_connected(_on_focus_exited):
			node.focus_exited.disconnect(_on_focus_exited)
		if node.mouse_entered.is_connected(_on_mouse_entered):
			node.mouse_entered.disconnect(_on_mouse_entered)
		if node.mouse_exited.is_connected(_on_mouse_exited):
			node.mouse_exited.disconnect(_on_mouse_exited)
		if node.pressed.is_connected(_on_item_select):
			node.pressed.disconnect(_on_item_select)

		node.material.set_shader_parameter("enable_shader", false)

		i += 1

	_hint.text = ControlHelper.hint("CONTEXT_HINT_ITEM", player.info.addr.idx)
	show()
	$Item1.grab_focus()

func _on_item_select(idx) -> void:
	# Reset the state.
	_stop_spin()
	hide()

	# Continue execution.
	item_selected.emit(idx)

func _on_focus_entered(button) -> void:
	button.material.set_shader_parameter("enable_shader", true)
	_start_spin(button)

func _on_focus_exited(button) -> void:
	button.material.set_shader_parameter("enable_shader", false)
	_stop_spin()

## The selected item turns, so it is clear which one the game is waiting on.
func _start_spin(button: Control):
	_stop_spin()
	_spinning = button
	button.pivot_offset = button.size / 2
	_spin = create_tween().set_loops()
	_spin.tween_property(button, "rotation", TAU, 1.8).from(0.0)

func _stop_spin():
	if _spin:
		_spin.kill()
		_spin = null
	if _spinning:
		_spinning.rotation = 0.0
		_spinning = null

func _on_mouse_entered(button) -> void:
	button.material.set_shader_parameter("enable_shader", true)

func _on_mouse_exited(button) -> void:
	if not button.has_focus():
		button.material.set_shader_parameter("enable_shader", false)
