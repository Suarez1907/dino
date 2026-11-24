extends Node

const DigWorld := preload("res://scripts/world/dig_world.gd")
const MuseumWorld := preload("res://scripts/museum/museum_world.gd")
const RevealWorld := preload("res://scripts/reveal/reveal_world.gd")
const Ui := preload("res://scripts/ui/ui_kit.gd")
const DinoBuilder := preload("res://scripts/dino/dino_builder.gd")

var world: Node
var ui: CanvasLayer
var overlay: CanvasLayer
var mode := "boot"
var gate_answer := 0
var gate_buffer := ""
var _current_site := ""

func _ready() -> void:
	_apply_theme()
	_setup_input()
	GameState.sticker_unlocked.connect(_on_sticker)
	GameState.site_unlocked.connect(_on_site)
	GameState.break_requested.connect(show_break)
	if OS.get_cmdline_user_args().has("--validate"):
		_validate()
		return
	show_menu()

func _apply_theme() -> void:
	Ui.apply(get_tree().root, bool(GameState.settings.large_text))

func _setup_input() -> void:
	var actions := {
		"dig_brush": KEY_B,
		"dig_heavy": KEY_N,
		"tool_next": KEY_TAB,
		"photo_mode": KEY_P,
		"pause": KEY_ESCAPE,
	}
	for action_name in actions:
		if InputMap.has_action(action_name):
			continue
		InputMap.add_action(action_name)
		var event := InputEventKey.new()
		event.physical_keycode = actions[action_name]
		InputMap.action_add_event(action_name, event)

func _set_world(node: Node) -> void:
	if world:
		world.process_mode = Node.PROCESS_MODE_DISABLED
		world.queue_free()
	world = node
	if world:
		add_child(world)

func _clear_overlay() -> void:
	if overlay:
		overlay.queue_free()
		overlay = null

func _panel() -> Control:
	if ui:
		ui.queue_free()
	ui = CanvasLayer.new()
	ui.layer = 20
	add_child(ui)
	var root := Control.new()
	Ui.fill(root)
	ui.add_child(root)
	return root

func _center_card() -> VBoxContainer:
	var root := _panel()
	var center := CenterContainer.new()
	Ui.fill(center)
	root.add_child(center)
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(560, 0)
	center.add_child(card)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	card.add_child(box)
	return box

func show_menu() -> void:
	mode = "menu"
	GameState.counting = false
	_clear_overlay()
	_current_site = ""
	var vista = DigWorld.new()
	vista.site_id = GameState.first_unlocked_site()
	vista.spectator = true
	_set_world(vista)
	var box := _center_card()
	var title := Ui.label(Locale.t("title"), 64)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var tag := Ui.label(Locale.t("tagline"), 24)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(tag)
	_add(box, Locale.t("play"), "primary", show_sites)
	_add(box, Locale.t("museum"), "teal", func(): _open_museum(GameState.first_unlocked_site()))
	_add(box, Locale.t("passport"), "sun", show_passport)
	_add(box, Locale.t("settings"), "cream", show_settings)
	_add(box, Locale.t("credits"), "cream", show_credits)
	_add(box, Locale.t("parents"), "cream", show_gate)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(row)
	var tr := Ui.button(Locale.t("lang_tr"), "primary" if Locale.lang == "tr" else "cream")
	tr.pressed.connect(func():
		Locale.set_lang("tr")
		show_menu()
	)
	var en := Ui.button(Locale.t("lang_en"), "primary" if Locale.lang == "en" else "cream")
	en.pressed.connect(func():
		Locale.set_lang("en")
		show_menu()
	)
	row.add_child(tr)
	row.add_child(en)
	var note := Ui.label(Locale.t("offline"), 20)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(note)

func show_sites() -> void:
	mode = "sites"
	GameState.counting = false
	var box := _center_card()
	box.add_child(Ui.label(Locale.t("choose_site"), 40))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(520, 420)
	box.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)
	for site in Catalog.sites:
		var id := str(site.id)
		var unlocked := GameState.is_site_unlocked(id)
		var stars := GameState.site_stars(id)
		var name := Locale.pick(site.name)
		var biome := Locale.pick(Catalog.biome(str(site.biome)))
		var text := "%s · %s" % [name, biome]
		if unlocked:
			text += "  " + "★".repeat(stars)
			if bool(GameState.site_state(id).revealed):
				text += "  " + Locale.t("revealed")
		else:
			text += "  " + Locale.t("locked")
		var btn := Ui.button(text, "primary" if unlocked else "cream")
		btn.disabled = not unlocked
		var captured := id
		btn.pressed.connect(func(): show_dig(captured))
		list.add_child(btn)
		if not unlocked:
			list.add_child(Ui.label(Locale.t("site_locked"), 18))
	_add(box, Locale.t("back"), "cream", show_menu)

