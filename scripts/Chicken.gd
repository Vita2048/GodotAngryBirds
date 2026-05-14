extends Area2D

signal chicken_shot(chicken: Area2D, bird_node: RigidBody2D)
signal chicken_grounded(chicken: Area2D, bird_type: String, radius: float)

var flying_texture: Texture2D
var shot_texture: Texture2D

var state := "FLYING" # FLYING, SHOT, FALLING
var velocity := Vector2.ZERO
var frame := 0
var frame_timer := 0.0
var target_velocity := Vector2.ZERO
var direction_change_timer := 0.0
var shot_bird_type := "bird_s"
var shot_bird_radius := 16.0
var scale_val := 0.6
var can_change_direction := true

const FLY_SPEED := 120.0
const CHANGE_TIME := 2.0
const GRAVITY := 500.0

func setup(f_tex: Texture2D, s_tex: Texture2D) -> void:
	flying_texture = f_tex
	shot_texture = s_tex
	
	var shape := CircleShape2D.new()
	shape.radius = 25.0
	var col := CollisionShape2D.new()
	col.shape = shape
	add_child(col)
	
	_pick_new_target_velocity()
	body_entered.connect(_on_body_entered)

func _pick_new_target_velocity() -> void:
	var from_left = randf() > 0.5
	var speed = randf_range(60.0, 180.0)
	target_velocity = Vector2(speed if from_left else -speed, randf_range(-60.0, 60.0))
	direction_change_timer = randf_range(1.0, 3.0)

func _process(delta: float) -> void:
	if state == "FLYING":
		_process_flying(delta)
	elif state == "SHOT":
		_process_shot(delta)
	elif state == "FALLING":
		_process_falling(delta)
	
	queue_redraw()

var last_flip := 1.0

func _process_flying(delta: float) -> void:
	direction_change_timer -= delta
	if direction_change_timer <= 0 and can_change_direction:
		_pick_new_target_velocity()
	
	velocity = velocity.lerp(target_velocity, delta * 2.0)
	position += velocity * delta
	
	if abs(velocity.x) > 5.0:
		last_flip = 1.0 if velocity.x < 0 else -1.0
	
	# Keep within vertical bounds (25% - 75%)
	var min_y := 720.0 * 0.25
	var max_y := 720.0 * 0.75
	if position.y < min_y:
		target_velocity.y = abs(target_velocity.y)
	elif position.y > max_y:
		target_velocity.y = -abs(target_velocity.y)
	
	# Animation
	frame_timer += delta * 24.0 # Faster animation
	if frame_timer >= 1.0:
		frame = (frame + 1) % 13
		frame_timer = 0.0

func _process_shot(delta: float) -> void:
	velocity.y += GRAVITY * 0.8 * delta # Stronger gravity for JS feel
	position += velocity * delta
	
	frame_timer += delta * 12.0
	if frame_timer >= 1.0:
		if frame < 7:
			frame += 1
		else:
			state = "FALLING"
		frame_timer = 0.0

func _process_falling(delta: float) -> void:
	velocity.y += GRAVITY * delta
	position += velocity * delta
	
	if position.y >= 680: # Ground level approx
		chicken_grounded.emit(self, shot_bird_type, shot_bird_radius)
		queue_free()

func _on_body_entered(body: Node) -> void:
	if state == "FLYING" and body.get("game_state") == "flying":
		# Hit by a bird
		state = "SHOT"
		frame = 0
		frame_timer = 0.0
		shot_bird_type = body.get("bird_type")
		shot_bird_radius = body.get("radius")
		# Give it some initial hit momentum and a pop up
		velocity = body.linear_velocity * 0.15
		velocity.y = -200.0 # Pop up
		chicken_shot.emit(self, body)

func _draw() -> void:
	var tex := flying_texture if state == "FLYING" else shot_texture
	if not tex: return
	
	var frame_count := 13 if state == "FLYING" else 8
	var h := tex.get_height() / float(frame_count)
	var w := tex.get_width()
	
	var src_rect := Rect2(0, frame * h, w, h)
	
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(last_flip * scale_val, scale_val))
	draw_texture_rect_region(tex, Rect2(-w*0.5, -h*0.5, w, h), src_rect)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
