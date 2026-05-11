extends RigidBody2D

signal damaged(at_position: Vector2, material_type: String, force: float)
signal destroyed(block: Node, material_type: String, at_position: Vector2)

var material_type := "wood"
var size := Vector2(80, 20)
var health := 50.0
var max_health := 50.0
var chip_cooldown := 0.0

func setup(p_material: String, p_size: Vector2, angle_radians := 0.0) -> void:
	material_type = p_material
	size = p_size
	rotation = angle_radians
	max_health = _calc_health()
	health = max_health
	contact_monitor = true
	max_contacts_reported = 8
	continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE
	mass = max(0.25, size.x * size.y / 1450.0) * {"glass": 0.42, "wood": 0.5, "stone": 1.5}.get(material_type, 1.0)
	physics_material_override = PhysicsMaterial.new()
	physics_material_override.friction = {"glass": 0.45, "wood": 0.82, "stone": 0.92}.get(material_type, 0.7)
	physics_material_override.bounce = {"glass": 0.28, "wood": 0.16, "stone": 0.08}.get(material_type, 0.1)
	var rect := RectangleShape2D.new()
	rect.size = size
	var collision := CollisionShape2D.new()
	collision.shape = rect
	add_child(collision)
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	chip_cooldown = max(0.0, chip_cooldown - delta)
	queue_redraw()

func _calc_health() -> float:
	var base: float = {"glass": 20.0, "wood": 40.0, "stone": 80.0}.get(material_type, 80.0)
	var min_side: float = max(10.0, min(size.x, size.y))
	var area: float = max(400.0, size.x * size.y)
	var hp: float = round(base * pow(min_side / 20.0, 0.9) * pow(area / 1600.0, 0.35))
	return clamp(hp, round(base * 0.6), round(base * 8.0))

func _on_body_entered(body: Node) -> void:
	var other_velocity := Vector2.ZERO
	if body is RigidBody2D:
		other_velocity = body.linear_velocity
	var force := (linear_velocity - other_velocity).length() * 0.075
	if force > 16.0:
		health -= force
		if chip_cooldown <= 0.0:
			damaged.emit(global_position, material_type, force)
			chip_cooldown = 0.10
	if health <= 0.0:
		destroyed.emit(self, material_type, global_position)

func _draw() -> void:
	var rect := Rect2(-size * 0.5, size)
	var hp_ratio: float = clamp(health / max_health, 0.0, 1.0)
	draw_rect(rect.grow(4.0), Color(0, 0, 0, 0.18), true)
	if material_type == "wood":
		draw_rect(rect, Color("#8f5428").lerp(Color("#c7823a"), hp_ratio), true)
		for x in range(int(-size.x / 2.0) + 6, int(size.x / 2.0), 11):
			draw_line(Vector2(x, -size.y / 2.0 + 3), Vector2(x + sin(float(x) * 0.2) * 3.0, size.y / 2.0 - 3), Color(0.35, 0.18, 0.07, 0.42), 1.5)
	elif material_type == "stone":
		draw_rect(rect, Color("#6f736e").lerp(Color("#aaa99d"), hp_ratio), true)
		draw_line(Vector2(-size.x * 0.42, -size.y * 0.20), Vector2(size.x * 0.35, size.y * 0.18), Color(1, 1, 1, 0.12), 2.0)
	else:
		draw_rect(rect, Color(0.55, 0.86, 1.0, 0.58), true)
		draw_rect(rect.grow(-3.0), Color(0.9, 1.0, 1.0, 0.24), false, 2.0)
	if hp_ratio < 0.62:
		var cracks := int((1.0 - hp_ratio) * 7.0) + 1
		for i in cracks:
			var t := float(i) / float(cracks + 1)
			draw_line(Vector2(lerp(-size.x * 0.42, size.x * 0.35, t), -size.y * 0.22), Vector2(lerp(-size.x * 0.25, size.x * 0.45, t), size.y * 0.22), Color(0.05, 0.04, 0.03, 0.28), 1.2)
	draw_rect(rect, Color(1, 1, 1, 0.18), false, 2.0)
