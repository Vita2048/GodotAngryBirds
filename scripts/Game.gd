extends Node2D

const BirdScene := preload("res://scripts/Bird.gd")
const BlockScene := preload("res://scripts/BreakableBlock.gd")
const PigScene := preload("res://scripts/Pig.gd")
const ParticleLayer := preload("res://scripts/ParticleLayer.gd")
const ChickenScene := preload("res://scripts/Chicken.gd")

const SpecialProp := preload("res://scripts/SpecialProp.gd")
const GameAudio := preload("res://scripts/GameAudio.gd")
const PaintedArt := preload("res://scripts/PaintedArt.gd")
var audio: GameAudio
var props: Array = []
var counterweight: RigidBody2D
var shake := 0.0
# Painted (hybrid raster + vector) presentation on every campaign level.
# Campaign puzzle data lives in CampaignLevels.gd.
var sling_front: Node2D
var sling_texture: Texture2D
var band_recoil := 0.0
var sound_slider: HSlider
var sound_button: Button
var menu_panel: PanelContainer
var volume_label: Label
var debug_level_select := false
var debug_level_buttons: Array[Button] = []
var touch_mode := false
# --- Per-frame caches: values computed once, reused by _draw_* so a frame
# issues no redundant native calls or allocations. All pixel-identical. ---
var _tick_ms := 0
var _btn_style: StyleBoxFlat
var _score_outline: StyleBoxFlat
var _card_style: StyleBoxFlat
var _btn_metrics_size := -1
var _btn_ascent := 0.0
var _btn_descent := 0.0
var _title_metrics_size := -1
var _title_ascent := 0.0
var _title_descent := 0.0
var _bg_draw_w := 0.0
var _bf_fw := 0.0
var _bf_fh := 0.0

const VIEW := Vector2(1280, 720)
const SLING := Vector2(250, 570)
const MAX_DRAG := 100.0
const GROUND_SCROLL_WIDTH := 520.0
const SKY_DECORATION_BOTTOM := VIEW.y * 0.30
const SKY_COLOR := Color("#76c7ff")
const BLOCK_POINTS := 7
const PIG_POINTS := 50
const CRATE_POINTS := 10
const UNUSED_BIRD_POINTS := 100

var background_texture: Texture2D
var butterfly_texture: Texture2D
var sun_texture: Texture2D
var chicken_flying_texture: Texture2D
var chicken_shot_texture: Texture2D
var butterflies: Array[Dictionary] = []
var chickens: Array = []
const WORLD_WIDTH := 3500.0
var levels: Array[Dictionary] = []
var birds: Array = []
var pigs: Array = []
var blocks: Array = []
var active_bird: BirdScene
var drag_bird: BirdScene
var is_dragging := false
var game_state := "START"
var current_level := 0
var score := 0
var level_start_score := 0
var attempt_score := 0
var level_generation := 0
var result_level_score := 0
var result_destruction_score := 0
var result_bonus := 0
var result_previous_total := 0
var result_elapsed := 0.0
var launch_time := 0.0
var world_root: Node2D
var fx: ParticleLayer
var camera: Camera2D
var ui_layer: CanvasLayer
var ui: Control
var launch_power := 15.08
var focus_target: Node2D
var focus_pos: Vector2
var focus_timer := 0.0
var campaign_levels_completed := 0
var campaign_shots := 0
var campaign_retries := 0
var campaign_play_time := 0.0

func _ready() -> void:
	randomize()
	touch_mode = DisplayServer.is_touchscreen_available()
	debug_level_select = "--debug-levels" in OS.get_cmdline_user_args()
	_load_assets()
	_build_levels()
	_build_scene()
	_build_audio_controls()
	_build_draw_caches()
	_make_butterflies()
	set_process_input(true)

func _font_scale() -> float:
	# All UI text is 25% larger on touchscreen (mobile) devices.
	return 1.25 if touch_mode else 1.0

func _fs(base: int) -> int:
	return int(round(float(base) * _font_scale()))

