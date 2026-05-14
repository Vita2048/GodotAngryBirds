extends Node2D

const BirdScene := preload("res://scripts/Bird.gd")
const BlockScene := preload("res://scripts/BreakableBlock.gd")
const PigScene := preload("res://scripts/Pig.gd")
const ParticleLayer := preload("res://scripts/ParticleLayer.gd")
const ChickenScene := preload("res://scripts/Chicken.gd")

const VIEW := Vector2(1280, 720)
const SLING := Vector2(250, 570)
const MAX_DRAG := 100.0
const GROUND_SCROLL_WIDTH := 520.0
const SKY_DECORATION_BOTTOM := VIEW.y * 0.30
const SKY_COLOR := Color("#76c7ff")

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

func _ready() -> void:
	randomize()
	_load_assets()
	_build_levels()
	_build_scene()
	_make_butterflies()
	set_process_input(true)

func _load_assets() -> void:
	background_texture = _load_texture("res://assets/ABBackgroundWide.png")
	butterfly_texture = _load_texture("res://assets/Butterfly.png")
	sun_texture = _load_texture("res://assets/SunSingle.png")
	chicken_flying_texture = _load_texture("res://assets/ChickenFlyingL.png")
	chicken_shot_texture = _load_texture("res://assets/ChickenShotL.png")

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
	var t := Time.get_ticks_msec() * 0.001
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
	levels = [
		# Level 0
		{"birds":["bird_s","bird_s","bird_m","bird_s","bird_m"],
		 "pigs":[{"x":950,"y":660,"r":25}],
		 "blocks":[
			{"x":900,"y":630,"w":20,"h":100,"type":"wood"},
			{"x":1000,"y":630,"w":20,"h":100,"type":"wood"},
			{"x":950,"y":570,"w":140,"h":20,"type":"wood"}
		]},
		
		# Level 1
		{"birds":["bird_m","bird_s","bird_l","bird_m"],
		 "pigs":[{"x":900,"y":660,"r":25},{"x":1100,"y":660,"r":25}],
		 "blocks":[
			{"x":850,"y":630,"w":20,"h":100,"type":"stone"},
			{"x":950,"y":630,"w":20,"h":100,"type":"stone"},
			{"x":900,"y":570,"w":140,"h":20,"type":"wood"},
			{"x":900,"y":540,"w":20,"h":40,"type":"glass"},
			{"x":1050,"y":630,"w":20,"h":100,"type":"stone"},
			{"x":1150,"y":630,"w":20,"h":100,"type":"stone"},
			{"x":1100,"y":570,"w":140,"h":20,"type":"wood"},
			{"x":1100,"y":540,"w":20,"h":40,"type":"glass"}
		]},
		
		# Level 2
		{"birds":["bird_m","bird_m","bird_l","bird_s","bird_s"],
		 "pigs":[{"x":950,"y":660,"r":25},{"x":1050,"y":660,"r":25},{"x":1000,"y":540,"r":25}],
		 "blocks":[
			{"x":900,"y":630,"w":20,"h":100,"type":"stone"},
			{"x":1000,"y":630,"w":20,"h":100,"type":"wood"},
			{"x":1100,"y":630,"w":20,"h":100,"type":"stone"},
			{"x":1000,"y":570,"w":240,"h":20,"type":"stone"},
			{"x":950,"y":510,"w":20,"h":100,"type":"glass"},
			{"x":1050,"y":510,"w":20,"h":100,"type":"glass"},
			{"x":1000,"y":450,"w":140,"h":20,"type":"wood"},
			{"x":1000,"y":420,"w":40,"h":40,"type":"wood"}
		]},
		
		# Level 3
		{"birds":["bird_s","bird_m","bird_l","bird_l"],
		 "pigs":[{"x":1000,"y":660,"r":25},{"x":1000,"y":480,"r":25},{"x":1000,"y":300,"r":25}],
		 "blocks":[
			{"x":950,"y":630,"w":20,"h":100,"type":"stone"},
			{"x":1050,"y":630,"w":20,"h":100,"type":"stone"},
			{"x":1000,"y":570,"w":150,"h":20,"type":"stone"},
			{"x":970,"y":510,"w":15,"h":100,"type":"wood"},
			{"x":1030,"y":510,"w":15,"h":100,"type":"wood"},
			{"x":1000,"y":450,"w":100,"h":20,"type":"wood"},
			{"x":985,"y":390,"w":10,"h":100,"type":"glass"},
			{"x":1015,"y":390,"w":10,"h":100,"type":"glass"},
			{"x":1000,"y":330,"w":60,"h":15,"type":"glass"}
		]},
		
		# Level 4 (your thick/hard level - now correctly placed)
		{"birds":["bird_l","bird_m","bird_m","bird_s","bird_s"],
		 "pigs":[{"x":800,"y":660,"r":25},{"x":1200,"y":660,"r":25},{"x":1000,"y":450,"r":25},{"x":1000,"y":150,"r":25}],
		 "blocks":[
			# Left tower
			{"x":740,"y":630,"w":20,"h":100,"type":"stone"},
			{"x":860,"y":630,"w":20,"h":100,"type":"stone"},
			{"x":800,"y":565,"w":160,"h":20,"type":"stone"},
			
			# Right tower
			{"x":1140,"y":630,"w":20,"h":100,"type":"stone"},
			{"x":1260,"y":630,"w":20,"h":100,"type":"stone"},
			{"x":1200,"y":565,"w":160,"h":20,"type":"stone"},
			
			# Middle connectors
			{"x":800,"y":510,"w":30,"h":110,"type":"wood"},
			{"x":1200,"y":510,"w":30,"h":110,"type":"wood"},
			{"x":1000,"y":505,"w":420,"h":20,"type":"stone"},
			
			# Upper level
			{"x":950,"y":445,"w":20,"h":110,"type":"glass"},
			{"x":1050,"y":445,"w":20,"h":110,"type":"glass"},
			{"x":1000,"y":385,"w":170,"h":25,"type":"wood"},
			
			# Top structures
			{"x":975,"y":325,"w":20,"h":110,"type":"wood"},
			{"x":1025,"y":325,"w":20,"h":110,"type":"wood"},
			{"x":1000,"y":265,"w":100,"h":20,"type":"stone"},
			{"x":1000,"y":205,"w":50,"h":110,"type":"glass"}
		]}
	]

