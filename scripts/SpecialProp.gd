extends RigidBody2D

signal exploded(prop: Node, at: Vector2)
signal struck(at: Vector2, force: float)
const Art := preload("res://scripts/PaintedArt.gd")
var illustrated := false
var scuffs: Array[Vector2] = []
var flash := 0.0

var kind := "crate"
var armed := false
var spent := false
var age := 0.0
var cooldown := 0.0
var previous_velocity := Vector2.ZERO

func setup(type: String) -> void:
	if illustrated: material = Art.hit_material()
	kind = type
	mass = 5.0 if kind == "boulder" else 0.8
	contact_monitor = true
	max_contacts_reported = 8
	continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE
	physics_material_override = PhysicsMaterial.new()
	physics_material_override.friction = 0.65
	physics_material_override.bounce = 0.08
	if illustrated:
		physics_material_override.bounce = 0.0
		physics_material_override.friction = 0.85
		linear_damp = 0.15
		angular_damp = 1.8
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
	previous_velocity = linear_velocity
	age += delta
	flash = maxf(0,flash-delta*7)
	if illustrated: material.set_shader_parameter("hit_flash", flash)
	cooldown = maxf(0, cooldown - delta)
	armed = age > 0.7
	queue_redraw()

func _hit(body: Node) -> void:
	if not armed or spent: return
	var other := Vector2.ZERO
	if body is RigidBody2D: other = body.linear_velocity
	var speed := (linear_velocity - other).length()
	if body.get_script() == get_script():
		speed = maxf(speed,(previous_velocity-body.previous_velocity).length())
	if kind == "crate" and speed > 95.0:
		detonate()
	elif kind == "boulder" and speed > 85.0 and cooldown <= 0.0:
		flash = 1
		if scuffs.size()<6: scuffs.append(to_local(body.global_position).limit_length(25))
		cooldown = 0.18
		struck.emit(global_position, speed * 0.085)

func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	if kind != "crate" or not armed or spent: return
	# Recover the impact after collision response, including heavy rolling rocks.
	for i in state.get_contact_count():
		var body := state.get_contact_collider_object(i)
		var effective_mass := mass
		if body is RigidBody2D and not body.freeze:
			effective_mass = mass * body.mass / (mass + body.mass)
		var normal := state.get_contact_local_normal(i).normalized()
		var speed := absf(state.get_contact_impulse(i).dot(normal)) / maxf(effective_mass,0.01)
		if speed > 95.0:
			detonate()
			return

func detonate() -> void:
	if spent or kind != "crate": return
	spent = true
	exploded.emit(self, global_position)

func _draw() -> void:
	if illustrated:
		if kind == "boulder":
			Art.paint(self,"boulder",Rect2(-35,-35,70,70),Color.WHITE.lerp(Color("#fff1bd"),flash*0.5))
			for point in scuffs:
				draw_polyline(PackedVector2Array([point-Vector2(7,4),point+Vector2(0,3),point+Vector2(5,-2)]),Color("#d6e0df"),1.7,true)
		else:
			Art.paint(self,"crate",Rect2(-25,-33,50,57))
			draw_circle(Vector2(4,-31),2+sin(age*12)*0.5,Color("#ffe4a0"))
		return
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
