extends RigidBody2D

signal damaged(at_position: Vector2, material_type: String, force: float)
signal destroyed(block: Node, material_type: String, at_position: Vector2)
signal debris(at_position: Vector2, material_type: String, force: float, direction: Vector2, inherited_velocity: Vector2)

const Art := preload("res://scripts/PaintedArt.gd")
var illustrated := false
var wounds: Array[Vector2] = []
var fractures: Array[Dictionary] = []
var flash := 0.0

var material_type := "wood"
var size := Vector2(80, 20)
var health := 50.0
var max_health := 50.0
var chip_cooldown := 0.0
var spent := false
var collision_damage_enabled := true

func setup(p_material: String, p_size: Vector2, angle_radians := 0.0) -> void:
	if illustrated: material = Art.hit_material()
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


func _physics_process(delta: float) -> void:
	flash = maxf(0,flash-delta*8)
	if illustrated: material.set_shader_parameter("hit_flash", flash)
	chip_cooldown = max(0.0, chip_cooldown - delta)
	queue_redraw()

func _calc_health() -> float:
	var base: float = {"glass": 20.0, "wood": 40.0, "stone": 80.0}.get(material_type, 80.0)
	var min_side: float = max(10.0, min(size.x, size.y))
	var area: float = max(400.0, size.x * size.y)
	var hp: float = round(base * pow(min_side / 20.0, 0.9) * pow(area / 1600.0, 0.35))
	return clamp(hp, round(base * 0.6), round(base * 8.0))

# Use the strongest normal contact per step. Tangential sliding does not
# count as a head-on strike; reduced mass gives heavy objects more authority.
func impact_damage(normal_speed: float, effective_mass: float) -> float:
	var force := normal_speed * 0.075 * sqrt(clampf(effective_mass, 0.1, 4.0))
	var threshold: float = {"glass": 9.0, "wood": 16.0, "stone": 23.0}[material_type]
	return force if force > threshold else 0.0

func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	if spent or not collision_damage_enabled or chip_cooldown > 0.0: return
	var strongest := 0.0
	var point := Vector2.ZERO
	for i in state.get_contact_count():
		var body := state.get_contact_collider_object(i)
		var effective_mass := mass
		if body is RigidBody2D:
			effective_mass = mass * body.mass / (mass + body.mass)
		var normal := state.get_contact_local_normal(i).normalized()
		var relative := state.get_contact_local_velocity_at_position(i) - state.get_contact_collider_velocity_at_position(i)
		# Solver impulse recovers impact severity when the reported velocity
		# has already been resolved. Projection excludes friction impulses.
		var speed := maxf(absf(relative.dot(normal)), absf(state.get_contact_impulse(i).dot(normal)) / maxf(effective_mass, 0.01))
		var damage := impact_damage(speed, effective_mass)
		if damage > strongest:
			strongest = damage
			point = to_local(state.get_contact_local_position(i))
	if strongest > 0.0:
		chip_cooldown = 0.10
		_apply_damage(strongest, point)

func _apply_damage(damage: float, point: Vector2) -> void:
	if spent or damage <= 0.0: return
	health -= damage
	mark_hit(point, damage)
	var at := to_global(_clamp_point(point))
	damaged.emit(at, material_type, damage)
	debris.emit(at, material_type, damage, (at-global_position).normalized(), linear_velocity)
	if health <= 0.0:
		spent = true
		destroyed.emit(self, material_type, global_position)

func take_blast(damage: float, source_position: Vector2 = Vector2.INF) -> void:
	_apply_damage(damage, Vector2.ZERO if source_position == Vector2.INF else to_local(source_position))

func _clamp_point(point: Vector2) -> Vector2:
	return Vector2(clampf(point.x,-size.x*0.48,size.x*0.48),clampf(point.y,-size.y*0.48,size.y*0.48))

func mark_hit(point: Vector2, strength := 25.0) -> void:
	flash = 1.0
	point = _clamp_point(point)
	if illustrated: material.set_shader_parameter("impact_position",point)
	var nearby := false
	for wound in wounds:
		if wound.distance_to(point) < 12.0: nearby = true
	if not nearby and wounds.size() < 7: wounds.append(point)
	# Rebuild from stable seeds: existing cracks deepen and extend as health
	# falls, even once the bounded number of impact sites has been reached.
	fractures.clear()
	var severity := clampf(maxf(1.0-health/max_health, strength/max_health), 0.08, 1.0)
	for wound in wounds:
		if material_type == "wood": _make_wood_fracture(wound, severity)
		elif material_type == "glass": _make_glass_fracture(wound, severity)
		else: _make_stone_fracture(wound, severity)
	queue_redraw()