func _process(delta: float) -> void:
	_update_camera(delta)
	_update_butterflies(delta)
	_update_chickens(delta)
	if focus_timer > 0:
		focus_timer -= delta
	_check_bird_stop()
	_cleanup_fallen()
	_check_win_lose()
	if fx.particles.size() > 600:
		fx.particles.remove_at(0)
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
	chickens.clear()
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
	elif event is InputEventScreenTouch:
		var m := get_global_mouse_position()
		var screen_m := (event as InputEventScreenTouch).position
		if event.pressed:
			_handle_press(m, screen_m)
		else:
			_handle_release()
	elif event is InputEventScreenDrag and is_dragging and drag_bird:
		var d := get_global_mouse_position() - SLING
		if d.length() > MAX_DRAG:
			d = d.normalized() * MAX_DRAG
		drag_bird.position = SLING + d
		drag_bird.linear_velocity = Vector2.ZERO

func _handle_press(world_m: Vector2, screen_m: Vector2) -> void:
	if game_state == "START":
		if _get_ui_rect("play").has_point(screen_m):
			load_level(0)
		return
	if game_state in ["WIN", "LOSE"]:
		if _get_ui_rect("result").has_point(screen_m):
			if game_state == "WIN" and current_level < levels.size() - 1:
				load_level(current_level + 1)
			elif game_state == "WIN":
				game_state = "START"
			else:
				load_level(current_level)
		return
	if game_state.begins_with("WAITING") or game_state == "PLAYING":
		if _get_ui_rect("reset").has_point(screen_m):
			load_level(current_level)
			return
		if drag_bird and world_m.distance_to(drag_bird.position) < drag_bird.radius * 2.6:
			is_dragging = true

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
		active_bird.launch_time = Time.get_ticks_msec() / 1000.0
		active_bird.linear_velocity = d * launch_power
		active_bird.angular_velocity = sign(d.x) * 2.5
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
	var now := Time.get_ticks_msec() / 1000.0
	for b in birds:
		var node = b.node
		if node and is_instance_valid(node) and node.game_state == "flying":
			if (now - node.launch_time > 2.3 and node.linear_velocity.length() < 28.0 and abs(node.angular_velocity) < 0.25) or node.position.y > 1000 or node.position.x < -500 or node.position.x > _world_right_wall_x() + 250.0:
				if node == active_bird:
					b.state = "used"
					active_bird = null
					node.queue_free()
					await get_tree().create_timer(0.55).timeout
					_load_next_bird()
				else:
					b.state = "used"
					node.queue_free()
					b.node = null

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

func _on_bird_impact(pos: Vector2, force: float, type: String) -> void:
	# Reduce particle count if there are already many particles
	var count := clampi(int(force / 3.0), 3, 12)
	if fx.particles.size() > 400:
		count = clampi(count / 2, 2, 6)
	
	var palette: Array = {"bird_s":[Color("#ff3a3a"), Color("#ffac8c"), Color("#ffebd2")], "bird_m":[Color("#ffe845"), Color("#ffb226"), Color("#fff8b2")], "bird_l":[Color("#aa1010"), Color("#ff785a"), Color("#5a0c0c")]}.get(type)
	fx.burst(pos, palette, count, 0.7, "spark")

func _draw() -> void:
	_draw_sky()
	_draw_sun()
	_draw_butterflies()
	_draw_sling()

func _draw_sky() -> void:
	var cam_x := camera.position.x - VIEW.x * 0.5
	var cam_y := camera.position.y - VIEW.y * 0.5
	draw_rect(Rect2(cam_x - 2000, cam_y - 1000, WORLD_WIDTH + 4000, 3000), SKY_COLOR, true)
	if not background_texture:
		return
	var tex_w := background_texture.get_size().x
	var tex_h := background_texture.get_size().y
	var scale := 720.0 / tex_h
	var draw_w := tex_w * scale
	
	var start_x : float = floor(cam_x / draw_w) * draw_w - draw_w
	var end_x : float = cam_x + VIEW.x + draw_w
	
	var x : float = start_x
	while x < end_x:
		draw_texture_rect(background_texture, Rect2(x, 0, draw_w, 720), false)
		x += draw_w

