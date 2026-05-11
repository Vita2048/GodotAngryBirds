extends RigidBody2D

signal damaged(at_position: Vector2, force: float)
signal popped(pig: Node, at_position: Vector2)

var radius := 25.0
var health := 100.0

func setup(p_radius: float) -> void:
	radius = p_radius
	mass = 1.0
	physics_material_override = PhysicsMaterial.new()
	physics_material_override.friction = 0.85
	physics_material_override.bounce = 0.35
	contact_monitor = true
	max_contacts_reported = 8
	var shape := CircleShape2D.new()
	shape.radius = radius
	var collision := CollisionShape2D.new()
	collision.shape = shape
	add_child(collision)
	body_entered.connect(_on_body_entered)

func _physics_process(_delta: float) -> void:
	queue_redraw()

func _on_body_entered(body: Node) -> void:
	var other_velocity := Vector2.ZERO
	if body is RigidBody2D:
		other_velocity = body.linear_velocity
	var force := (linear_velocity - other_velocity).length() * 0.08
	if force > 16.0:
		health -= force
		damaged.emit(global_position, force)
	if health <= 0.0:
		popped.emit(self, global_position)

func _draw() -> void:
	var hurt: float = clamp(1.0 - health / 100.0, 0.0, 1.0)
	draw_circle(Vector2(4, 5), radius * 1.06, Color(0, 0, 0, 0.20))
	draw_circle(Vector2.ZERO, radius, Color("#4f8f35").lerp(Color("#9be45f"), 1.0 - hurt * 0.45))
	draw_circle(Vector2(-radius * 0.55, -radius * 0.72), radius * 0.30, Color("#6dbd42"))
	draw_circle(Vector2(radius * 0.55, -radius * 0.72), radius * 0.30, Color("#6dbd42"))
	draw_circle(Vector2.ZERO, radius * 0.38, Color("#79c952"))
	draw_circle(Vector2(-radius * 0.16, 0), radius * 0.08, Color("#315222"))
	draw_circle(Vector2(radius * 0.16, 0), radius * 0.08, Color("#315222"))
	draw_circle(Vector2(-radius * 0.32, -radius * 0.28), radius * 0.18, Color.WHITE)
	draw_circle(Vector2(radius * 0.32, -radius * 0.28), radius * 0.18, Color.WHITE)
	draw_circle(Vector2(-radius * 0.27, -radius * 0.25), radius * 0.07, Color("#111a10"))
	draw_circle(Vector2(radius * 0.37, -radius * 0.25), radius * 0.07, Color("#111a10"))
	if hurt > 0.15:
		draw_line(Vector2(-radius * 0.75, -radius * 0.55), Vector2(-radius * 0.05, -radius * 0.40), Color("#27421c"), 2.5)
		draw_line(Vector2(radius * 0.75, -radius * 0.55), Vector2(radius * 0.05, -radius * 0.40), Color("#27421c"), 2.5)
