extends Node2D

const BirdScene := preload("res://scripts/Bird.gd")
const BlockScene := preload("res://scripts/BreakableBlock.gd")
const PigScene := preload("res://scripts/Pig.gd")
const ParticleLayer := preload("res://scripts/ParticleLayer.gd")

const VIEW := Vector2(1280, 720)
const SLING := Vector2(250, 570)
const MAX_DRAG := 100.0
const GROUND_SCROLL_WIDTH := 520.0
const SKY_DECORATION_BOTTOM := VIEW.y * 0.30

var cloud_textures: Array[Texture2D] = []
var grass_texture: Texture2D
var clouds: Array[Dictionary] = []
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
var launch_time := 0.0
var world_root: Node2D
var fx: ParticleLayer
var camera: Camera2D
var ui_layer: CanvasLayer
var ui: Control
var restart_rect := Rect2(VIEW.x - 218, 20, 190, 48)
var launch_power := 15.08

func _ready() -> void:
	randomize()
	_load_assets()
	_build_levels()
	_build_scene()
	_make_clouds()
	set_process_input(true)

func _load_assets() -> void:
	for i in range(1, 6):
		cloud_textures.append(_load_texture("res://assets/cloud_%d.svg" % i))
	grass_texture = _load_texture("res://assets/GrassHorizon.svg")

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
	world_root.add_child(fx)
	ui_layer = CanvasLayer.new()
	add_child(ui_layer)
	ui = Control.new()
	ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.draw.connect(_draw_ui)
	ui_layer.add_child(ui)

func _make_clouds() -> void:
	for i in 12:
		var texture: Texture2D = cloud_textures.pick_random()
		var scale: float = randf_range(0.055, 0.09)
		clouds.append({
			"texture": texture,
			"pos": Vector2(180 + i * 260 + randf_range(40, 150), randf_range(18, VIEW.y * 0.16)),
			"scale": scale,
			"phase": randf() * TAU,
			"speed": randf_range(0.12, 0.38)
		})

func _build_levels() -> void:
	levels = [
		{"birds":["bird_s","bird_s","bird_m","bird_s","bird_m"],"pigs":[{"x":950,"y":660,"r":25}],"blocks":[{"x":900,"y":630,"w":20,"h":100,"type":"wood"},{"x":1000,"y":630,"w":20,"h":100,"type":"wood"},{"x":950,"y":570,"w":140,"h":20,"type":"wood"}]},
		{"birds":["bird_m","bird_s","bird_l","bird_m"],"pigs":[{"x":900,"y":660,"r":25},{"x":1100,"y":660,"r":25}],"blocks":[{"x":850,"y":630,"w":20,"h":100,"type":"stone"},{"x":950,"y":630,"w":20,"h":100,"type":"stone"},{"x":900,"y":570,"w":140,"h":20,"type":"wood"},{"x":900,"y":540,"w":20,"h":40,"type":"glass"},{"x":1050,"y":630,"w":20,"h":100,"type":"stone"},{"x":1150,"y":630,"w":20,"h":100,"type":"stone"},{"x":1100,"y":570,"w":140,"h":20,"type":"wood"},{"x":1100,"y":540,"w":20,"h":40,"type":"glass"}]},
		{"birds":["bird_m","bird_m","bird_l","bird_s","bird_s"],"pigs":[{"x":950,"y":660,"r":25},{"x":1050,"y":660,"r":25},{"x":1000,"y":540,"r":25}],"blocks":[{"x":900,"y":630,"w":20,"h":100,"type":"stone"},{"x":1000,"y":630,"w":20,"h":100,"type":"wood"},{"x":1100,"y":630,"w":20,"h":100,"type":"stone"},{"x":1000,"y":570,"w":240,"h":20,"type":"stone"},{"x":950,"y":510,"w":20,"h":100,"type":"glass"},{"x":1050,"y":510,"w":20,"h":100,"type":"glass"},{"x":1000,"y":450,"w":140,"h":20,"type":"wood"},{"x":1000,"y":420,"w":40,"h":40,"type":"wood"}]},
		{"birds":["bird_s","bird_m","bird_l","bird_l"],"pigs":[{"x":1000,"y":660,"r":25},{"x":1000,"y":480,"r":25},{"x":1000,"y":300,"r":25}],"blocks":[{"x":950,"y":630,"w":20,"h":100,"type":"stone"},{"x":1050,"y":630,"w":20,"h":100,"type":"stone"},{"x":1000,"y":570,"w":150,"h":20,"type":"stone"},{"x":970,"y":510,"w":15,"h":100,"type":"wood"},{"x":1030,"y":510,"w":15,"h":100,"type":"wood"},{"x":1000,"y":450,"w":100,"h":20,"type":"wood"},{"x":985,"y":390,"w":10,"h":100,"type":"glass"},{"x":1015,"y":390,"w":10,"h":100,"type":"glass"},{"x":1000,"y":330,"w":60,"h":15,"type":"glass"}]},
		{"birds":["bird_l","bird_m","bird_m","bird_s","bird_s"],"pigs":[{"x":800,"y":660,"r":25},{"x":1200,"y":660,"r":25},{"x":1000,"y":450,"r":25},{"x":1000,"y":150,"r":25}],"blocks":[{"x":750,"y":630,"w":30,"h":100,"type":"stone"},{"x":850,"y":630,"w":30,"h":100,"type":"stone"},{"x":800,"y":570,"w":130,"h":30,"type":"stone"},{"x":1150,"y":630,"w":30,"h":100,"type":"stone"},{"x":1250,"y":630,"w":30,"h":100,"type":"stone"},{"x":1200,"y":570,"w":130,"h":30,"type":"stone"},{"x":800,"y":510,"w":20,"h":100,"type":"wood"},{"x":1200,"y":510,"w":20,"h":100,"type":"wood"},{"x":1000,"y":510,"w":400,"h":20,"type":"stone"},{"x":950,"y":450,"w":15,"h":100,"type":"glass"},{"x":1050,"y":450,"w":15,"h":100,"type":"glass"},{"x":1000,"y":390,"w":150,"h":15,"type":"wood"},{"x":980,"y":330,"w":10,"h":100,"type":"wood"},{"x":1020,"y":330,"w":10,"h":100,"type":"wood"},{"x":1000,"y":270,"w":80,"h":15,"type":"stone"},{"x":1000,"y":210,"w":20,"h":100,"type":"glass"}]}
	]