func show_dig(site_id: String) -> void:
	if not GameState.is_site_unlocked(site_id):
		show_sites()
		return
	mode = "dig"
	_current_site = site_id
	GameState.counting = true
	_clear_overlay()
	if ui:
		ui.queue_free()
		ui = null
	var dig = DigWorld.new()
	dig.site_id = site_id
	dig.request_menu.connect(show_menu)
	dig.request_museum.connect(func(): _open_museum(site_id))
	dig.request_passport.connect(show_passport)
	_set_world(dig)

func _open_museum(site_id: String) -> void:
	mode = "museum"
	_current_site = site_id
	GameState.counting = true
	if ui:
		ui.queue_free()
		ui = null
	var museum = MuseumWorld.new()
	museum.site_id = site_id
	museum.request_back.connect(show_menu)
	museum.request_dig.connect(func(): show_dig(site_id))
	museum.request_reveal.connect(func(): show_reveal(site_id))
	_set_world(museum)

func show_reveal(site_id: String) -> void:
	if not GameState.all_placed(site_id):
		return
	mode = "reveal"
	_current_site = site_id
	GameState.counting = true
	if ui:
		ui.queue_free()
		ui = null
	var reveal = RevealWorld.new()
	reveal.site_id = site_id
	reveal.request_menu.connect(show_menu)
	reveal.request_museum.connect(func(): _open_museum(site_id))
	reveal.request_next.connect(func():
		var idx := Catalog.site_index(site_id)
		if idx >= 0 and idx + 1 < Catalog.sites.size():
			show_dig(str(Catalog.sites[idx + 1].id))
		else:
			show_passport()
	)
	_set_world(reveal)

func show_passport() -> void:
	mode = "passport"
	GameState.counting = false
	var root := _panel()
	var margin := MarginContainer.new()
	Ui.fill(margin)
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 24)
	root.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	margin.add_child(box)
	box.add_child(Ui.label(Locale.t("passport"), 44))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	box.add_child(grid)
	for site in Catalog.sites:
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(280, 150)
		var inner := VBoxContainer.new()
		card.add_child(inner)
		var dino := Catalog.dino(str(site.dino))
		var awake := bool(GameState.site_state(str(site.id)).revealed)
		inner.add_child(Ui.label(Locale.pick(dino.name), 28))
		inner.add_child(Ui.label(Locale.pick(site.name), 18))
		if awake:
			var diet := Locale.t("diet_herb" if str(dino.diet) == "herbivore" else "diet_carn")
			inner.add_child(Ui.label("%s  %s" % [diet, "★".repeat(GameState.site_stars(str(site.id)))], 22))
			var fact: Array = dino.facts
			if fact.size() > 0:
				inner.add_child(Ui.label(Locale.pick(fact[0]), 18))
		else:
			inner.add_child(Ui.label(Locale.t("passport_empty"), 20))
		grid.add_child(card)
	box.add_child(Ui.label(Locale.t("album"), 32))
	var stickers := HBoxContainer.new()
	stickers.add_theme_constant_override("separation", 8)
	box.add_child(stickers)
	for item in Catalog.catalog.stickers:
		var owned := GameState.has_sticker(str(item.id))
		var text := Locale.pick(item) if owned else "·"
		var chip := Ui.button(text, "sun" if owned else "cream")
		chip.custom_minimum_size = Vector2(140, 64)
		chip.disabled = true
		stickers.add_child(chip)
	_add(box, Locale.t("back"), "teal", show_menu)

func show_credits() -> void:
	mode = "credits"
	var box := _center_card()
	box.add_child(Ui.label(Locale.t("credits"), 40))
	var body := Ui.label(Locale.t("credits_body"), 22)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(640, 180)
	box.add_child(body)
	_add(box, Locale.t("back"), "teal", show_menu)

func show_settings() -> void:
	mode = "settings"
	var box := _center_card()
	box.add_child(Ui.label(Locale.t("settings"), 40))
	box.add_child(_slider(Locale.t("music"), "music"))
	box.add_child(_slider(Locale.t("sfx"), "sfx"))
	box.add_child(_slider(Locale.t("voice"), "voice"))
	box.add_child(_toggle(Locale.t("large_text"), "large_text"))
	box.add_child(_toggle(Locale.t("colorblind"), "colorblind"))
	box.add_child(_toggle(Locale.t("guide_arrow"), "guide_arrow"))
	box.add_child(_toggle(Locale.t("effects"), "effects"))
	box.add_child(_quality_button())
	box.add_child(_toggle(Locale.t("haptics"), "haptics"))
	box.add_child(Ui.label(Locale.t("save_note"), 18))
	_add(box, Locale.t("back"), "teal", show_menu)

