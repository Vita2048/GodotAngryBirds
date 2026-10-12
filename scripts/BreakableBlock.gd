extends RigidBody2D

signal damaged(at_position: Vector2, material_type: String, force: float)
signal destroyed(block: Node, material_type: String, at_position: Vector2)

var material_type := "wood"
var size := Vector2(80, 20)
var health := 50.0
var max_health := 50.0
var chip_cooldown := 0.0
var spent := false

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
	if spent: return
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
		spent = true
		destroyed.emit(self, material_type, global_position)

func take_blast(damage: float) -> void:
	if spent: return
	health -= damage
	damaged.emit(global_position, material_type, damage)
	if health <= 0:
		spent = true
		destroyed.emit(self, material_type, global_position)

func _draw() -> void:
	var rect := Rect2(-size * 0.5, size)
	var ratio := clampf(health / max_health, 0, 1)
	var base: Color = {"wood":Color("#c78b48"), "stone":Color("#8996a3"), "glass":Color("#91def0", 0.68)}[material_type]
	var edge: Color = {"wood":Color("#603820"), "stone":Color("#3f4a59"), "glass":Color("#327c99")}[material_type]
	var box := StyleBoxFlat.new()
	box.bg_color = base.darkened((1.0-ratio)*0.15)
	box.border_color = edge
	box.set_border_width_all(2)
	box.set_corner_radius_all(3)
	box.shadow_color = Color(0,0,0,0.18)
	box.shadow_size = 3
	box.shadow_offset = Vector2(2,3)
	draw_style_box(box, rect)
	draw_line(rect.position+Vector2(3,3), Vector2(rect.end.x-3,rect.position.y+3), base.lightened(0.45),2,true)
	draw_line(Vector2(rect.position.x+3,rect.end.y-3),rect.end-Vector2(3,3),edge.lightened(0.1),2,true)
	if material_type == "wood":
		var horizontal := size.x > size.y
		var length := size.x if horizontal else size.y
		var width := size.y if horizontal else size.x
		if not horizontal: draw_set_transform(Vector2.ZERO, PI/2)
		for i in 3:
			var y := -width*0.5 + 5 + i*(width-10)/3.0
			var points := PackedVector2Array()
			for j in 9: points.append(Vector2(-length*0.5+5+j*(length-10)/8.0,y+sin(j*1.2+i)*1.2))
			draw_polyline(points,Color(0.38,0.20,0.08,0.38),1,true)
		draw_arc(Vector2(length*0.16,0),3,0,TAU,16,Color("#986034"),1,true)
		for x in [-length*0.5+7,length*0.5-7]:
			draw_circle(Vector2(x,0),2,Color("#604b3a"))
			draw_circle(Vector2(x-0.5,-0.6),0.8,Color("#d4bd98"))
		draw_set_transform(Vector2.ZERO)
	elif material_type == "stone":
		for i in 5:
			var point := Vector2(sin(i*13.1)*size.x*0.36,cos(i*7.3)*size.y*0.27)
			draw_line(point,point+Vector2(3,1),Color(0.2,0.26,0.33,0.35),1.5,true)
	else:
		draw_line(rect.position+Vector2(5,5),Vector2(rect.position.x+5,rect.end.y-5),Color(0.9,1,1,0.8),2,true)
		var center := Vector2.ZERO
		draw_line(center-Vector2(size.x*0.23,size.y*0.30),center+Vector2(size.x*0.23,size.y*0.30),Color(1,1,1,0.6),3,true)
	if ratio < 0.7:
		var points := PackedVector2Array([Vector2(-size.x*0.35,-size.y*0.35),Vector2(-size.x*0.08,size.y*0.1),Vector2(size.x*0.12,-size.y*0.1),Vector2(size.x*0.3,size.y*0.38)])
		draw_polyline(points,edge,1.8,true)