func _process(delta: float) -> void:
	_update_camera(delta)
	_check_bird_stop()
	_cleanup_fallen()
	_check_win_lose()
	queue_redraw()
	ui.queue_redraw()

func load_level(idx: int) -> void:
	for child in world_root.get_children():
		child.queue_free()
	fx = ParticleLayer.new()
	world_root.add_child(fx)
	birds.clear()
	pigs.clear()
	blocks.clear()
	active_bird = null
	drag_bird = null
	is_dragging = false
	current_level = idx
	if idx == 0:
		score = 0
	level_start_score = score
	_add_boundaries()
	var data := levels[idx]
	for b in data.blocks:
		var block := BlockScene.new()
		block.position = Vector2(b.x, b.y)
		block.setup(b.type, Vector2(b.w, b.h), b.get("angle", 0.0))
		block.damaged.connect(_on_block_damaged)
		block.destroyed.connect(_on_block_destroyed)
		world_root.add_child(block)
		blocks.append(block)
	for p in data.pigs:
		var pig := PigScene.new()
		pig.position = Vector2(p.x, p.y)
		pig.setup(p.r)
		pig.damaged.connect(_on_pig_damaged)
		pig.popped.connect(_on_pig_popped)
		world_root.add_child(pig)
		pigs.append(pig)
	for type in data.birds:
		birds.append({"type": type, "state": "queue", "node": null})
	game_state = "PLAYING"
	await get_tree().create_timer(0.35).timeout
	_load_next_bird()

func _add_boundaries() -> void:
	_add_static_rect(Vector2(1500, 700), Vector2(6000, 40))
	_add_static_rect(Vector2(-500, 360), Vector2(100, 2000))
	_add_static_rect(Vector2(_world_right_wall_x(), 360), Vector2(100, 2000))

func _add_static_rect(pos: Vector2, size: Vector2) -> void:
	var body := StaticBody2D.new()
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
	for b in birds:
		if b.state == "slingshot":
			b.state = "used"
	for b in birds:
		if b.state == "queue":
			var node := BirdScene.new()
			var radius: float = {"bird_s": 16.0, "bird_m": 22.0, "bird_l": 30.0}.get(b.type, 18.0)
			node.position = SLING
			node.setup(b.type, radius)
			node.freeze = true
			node.strong_impact.connect(_on_bird_impact)
			world_root.add_child(node)
			b.node = node
			b.state = "slingshot"
			drag_bird = node
			return

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var m := get_global_mouse_position()
		var screen_m := get_viewport().get_mouse_position()
		if event.pressed:
			_handle_press(m, screen_m)
		else:
			_handle_release()
	elif event is InputEventMouseMotion and is_dragging and drag_bird:
		var d := get_global_mouse_position() - SLING
		if d.length() > MAX_DRAG:
			d = d.normalized() * MAX_DRAG
		drag_bird.position = SLING + d
		drag_bird.linear_velocity = Vector2.ZERO
	elif event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
		_use_ability()