func _slider(title: String, key: String) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_child(Ui.label("%s  %d%%" % [title, int(float(GameState.settings[key]) * 100.0)], 22))
	var slider := HSlider.new()
	slider.min_value = 0
	slider.max_value = 100
	slider.step = 5
	slider.value = float(GameState.settings[key]) * 100.0
	slider.custom_minimum_size = Vector2(420, 40)
	slider.value_changed.connect(func(v):
		GameState.set_setting(key, float(v) / 100.0)
		box.get_child(0).text = "%s  %d%%" % [title, int(v)]
	)
	box.add_child(slider)
	return box

func _quality_button() -> Button:
	var q := str(GameState.settings.get("quality", "medium"))
	var btn := Ui.button("%s: %s" % [Locale.t("quality"), Locale.t("quality_" + q)], "cream")
	btn.pressed.connect(func():
		var order := ["low", "medium", "high"]
		var index := order.find(q)
		if index < 0:
			index = 1
		GameState.set_setting("quality", order[(index + 1) % order.size()])
		show_settings()
	)
	return btn

func _toggle(title: String, key: String) -> Button:
	var on := bool(GameState.settings[key])
	var btn := Ui.button("%s: %s" % [title, Locale.t("on") if on else Locale.t("off")], "good" if on else "cream")
	btn.pressed.connect(func():
		var next := not bool(GameState.settings[key])
		GameState.set_setting(key, next)
		if key == "large_text":
			_apply_theme()
		show_settings()
	)
	return btn

func show_gate() -> void:
	var a := randi_range(2, 8)
	var b := randi_range(2, 8)
	gate_answer = a + b
	gate_buffer = ""
	var box := _center_card()
	box.add_child(Ui.label(Locale.t("parent_gate"), 36))
	box.add_child(Ui.label(Locale.t("gate_prompt", {"a": a, "b": b}), 32))
	var entry := Ui.label("", 40)
	entry.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(entry)
	var keys := GridContainer.new()
	keys.columns = 5
	box.add_child(keys)
	for n in range(0, 10):
		var digit := str(n)
		var btn := Ui.button(digit, "cream")
		btn.custom_minimum_size = Vector2(72, 72)
		btn.pressed.connect(_gate_digit.bind(digit, entry))
		keys.add_child(btn)
	_add(box, Locale.t("back"), "cream", show_menu)

func _gate_digit(digit: String, entry: Label) -> void:
	gate_buffer += digit
	entry.text = gate_buffer
	if gate_buffer.length() >= 2 or int(gate_buffer) > 9:
		if int(gate_buffer) == gate_answer:
			Sfx.play("collect")
			show_parental()
		else:
			entry.text = Locale.t("math_wrong")
			gate_buffer = ""
			Sfx.play("wrong")

func show_parental() -> void:
	var box := _center_card()
	box.add_child(Ui.label(Locale.t("parents"), 40))
	box.add_child(Ui.label(Locale.t("parent_note"), 20))
	box.add_child(Ui.label(Locale.t("session"), 26))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	box.add_child(row)
	for mins in [0, 15, 30, 45]:
		var minutes := int(mins)
		var label := Locale.t("unlimited") if minutes == 0 else "%d %s" % [minutes, Locale.t("minutes")]
		var active: bool = int(GameState.settings.session_minutes) == minutes
		var btn := Ui.button(label, "primary" if active else "cream")
		var captured: int = minutes
		btn.pressed.connect(func():
			GameState.set_setting("session_minutes", captured)
			show_parental()
		)
		row.add_child(btn)
	var pin_row := HBoxContainer.new()
	box.add_child(pin_row)
	var pin_edit := LineEdit.new()
	pin_edit.placeholder_text = Locale.t("pin_set")
	pin_edit.secret = true
	pin_edit.max_length = 4
	pin_edit.custom_minimum_size = Vector2(220, 64)
	pin_row.add_child(pin_edit)
	var save_pin := Ui.button(Locale.t("pin_set"), "teal")
	save_pin.pressed.connect(func():
		var text := pin_edit.text.strip_edges()
		if text.length() == 4 and text.is_valid_int():
			GameState.set_setting("pin", text)
			_toast(Locale.t("pin_saved"))
		elif text == "":
			GameState.set_setting("pin", "")
			_toast(Locale.t("pin_clear"))
	)
	pin_row.add_child(save_pin)
	_add(box, Locale.t("reset_progress"), "primary", func(): _confirm_reset(box))
	_add(box, Locale.t("back"), "cream", show_menu)