func _draw_sun() -> void:
	if not sun_texture:
		return
	var cam_x := camera.position.x - VIEW.x * 0.5
	var cam_y := camera.position.y - VIEW.y * 0.5
	var sun_pos := Vector2(cam_x + 1150, cam_y + 110)
	var t := Time.get_ticks_msec() * 0.001
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
	var tex_size := sun_texture.get_size()
	draw_texture_rect(sun_texture, Rect2(-64, -64, 128, 128), false)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_butterflies() -> void:
	if not butterfly_texture:
		return
	var tex_size := butterfly_texture.get_size()
	var fw := tex_size.x / 4.0
	var fh := tex_size.y / 4.0
	
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
		_draw_text_fx(font, Vector2(30, 45), "LEVEL %d   SCORE %d" % [current_level + 1, score], HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color(1, 0.196, 0.196), 4.0, 4.0)
		_draw_button(_get_ui_rect("reset"), "RESET")
		var x := 40.0
		for b in birds:
			if b.state == "queue":
				_draw_bird_icon(Vector2(x, 88), b.type)
				x += 38
	elif game_state == "WIN":
		_draw_result(font, "LEVEL %d CLEARED" % (current_level + 1), "NEXT LEVEL" if current_level < levels.size() - 1 else "MAIN MENU"
)
	elif game_state == "LOSE":
		_draw_result(font, "TRY AGAIN", "RESTART")

func _draw_center_title(font: Font) -> void:
	var vp := get_viewport_rect().size
	var title_text = "ANGRY BIRDS"
	var font_size = 100
	var target_y = 220.0
	
	# Precise vertical centering for Godot draw_string (which uses baseline)
	var ascent = font.get_ascent(font_size)
	var descent = font.get_descent(font_size)
	var title_pos = Vector2(0, target_y + (ascent - descent) * 0.5)
	
	_draw_text_fx(font, title_pos, title_text, HORIZONTAL_ALIGNMENT_CENTER, int(vp.x), font_size, Color(1, 0.196, 0.196), 10.0, 12.0)
	var version = ProjectSettings.get_setting("application/config/version", "dev")
	var version_text = "Version: " + version
	
	var version_font_size = 18
	var version_y_offset = 75.0                    # Distance below the title
	
	var version_pos = Vector2(0, target_y + version_y_offset)
	
	# Draw version using the same helper and color style as the title
	_draw_text_fx(font, version_pos, version_text, HORIZONTAL_ALIGNMENT_CENTER, 
				  int(vp.x), version_font_size, Color(1, 0.196, 0.196), 5.0, 6.0)
	_draw_button(_get_ui_rect("play"), "PLAY")

func _draw_text_fx(font: Font, pos: Vector2, text: String, align: int, width: int, size: int, color: Color, stroke_size: float = 4.0, shadow_blur: float = 8.0) -> void:
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

func _draw_result(font: Font, title: String, button: String) -> void:
	var vp := get_viewport_rect().size
	_draw_text_fx(font, Vector2(0, 330), title, HORIZONTAL_ALIGNMENT_CENTER, int(vp.x), 52, Color(1, 0.196, 0.196), 6.0, 8.0)
	_draw_text_fx(font, Vector2(0, 374), "SCORE %d" % score, HORIZONTAL_ALIGNMENT_CENTER, int(vp.x), 26, Color(1, 0.196, 0.196), 4.0, 4.0)
	_draw_button(_get_ui_rect("result"), button)

func _get_ui_rect(id: String) -> Rect2:
	var vp := get_viewport_rect().size
	var cx := vp.x * 0.5
	match id:
		"play": return Rect2(cx - 100, 310, 200, 80)
		"result": return Rect2(cx - 125, 410, 250, 76)
		"reset": return Rect2(vp.x - 220, 20, 190, 48)
	return Rect2()

func _draw_button(rect: Rect2, text: String) -> void:
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color("#e84a31")
	sb.set_corner_radius_all(18) # Modern Android rounded corners
	sb.shadow_color = Color(0, 0, 0, 0.3)
	sb.shadow_size = 6
	sb.shadow_offset = Vector2(0, 4)
	sb.border_width_bottom = 4
	sb.border_color = Color("#b82e1c")
	sb.anti_aliasing = true
	ui.draw_style_box(sb, rect)
	
	var font = ThemeDB.fallback_font
	var f_size = 28
	var ascent = font.get_ascent(f_size)
	var descent = font.get_descent(f_size)
	var text_y = rect.position.y + (rect.size.y - 4) * 0.5 + (ascent - descent) * 0.5
	
	ui.draw_string(font, Vector2(rect.position.x, text_y), text, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, f_size, Color.WHITE)

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