func _handle_press(world_m: Vector2, screen_m: Vector2) -> void:
	if game_state == "START":
		if Rect2(540, 330, 200, 72).has_point(screen_m):
			load_level(0)
		return
	if game_state in ["WIN", "LOSE"]:
		if Rect2(515, 410, 250, 76).has_point(screen_m):
			if game_state == "WIN" and current_level < levels.size() - 1:
				load_level(current_level + 1)
			elif game_state == "WIN":
				game_state = "START"
			else:
				load_level(current_level)
		return
	if game_state.begins_with("WAITING") or game_state == "PLAYING":
		if restart_rect.has_point(screen_m):
			load_level(current_level)
			return
		if drag_bird and world_m.distance_to(drag_bird.position) < drag_bird.radius * 2.6:
			is_dragging = true
		elif active_bird and active_bird.game_state == "flying" and not active_bird.ability_used:
			_use_ability()

func _handle_release() -> void:
	if not is_dragging or not drag_bird:
		return
	is_dragging = false
	var d := SLING - drag_bird.position
	if d.length() > 20.0:
		active_bird = drag_bird
		drag_bird = null
		active_bird.freeze = false
		active_bird.game_state = "flying"
		active_bird.linear_velocity = d * launch_power
		active_bird.angular_velocity = sign(d.x) * 2.5
		launch_time = Time.get_ticks_msec() / 1000.0
	else:
		drag_bird.position = SLING

func _use_ability() -> void:
	if not active_bird or active_bird.ability_used:
		return
	active_bird.ability_used = true
	if active_bird.bird_type == "bird_l":
		active_bird.linear_velocity = active_bird.linear_velocity.normalized() * 1250.0
		fx.burst(active_bird.global_position, [Color("#ffd447"), Color("#ff6e52"), Color.WHITE], 32, 1.2, "spark")
	elif active_bird.bird_type == "bird_m":
		for offset in [-16.0, 16.0]:
			var clone := BirdScene.new()
			clone.position = active_bird.position + Vector2(0, offset)
			clone.setup("bird_m", 18.0)
			clone.game_state = "flying"
			clone.ability_used = true
			clone.linear_velocity = active_bird.linear_velocity * 1.08 + Vector2(0, offset * 14.0)
			clone.strong_impact.connect(_on_bird_impact)
			world_root.add_child(clone)
			birds.append({"type": "bird_m", "state": "flying", "node": clone})
		fx.burst(active_bird.global_position, [Color("#ffe84a"), Color("#fff8b4"), Color("#ffb22a")], 28, 1.0, "spark")

func _update_camera(_delta: float) -> void:
	var target_x := VIEW.x * 0.5
	if active_bird and active_bird.game_state == "flying":
		target_x = clamp(active_bird.position.x, VIEW.x * 0.5, _max_camera_x())
	camera.position = Vector2(target_x, VIEW.y * 0.5)

func _check_bird_stop() -> void:
	if game_state not in ["PLAYING", "WAITING_WIN", "WAITING_LOSE"]:
		return
	var now := Time.get_ticks_msec() / 1000.0
	for b in birds:
		var node = b.node
		if node and b.state != "used" and node.game_state == "flying":
			if (now - launch_time > 2.3 and node.linear_velocity.length() < 28.0 and abs(node.angular_velocity) < 0.25) or node.position.y > 1000 or node.position.x < -500 or node.position.x > _world_right_wall_x() + 250.0:
				b.state = "used"
				if node == active_bird:
					active_bird = null
					node.queue_free()
					await get_tree().create_timer(0.55).timeout
					_load_next_bird()

func _cleanup_fallen() -> void:
	for block in blocks.duplicate():
		if not is_instance_valid(block) or block.position.y > 1050:
			blocks.erase(block)
			if is_instance_valid(block):
				block.queue_free()
	for pig in pigs.duplicate():
		if not is_instance_valid(pig) or pig.position.y > 1050:
			pigs.erase(pig)
			score += 5000
			if is_instance_valid(pig):
				pig.queue_free()

