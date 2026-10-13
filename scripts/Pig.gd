extends RigidBody2D

signal damaged(at_position: Vector2, force: float)
signal popped(pig: Node, at_position: Vector2)

const Art := preload("res://scripts/PaintedArt.gd")
var illustrated := false
var gaze := Vector2(-0.6,0)
var clock := 1.2
var flash := 0.0
var recoil := 0.0

var radius := 25.0
var health := 35.0
var spent := false
var collision_damage_enabled := true
var hit_cooldown := 0.0

func setup(p_radius: float) -> void:
	if illustrated: material = Art.hit_material()
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

func _physics_process(_delta: float) -> void:
	hit_cooldown = maxf(0.0, hit_cooldown - _delta)
	clock += _delta
	flash = maxf(0,flash-_delta*6)
	if illustrated: material.set_shader_parameter("hit_flash", flash)
	recoil = maxf(0,recoil-_delta*4)
	queue_redraw()

func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	if spent or not collision_damage_enabled or hit_cooldown > 0.0: return
	# Contact velocities can already be resolved when body_entered fires.
	# Use the normal solver impulse too, so a falling roof can actually crush a pig.
	var force := 0.0
	for i in state.get_contact_count():
		var body := state.get_contact_collider_object(i)
		var effective_mass := mass
		if body is RigidBody2D and not body.freeze:
			effective_mass = mass * body.mass / (mass + body.mass)
		var normal := state.get_contact_local_normal(i).normalized()
		var relative := state.get_contact_local_velocity_at_position(i) - state.get_contact_collider_velocity_at_position(i)
		var speed := maxf(absf(relative.dot(normal)), absf(state.get_contact_impulse(i).dot(normal)) / maxf(effective_mass, 0.01))
		force = maxf(force, speed * 0.08 * sqrt(effective_mass))
	if force > 16.0:
		hit_cooldown = 0.12
		flash = 1
		recoil = 0.3
		health -= force
		damaged.emit(global_position, force)
	if health <= 0.0:
		spent = true
		popped.emit(self, global_position)

func _draw() -> void:
	var hurt: float = clamp(1.0 - health / 35.0, 0.0, 1.0)
	if illustrated:
		draw_set_transform(Vector2.ZERO,0,Vector2(1+recoil*0.22,1-recoil*0.17))
		Art.paint(self,"pig",Rect2(-radius*1.10,-radius*1.43,radius*2.2,radius*2.47),Color.WHITE.lerp(Color("#ffd1c0"),hurt*0.22+flash*0.3))
		Art.face(self,radius,true,gaze,hurt,clock)
		draw_set_transform(Vector2.ZERO)
		return
	draw_circle(Vector2(4, 5), radius * 1.06, Color(0, 0, 0, 0.20))
	draw_circle(Vector2.ZERO, radius + 2.0, Color("#34532c"))
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
	draw_arc(Vector2(-2,-2), radius*0.76, 3.6, 4.8, 20, Color(0.85,1,0.6,0.5), 3, true)
	draw_circle(Vector2(-radius*0.55,-radius*0.72),radius*0.15,Color("#467c32"))
	draw_circle(Vector2(radius*0.55,-radius*0.72),radius*0.15,Color("#467c32"))
	draw_arc(Vector2(0,radius*0.3),radius*0.25,0.1,PI-0.1,16,Color("#315222"),2,true)
	draw_circle(Vector2(-radius*0.58,radius*0.18),radius*0.12,Color(0.95,0.7,0.45,0.35))
	if hurt > 0.15:
		draw_line(Vector2(-radius * 0.75, -radius * 0.55), Vector2(-radius * 0.05, -radius * 0.40), Color("#27421c"), 2.5)
		draw_line(Vector2(radius * 0.75, -radius * 0.55), Vector2(radius * 0.05, -radius * 0.40), Color("#27421c"), 2.5)

func take_blast(damage: float) -> void:
	if spent: return
	flash = 1
	recoil = 0.3
	health -= damage
	damaged.emit(global_position, damage)
	if health <= 0:
		spent = true
		popped.emit(self, global_position)
