extends PanelContainer

const PLACEMENT_COLORS := [Color("#FFD700"), Color("#C9C0BB"), Color("#CD7F32"), Color(0.3, 0.3, 0.3)]

func update(p: PlayerBoard, placement: int, highlighted: bool) -> void:
	var stylebox: StyleBoxFlat = get_theme_stylebox("panel")
	stylebox.border_color.a = 0.8 if highlighted else 0.0

	%Position.text = str(placement)
	%Position.set("theme_override_colors/font_color", PLACEMENT_COLORS[placement - 1])
	%Name.text = p.info.name

	if p.cookies_gui == p.cookies:
		%Cookies.text = str(p.cookies)
	elif p.destination.size() > 0:
		%Cookies.text = str(p.cookies_gui)
	elif p.cookies_gui > p.cookies:
		var diff := p.cookies_gui - p.cookies
		%Cookies.text = "-" + str(diff) + "  " + str(p.cookies_gui)
	else:
		var diff := p.cookies - p.cookies_gui
		%Cookies.text = "+" + str(diff) + "  " + str(p.cookies_gui)

	var character_loader := PluginSystem.character_loader
	var icon := character_loader.load_character_icon(p.info.character)
	%Icon.texture = icon
	%Cakes.text = str(p.cakes)
	for i in PlayerBoard.MAX_ITEMS:
		var item: Item = null
		if i < p.items.size():
			item = p.items[i]
		var texture_rect: TextureRect = %Items.get_child(i + 1)
		if item != null:
			texture_rect.texture = item.icon
		else:
			texture_rect.texture = null

		i += 1