func _check_win_lose() -> void:
	if game_state != "PLAYING":
		return
	if pigs.is_empty():
		game_state = "WAITING_WIN"
		await get_tree().create_timer(1.0).timeout
		if game_state == "WAITING_WIN":
			game_state = "WIN"
			score += _queued_bird_count() * 10000
			fx.confetti(Rect2(camera.position.x - 500, 30, 1000, 80))
	elif _live_bird_count() == 0:
		game_state = "WAITING_LOSE"
		await get_tree().create_timer(1.8).timeout
		if game_state == "WAITING_LOSE":
			game_state = "LOSE" if not pigs.is_empty() else "WIN"

func _queued_bird_count() -> int:
	var count := 0
	for b in birds:
		if b.state == "queue":
			count += 1
	return count

func _live_bird_count() -> int:
	var count := 0
	for b in birds:
		if b.state in ["queue", "slingshot"] or (b.node and is_instance_valid(b.node) and b.node.game_state == "flying"):
			count += 1
	return count

func _on_block_damaged(pos: Vector2, type: String, force: float) -> void:
	var palette: Array = {"glass":[Color("#bdf0ff"), Color.WHITE, Color("#76ceff")], "stone":[Color("#858982"), Color("#c6c4b7"), Color("#555a55")], "wood":[Color("#a6642d"), Color("#db9a4c"), Color("#743e18")]}.get(type)
	fx.burst(pos, palette, clampi(int(force / 2.0), 5, 18), 0.65, "chip")

func _on_block_destroyed(block: Node, type: String, pos: Vector2) -> void:
	if blocks.has(block):
		blocks.erase(block)
	score += 700
	_on_block_damaged(pos, type, 45.0)
	block.queue_free()

func _on_pig_damaged(pos: Vector2, force: float) -> void:
	fx.burst(pos, [Color("#9be45f"), Color("#d8ff9a"), Color("#4f8f35")], clampi(int(force / 3.0), 4, 14), 0.7, "spark")

func _on_pig_popped(pig: Node, pos: Vector2) -> void:
	if pigs.has(pig):
		pigs.erase(pig)
	score += 5000
	fx.burst(pos, [Color("#9be45f"), Color("#ffffff"), Color("#76f06d")], 36, 1.2, "spark")
	pig.queue_free()

func _on_bird_impact(pos: Vector2, force: float, type: String) -> void:
	var palette: Array = {"bird_s":[Color("#ff3a3a"), Color("#ffac8c"), Color("#ffebd2")], "bird_m":[Color("#ffe845"), Color("#ffb226"), Color("#fff8b2")], "bird_l":[Color("#aa1010"), Color("#ff785a"), Color("#5a0c0c")]}.get(type)
	fx.burst(pos, palette, clampi(int(force / 2.0), 4, 18), 0.7, "spark")

func _draw() -> void:
	_draw_sky()
	_draw_ground()
	_draw_clouds()
	_draw_sling()

func _draw_sky() -> void:
	var visible_width := _visible_world_width()
	var cam_x := camera.position.x - visible_width * 0.5
	draw_rect(Rect2(cam_x, 0, visible_width + 40, VIEW.y), Color("#76c7ff"), true)
	var sun_pos := Vector2(cam_x + visible_width * 0.78, VIEW.y * 0.10)
	var t := Time.get_ticks_msec() * 0.001
	var pulse := sin(t * 2.2)
	draw_circle(sun_pos, 112.0 + pulse * 8.0, Color(1.0, 0.82, 0.24, 0.08))
	draw_circle(sun_pos, 78.0 + pulse * 5.0, Color(1.0, 0.88, 0.32, 0.18))
	for i in 16:
		var a := TAU * float(i) / 16.0 + t * 0.16
		var r1 := 42.0 + sin(t * 3.0 + float(i)) * 3.0
		var r2 := 92.0 + sin(t * 2.0 + float(i) * 0.7) * 7.0
		draw_line(sun_pos + Vector2(cos(a), sin(a)) * r1, sun_pos + Vector2(cos(a), sin(a)) * r2, Color(1.0, 0.78, 0.18, 0.24), 5.0)
	draw_circle(sun_pos, 36.0 + pulse * 2.0, Color("#ffd84a"))
	draw_circle(sun_pos + Vector2(-11, -11), 14.0, Color(1, 1, 1, 0.14))
	