# Wood fails along the grain: one main split running from the dent toward the
# longer side (stair-stepped by alternating fiber runs and cross-grain jogs),
# a shorter counter-split, cross-grain checks around the crushed impact zone,
# and thin whiskers peeling off the main split. Cracks stay localized so
# repeated hits read as growing damage instead of full-length scratches.
func _make_wood_fracture(point: Vector2, severity: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(size.x*37+size.y*71+point.x*191+point.y*139)
	var horizontal := size.x >= size.y
	var length := maxf(size.x,size.y)
	var width := minf(size.x,size.y)
	var origin := point if horizontal else Vector2(point.y,-point.x)
	var bounds := Rect2(-Vector2(length,width)*0.48,Vector2(length,width)*0.96)
	var cracks: Array = []
	var dir := -signf(origin.x)
	if absf(origin.x) < length*0.05:
		dir = 1.0 if rng.randf() < 0.5 else -1.0
	var main_len := clampf(length*(0.16+0.42*severity),12.0,length*0.62)
	var main := _stair_crack(rng,origin,dir,main_len,bounds,1.7+2.3*severity,"main")
	_store_crack(cracks,main)
	_store_crack(cracks,_stair_crack(rng,origin,-dir,main_len*rng.randf_range(0.25,0.45),bounds,1.2+1.4*severity,"main"))
	var check_count := 1 + (1 if severity > 0.45 else 0)
	for c in check_count:
		var start := (origin+Vector2(rng.randf_range(-4.0,4.0)*dir,rng.randf_range(-3.0,3.0))).clamp(bounds.position,bounds.end)
		var heading := Vector2(0,1.0 if rng.randf() < 0.5 else -1.0).rotated(rng.randf_range(-0.3,0.3))
		var pts := PackedVector2Array([start])
		var cursor := start
		for j in 3:
			cursor += heading*rng.randf_range(1.5,3.5)+Vector2(rng.randf_range(-1.0,1.0),0)
			cursor = cursor.clamp(bounds.position,bounds.end)
			pts.append(cursor)
		_store_crack(cracks,{"points":pts,"w0":0.9+0.7*severity,"w1":0.35,"kind":"check"})
	var joints: PackedVector2Array = main["points"]
	var whiskers := 2 + (1 if severity > 0.6 else 0)
	for w in whiskers:
		if joints.size() < 3: break
		var base := joints[rng.randi_range(1,joints.size()-2)]
		var wdir := (Vector2(-dir,0)+Vector2(0,1.0 if rng.randf() < 0.5 else -1.0)).normalized()
		var wpts := PackedVector2Array([base])
		var wc := base
		for j in 3:
			wc += wdir*rng.randf_range(1.2,2.6)+Vector2(rng.randf_range(-0.6,0.6),rng.randf_range(-0.6,0.6))
			wc = wc.clamp(bounds.position,bounds.end)
			wpts.append(wc)
		_store_crack(cracks,{"points":wpts,"w0":0.8,"w1":0.3,"kind":"whisker"})
	fractures.append({"cracks":cracks,"strength":severity,"origin":origin,"bruise":Vector2(5.0+7.0*severity,2.6+2.6*severity)})

# The ribbon fill is validated once here (never per-frame): hairpin miters in
# extreme clamped cases fall back to layered strokes, which always render.
func _store_crack(cracks: Array, crack: Dictionary) -> void:
	var pts: PackedVector2Array = crack["points"]
	crack["solid"] = pts.size() >= 2 and not Geometry2D.triangulate_polygon(_ribbon(pts,float(crack["w0"]),float(crack["w1"]))).is_empty()
	cracks.append(crack)

# One stair-stepped run along the grain: mostly fiber-direction steps with an
# occasional cross-grain jog where the split jumps to the next fiber bundle.
func _stair_crack(rng: RandomNumberGenerator, start: Vector2, dir: float, total_len: float, bounds: Rect2, w0: float, kind: String) -> Dictionary:
	var steps := 9
	var pts := PackedVector2Array([start])
	var cursor := start
	for i in steps:
		cursor += Vector2(dir*(total_len/float(steps))*rng.randf_range(0.8,1.2),rng.randf_range(-1.3,1.3))
		if rng.randf() < 0.24:
			cursor.y += signf(rng.randf_range(-1.0,1.0))*rng.randf_range(2.0,4.5)
		cursor = cursor.clamp(bounds.position,bounds.end)
		pts.append(cursor)
	return {"points":pts,"w0":w0,"w1":0.45,"kind":kind}

func _make_glass_fracture(point: Vector2, severity: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(size.x*37+size.y*71+point.x*191+point.y*139)+41
	var horizontal := size.x >= size.y
	var length := maxf(size.x,size.y)
	var width := minf(size.x,size.y)
	var origin := point if horizontal else Vector2(point.y,-point.x)
	var bounds := Rect2(-Vector2(length,width)*0.48,Vector2(length,width)*0.96)
	var cracks: Array = []
	# Glass radiates fine, asymmetric fractures from the contact point.
	for ray in 6:
		var angle := float(ray)*TAU/6+rng.randf_range(-0.35,0.35)
		var path := PackedVector2Array([origin])
		var cursor := origin
		for j in 5:
			cursor += Vector2.from_angle(angle+rng.randf_range(-0.25,0.25))*rng.randf_range(3,9)*(0.35+severity*1.3)
			cursor = cursor.clamp(bounds.position,bounds.end)
			path.append(cursor)
		cracks.append({"points":path,"w0":0.6+severity,"w1":0.35,"kind":"ray"})
		cracks.append({"points":PackedVector2Array([path[2],(path[2]+Vector2.from_angle(angle+0.7)*8).clamp(bounds.position,bounds.end)]),"w0":0.7,"w1":0.3,"kind":"ray"})
	# Short bridges connect adjacent rays into a shattered pane network.
	for ray in range(1, 6):
		var previous: PackedVector2Array = cracks[(ray-1)*2]["points"]
		var current: PackedVector2Array = cracks[ray*2]["points"]
		cracks.append({"points":PackedVector2Array([previous[2],current[2]]),"w0":0.5+severity*0.5,"w1":0.3,"kind":"bridge"})
	fractures.append({"cracks":cracks,"strength":severity,"origin":origin,"bruise":Vector2(3.0,2.2)})

func _make_stone_fracture(point: Vector2, severity: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(point.x*191+point.y*139+size.x*37+size.y*71)
	var cracks: Array = []
	for ray in 3:
		var pts := PackedVector2Array([point])
		var cursor := point
		var direction := Vector2.from_angle(float(ray)*TAU/3.0+rng.randf_range(-0.5,0.5))
		for step in 5:
			cursor = _clamp_point(cursor+direction.rotated(rng.randf_range(-0.6,0.6))*rng.randf_range(4,12)*(0.3+severity))
			pts.append(cursor)
		cracks.append({"points":pts,"w0":1.0+severity*2.5,"w1":0.4,"kind":"stone"})
	fractures.append({"cracks":cracks,"strength":severity,"origin":point})

func _draw_stone_damage() -> void:
	for fracture in fractures:
		var severity: float = fracture["strength"]
		for crack in fracture["cracks"]:
			var pts: PackedVector2Array = crack["points"]
			draw_polyline(pts,Color(0.15,0.19,0.22,0.9),crack["w0"],true)
			var lip := PackedVector2Array()
			for p in pts: lip.append(p+Vector2(0,1.2))
			draw_polyline(lip,Color(0.80,0.84,0.82,0.7),0.8,true)
		var hit: Vector2 = fracture["origin"]
		var corner := Vector2(signf(hit.x)*size.x*0.5,signf(hit.y)*size.y*0.5)
		var chip := minf(9.0, minf(size.x,size.y)*0.3)*severity
		if hit.distance_to(corner) < 22.0:
			draw_colored_polygon(PackedVector2Array([corner,corner-Vector2(signf(hit.x)*chip,0),corner-Vector2(0,signf(hit.y)*chip)]),Color("#56616b"))

func _draw() -> void:
	if illustrated and material_type in ["wood","glass"]:
		_draw_painted()
		if get_meta("puzzle_id", "") in ["stopper", "counterweight_release"]:
			# Pale cuts mark the release timber even before the first hit.
			draw_line(Vector2(-size.x*0.5,-7),Vector2(size.x*0.15,0),Color("#ffe0a0"),3,true)
			draw_line(Vector2(size.x*0.5,7),Vector2(-size.x*0.15,0),Color("#ffe0a0"),3,true)
		return
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
	if material_type == "stone":
		_draw_stone_damage()
	elif ratio < 0.7:
		var points := PackedVector2Array([Vector2(-size.x*0.35,-size.y*0.35),Vector2(-size.x*0.08,size.y*0.1),Vector2(size.x*0.12,-size.y*0.1),Vector2(size.x*0.3,size.y*0.38)])
		draw_polyline(points,edge,1.8,true)

# Tapered ribbon around a crack centerline: wide at the impact end, hairline
# at the tip. Gives splits a torn interior instead of a uniform scratch.
func _ribbon(points: PackedVector2Array, w0: float, w1: float) -> PackedVector2Array:
	var clean := PackedVector2Array()
	for p in points:
		if clean.is_empty() or clean[clean.size()-1].distance_to(p) > 0.5:
			clean.append(p)
	points = clean
	var n := points.size()
	if n < 2: return PackedVector2Array()
	var total := 0.0
	var cum: Array[float] = [0.0]
	for i in range(1,n):
		total += points[i].distance_to(points[i-1])
		cum.append(total)
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	for i in n:
		var d := points[mini(i+1,n-1)] - points[maxi(i-1,0)]
		if d.length() < 0.001: d = Vector2.RIGHT
		var normal := Vector2(-d.y,d.x).normalized()
		var w := lerpf(w0,w1,cum[i]/maxf(total,0.001))*0.5
		left.append(points[i]+normal*w)
		right.append(points[i]-normal*w)
	var poly := PackedVector2Array()
	poly.append_array(left)
	for i in range(n-1,-1,-1): poly.append(right[i])
	return poly

func _draw_bruise(center: Vector2, radii: Vector2, outer: Color, core: Color) -> void:
	var poly := PackedVector2Array()
	for i in 12:
		var a := TAU*float(i)/12.0
		poly.append(center+Vector2(cos(a)*radii.x,sin(a)*radii.y))
	draw_colored_polygon(poly,outer)
	var inner := PackedVector2Array()
	for p in poly: inner.append(center+(p-center)*0.55)
	draw_colored_polygon(inner,core)

func _draw_wood_crack(crack: Dictionary) -> void:
	var pts: PackedVector2Array = crack["points"]
	if pts.size() < 2: return
	var w0 := float(crack["w0"])
	if bool(crack.get("solid",false)):
		draw_colored_polygon(_ribbon(pts,w0,float(crack["w1"])),Color(0.15,0.065,0.02,0.92))
	else:
		draw_polyline(pts,Color(0.15,0.065,0.02,0.9),w0,true)
	draw_polyline(pts,Color(0.08,0.03,0.01,0.95),maxf(0.8,w0*0.35),true)
	# Torn fibers catch the light along the upper lip of the split.
	var lip := PackedVector2Array()
	for p in pts: lip.append(p+Vector2(0,w0*0.28+0.5))
	draw_polyline(lip,Color(0.97,0.74,0.42,0.5),0.7,true)
	# Short fiber-break ticks across the main split sell the tear.
	if String(crack["kind"]) == "main":
		var side := 1.0
		for i in range(1,pts.size()-1):
			if i % 2 == 0:
				var d := pts[mini(i+1,pts.size()-1)]-pts[i-1]
				if d.length() < 0.01: continue
				var nrm := Vector2(-d.y,d.x).normalized()*side
				draw_line(pts[i],pts[i]+nrm*(2.0 if side > 0.0 else 2.6),Color(0.97,0.76,0.45,0.45),0.8,true)
				side = -side

func _draw_glass_crack(crack: Dictionary) -> void:
	# Fine radiating lines: lines cannot fail triangulation no matter how the
	# ray bounces along the beam bounds.
	var pts: PackedVector2Array = crack["points"]
	if pts.size() < 2: return
	draw_polyline(pts,Color(0.12,0.43,0.53,0.55),float(crack["w0"])+0.6,true)
	draw_polyline(pts,Color(0.91,1,1,0.88),0.65,true)

func _draw_painted() -> void:
	var horizontal := size.x >= size.y
	var length := maxf(size.x,size.y)
	var width := minf(size.x,size.y)
	if not horizontal: draw_set_transform(Vector2.ZERO,PI/2)
	Art.paint(self,material_type,Rect2(-length*0.5,-width*0.5,length,width),Color.WHITE.lerp(Color("#ffe9bf"),flash*0.6))
	for fracture in fractures:
		if material_type == "wood":
			_draw_bruise(fracture["origin"],fracture["bruise"],Color(0.23,0.11,0.04,0.32),Color(0.13,0.055,0.02,0.5))
			for crack in fracture["cracks"]:
				_draw_wood_crack(crack)
		else:
			_draw_bruise(fracture["origin"],fracture["bruise"],Color(0.75,0.95,1.0,0.30),Color(1,1,1,0.5))
			for crack in fracture["cracks"]:
				_draw_glass_crack(crack)
	draw_set_transform(Vector2.ZERO)
