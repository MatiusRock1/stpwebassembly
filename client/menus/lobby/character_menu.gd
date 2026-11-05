extends Control

signal character_selected(character)

func _ready():
	hide()
	for character in PluginSystem.character_loader.get_loaded_characters():
		var button := Button.new()
		button.expand_icon = true
		button.custom_minimum_size = Vector2(64, 64)
		button.icon = PluginSystem.character_loader.load_character_icon(character)
		button.pressed.connect(_on_character_selected.bind(character))
		$VBoxContainer/GridContainer.add_child(button)
	if WebPlatform.is_touch_device():
		_fit_for_touch()

## 64 pixels of the canvas are a few millimetres on a phone, too small to hit with a finger.
func _fit_for_touch():
	var grid := $VBoxContainer/GridContainer
	grid.columns = mini(grid.get_child_count(), 6)
	grid.add_theme_constant_override("h_separation", 28)
	grid.add_theme_constant_override("v_separation", 28)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	grid.size_flags_vertical = Control.SIZE_EXPAND | Control.SIZE_SHRINK_CENTER
	for button in grid.get_children():
		button.custom_minimum_size = Vector2(180, 180)


func select_character(character: String):
	var idx := PluginSystem.character_loader.get_loaded_characters().find(character)
	if idx != -1:
		$VBoxContainer/GridContainer.get_child(idx).grab_focus()
	else:
		# This should only happen if the character is not set
		assert(character == "", "Couldn't find character in character selection: {0}".format([character]))
		$VBoxContainer/GridContainer.get_child(0).grab_focus()
	show()

func _on_character_selected(character: String):
	character_selected.emit(character)
	hide()