func _draw_clouds() -> void:
	var visible_width := _visible_world_width()
	var cam_x := camera.position.x - visible_width * 0.5
	for cloud in clouds:
		var tex: Texture2D = cloud.texture
		var phase: float = cloud.phase + Time.get_ticks_msec() * 0.00008 * cloud.speed
		var pos: Vector2 = cloud.pos + Vector2(cam_x * 0.12, 0) + Vector2(cos(phase) * 12.0, sin(phase * 0.8) * 6.0)
		var s: float = cloud.scale * (1.0 + sin(phase) * 0.04)
		var size := tex.get_size() * s
		pos.y = clamp(pos.y, 8.0, SKY_DECORATION_BOTTOM - size.y - 8.0)
		if pos.x < cam_x + 36.0 or pos.x + size.x > cam_x + visible_width - 36.0:
			continue
		draw_texture_rect(tex, Rect2(pos, size), false, Color(1, 1, 1, 0.92))

func _draw_ground() -> void:
	if grass_texture:
		var target := Rect2(Vector2(_ground_left_x(), VIEW.y - _ground_draw_size().y), _ground_draw_size())
		draw_texture_rect(grass_texture, target, false)

func _ground_draw_size() -> Vector2:
	if not grass_texture:
		return Vector2.ZERO
	var src_size := grass_texture.get_size()
	var draw_width := _visible_world_width() + GROUND_SCROLL_WIDTH
	var scale_to_width := draw_width / src_size.x
	return src_size * scale_to_width

func _ground_left_x() -> float:
	return VIEW.x * 0.5 - _visible_world_width() * 0.5

func _world_right_wall_x() -> float:
	return _ground_left_x() + _ground_draw_size().x

func _max_camera_x() -> float:
	var visible_width := _visible_world_width()
	return max(VIEW.x * 0.5, _world_right_wall_x() - visible_width * 0.5)

func _visible_world_width() -> float:
	var window_size := DisplayServer.window_get_size()
	if window_size.y <= 0:
		return VIEW.x
	return max(VIEW.x, VIEW.y * float(window_size.x) / float(window_size.y))

func _draw_sling() -> void:
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

func _draw_ui() -> void:
	var font := ThemeDB.fallback_font
	if game_state == "START":
		_draw_center_title(font)
	elif game_state in ["PLAYING", "WAITING_WIN", "WAITING_LOSE"]:
		ui.draw_string(font, Vector2(30, 45), "LEVEL %d   SCORE %d" % [current_level + 1, score], HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color.WHITE)
		_draw_button(restart_rect, "RESET")
		var x := 40.0
		for b in birds:
			if b.state == "queue":
				_draw_bird_icon(Vector2(x, 88), b.type)
				x += 38
		if active_bird and active_bird.game_state == "flying" and not active_bird.ability_used and active_bird.bird_type != "bird_s":
			ui.draw_string(font, Vector2(470, 48), "CLICK OR SPACE FOR POWER", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1, 1, 1, 0.86))
	elif game_state == "WIN":
		_draw_result(font, "LEVEL CLEARED", "NEXT LEVEL" if current_level < levels.size() - 1 else "MAIN MENU")
	elif game_state == "LOSE":
		_draw_result(font, "TRY AGAIN", "RESTART")

func _draw_center_title(font: Font) -> void:
	ui.draw_rect(Rect2(Vector2.ZERO, VIEW), Color(0, 0, 0, 0.08), true)
	ui.draw_string(font, Vector2(370, 250), "ANGRY BIRDS", HORIZONTAL_ALIGNMENT_LEFT, -1, 74, Color.WHITE)
	ui.draw_string(font, Vector2(442, 296), "PREMIUM GODOT EDITION", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1, 0.92, 0.55, 0.95))
	_draw_button(Rect2(540, 330, 200, 72), "PLAY")

func _draw_result(font: Font, title: String, button: String) -> void:
	ui.draw_rect(Rect2(Vector2.ZERO, VIEW), Color(0, 0, 0, 0.34), true)
	ui.draw_string(font, Vector2(445, 330), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 52, Color.WHITE)
	ui.draw_string(font, Vector2(510, 374), "SCORE %d" % score, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(1, 0.92, 0.55))
	_draw_button(Rect2(515, 410, 250, 76), button)

func _draw_button(rect: Rect2, text: String) -> void:
	ui.draw_rect(rect.grow(4), Color(0, 0, 0, 0.25), true)
	ui.draw_rect(rect, Color("#e84a31"), true)
	ui.draw_rect(rect.grow(-5), Color(1, 1, 1, 0.13), false, 2)
	ui.draw_string(ThemeDB.fallback_font, rect.position + Vector2(0, rect.size.y * 0.68), text, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 28, Color.WHITE)

func _draw_bird_icon(pos: Vector2, type: String) -> void:
	var radius := 16.0 if type == "bird_s" else (18.0 if type == "bird_m" else 20.0)
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