func _confirm_reset(box: VBoxContainer) -> void:
	box.add_child(Ui.label(Locale.t("reset_confirm"), 22))
	var row := HBoxContainer.new()
	box.add_child(row)
	var yes := Ui.button(Locale.t("yes"), "primary")
	yes.pressed.connect(func():
		GameState.reset_progress()
		show_menu()
	)
	var no := Ui.button(Locale.t("no"), "cream")
	no.pressed.connect(show_parental)
	row.add_child(yes)
	row.add_child(no)

func show_break() -> void:
	GameState.counting = false
	if world:
		world.process_mode = Node.PROCESS_MODE_DISABLED
	_clear_overlay()
	overlay = CanvasLayer.new()
	overlay.layer = 40
	add_child(overlay)
	var root := Control.new()
	Ui.fill(root)
	overlay.add_child(root)
	var dim := ColorRect.new()
	Ui.fill(dim)
	dim.color = Color(0.96, 0.9, 0.78, 0.94)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(dim)
	var center := CenterContainer.new()
	Ui.fill(center)
	root.add_child(center)
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(560, 0)
	center.add_child(card)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	card.add_child(box)
	box.add_child(Ui.label(Locale.t("break_title"), 48))
	box.add_child(Ui.label(Locale.t("break_body"), 26))
	var more := Ui.button(Locale.t("continue_parent"), "primary")
	more.pressed.connect(func():
		GameState.extend_session()
		_clear_overlay()
		if world:
			world.process_mode = Node.PROCESS_MODE_INHERIT
		GameState.counting = mode in ["dig", "museum", "reveal"]
	)
	box.add_child(more)
	var done := Ui.button(Locale.t("end_session"), "cream")
	done.pressed.connect(func():
		_clear_overlay()
		show_menu()
	)
	box.add_child(done)

func _add(box: Node, text: String, kind: String, action: Callable) -> void:
	var btn := Ui.button(text, kind)
	btn.pressed.connect(action)
	box.add_child(btn)

func _on_sticker(id: String) -> void:
	_toast(Locale.t("new_sticker") + " " + Locale.pick(Catalog.sticker(id)))
	Sfx.play("star")

func _on_site(_id: String) -> void:
	_toast(Locale.t("unlocked_site"))

func _toast(text: String) -> void:
	if ui == null:
		return
	var label := Ui.label(text, 28)
	label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	label.offset_top = 12
	label.offset_left = -300
	label.offset_right = 300
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ui.add_child(label)
	var timer := get_tree().create_timer(2.4)
	timer.timeout.connect(label.queue_free)

func _validate() -> void:
	var errors: Array[String] = []
	if Catalog.dinos.size() < 5:
		errors.append("need 5 dinosaurs")
	if Catalog.sites.size() < 5:
		errors.append("need 5 sites")
	for site in Catalog.sites:
		var dino: Dictionary = Catalog.dino(str(site.dino))
		if dino.is_empty():
			errors.append("missing dino " + str(site.dino))
			continue
		var bones := {}
		for bone in dino.bones:
			bones[str(bone.id)] = true
		if bones.size() < 6:
			errors.append("bones " + str(dino.id))
		for spot in site.spots:
			if not bones.has(str(spot.bone)):
				errors.append("spot bone " + str(spot.bone))
			for layer in spot.layers:
				if Catalog.tool(str(layer.tool)).is_empty():
					errors.append("tool " + str(layer.tool))
				if Catalog.soil(str(layer.soil)).is_empty():
					errors.append("soil " + str(layer.soil))
		var dig = DigWorld.new()
		dig.site_id = str(site.id)
		dig.spectator = true
		add_child(dig)
		if dig.spots.size() != site.spots.size():
			errors.append("dig spots " + str(site.id))
		dig.free()
		var living = DinoBuilder.build(dino, "living")
		var fossil = DinoBuilder.build(dino, "ghost")
		add_child(living)
		add_child(fossil)
		if living.get("parts") == null or fossil.get("parts") == null:
			errors.append("builder " + str(dino.id))
		living.free()
		fossil.free()
	var museum = MuseumWorld.new()
	museum.site_id = str(Catalog.sites[0].id)
	add_child(museum)
	if museum.dino == null:
		errors.append("museum")
	museum.free()
	if errors.is_empty():
		print("VALIDATE_OK")
		get_tree().quit(0)
	else:
		push_error("VALIDATE " + ", ".join(errors))
		print("VALIDATE_FAIL")
		get_tree().quit(1)
