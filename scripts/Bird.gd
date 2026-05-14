extends RigidBody2D

signal strong_impact(at_position: Vector2, force: float, bird_type: String)

var bird_type := "bird_s"
var radius := 18.0
var game_state := "queue"
var ability_used := false
var squash := 0.0
var squash_time := 0.0
var life_time := 0.0
var launch_time := 0.0
var is_bonus := false

func setup(p_type: String, p_radius: float) -> void:
	bird_type = p_type
	radius = p_radius
	mass = {"bird_s": 1.1, "bird_m": 1.6, "bird_l": 2.3}.get(bird_type, 1.0)
	gravity_scale = 1.0
	linear_damp = 0.05
	angular_damp = 0.08
	contact_monitor = true
	max_contacts_reported = 4 # Reduced from 8
	continuous_cd = RigidBody2D.CCD_MODE_DISABLED # Default to disabled
	var shape := CircleShape2D.new()
	shape.radius = radius
	var collision := CollisionShape2D.new()
	collision.shape = shape
	add_child(collision)
	body_entered.connect(_on_body_entered)
	if bird_type == "bird_l": # Only big bird really needs CCD
		continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE

func _physics_process(delta: float) -> void:
	life_time += delta
	if squash > 0.0:
		squash_time += delta
		if squash_time > 0.28:
			squash = 0.0
	queue_redraw()

func _on_body_entered(body: Node) -> void:
	var other_velocity := Vector2.ZERO
	if body is RigidBody2D:
		other_velocity = body.linear_velocity
	var force := (linear_velocity - other_velocity).length() * 0.085
	if force > 13.0:
		squash = min(0.34, force / 80.0)
		squash_time = 0.0
		strong_impact.emit(global_position, force, bird_type)

func _draw() -> void:
	var pulse: float = max(0.0, 1.0 - squash_time / 0.28)
	var wobble: float = sin(squash_time * 40.0) * pulse
	var sx: float = 1.0 + squash * (0.65 * pulse + 0.12 * wobble)
	var sy: float = max(0.70, 1.0 - squash * (0.50 * pulse + 0.08 * wobble))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(sx, sy))
	var body_color := Color("#f13434")
	var shade := Color("#9e1212")
	var belly := Color("#ffe9cf")
	var brow := Color("#5b1212")
	if bird_type == "bird_m":
		body_color = Color("#ffd83a")
		shade = Color("#c58b00")
		belly = Color("#fff1a7")
		brow = Color("#7a4d00")
	elif bird_type == "bird_l":
		body_color = Color("#9f1212")
		shade = Color("#520000")
		belly = Color("#ffd6ba")
		brow = Color("#360000")
	draw_circle(Vector2(4, 6), radius * 1.04, Color(0, 0, 0, 0.22))
	draw_circle(Vector2.ZERO, radius, shade)
	draw_circle(Vector2(-radius * 0.20, -radius * 0.25), radius * 0.88, body_color)
	draw_circle(Vector2(radius * 0.10, radius * 0.35), radius * 0.42, belly)
	draw_circle(Vector2(-radius * 0.38, -radius * 0.28), radius * 0.30, Color.WHITE)
	draw_circle(Vector2(radius * 0.18, -radius * 0.30), radius * 0.30, Color.WHITE)
	draw_circle(Vector2(-radius * 0.30, -radius * 0.25), radius * 0.10, Color("#181818"))
	draw_circle(Vector2(radius * 0.26, -radius * 0.27), radius * 0.10, Color("#181818"))
	draw_line(Vector2(-radius * 0.70, -radius * 0.62), Vector2(-radius * 0.12, -radius * 0.42), brow, max(2.0, radius * 0.12))
	draw_line(Vector2(radius * 0.60, -radius * 0.66), Vector2(radius * 0.04, -radius * 0.43), brow, max(2.0, radius * 0.12))
	var beak := PackedVector2Array([Vector2(radius * 0.12, -radius * 0.05), Vector2(radius * 0.92, radius * 0.10), Vector2(radius * 0.12, radius * 0.33)])
	draw_colored_polygon(beak, Color("#ff9f1c"))
	draw_polyline(PackedVector2Array([beak[0], beak[1], beak[2]]), Color("#b65a00"), max(1.5, radius * 0.06), true)
	if bird_type == "bird_l":
		draw_line(Vector2(-radius * 0.30, -radius * 1.0), Vector2(-radius * 0.12, -radius * 1.34), shade, max(3.0, radius * 0.10))
		draw_line(Vector2(radius * 0.00, -radius * 1.02), Vector2(radius * 0.08, -radius * 1.38), shade, max(3.0, radius * 0.10))