func _build_audio_controls() -> void:
	audio = GameAudio.new()
	add_child(audio)
	menu_panel = PanelContainer.new()
	menu_panel.visible = false
	menu_panel.custom_minimum_size = Vector2(320, 190)
	var background := StyleBoxFlat.new()
	background.bg_color = Color("#263e46")
	background.set_corner_radius_all(16)
	background.set_content_margin_all(20)
	background.shadow_color = Color(0, 0, 0, 0.3)
	background.shadow_size = 8
	menu_panel.add_theme_stylebox_override("panel", background)
	ui.add_child(menu_panel)
	var panel := VBoxContainer.new()
	panel.add_theme_constant_override("separation", 12)
	menu_panel.add_child(panel)
	var title := Label.new()
	title.text = "MENU"
	title.add_theme_font_size_override("font_size", _fs(24))
	panel.add_child(title)
	sound_button = Button.new()
	sound_button.text = "SOUND ON"
	sound_button.custom_minimum_size = Vector2(140, 44)
	sound_button.add_theme_font_size_override("font_size", _fs(16))
	for state in ["normal","hover","pressed"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("#344b51") if state == "normal" else Color("#50747a")
		style.set_corner_radius_all(9)
		style.set_content_margin_all(8)
		sound_button.add_theme_stylebox_override(state, style)
	panel.add_child(sound_button)
	sound_button.pressed.connect(func():
		audio.muted = not audio.muted
		sound_button.text = "SOUND OFF" if audio.muted else "SOUND ON"
		audio.play("click",0.5)
		for voice in audio.voices:
			if audio.muted: voice.stop()
	)
	volume_label = Label.new()
	volume_label.text = "Sound volume: 65%"
	volume_label.add_theme_font_size_override("font_size", _fs(16))
	panel.add_child(volume_label)
	# Volume row: step buttons flank the slider. Precise slider dragging is
	# hard with a finger, so -/+ give a guaranteed-tappable fallback that
	# steps by 10. Both paths funnel through value_changed below.
	var volume_row := HBoxContainer.new()
	volume_row.add_theme_constant_override("separation", 8)
	volume_row.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(volume_row)
	var vol_down := Button.new()
	vol_down.text = "-"
	vol_down.custom_minimum_size = Vector2(48, 44)
	vol_down.add_theme_font_size_override("font_size", _fs(20))
	vol_down.tooltip_text = "Volume down"
	vol_down.focus_mode = Control.FOCUS_NONE
	volume_row.add_child(vol_down)
	sound_slider = HSlider.new()
	sound_slider.min_value = 0
	sound_slider.max_value = 100
	sound_slider.step = 1
	sound_slider.value = 65
	sound_slider.custom_minimum_size = Vector2(160, 44)
	sound_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sound_slider.tooltip_text = "Sound volume"
	volume_row.add_child(sound_slider)
	var vol_up := Button.new()
	vol_up.text = "+"
	vol_up.custom_minimum_size = Vector2(48, 44)
	vol_up.add_theme_font_size_override("font_size", _fs(20))
	vol_up.tooltip_text = "Volume up"
	vol_up.focus_mode = Control.FOCUS_NONE
	volume_row.add_child(vol_up)
	vol_down.pressed.connect(func():
		sound_slider.value = clampf(sound_slider.value - 10.0, 0.0, 100.0)
		audio.play("click", 0.5)
	)
	vol_up.pressed.connect(func():
		sound_slider.value = clampf(sound_slider.value + 10.0, 0.0, 100.0)
		audio.play("click", 0.5)
	)
	sound_slider.value_changed.connect(func(value: float):
		audio.volume = value / 100.0
		volume_label.text = "Sound volume: %d%%" % int(value)
	)
	if debug_level_select:
		var level_title := Label.new()
		level_title.text = "DEBUG LEVEL SELECT"
		level_title.add_theme_font_size_override("font_size", _fs(18))
		panel.add_child(level_title)
		var grid := GridContainer.new()
		grid.columns = 3
		grid.add_theme_constant_override("h_separation", 8)
		grid.add_theme_constant_override("v_separation", 8)
		panel.add_child(grid)
		for index in levels.size():
			var level_button := Button.new()
			level_button.text = "Level %d" % (index + 1)
			level_button.tooltip_text = levels[index].name
			level_button.custom_minimum_size = Vector2(88, 36)
			level_button.add_theme_font_size_override("font_size", _fs(12))
			level_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			for state in ["normal", "hover", "pressed"]:
				level_button.add_theme_stylebox_override(state, sound_button.get_theme_stylebox(state))
			level_button.pressed.connect(_jump_to_level.bind(index))
			grid.add_child(level_button)
			debug_level_buttons.append(level_button)
	var close_button := Button.new()
	close_button.text = "CLOSE"
	close_button.custom_minimum_size = Vector2(140, 44)
	close_button.add_theme_font_size_override("font_size", _fs(16))
	panel.add_child(close_button)
	close_button.pressed.connect(func(): menu_panel.hide())
	get_viewport().size_changed.connect(_layout_menu)
	_layout_menu()

func _layout_menu() -> void:
	var vs := get_viewport_rect().size
	# Clamp so the panel stays on-screen on narrow/short phone screens.
	menu_panel.position = Vector2(maxf(10.0, vs.x - 350.0), clampf(82.0, 10.0, maxf(10.0, vs.y - 210.0)))

func _toggle_menu() -> void:
	menu_panel.visible = not menu_panel.visible
	audio.play("click", 0.5)
	if is_dragging and is_instance_valid(drag_bird):
		is_dragging = false
		drag_bird.position = SLING

func _wants_painted_graphics(level_idx: int) -> bool:
	# Hybrid raster + vector look on every campaign level.
	return true

func _is_painted_now() -> bool:
	return fx != null and fx.illustrated

func _show_painted_chrome() -> bool:
	# Sky veil and raster sling preview on the title screen (level 0) as well
	# as in-game. After load_level, this matches fx.illustrated.
	return _is_painted_now() or _wants_painted_graphics(current_level)

func _load_assets() -> void:
	background_texture = _load_texture("res://assets/ABBackgroundWide.png")
	butterfly_texture = _load_texture("res://assets/Butterfly.png")
	sun_texture = _load_texture("res://assets/SunSingle.png")
	chicken_flying_texture = _load_texture("res://assets/ChickenFlyingL.png")
	chicken_shot_texture = _load_texture("res://assets/ChickenShotL.png")
	sling_texture = load("res://assets/sling-side.png") as Texture2D
	# Cache derived draw dimensions so the per-frame draws issue no
	# get_size() calls. Textures never change after load.
	if background_texture:
		_bg_draw_w = background_texture.get_size().x * (720.0 / background_texture.get_size().y)
	if butterfly_texture:
		_bf_fw = butterfly_texture.get_size().x / 4.0
		_bf_fh = butterfly_texture.get_size().y / 4.0
	# Pre-build the hue-shifted bird variants so the first yellow/big bird
	# costs nothing at draw time.
	PaintedArt.bird_texture("bird_m")
	PaintedArt.bird_texture("bird_l")

func _build_draw_caches() -> void:
	# Styles used by the per-frame canvas draws: building them once removes
	# several allocations every frame. They are only ever read by
	# draw_style_box, so sharing one instance is safe.
	_btn_style = StyleBoxFlat.new()
	_btn_style.bg_color = Color("#e84a31")
	_btn_style.set_corner_radius_all(18)
	_btn_style.shadow_color = Color(0, 0, 0, 0.3)
	_btn_style.shadow_size = 6
	_btn_style.shadow_offset = Vector2(0, 4)
	_btn_style.border_width_bottom = 4
	_btn_style.border_color = Color("#b82e1c")
	_btn_style.anti_aliasing = true
	_score_outline = StyleBoxFlat.new()
	_score_outline.bg_color = Color(1.0, 0.976, 0.910, 0.0)
	_score_outline.set_corner_radius_all(14)
	_score_outline.set_border_width_all(2)
	_score_outline.border_color = Color(0.42, 0.24, 0.12, 0.60)
	_score_outline.shadow_color = Color(0, 0, 0, 0.0)
	_score_outline.shadow_size = 0
	_card_style = StyleBoxFlat.new()
	_card_style.bg_color = Color("#fff8e8")
	_card_style.set_corner_radius_all(16)
	_card_style.shadow_color = Color(0,0,0,0.18)
	_card_style.shadow_size = 5
	_card_style.shadow_offset = Vector2(0,3)

func _visible_rect() -> Rect2:
	# World-space rect actually shown on screen, grown slightly so camera
	# shake offset can never expose an uncovered edge. Used to cull giant
	# fill rects down to what the GPU would clip anyway: identical pixels.
	var vs := _visible_world_size()
	return Rect2(camera.position - vs * 0.5, vs).grow(16.0)

func _load_texture(path: String) -> Texture2D:
	var texture := load(path) as Texture2D
	if texture:
		return texture
	var fallback := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	fallback.fill(Color(1, 1, 1, 0.25))
	return ImageTexture.create_from_image(fallback)

func _build_scene() -> void:
	world_root = Node2D.new()
	add_child(world_root)
	camera = Camera2D.new()
	camera.position = VIEW * 0.5
	camera.enabled = true
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 5.0
	add_child(camera)
	fx = ParticleLayer.new()
	fx.illustrated = true
	fx.z_index = 10
	world_root.add_child(fx)
	ui_layer = CanvasLayer.new()
	add_child(ui_layer)
	ui = Control.new()
	ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.draw.connect(_draw_ui)
	ui_layer.add_child(ui)
	# Front elastic band renders above the bird when the painted sling is used.
	if sling_front == null:
		sling_front = Node2D.new()
		sling_front.z_index = 2
		add_child(sling_front)
		sling_front.draw.connect(_draw_front_band)

func _make_butterflies() -> void:
	for i in 3:
		_spawn_butterfly(true)

func _spawn_butterfly(random_x := false) -> void:
	var cam_x := camera.position.x - VIEW.x * 0.5
	var x := randf_range(cam_x - 200, cam_x + VIEW.x + 200) if random_x else (cam_x - 200 if randf() > 0.5 else cam_x + VIEW.x + 200)
	butterflies.append({
		"pos": Vector2(x, randf_range(288, 650)),
		"vx": randf_range(30.0, 90.0) * (1.0 if x < cam_x + VIEW.x * 0.5 else -1.0),
		"vy": randf_range(-30.0, 30.0),
		"scale": 0.12,
		"phase": randf() * TAU,
		"frame": randi() % 15,
		"frame_timer": 0.0
	})

func _update_butterflies(delta: float) -> void:
	var cam_x := camera.position.x - VIEW.x * 0.5
	var t := _tick_ms * 0.001
	for i in range(butterflies.size() - 1, -1, -1):
		var bf := butterflies[i]
		bf.pos.x += bf.vx * delta
		bf.pos.y += (bf.vy + sin(t * 3.0 + bf.phase) * 45.0) * delta
		
		bf.frame_timer += delta * 15.0 # ~15 FPS
		if bf.frame_timer >= 0.066: # roughly 15fps
			bf.frame = (bf.frame + 1) % 15
			bf.frame_timer = 0.0
			
		if bf.pos.x < cam_x - 400 or bf.pos.x > cam_x + VIEW.x + 400 or bf.pos.y < 200 or bf.pos.y > 750:
			butterflies.remove_at(i)
			_spawn_butterfly()

func _build_levels() -> void:
	levels = preload("res://scripts/CampaignLevels.gd").build()

func _process(delta: float) -> void:
	_tick_ms = Time.get_ticks_msec()
	if game_state in ["PLAYING", "WAITING_WIN", "WAITING_LOSE"]:
		campaign_play_time += delta
	if game_state in ["WIN", "LOSE"]: result_elapsed += delta
	shake = maxf(0.0, shake - delta * 22.0)
	band_recoil = maxf(0, band_recoil - delta)
	_update_camera(delta)
	camera.offset = Vector2(sin(_tick_ms*0.063),cos(_tick_ms*0.079))*shake
	_update_butterflies(delta)
	_update_chickens(delta)
	if _is_painted_now():
		if is_instance_valid(sling_front): sling_front.queue_redraw()
		# Live gaze for the painted face layer; vector pigs ignore it.
		for pig in pigs:
			if is_instance_valid(pig):
				pig.gaze = (active_bird.position-pig.position).normalized() if is_instance_valid(active_bird) else Vector2(-0.6,0)
	if focus_timer > 0:
		focus_timer -= delta
	_check_bird_stop()
	_cleanup_fallen()
	_check_win_lose()
	
	if game_state == "PLAYING" and not _is_board_active() and not drag_bird and _queued_bird_count() > 0:
		_load_next_bird()
	if fx.particles.size() > 620:
		# Drop the oldest in one chunk instead of one O(n) remove_at(0)
		# per frame. Same newest-600 policy, a fraction of the memmoves.
		fx.particles = fx.particles.slice(-600)
	queue_redraw()
	ui.queue_redraw()

func load_level(idx: int) -> void:
	level_generation += 1
	var generation := level_generation
	# Only completed levels contribute to the campaign total.
	score = level_start_score
	attempt_score = 0
	result_level_score = 0
	result_destruction_score = 0
	result_bonus = 0
	result_elapsed = 0.0
	menu_panel.hide()
	for child in world_root.get_children():
		child.queue_free()
	band_recoil = 0.0
	var painted := _wants_painted_graphics(idx)
	fx = ParticleLayer.new()
	fx.illustrated = painted
	fx.z_index = 10
	world_root.add_child(fx)
	birds.clear()
	pigs.clear()
	blocks.clear()
	chickens.clear()
	props.clear()
	counterweight = null
	shake = 0
	focus_target = null
	focus_timer = 0
	active_bird = null
	drag_bird = null
	is_dragging = false
	current_level = idx
	if idx == 0:
		score = 0
	level_start_score = score
	_add_boundaries()
	var data := levels[idx]
	for terrain in data.get("terrain", []):
		var body := preload("res://scripts/PuzzleTerrain.gd").new()
		body.setup(terrain.points, terrain.kind)
		world_root.add_child(body)
	if data.has("gap"):
		var gap: Vector2 = data.gap
		var shadow := Polygon2D.new()
		shadow.polygon = PackedVector2Array([Vector2(gap.x,680),Vector2(gap.y,680),Vector2(gap.y,850),Vector2(gap.x,850)])
		shadow.color = Color("#293a42")
		shadow.z_index = 0
		world_root.add_child(shadow)
	if data.has("counterweight"):
		counterweight = preload("res://scripts/Counterweight.gd").new()
		counterweight.position = data.counterweight
		world_root.add_child(counterweight)
		for body in world_root.get_children():
			if body is StaticBody2D and body.get("kind") == "frame":
				counterweight.add_collision_exception_with(body)
	for b in data.blocks:
		var block := BlockScene.new()
		block.position = Vector2(b.x, b.y)
		block.set_meta("puzzle_id", b.get("id", ""))
		block.illustrated = painted
		block.setup(b.type, Vector2(b.w, b.h), b.get("angle", 0.0))
		if b.get("id", "") == "counterweight_release":
			# A notched latch behind the stone guard: one accurate hit can release it.
			block.max_health = 30.0
			block.health = block.max_health
		# Let authored stacks settle without interpreting overlap correction as a hit.
		block.collision_damage_enabled = false
		block.damaged.connect(_on_block_damaged)
		if painted: block.debris.connect(fx.surface_hit)
		block.destroyed.connect(_on_block_destroyed)
		world_root.add_child(block)
		blocks.append(block)
		if b.get("id", "") == "stopper":
			# Bolted gate: support pressure cannot gradually destroy it.
			# Incoming birds deliver collision damage from their contact callback.
			block.freeze = true
			block.set_meta("bolt_gate", true)
	for p in data.pigs:
		var pig := PigScene.new()
		pig.position = Vector2(p.x, p.y)
		pig.illustrated = painted
		pig.setup(p.r)
		pig.collision_damage_enabled = false
		pig.damaged.connect(_on_pig_damaged)
		pig.popped.connect(_on_pig_popped)
		world_root.add_child(pig)
		pigs.append(pig)
	for spec in data.get("props", []):
		var prop := SpecialProp.new()
		prop.position = Vector2(spec.x, spec.y)
		prop.illustrated = painted
		prop.setup(spec.type)
		prop.exploded.connect(_on_exploded)
		prop.struck.connect(_on_boulder_hit)
		world_root.add_child(prop)
		props.append(prop)
	for type in data.birds:
		birds.append({"type": type, "state": "queue", "node": null})
	game_state = "PLAYING"
	await get_tree().create_timer(0.35).timeout
	if generation == level_generation: _load_next_bird()

func _reset_campaign_statistics() -> void:
	campaign_levels_completed = 0
	campaign_shots = 0
	campaign_retries = 0
	campaign_play_time = 0.0

func _start_campaign() -> void:
	_reset_campaign_statistics()
	load_level(0)

func _jump_to_level(index: int) -> void:
	if not debug_level_select or index < 0 or index >= levels.size(): return
	audio.play("click", 0.5)
	_return_to_start()
	load_level(index)

func _return_to_start() -> void:
	# Recreate the empty title scene and invalidate pending level callbacks.
	level_generation += 1
	game_state = "START"
	menu_panel.hide()
	for child in world_root.get_children():
		world_root.remove_child(child)
		child.queue_free()
	fx = ParticleLayer.new()
	fx.illustrated = true
	fx.z_index = 10
	world_root.add_child(fx)
	birds.clear()
	pigs.clear()
	blocks.clear()
	chickens.clear()
	props.clear()
	counterweight = null
	active_bird = null
	drag_bird = null
	is_dragging = false
	current_level = 0
	score = 0
	level_start_score = 0
	attempt_score = 0
	result_level_score = 0
	result_destruction_score = 0
	result_bonus = 0
	result_previous_total = 0
	result_elapsed = 0.0
	shake = 0
	band_recoil = 0
	focus_target = null
	focus_pos = Vector2.ZERO
	focus_timer = 0
	camera.position = VIEW * 0.5
	camera.offset = Vector2.ZERO
	camera.reset_smoothing()
	butterflies.clear()
	_make_butterflies()
	_reset_campaign_statistics()
	queue_redraw()
	ui.queue_redraw()

func _add_boundaries() -> void:
	if levels[current_level].has("gap"):
		var gap: Vector2 = levels[current_level].gap
		_add_static_rect(Vector2((gap.x-1500)/2,700),Vector2(gap.x+1500,40))
		_add_static_rect(Vector2((gap.y+4500)/2,700),Vector2(4500-gap.y,40))
	else:
		_add_static_rect(Vector2(1500, 700), Vector2(6000, 40))
	_add_static_rect(Vector2(-500, 360), Vector2(100, 2000))
	_add_static_rect(Vector2(_world_right_wall_x(), 360), Vector2(100, 2000))

func _add_static_rect(pos: Vector2, size: Vector2) -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 3
	body.position = pos
	var shape := RectangleShape2D.new()
	shape.size = size
	var col := CollisionShape2D.new()
	col.shape = shape
	body.add_child(col)
	world_root.add_child(body)

func _load_next_bird() -> void:
	if game_state not in ["PLAYING", "WAITING_WIN", "WAITING_LOSE"]:
		return
	if is_instance_valid(drag_bird) or _is_board_active():
		return
	for b in birds:
		if b.state == "slingshot":
			b.state = "used"
	for b in birds:
		if b.state == "queue":
			var node := BirdScene.new()
			var radius: float = {"bird_s": 16.0, "bird_m": 22.0, "bird_l": 30.0}.get(b.type, 18.0)
			node.illustrated = _wants_painted_graphics(current_level)
			node.position = SLING
			node.setup(b.type, radius)
			node.freeze = true
			node.strong_impact.connect(_on_bird_impact)
			world_root.add_child(node)
			b.node = node
			b.state = "slingshot"
			drag_bird = node
			return

func _screen_to_world(screen_pos: Vector2) -> Vector2:
	# get_global_mouse_position() only follows the mouse. On mobile (touch)
	# it is stale/zero unless mouse emulation is on, so convert explicitly.
	return get_viewport().get_canvas_transform().affine_inverse() * screen_pos

func _is_emulated_mouse(event: InputEvent) -> bool:
	# With emulate_mouse_from_touch=true every touch also arrives as an
	# InputEventMouseButton/Motion with device -1. Custom-drawn buttons must
	# ignore those (the real ScreenTouch branch already handled them), or the
	# menu double-toggles (open then instantly close). Native Controls keep
	# working through the emulated events.
	return event.device == InputEvent.DEVICE_ID_EMULATION

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if _is_emulated_mouse(event):
			return
		var screen_m := (event as InputEventMouseButton).position
		var m := _screen_to_world(screen_m)
		if event.pressed:
			_handle_press(m, screen_m)
		else:
			_handle_release()
	elif event is InputEventMouseMotion and is_dragging and drag_bird:
		if _is_emulated_mouse(event):
			return
		var d := _screen_to_world((event as InputEventMouseMotion).position) - SLING
		if d.length() > MAX_DRAG:
			d = d.normalized() * MAX_DRAG
		drag_bird.position = SLING + d
		drag_bird.linear_velocity = Vector2.ZERO
	elif event is InputEventScreenTouch:
		var screen_m := (event as InputEventScreenTouch).position
		var m := _screen_to_world(screen_m)
		if event.pressed:
			_handle_press(m, screen_m)
		else:
			_handle_release()
	elif event is InputEventScreenDrag and is_dragging and drag_bird:
		var d := _screen_to_world((event as InputEventScreenDrag).position) - SLING
		if d.length() > MAX_DRAG:
			d = d.normalized() * MAX_DRAG
		drag_bird.position = SLING + d
		drag_bird.linear_velocity = Vector2.ZERO

func _handle_press(world_m: Vector2, screen_m: Vector2) -> void:
	if _get_ui_rect("menu").has_point(screen_m):
		_toggle_menu()
		return
	if menu_panel.visible and menu_panel.get_global_rect().has_point(screen_m):
		# Press landed on the menu panel itself (slider, buttons). The GUI
		# owns it: never dismiss the menu or start game actions from here.
		# This also covers the case where a real ScreenTouch reaches
		# _unhandled_input but the matching emulated mouse event is what the
		# Control actually consumes.
		return
	# PLAY / NEXT / RESTART must work even while the menu is open. Taps on
	# the menu PanelContainer itself are consumed by the GUI and never reach
	# here, so reaching this point with menu visible means "tap outside".
	if game_state == "START":
		if _get_ui_rect("play").has_point(screen_m):
			audio.play("click",0.5)
			_start_campaign()
		elif menu_panel.visible:
			menu_panel.hide()
		return
	if game_state in ["WIN", "LOSE"]:
		if _get_ui_rect("result").has_point(screen_m):
			if game_state == "WIN" and current_level < levels.size() - 1:
				load_level(current_level + 1)
			elif game_state == "WIN":
				_return_to_start()
			else:
				campaign_retries += 1
				load_level(current_level)
		elif menu_panel.visible:
			menu_panel.hide()
		return
	if menu_panel.visible:
		menu_panel.hide()
		return
	if game_state.begins_with("WAITING") or game_state == "PLAYING":
		if drag_bird and world_m.distance_to(drag_bird.position) < drag_bird.radius * 2.6:
			is_dragging = true
			audio.play("stretch",0.6)

func _handle_release() -> void:
	if not is_dragging or not drag_bird:
		return
	is_dragging = false
	var d := SLING - drag_bird.position
	var launching := d.length() > 20.0
	if launching:
		campaign_shots += 1
		for block in blocks:
			if is_instance_valid(block): block.collision_damage_enabled = true
		for pig in pigs:
			if is_instance_valid(pig): pig.collision_damage_enabled = true
		active_bird = drag_bird
		drag_bird = null
		for entry in birds:
			if entry.node == active_bird:
				entry.state = "used"
				break
		active_bird.freeze = false
		active_bird.game_state = "flying"
		active_bird.launch_time = Time.get_ticks_msec() / 1000.0
		audio.play("launch", d.length()/MAX_DRAG)
		active_bird.linear_velocity = d * launch_power
		active_bird.angular_velocity = sign(d.x) * 2.5
		if _is_painted_now(): band_recoil = 0.34
	else:
		drag_bird.position = SLING


func _update_camera(_delta: float) -> void:
	var target_x := VIEW.x * 0.5
	var target_y := VIEW.y * 0.5
	
	if is_instance_valid(focus_target):
		target_x = focus_target.position.x
	elif focus_timer > 0:
		target_x = focus_pos.x
	elif active_bird and is_instance_valid(active_bird) and active_bird.game_state == "flying":
		target_x = active_bird.position.x
	
	target_x = clamp(target_x, VIEW.x * 0.5, _max_camera_x())
	camera.position = Vector2(target_x, VIEW.y * 0.5)

func _check_bird_stop() -> void:
	if game_state not in ["PLAYING", "WAITING_WIN", "WAITING_LOSE"]:
		return
	for b in birds:
		var node = b.node
		if node and is_instance_valid(node) and node.game_state == "flying":
			if _is_bird_stopped(node):
				if node == active_bird:
					b.state = "used"
					active_bird = null
					node.queue_free()
					var generation := level_generation
					await get_tree().create_timer(0.55).timeout
					if generation == level_generation: _load_next_bird()
				else:
					b.state = "used"
					node.queue_free()
					b.node = null

func _is_bird_stopped(node: Node) -> bool:
	if not node or not is_instance_valid(node):
		return true
	var now := _tick_ms / 1000.0
	var launch_t = node.get("launch_time") if node.has_method("get") else 0.0
	var vel = node.linear_velocity if "linear_velocity" in node else Vector2.ZERO
	var ang_vel = node.angular_velocity if "angular_velocity" in node else 0.0
	
	if (now - launch_t > 2.3 and vel.length() < 28.0 and abs(ang_vel) < 0.9):
		return true
	if node.position.y > 1000 or node.position.x < -500 or node.position.x > _world_right_wall_x() + 250.0:
		return true
	return false

func _cleanup_fallen() -> void:
	# Backward in-place removal: same removals/frees/awards as iterating a
	# duplicate(), but without allocating two throwaway arrays every frame.
	for i in range(blocks.size() - 1, -1, -1):
		var block = blocks[i]
		if not is_instance_valid(block) or block.position.y > 1050:
			blocks.remove_at(i)
			if is_instance_valid(block):
				block.queue_free()
	for i in range(pigs.size() - 1, -1, -1):
		var pig = pigs[i]
		if not is_instance_valid(pig) or pig.position.y > 1050:
			pigs.remove_at(i)
			_award_points(PIG_POINTS)
			if is_instance_valid(pig):
				pig.queue_free()

func _check_win_lose() -> void:
	if game_state != "PLAYING" and game_state != "WAITING_LOSE":
		return
		
	if pigs.is_empty():
		game_state = "WAITING_WIN"
		var generation := level_generation
		await get_tree().create_timer(1.0).timeout
		if generation == level_generation and game_state == "WAITING_WIN":
			_finish_attempt(true)
			audio.play("win")
			fx.confetti(Rect2(camera.position.x - 500, 30, 1000, 80))
	elif _live_bird_count() == 0:
		if game_state == "PLAYING":
			game_state = "WAITING_LOSE"
			var generation := level_generation
			await get_tree().create_timer(1.8).timeout
			if generation == level_generation and game_state == "WAITING_LOSE":
				if _live_bird_count() == 0:
					_finish_attempt(pigs.is_empty())
				else:
					game_state = "PLAYING"

func _award_points(value: int) -> bool:
	if game_state not in ["PLAYING", "WAITING_WIN", "WAITING_LOSE"]:
		return false
	attempt_score += value
	score = level_start_score + attempt_score
	return true

func _finish_attempt(won: bool) -> void:
	if game_state not in ["PLAYING", "WAITING_WIN", "WAITING_LOSE"]: return
	result_previous_total = level_start_score
	result_destruction_score = attempt_score
	result_bonus = 0
	result_elapsed = 0.0
	if won:
		campaign_levels_completed += 1
		var unused := 0
		for bird in birds:
			if bird.state in ["queue", "slingshot"]: unused += 1
		result_bonus = unused * UNUSED_BIRD_POINTS
		_award_points(result_bonus)
		result_level_score = attempt_score
		level_start_score = score
	else:
		result_level_score = attempt_score
		score = level_start_score
		attempt_score = 0
	game_state = "WIN" if won else "LOSE"

func _score_transfer_progress() -> float:
	return smoothstep(0.0, 1.0, clampf((result_elapsed - 0.65) / 1.15, 0.0, 1.0))

func _displayed_total() -> int:
	if game_state != "WIN": return level_start_score
	return result_previous_total + roundi(result_level_score * _score_transfer_progress())

func _queued_bird_count() -> int:
	var count := 0
	for b in birds:
		if b.state == "queue":
			count += 1
	return count

func _live_bird_count() -> int:
	var count := 0
	for b in birds:
		if b.state in ["queue", "slingshot"]:
			count += 1
		elif b.node and is_instance_valid(b.node):
			count += 1
	if _any_chicken_falling():
		count += 1
	return count

func _is_board_active() -> bool:
	for b in birds:
		if b.node and is_instance_valid(b.node):
			return true
	return _any_chicken_falling()

func _any_chicken_falling() -> bool:
	for c in chickens:
		if is_instance_valid(c) and c.state in ["SHOT", "FALLING"]:
			return true
	return false

func _on_block_damaged(pos: Vector2, type: String, force: float) -> void:
	if _is_painted_now():
		# Painted style relies on debris -> surface_hit for chips; skip the
		# flat vector burst so impacts are not drawn twice.
		audio.play(type,force/55.0)
		return
	var palette: Array = {"glass":[Color("#bdf0ff"), Color.WHITE, Color("#76ceff")], "stone":[Color("#858982"), Color("#c6c4b7"), Color("#555a55")], "wood":[Color("#a6642d"), Color("#db9a4c"), Color("#743e18")]}.get(type)
	fx.burst(pos, palette, clampi(int(force / 2.0), 5, 18), 0.65, type)
	if force > 25:
		fx.burst(pos,[Color(0.72,0.65,0.52,0.22)],5,0.25,"dust")
	audio.play(type, force/55.0)

func _on_block_destroyed(block: Node, type: String, pos: Vector2) -> void:
	if not blocks.has(block): return
	if block.get_meta("puzzle_id", "") == "counterweight_release" and is_instance_valid(counterweight):
		counterweight.release.call_deferred()
	if blocks.has(block):
		blocks.erase(block)
	if _is_painted_now():
		# Tear the beam where it was last hit so the break matches the damage.
		var bias := 0.0
		if block.wounds.size() > 0:
			var last: Vector2 = block.wounds[block.wounds.size()-1]
			if block.size.x >= block.size.y:
				bias = clampf(last.x/block.size.x,-0.3,0.3)
			else:
				bias = clampf(last.y/block.size.y,-0.3,0.3)
		fx.fragments.call_deferred(block.global_position, type, block.size, block.rotation, block.linear_velocity, block.angular_velocity, bias)
	if _award_points(BLOCK_POINTS): fx.score_popup(pos, "+%d" % BLOCK_POINTS)
	fx.impact(pos, 25)
	shake = maxf(shake, 2.0)
	_on_block_damaged(pos, type, 45.0)
	block.queue_free()

func _on_pig_damaged(pos: Vector2, force: float) -> void:
	fx.burst(pos, [Color("#9be45f"), Color("#d8ff9a"), Color("#4f8f35")], clampi(int(force / 3.0), 4, 14), 0.7, "spark")

func _on_pig_popped(pig: Node, pos: Vector2) -> void:
	if not pigs.has(pig): return
	if pigs.has(pig):
		pigs.erase(pig)
	if _award_points(PIG_POINTS): fx.score_popup(pos, "+%d" % PIG_POINTS)
	audio.play("pig")
	fx.impact(pos, 35)
	if _is_painted_now():
		fx.burst(pos,[Color("#e7dac0")],8,0.75,"dust")
	else: fx.burst(pos, [Color("#9be45f"), Color("#ffffff"), Color("#76f06d")], 36, 1.2, "spark")
	pig.queue_free()

func _update_chickens(delta: float) -> void:
	if game_state not in ["PLAYING", "WAITING_WIN", "WAITING_LOSE", "WIN", "LOSE"]:
		return
		
	var cam_x := camera.position.x - VIEW.x * 0.5
	var margin := VIEW.x * 0.1
	var active_count := 0
	
	for i in range(chickens.size() - 1, -1, -1):
		var chicken = chickens[i]
		if not is_instance_valid(chicken):
			chickens.remove_at(i)
			continue
			
		if chicken.state == "FLYING":
			# Count chickens that are visible or moving into the view
			var on_screen = chicken.position.x > cam_x - 50 and chicken.position.x < cam_x + VIEW.x + 50
			var moving_in = (chicken.position.x < cam_x and chicken.velocity.x > 0) or (chicken.position.x > cam_x + VIEW.x and chicken.velocity.x < 0)
			
			if on_screen or moving_in:
				active_count += 1
				
			# Edge check for direction change (10% margin)
			chicken.can_change_direction = (chicken.position.x > cam_x + margin and chicken.position.x < cam_x + VIEW.x - margin)
			
			if chicken.position.x < cam_x - 800 or chicken.position.x > cam_x + VIEW.x + 800:
				chickens.remove_at(i)
				chicken.queue_free()

	while active_count < 3:
		_spawn_chicken()
		active_count += 1

func _spawn_chicken() -> void:
	var cam_x := camera.position.x - VIEW.x * 0.5
	var from_left := randf() > 0.5
	var x := cam_x - 60 if from_left else cam_x + VIEW.x + 60
	var y := randf_range(VIEW.y * 0.25, VIEW.y * 0.75)
	
	var chicken := ChickenScene.new()
	chicken.position = Vector2(x, y)
	chicken.setup(chicken_flying_texture, chicken_shot_texture)
	
	# Ensure initial direction is into the screen
	var speed := randf_range(100.0, 180.0)
	chicken.target_velocity = Vector2(speed if from_left else -speed, randf_range(-40.0, 40.0))
	chicken.velocity = chicken.target_velocity
	
	chicken.chicken_shot.connect(_on_chicken_shot)
	chicken.chicken_grounded.connect(_on_chicken_grounded)
	world_root.add_child(chicken)
	chickens.append(chicken)

func _on_chicken_shot(chicken: Node, bird: Node) -> void:
	audio.play("chicken")
	focus_target = chicken
	focus_timer = 0.0
	# Bird disappears with splash
	var palette: Array = {"bird_s":[Color("#ff3a3a"), Color("#ffac8c"), Color("#ffebd2")], "bird_m":[Color("#ffe845"), Color("#ffb226"), Color("#fff8b2")], "bird_l":[Color("#aa1010"), Color("#ff785a"), Color("#5a0c0c")]}.get(bird.bird_type)
	fx.burst(bird.global_position, palette, 15, 1.0, "spark")
	
	# Clean up bird
	for b in birds:
		if b.node == bird:
			b.state = "used"
			break
	if active_bird == bird:
		active_bird = null
		get_tree().create_timer(0.55).timeout.connect(_load_next_bird)
	
	bird.queue_free()

func _on_chicken_grounded(chicken: Node, bird_type: String, radius: float) -> void:
	audio.play("boom",0.7)
	fx.impact(chicken.global_position,60)
	shake = maxf(shake,4)
	focus_pos = chicken.global_position
	focus_timer = 2.0 # Stay on explosion for 2 seconds
	if focus_target == chicken:
		focus_target = null
	# Dramatic splash
	fx.burst(chicken.global_position, [Color("#ffffff"), Color("#ffecd2"), Color("#ffc880")], 40, 1.8, "spark")
	
	# Respawn birds (7 for initial shot, 3 for chain reaction)
	var bird_count := 3 if chicken.was_hit_by_bonus else 7
	for i in bird_count:
		var node := BirdScene.new()
		node.position = chicken.global_position
		node.illustrated = _is_painted_now()
		node.setup(bird_type, radius)
		node.is_bonus = true # Mark as bonus bird
		node.strong_impact.connect(_on_bird_impact)
		world_root.add_child(node)
		
		var angle := randf_range(-PI, 0) # Mostly upwards
		var speed := randf_range(500, 1000)
		node.linear_velocity = Vector2(cos(angle), sin(angle)) * speed
		node.game_state = "flying"
		node.launch_time = Time.get_ticks_msec() / 1000.0 # Add launch_time to Bird node if needed, or use a local one
		
		birds.append({"type": bird_type, "state": "used", "node": node})
	
	if game_state == "WAITING_LOSE":
		game_state = "PLAYING"

func _on_bird_impact(pos: Vector2, force: float, type: String) -> void:
	fx.impact(pos, force)
	shake = maxf(shake, minf(force/12, 5))
	audio.play("stone", force/80.0)
	# Reduce particle count if there are already many particles
	var count := clampi(int(force / 3.0), 3, 12)
	if fx.particles.size() > 400:
		count = clampi(count / 2, 2, 6)
	
	var palette: Array = {"bird_s":[Color("#ff3a3a"), Color("#ffac8c"), Color("#ffebd2")], "bird_m":[Color("#ffe845"), Color("#ffb226"), Color("#fff8b2")], "bird_l":[Color("#aa1010"), Color("#ff785a"), Color("#5a0c0c")]}.get(type)
	fx.burst(pos, palette, count, 0.7, "spark")

func _on_boulder_hit(pos: Vector2, force: float) -> void:
	audio.play("stone",force/60.0)
	fx.impact(pos,force)
	fx.burst(pos,[Color("#acb5bb"),Color("#657582")],8,0.55,"stone")
	shake = maxf(shake,minf(5,force/10))

func _on_exploded(prop: Node, pos: Vector2) -> void:
	# Defer physics mutations and chain detonations out of collision callbacks.
	_resolve_explosion.call_deferred(prop, pos)

func _resolve_explosion(prop: Node, pos: Vector2) -> void:
	if not is_instance_valid(prop) or not props.has(prop): return
	props.erase(prop)
	prop.queue_free()
	if _award_points(CRATE_POINTS): fx.score_popup(pos,"+%d" % CRATE_POINTS)
	audio.play("boom")
	shake = 7.0
	fx.impact(pos,70)
	if _is_painted_now():
		fx.explosion(pos)
		fx.fragments(pos,"wood",Vector2(44,44),0,Vector2(0,-150))
	else:
		fx.burst(pos,[Color("#ffe99a"),Color("#ffab42"),Color("#e95730")],38,1.65,"spark")
		fx.burst(pos,[Color("#cc9854"),Color("#854a2c")],18,1.4,"wood")
		fx.burst(pos,[Color(0.3,0.26,0.22,0.3)],16,0.6,"dust")
	for body in blocks.duplicate() + pigs.duplicate() + props.duplicate():
		if not is_instance_valid(body) or body.is_queued_for_deletion(): continue
		var offset: Vector2 = body.global_position - pos
		var distance := offset.length()
		if distance > 210.0: continue
		var power := 1.0-distance/210.0
		body.apply_central_impulse((offset.normalized()+Vector2(0,-0.45))*power*950.0)
		if body is BlockScene: body.take_blast(110.0*power,pos)
		elif body.has_method("take_blast"): body.take_blast(110.0*power)
		elif body is SpecialProp and body.kind == "crate": body.detonate()

func _draw() -> void:
	_draw_sky()
	_draw_sun()
	_draw_butterflies()
	_draw_sling()

func _draw_sky() -> void:
	var cam_x := camera.position.x - VIEW.x * 0.5
	var vis := _visible_rect()
	# Fill only what is on screen: the old 7500x3000 rect drew (and blended,
	# for the veil) far beyond the viewport with identical clipped output.
	draw_rect(vis, SKY_COLOR, true)
	if not background_texture:
		return
	var draw_w := _bg_draw_w
	
	var start_x : float = floor(cam_x / draw_w) * draw_w - draw_w
	var end_x : float = cam_x + VIEW.x + draw_w
	
	var x : float = start_x
	while x < end_x:
		draw_texture_rect(background_texture, Rect2(x, 0, draw_w, 720), false)
		x += draw_w
	if _show_painted_chrome():
		# Light atmospheric veil separates the detailed painted sprites from
		# the background photo.
		# Covers the whole visible area like the sky base: otherwise wide
		# windows show an un-veiled darker strip with a hard seam where the
		# veil starts (vertical at x=0) or ends (horizontal at y=680).
		draw_rect(vis,Color(0.95,0.98,1,0.09))
		# Soft contact shadows ground the painted structures. Positions follow
		# the live level layout. Integer-bucketed dict dedup replaces the old
		# O(n^2) scan with identical merging; off-screen shadows are skipped
		# (the GPU clipped them anyway).
		var seen := {}
		var left := vis.position.x - 160.0
		var right := vis.end.x + 160.0
		for pig in pigs:
			if is_instance_valid(pig):
				_draw_shadow(pig.position.x, left, right, seen)
		for block in blocks:
			if is_instance_valid(block):
				_draw_shadow(block.position.x, left, right, seen)
		for prop in props:
			if is_instance_valid(prop):
				_draw_shadow(prop.position.x, left, right, seen)
	# end painted sky extras

func _draw_shadow(x: float, left: float, right: float, seen: Dictionary) -> void:
	var key := int(round(x / 40.0))
	if seen.has(key):
		return
	seen[key] = true
	var sx := float(key) * 40.0
	if sx < left or sx > right:
		return
	draw_set_transform(Vector2(sx,679),0,Vector2(1,0.12))
	draw_circle(Vector2.ZERO,100,Color(0.15,0.21,0.13,0.22))
	draw_set_transform(Vector2.ZERO)

func _draw_sun() -> void:
	if not sun_texture:
		return
	var cam_x := camera.position.x - VIEW.x * 0.5
	var cam_y := camera.position.y - VIEW.y * 0.5
	var sun_pos := Vector2(cam_x + 1150, cam_y + 110)
	var t := _tick_ms * 0.001
	var pulse : float = sin(t * 1.5) # Reduced speed to match 0.025 * 60 approx
	var scale_val : float = remap(pulse, -1.0, 1.0, 0.9, 1.1)
	
	# Glow
	var glow_size : float = remap(pulse, -1.0, 1.0, 110.0, 210.0)
	# Godot doesn't have easy radial gradients in draw calls, 
	# but we can draw a few circles with fading alpha to simulate it
	for i in 8:
		var r := glow_size * (1.0 - float(i) / 8.0) * 2.2
		var a := 0.15 * (float(i) / 8.0)
		draw_circle(sun_pos, r, Color(1.0, 0.8, 0.0, a))

	var sun_rot := t * 0.5 # Slow rotation
	draw_set_transform(sun_pos, sun_rot, Vector2.ONE * scale_val)
	draw_texture_rect(sun_texture, Rect2(-64, -64, 128, 128), false)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_butterflies() -> void:
	if not butterfly_texture:
		return
	var fw := _bf_fw
	var fh := _bf_fh
	
	for bf in butterflies:
		var row : float = floor(bf.frame / 4.0)
		var col : int = int(bf.frame) % 4
		var src_rect : Rect2 = Rect2(col * fw, row * fh, fw, fh)
		var draw_size : Vector2 = Vector2(fw, fh) * bf.scale
		
		var flip : float = 1.0 if bf.vx > 0 else -1.0
		draw_set_transform(bf.pos, 0.0, Vector2(flip, 1.0))
		draw_texture_rect_region(butterfly_texture, Rect2(-draw_size * 0.5, draw_size), src_rect)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _world_right_wall_x() -> float:
	return WORLD_WIDTH

func _max_camera_x() -> float:
	var visible_width := _visible_world_width()
	return max(VIEW.x * 0.5, WORLD_WIDTH - visible_width * 0.5)

func _visible_world_width() -> float:
	return _visible_world_size().x

func _visible_world_size() -> Vector2:
	var viewport_size := get_viewport_rect().size
	if viewport_size.y <= 0:
		return VIEW
	var viewport_aspect := viewport_size.x / viewport_size.y
	var view_aspect := VIEW.x / VIEW.y
	if viewport_aspect > view_aspect:
		return Vector2(VIEW.y * viewport_aspect, VIEW.y)
	return Vector2(VIEW.x, VIEW.x / viewport_aspect)

func _pouch_position() -> Vector2:
	if is_instance_valid(drag_bird): return drag_bird.position+Vector2(-24,16)
	return SLING+Vector2(sin(band_recoil*65)*band_recoil*24,3)

func _draw_band(canvas: Node2D, tip: Vector2, pull: Vector2, front: bool) -> void:
	var length := tip.distance_to(pull)
	var width := lerpf(5.0,3.0,clampf(length/110.0,0,1))
	var points := PackedVector2Array()
	for i in 9:
		var t := float(i)/8
		points.append(tip.lerp(pull,t)+Vector2(0,sin(t*PI)*maxf(0,5-length*0.08)))
	canvas.draw_polyline(points,Color("#41271c"),width+2,true)
	canvas.draw_polyline(points,Color("#bd8050") if front else Color("#865332"),width,true)
	canvas.draw_polyline(points,Color(1,0.79,0.5,0.28),1,true)

func _draw_front_band() -> void:
	if sling_front == null: return
	# Front band only exists for the painted side-view sling; the vector sling
	# draws both bands in _draw_sling itself.
	if not _show_painted_chrome(): return
	var pull := _pouch_position()
	_draw_band(sling_front,SLING+Vector2(11,2),pull,true)
	if is_instance_valid(drag_bird):
		sling_front.draw_arc(pull+Vector2(5,0),12,1.65,4.6,18,Color("#583525"),7,true)
		sling_front.draw_arc(pull+Vector2(5,0),12,1.65,4.6,18,Color("#b98755"),1.2,true)

func _draw_painted_sling() -> void:
	if sling_texture == null: return
	draw_texture_rect_region(sling_texture,Rect2(230,548,42,132),Rect2(383,78,280,1311))
	_draw_band(self,SLING+Vector2(-10,-7),_pouch_position(),false)

func _draw_sling() -> void:
	if _show_painted_chrome():
		_draw_painted_sling()
		return
	var rear_tip := SLING + Vector2(-20, -10)
	var rear_base := SLING + Vector2(0, 60)
	var trunk_top := SLING + Vector2(0, 50)
	var trunk_base := Vector2(SLING.x, 680)
	var front_tip := SLING + Vector2(12, -5)
	var fork_join := SLING + Vector2(0, 55)
	var pull := drag_bird.position if drag_bird else SLING
	draw_line(rear_tip + Vector2(5, 5), rear_base + Vector2(5, 5), Color(0, 0, 0, 0.20), 16.0)
	draw_line(trunk_top + Vector2(5, 5), trunk_base + Vector2(5, 5), Color(0, 0, 0, 0.20), 18.0)
	draw_line(front_tip + Vector2(5, 5), fork_join + Vector2(5, 5), Color(0, 0, 0, 0.20), 18.0)
	draw_line(rear_tip, rear_base, Color("#46230f"), 14.0)
	if is_dragging and drag_bird:
		draw_line(rear_tip + Vector2(-5, 0), pull, Color("#2b0a0a"), 6.0)
	draw_line(trunk_top, trunk_base, Color("#5a2d16"), 16.0)
	draw_line(front_tip, fork_join, Color("#5a2d16"), 16.0)
	draw_line(trunk_top + Vector2(-4, 0), trunk_base + Vector2(-4, -2), Color("#8a4b25"), 5.0)
	draw_line(front_tip + Vector2(-4, 0), fork_join + Vector2(-4, 0), Color("#8a4b25"), 5.0)
	for y in [40.0, 45.0, 50.0]:
		draw_line(SLING + Vector2(-5, y), SLING + Vector2(5, y), Color("#c8b48c"), 3.0)
	if is_dragging and drag_bird:
		var angle := (SLING - pull).angle()
		draw_set_transform(pull, angle, Vector2.ONE)
		draw_rect(Rect2(Vector2(-drag_bird.radius - 5.0, -14.0), Vector2(10.0, 28.0)), Color("#7a3e1f"), true)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		draw_line(pull, front_tip + Vector2(5, 0), Color("#2b0a0a"), 6.0)

	# Rounded bindings, end caps and grain keep the sling legible at game scale.
	for tip in [rear_tip,front_tip]:
		draw_circle(tip,7,Color("#9a6235"))
		draw_arc(tip,4,0,TAU,14,Color("#58351f"),1.5,true)
	for offset in [-3.0,3.0]:
		draw_line(trunk_top+Vector2(offset,10),trunk_base+Vector2(offset+1,-8),Color(0.9,0.66,0.34,0.25),1,true)
	for y in [37.0,41.0,45.0,49.0,53.0]:
		draw_line(SLING+Vector2(-7,y),SLING+Vector2(7,y+1),Color("#e6c795"),2.5,true)

func _draw_ui() -> void:
	var font := ThemeDB.fallback_font
	_draw_button(_get_ui_rect("menu"), "MENU")
	if game_state == "START":
		_draw_center_title(font)
	elif game_state in ["PLAYING", "WAITING_WIN", "WAITING_LOSE"]:
		_draw_text_fx(font, Vector2(30, 45), "LEVEL %d" % (current_level + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, _fs(28), Color(1, 0.196, 0.196), 4.0, 4.0)
		ui.draw_string_outline(font, Vector2(30,133), levels[current_level].name, HORIZONTAL_ALIGNMENT_LEFT, -1, _fs(21), 5, Color("#344953"))
		ui.draw_string(font, Vector2(30,133), levels[current_level].name, HORIZONTAL_ALIGNMENT_LEFT, -1, _fs(21), Color("#fff1bc"))
		ui.draw_string_outline(font, Vector2(30,158), levels[current_level].hint, HORIZONTAL_ALIGNMENT_LEFT, -1, _fs(16), 4, Color("#344953"))
		ui.draw_string(font, Vector2(30,158), levels[current_level].hint, HORIZONTAL_ALIGNMENT_LEFT, -1, _fs(16), Color.WHITE)
		var center_x := get_viewport_rect().size.x * 0.5
		_draw_score_hud(Rect2(center_x - 165, 10, 330, 68), attempt_score, level_start_score)
		var x := 40.0
		for b in birds:
			if b.state == "queue":
				_draw_bird_icon(Vector2(x, 88), b.type)
				x += 38
	elif game_state == "WIN":
		if current_level == levels.size() - 1:
			_draw_campaign_result(font)
		else:
			_draw_result(font, "LEVEL %d CLEARED" % (current_level + 1), "NEXT LEVEL")
	elif game_state == "LOSE":
		_draw_result(font, "TRY AGAIN", "RESTART")

func _draw_center_title(font: Font) -> void:
	var vp := get_viewport_rect().size
	var title_text = "ANGRY BIRDS"
	var font_size = _fs(100)
	var target_y = 220.0

	# Precise vertical centering for Godot draw_string (which uses baseline)
	if _title_metrics_size != font_size:
		_title_metrics_size = font_size
		_title_ascent = font.get_ascent(font_size)
		_title_descent = font.get_descent(font_size)
	var title_pos = Vector2(0, target_y + (_title_ascent - _title_descent) * 0.5)
	
	_draw_text_fx(font, title_pos, title_text, HORIZONTAL_ALIGNMENT_CENTER, int(vp.x), font_size, Color(1, 0.196, 0.196), 10.0, 12.0)
	var version = ProjectSettings.get_setting("application/config/version", "dev")
	var version_text = "Version: " + version
	
	var version_font_size = _fs(18)
	var version_y_offset = 75.0                    # Distance below the title
	
	var version_pos = Vector2(0, target_y + version_y_offset)
	
	# Draw version using the same helper and color style as the title
	_draw_text_fx(font, version_pos, version_text, HORIZONTAL_ALIGNMENT_CENTER, 
				  int(vp.x), version_font_size, Color(1, 0.196, 0.196), 5.0, 6.0)
	_draw_button(_get_ui_rect("play"), "PLAY")

func _draw_text_fx(font: Font, pos: Vector2, text: String, align: int, width: int, size: int, color: Color, stroke_size: float = 4.0, shadow_blur: float = 8.0) -> void:
	size = _fs(size)
	stroke_size *= _font_scale()
	# 1. Subtle Blurry Shadow (Deep back)
	for i in range(4, 0, -1):
		var alpha = 0.35 * (1.0 - float(i) / 4.0)
		ui.draw_string(font, pos + Vector2(i, i) * 1.5, text, align, width, size, Color(0, 0, 0, alpha))

	# 2. White Outline (Outermost)
	ui.draw_string_outline(font, pos, text, align, width, size, int(stroke_size + 2), Color.WHITE)
	
	# 3. Inner Subtle Shadow/Outline (Same width on all sides)
	ui.draw_string_outline(font, pos, text, align, width, size, int(stroke_size * 0.4), Color(0, 0, 0, 0.8))
	
	# 4. Main Red Fill
	ui.draw_string(font, pos, text, align, width, size, color)

func _score_card(rect: Rect2) -> void:
	ui.draw_style_box(_card_style,rect)

func _draw_score_hud(rect: Rect2, level_score: int, total_score: int) -> void:
	var font := ThemeDB.fallback_font
	var score_red := Color(1, 0.196, 0.196)
	# Transparent panel: no fill, only a thin rounded outline so the sky
	# shows through. Text keeps the LEVEL fx styling for readability.
	ui.draw_style_box(_score_outline, rect)
	# Same font + fx styling as LEVEL (fallback font, red fill, white outline).
	_draw_text_fx(font, rect.position + Vector2(0, 22), "SCORE", HORIZONTAL_ALIGNMENT_CENTER, int(rect.size.x), 15, score_red, 2.0, 3.0)
	_draw_text_fx(font, rect.position + Vector2(12, 52), "Level: %d" % level_score, HORIZONTAL_ALIGNMENT_LEFT, 160, 19, score_red, 3.0, 3.0)
	_draw_text_fx(font, rect.position + Vector2(rect.size.x - 12 - 140, 52), "Total: %d" % total_score, HORIZONTAL_ALIGNMENT_RIGHT, 140, 19, score_red, 3.0, 3.0)

func _result_row(font: Font, rect: Rect2, y: float, label: String, value: int, size := 21, primary := false) -> void:
	var s := _fs(size)
	ui.draw_string(font,Vector2(rect.position.x+30,y),label,HORIZONTAL_ALIGNMENT_LEFT,-1,s,Color("#34494d"))
	ui.draw_string(font,Vector2(rect.position.x+270,y),str(value),HORIZONTAL_ALIGNMENT_RIGHT,int(rect.size.x-300),s+5 if primary else s,Color("#d4422e") if primary else Color("#34494d"))

func _draw_result(font: Font, title: String, button: String) -> void:
	var vp := get_viewport_rect().size
	var rect := Rect2(vp*0.5-Vector2(250,235),Vector2(500,470))
	var top := rect.position.y
	ui.draw_rect(Rect2(Vector2.ZERO,vp),Color(0.12,0.19,0.22,0.48))
	_score_card(rect)
	ui.draw_string(font,Vector2(rect.position.x,top+54),title,HORIZONTAL_ALIGNMENT_CENTER,500,_fs(32),Color("#d4422e"))
	if game_state == "WIN":
		_result_row(font,rect,top+108,"Destruction",result_destruction_score)
		_result_row(font,rect,top+144,"Unused birds",result_bonus)
		ui.draw_line(Vector2(rect.position.x+30,top+164),Vector2(rect.end.x-30,top+164),Color("#ded5c2"),1,true)
	else:
		ui.draw_string(font,Vector2(rect.position.x,top+123),"Give it another shot!",HORIZONTAL_ALIGNMENT_CENTER,500,_fs(21),Color("#5b6869"))
	_result_row(font,rect,top+207,"Level score",result_level_score,28,true)
	var note := "Not added to total"
	if game_state == "WIN":
		note = "Added to total" if result_elapsed >= 1.8 else "Adding level score..."
	ui.draw_string(font,Vector2(rect.position.x+30,top+239),note,HORIZONTAL_ALIGNMENT_LEFT,-1,_fs(16),Color("#5b6869"))
	ui.draw_line(Vector2(rect.position.x+30,top+268),Vector2(rect.end.x-30,top+268),Color("#ded5c2"),1,true)
	_result_row(font,rect,top+312,"Total score",_displayed_total(),26)
	# A single points token moves from the level value into the total; the
	# real score is committed once, independently of this presentation.
	if game_state == "WIN" and result_elapsed > 0.65 and result_elapsed < 1.8 and result_level_score > 0:
		var progress := _score_transfer_progress()
		var pos := Vector2(rect.end.x-108,top+222+progress*64)
		ui.draw_string(font,pos,"+%d" % result_level_score,HORIZONTAL_ALIGNMENT_LEFT,-1,_fs(17),Color(0.83,0.26,0.18,sin(progress*PI)))
	_draw_button(_get_ui_rect("result"), button)

func _draw_campaign_result(font: Font) -> void:
	var vp := get_viewport_rect().size
	ui.draw_rect(Rect2(Vector2.ZERO, vp), Color(0.08, 0.16, 0.18, 0.45))
	var rect := Rect2(vp.x * 0.5 - 270, vp.y * 0.5 - 250, 540, 480)
	var top := rect.position.y
	_score_card(rect)
	_draw_text_fx(font, Vector2(rect.position.x, top + 50), "CONGRATULATIONS!", HORIZONTAL_ALIGNMENT_CENTER, 540, 34, Color("#d93d32"), 3, 3)
	ui.draw_string(font, Vector2(rect.position.x, top + 82), "You completed the entire campaign!", HORIZONTAL_ALIGNMENT_CENTER, 540, _fs(21), Color("#5b6869"))
	_result_row(font, rect, top + 135, "Levels completed", campaign_levels_completed)
	_result_row(font, rect, top + 175, "Birds launched", campaign_shots)
	_result_row(font, rect, top + 215, "Retries", campaign_retries)
	var seconds := int(campaign_play_time)
	ui.draw_string(font, Vector2(rect.position.x + 30, top + 255), "Play time", HORIZONTAL_ALIGNMENT_LEFT, -1, _fs(22), Color("#5b6869"))
	ui.draw_string(font, Vector2(rect.end.x - 180, top + 255), "%d:%02d" % [seconds / 60, seconds % 60], HORIZONTAL_ALIGNMENT_RIGHT, 150, _fs(22), Color("#5b6869"))
	ui.draw_line(Vector2(rect.position.x + 30, top + 280), Vector2(rect.end.x - 30, top + 280), Color("#ded5c2"), 1, true)
	_result_row(font, rect, top + 325, "Total score", score, 28, true)
	_draw_button(_get_ui_rect("result"), "OK")

func _get_ui_rect(id: String) -> Rect2:
	var vp := get_viewport_rect().size
	var cx := vp.x * 0.5
	# Larger MENU hit area on touch devices: 48px tall is hard to hit.
	# touch_mode is cached in _ready; DisplayServer lookup per frame avoided.
	match id:
		"play": return Rect2(cx - 100, 310, 200, 80)
		"result": return Rect2(cx - 125, vp.y * 0.5 + 150, 250, 64)
		"menu":
			if touch_mode:
				return Rect2(vp.x - 234, 12, 222, 60)
			return Rect2(vp.x - 220, 20, 190, 48)
	return Rect2()

func _draw_button(rect: Rect2, text: String) -> void:
	ui.draw_style_box(_btn_style, rect)

	var font = ThemeDB.fallback_font
	var f_size = _fs(28)
	if _btn_metrics_size != f_size:
		_btn_metrics_size = f_size
		_btn_ascent = font.get_ascent(f_size)
		_btn_descent = font.get_descent(f_size)
	var text_y = rect.position.y + (rect.size.y - 4) * 0.5 + (_btn_ascent - _btn_descent) * 0.5
	
	ui.draw_string(font, Vector2(rect.position.x, text_y), text, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, f_size, Color.WHITE)

func _draw_bird_icon(pos: Vector2, type: String) -> void:
	var radius := 16.0 if type == "bird_s" else (18.0 if type == "bird_m" else 20.0)
	# Hybrid queue icons: same painted atlas body + live-style face as the
	# sling bird, so the top-left queue matches the in-game look.
	if PaintedArt.texture() != null:
		ui.draw_circle(pos + Vector2(3, 4), radius * 1.05, Color(0, 0, 0, 0.20))
		ui.draw_set_transform(pos, 0.0, Vector2.ONE)
		PaintedArt.paint_bird(ui, type, Rect2(-radius * 1.35, -radius * 1.5, radius * 2.7, radius * 2.5))
		PaintedArt.face(ui, radius, false, Vector2(0.8, 0), 0.0, 1.2)
		ui.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return
	var body: Color = {"bird_s": Color("#f13434"), "bird_m": Color("#ffd83a"), "bird_l": Color("#9f1212")}.get(type)
	var shade: Color = {"bird_s": Color("#9e1212"), "bird_m": Color("#c58b00"), "bird_l": Color("#520000")}.get(type)
	var belly: Color = Color("#fff1a7") if type == "bird_m" else Color("#ffe9cf")
	var brow: Color = Color("#7a4d00") if type == "bird_m" else Color("#5b1212")
	ui.draw_circle(pos + Vector2(3, 4), radius * 1.05, Color(0, 0, 0, 0.20))
	ui.draw_circle(pos, radius, shade)
	ui.draw_circle(pos + Vector2(-radius * 0.18, -radius * 0.20), radius * 0.86, body)
	ui.draw_circle(pos + Vector2(radius * 0.12, radius * 0.36), radius * 0.40, belly)
	ui.draw_circle(pos + Vector2(-radius * 0.36, -radius * 0.28), radius * 0.28, Color.WHITE)
	ui.draw_circle(pos + Vector2(radius * 0.18, -radius * 0.30), radius * 0.28, Color.WHITE)
	ui.draw_circle(pos + Vector2(-radius * 0.28, -radius * 0.25), radius * 0.09, Color("#181818"))
	ui.draw_circle(pos + Vector2(radius * 0.26, -radius * 0.27), radius * 0.09, Color("#181818"))
	ui.draw_line(pos + Vector2(-radius * 0.68, -radius * 0.60), pos + Vector2(-radius * 0.10, -radius * 0.42), brow, 2.2)
	ui.draw_line(pos + Vector2(radius * 0.60, -radius * 0.63), pos + Vector2(radius * 0.04, -radius * 0.43), brow, 2.2)
	var beak := PackedVector2Array([pos + Vector2(radius * 0.12, -radius * 0.05), pos + Vector2(radius * 0.86, radius * 0.10), pos + Vector2(radius * 0.12, radius * 0.32)])
	ui.draw_colored_polygon(beak, Color("#ff9f1c"))
	ui.draw_polyline(PackedVector2Array([beak[0], beak[1], beak[2]]), Color("#b65a00"), 1.6, true)
