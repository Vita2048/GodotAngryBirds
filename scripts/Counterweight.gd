extends RigidBody2D
## One rigid assembly on a real pin joint. The breakable timber releases it.
const Art := preload("res://scripts/PaintedArt.gd")
var released := false

func _ready() -> void:
	mass = 8.0
	center_of_mass_mode = RigidBody2D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector2(-105,-22)
	angular_damp = 0.35
	continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE
	freeze = true
	_add_shape(Vector2.ZERO,Vector2(340,20))
	_add_shape(Vector2(-140,-38),Vector2(58,56))
	physics_material_override = PhysicsMaterial.new()
	physics_material_override.friction = 0.8
	var anchor := StaticBody2D.new()
	get_parent().add_child(anchor)
	anchor.global_position = global_position
	var pin := PinJoint2D.new()
	get_parent().add_child(pin)
	pin.global_position = global_position
	pin.node_a = pin.get_path_to(anchor)
	pin.node_b = pin.get_path_to(self)
	pin.angular_limit_enabled = true
	pin.angular_limit_lower = -1.1
	pin.angular_limit_upper = 1.1

func _add_shape(at: Vector2, dimensions: Vector2) -> void:
	var shape := RectangleShape2D.new()
	shape.size = dimensions
	var collider := CollisionShape2D.new()
	collider.position = at
	collider.shape = shape
	add_child(collider)

func release() -> void:
	if released: return
	released = true
	freeze = false
	sleeping = false

func _draw() -> void:
	Art.paint(self,"wood",Rect2(-170,-10,340,20))
	Art.paint(self,"boulder",Rect2(-172,-70,64,64))
	for x in [-157,-126]:
		draw_line(Vector2(x,-63),Vector2(x,9),Color("#4c4341"),5,true)
		draw_line(Vector2(x-1,-62),Vector2(x-1,8),Color("#b6ada0"),1,true)
	draw_circle(Vector2.ZERO,12,Color("#374450"))
	draw_circle(Vector2.ZERO,8,Color("#d6b968"))
	draw_circle(Vector2(-2,-2),3,Color("#fff0b0"))
