extends RigidBody2D

signal exploded(prop: Node, at: Vector2)
signal struck(at: Vector2, force: float)
var kind := "crate"
var armed := false
var spent := false
var age := 0.0
var cooldown := 0.0

func setup(type: String) -> void:
	kind = type
	mass = 5.0 if kind == "boulder" else 0.8
	contact_monitor = true
	max_contacts_reported = 8
	continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE
	physics_material_override = PhysicsMaterial.new()
	physics_material_override.friction = 0.65
	physics_material_override.bounce = 0.08
	var col := CollisionShape2D.new()
	if kind == "boulder":
		var shape := CircleShape2D.new()
		shape.radius = 34.0
		col.shape = shape
	else:
		var shape := RectangleShape2D.new()
		shape.size = Vector2(44, 44)
		col.shape = shape
	add_child(col)
	body_entered.connect(_hit)

func _physics_process(delta: float) -> void:
	age += delta
	cooldown = maxf(0, cooldown - delta)
	armed = age > 0.7
	if kind == "crate": queue_redraw()

func _hit(body: Node) -> void:
	if not armed or spent: return
	var other := Vector2.ZERO
	if body is RigidBody2D: other = body.linear_velocity
	var speed := (linear_velocity - other).length()
	if kind == "crate" and speed > 95.0:
		detonate()
	elif kind == "boulder" and speed > 85.0 and cooldown <= 0.0:
		cooldown = 0.18
		struck.emit(global_position, speed * 0.085)

func detonate() -> void:
	if spent or kind != "crate": return
	spent = true
	exploded.emit(self, global_position)

func _draw() -> void:
	if kind == "boulder":
		draw_circle(Vector2(3, 5), 35, Color(0, 0, 0, 0.20))
		draw_circle(Vector2.ZERO, 34, Color("#343e49"))
		draw_circle(Vector2(-1, -2), 31, Color("#6e8090"))
		draw_colored_polygon(PackedVector2Array([Vector2(-26,-11),Vector2(-13,-28),Vector2(13,-25),Vector2(22,-12),Vector2(1,-8)]), Color("#a8bbc5"))
		draw_colored_polygon(PackedVector2Array([Vector2(-26,8),Vector2(0,17),Vector2(24,2),Vector2(19,24),Vector2(-4,29)]), Color("#4e5f70"))
		draw_polyline(PackedVector2Array([Vector2(-15,-15),Vector2(-6,-2),Vector2(-12,8),Vector2(-3,16)]),Color("#3e4c58"),2.0,true)
		for p in [Vector2(12,-4), Vector2(-18,10), Vector2(7,21)]:
			draw_circle(p, 2.5, Color("#435362"))
	else:
		draw_style_box(_box(Color("#593026"), 4), Rect2(-24,-24,48,48))
		draw_style_box(_box(Color("#bd5131"), 3), Rect2(-21,-21,42,42))
		for y in [-14,0,14]: draw_line(Vector2(-19,y),Vector2(19,y),Color("#74342a"),2,true)
		for x in [-17,17]:
			draw_line(Vector2(x,-20),Vector2(x,20),Color("#e6a45c"),5,true)
			for y in [-16,16]: draw_circle(Vector2(x,y),1.8,Color("#4f3b38"))
		draw_colored_polygon(PackedVector2Array([Vector2(0,-14),Vector2(14,0),Vector2(0,14),Vector2(-14,0)]),Color("#ffe29a"))
		draw_line(Vector2(0,-7),Vector2(0,3),Color("#773024"),3,true)
		draw_circle(Vector2(0,8),1.8,Color("#773024"))
		draw_arc(Vector2(9,-26),7,PI,TAU,12,Color("#5b4030"),3,true)
		draw_circle(Vector2(16,-26),2.5 + sin(age*9)*0.6,Color("#ffda6b"))

func _box(color: Color, radius: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(radius)
	return box
