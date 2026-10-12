extends Node2D

const Art := preload("res://scripts/PaintedArt.gd")
const Fragment := preload("res://scripts/PaintedFragment.gd")
var illustrated := false
var blasts: Array[Dictionary] = []
var particles: Array[Dictionary] = []
var labels: Array[Dictionary] = []
var rings: Array[Dictionary] = []

func burst(pos: Vector2, palette: Array, count: int, power := 1.0, kind := "spark") -> void:
	if illustrated:
		natural_burst(pos,palette,mini(count,22),power,kind,Vector2.UP,Vector2.ZERO)
		return
	for i in count:
		var a := randf() * TAU
		var speed := randf_range(80.0, 260.0) * power
		particles.append({
			"p": pos + Vector2(randf_range(-6, 6), randf_range(-6, 6)),
			"v": Vector2(cos(a), sin(a)) * speed + Vector2(0, randf_range(-95, -10)),
			"life": randf_range(0.55, 1.25),
			"max": 1.25,
			"size": randf_range(3.0, 10.0),
			"color": palette.pick_random(),
			"rot": randf() * TAU,
			"rv": randf_range(-7.0, 7.0),
			"kind": kind
		})
	if particles.size() > 500:
		particles = particles.slice(-500)
	queue_redraw()

func confetti(rect: Rect2) -> void:
	var palette := [Color("#ff4151"), Color("#ffd447"), Color("#42d4ff"), Color("#76f06d"), Color("#ffffff")]
	for i in 150:
		particles.append({
			"p": Vector2(randf_range(rect.position.x, rect.end.x), randf_range(rect.position.y - 80, rect.position.y + 80)),
			"v": Vector2(randf_range(-120, 120), randf_range(40, 240)),
			"life": randf_range(1.5, 3.0),
			"max": 3.0,
			"size": randf_range(5.0, 12.0),
			"color": palette.pick_random(),
			"rot": randf() * TAU,
			"rv": randf_range(-10.0, 10.0),
			"kind": "confetti"
		})

func score_popup(pos: Vector2, value: String) -> void:
	labels.append({"p":pos,"text":value,"life":1.1})

func impact(pos: Vector2, power: float) -> void:
	if illustrated: return
	rings.append({"p":pos,"life":0.25,"power":clampf(power,12,70)})

func natural_burst(pos: Vector2, palette: Array, count: int, power: float, kind: String, direction: Vector2, inherited: Vector2) -> void:
	var smoke := kind in ["dust","smoke"]
	for i in count:
		var spread := randf_range(-1.35,1.35)
		var axis := direction.normalized() if direction.length()>0.1 else Vector2.UP
		var velocity := axis.rotated(spread)*randf_range(30,150)*power + inherited.limit_length(500)*0.18
		if smoke: velocity = Vector2(randf_range(-32,32),randf_range(-52,-15))*power
		var life := randf_range(1.0,2.0) if smoke else randf_range(0.45,1.1)
		var shape := PackedVector2Array([Vector2(-1,-0.35),Vector2(0.6,-0.6),Vector2(1,0.1),Vector2(-0.5,0.6)])
		particles.append({"p":pos+Vector2(randf_range(-3,3),randf_range(-3,3)),"v":velocity,
			"life":life,"max":life,"size":randf_range(7,15) if smoke else randf_range(1.5,4.5),
			"color":palette.pick_random(),"rot":randf()*TAU,"rv":randf_range(-5,5),"kind":kind,"shape":shape})
	if particles.size()>500: particles = particles.slice(-500)

func surface_hit(pos: Vector2, kind: String, force: float, direction: Vector2, inherited: Vector2) -> void:
	var palette: Array = [Color("#d6a369"),Color("#94613d"),Color("#edc28a")]
	if kind == "glass": palette = [Color("#dcfaff"),Color("#8bcada"),Color("#b8e5ed")]
	if kind == "stone": palette = [Color("#9da6aa"),Color("#677579")]
	natural_burst(pos,palette,clampi(int(force/6),4,11),clampf(force/65,0.35,1.1),kind,direction,inherited)
	if kind != "glass": natural_burst(pos,[Color("#c4b092")],3,0.5,"dust",direction,inherited)

func explosion(pos: Vector2) -> void:
	blasts.append({"p":pos,"life":0.5,"duration":0.5,"angle":randf_range(-0.3,0.3)})
	natural_burst(pos,[Color("#b9a38b")],10,1.3,"smoke",Vector2.UP,Vector2.ZERO)
	natural_burst(pos,[Color("#ffd78e"),Color("#ef9d49")],18,2.2,"ember",Vector2.UP,Vector2.ZERO)

# Beams tear into two mating halves at the break plus one thin splinter;
# glass falls into a few uneven angular shards. Far fewer, chunkier and more
# believable than uniform slices. `break_bias` (-0.3..0.3 along the beam)
# puts the tear where the beam was actually hit.
func fragments(pos: Vector2, kind: String, block_size: Vector2, angle: float, inherited := Vector2.ZERO, spin := 0.0, break_bias := 0.0) -> void:
	if kind not in ["wood","glass"]: return
	var horizontal := block_size.x >= block_size.y
	var length := maxf(block_size.x,block_size.y)
	var width := minf(block_size.x,block_size.y)
	var grain_angle := angle if horizontal else angle+PI/2
	var axis := Vector2.RIGHT.rotated(grain_angle)
	var across := axis.rotated(PI/2)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(absf(pos.x)*13.7+absf(pos.y)*7.3+length*3.1+width*5.7+absf(angle)*91.0)+int(break_bias*571.0)
	if kind == "wood":
		_spawn_torn_wood(pos,axis,across,grain_angle,length,width,break_bias,inherited,spin,rng)
	else:
		_spawn_glass_shards(pos,axis,across,grain_angle,length,width,inherited,spin,rng)

func _poly_center(poly: PackedVector2Array) -> Vector2:
	var bounds := Rect2(poly[0],Vector2.ZERO)
	for p in poly: bounds = bounds.expand(p)
	return bounds.get_center()

func _place_shard(kind: String, beam_poly: PackedVector2Array, fresh_beam: PackedVector2Array, axis: Vector2, across: Vector2, grain_angle: float, pos: Vector2, launch_velocity: Vector2, launch_spin: float, index: int) -> void:
	if get_child_count() >= 35: return
	if beam_poly.size() < 3: return
	var center := _poly_center(beam_poly)
	var local := PackedVector2Array()
	for p in beam_poly: local.append(p-center)
	var local_fresh := PackedVector2Array()
	for p in fresh_beam: local_fresh.append(p-center)
	var piece := Fragment.new()
	var bounds := Rect2(local[0],Vector2.ZERO)
	for p in local: bounds = bounds.expand(p)
	piece.setup_shard(kind,local,Vector2(maxf(bounds.size.x,2.0),maxf(bounds.size.y,2.0)),index,local_fresh)
	piece.position = pos+axis*center.x+across*center.y
	piece.rotation = grain_angle
	add_child(piece)
	piece.linear_velocity = launch_velocity
	piece.angular_velocity = launch_spin

func _spawn_torn_wood(pos: Vector2, axis: Vector2, across: Vector2, grain_angle: float, length: float, width: float, break_bias: float, inherited: Vector2, spin: float, rng: RandomNumberGenerator) -> void:
	var half_l := length*0.5
	var bx := clampf(clampf(break_bias,-0.3,0.3)*length,-half_l*0.6,half_l*0.6)
	var depth := clampf(width*0.16,2.0,5.0)
	# Shared torn centerline pinned at both faces so the halves mate.
	var line := PackedVector2Array([Vector2(bx,-width*0.5)])
	var interior := clampi(int(width/6.0),2,4)
	for t in range(interior):
		var y := -width*0.5+width*float(t+1)/float(interior+1)
		line.append(Vector2(bx+rng.randf_range(-1.0,1.0)*depth,y))
	line.append(Vector2(bx,width*0.5))
	# One long fiber spike stays on the left half; the right half gets the socket.
	var spike_at := rng.randi_range(1,line.size()-2)
	var spike_len := minf(rng.randf_range(6.0,11.0),width*0.5)
	var spike_apex := line[spike_at]+Vector2(spike_len,0)
	var left := PackedVector2Array([Vector2(-half_l,-width*0.5)])
	_add_face_notch(left,Vector2(-half_l,-width*0.5),Vector2(bx,-width*0.5),1.0,rng)
	left.append(Vector2(bx,-width*0.5))
	for i in range(1,line.size()):
		if i == spike_at: left.append(spike_apex)
		left.append(line[i])
	_add_face_notch(left,Vector2(bx,width*0.5),Vector2(-half_l,width*0.5),-1.0,rng)
	left.append(Vector2(-half_l,width*0.5))
	var right := PackedVector2Array([Vector2(half_l,-width*0.5)])
	_add_face_notch(right,Vector2(half_l,-width*0.5),Vector2(bx,-width*0.5),1.0,rng)
	right.append(Vector2(bx,-width*0.5))
	for i in range(1,line.size()):
		if i == spike_at:
			right.append(line[i]+Vector2(1.0,-2.4))
			right.append(line[i]+Vector2(-1.5,0))
			right.append(line[i]+Vector2(1.0,2.4))
		else:
			right.append(line[i])
	_add_face_notch(right,Vector2(bx,width*0.5),Vector2(half_l,width*0.5),-1.0,rng)
	right.append(Vector2(half_l,width*0.5))
	var fresh_left := PackedVector2Array([Vector2(bx,-width*0.5)])
	for i in range(1,line.size()):
		if i == spike_at: fresh_left.append(spike_apex)
		fresh_left.append(line[i])
	var fresh_right := PackedVector2Array([Vector2(bx,-width*0.5)])
	for i in range(1,line.size()):
		if i == spike_at:
			fresh_right.append(line[i]+Vector2(-1.5,0))
		else:
			fresh_right.append(line[i])
	var base := inherited.limit_length(700)
	var left_center := _poly_center(left)
	var right_center := _poly_center(right)
	_place_shard("wood",left,fresh_left,axis,across,grain_angle,pos,
		base+Vector2(-left_center.y,left_center.x)*spin-axis*rng.randf_range(30.0,70.0)+Vector2(rng.randf_range(-30.0,30.0),rng.randf_range(-50.0,-10.0)),
		spin+rng.randf_range(-2.5,2.5),0)
	_place_shard("wood",right,fresh_right,axis,across,grain_angle,pos,
		base+Vector2(-right_center.y,right_center.x)*spin+axis*rng.randf_range(30.0,70.0)+Vector2(rng.randf_range(-30.0,30.0),rng.randf_range(-50.0,-10.0)),
		spin+rng.randf_range(-2.5,2.5),2)
	# One thin sliver peels off near the tear on longer beams.
	if length >= 50.0 and width >= 9.0:
		var sl := clampf(length*rng.randf_range(0.22,0.34),10.0,38.0)
		var sw := rng.randf_range(2.0,3.2)
		var sliver := PackedVector2Array([Vector2(-sl*0.5,-sw*0.4),Vector2(0,-sw*0.5),Vector2(sl*0.5,0),Vector2(0,sw*0.5),Vector2(-sl*0.5,sw*0.4)])
		var at := Vector2(bx+rng.randf_range(-0.15,0.15)*length,rng.randf_range(-0.25,0.25)*width)
		var tilt := rng.randf_range(-0.4,0.4)
		var piece := Fragment.new()
		if get_child_count() < 35:
			var bounds := Rect2(sliver[0],Vector2.ZERO)
			for p in sliver: bounds = bounds.expand(p)
			piece.setup_shard("wood",sliver,Vector2(sl,sw*2.0),4,sliver)
			piece.position = pos+axis*at.x+across*at.y
			piece.rotation = grain_angle+tilt
			add_child(piece)
			piece.linear_velocity = inherited.limit_length(700)*0.3+axis*rng.randf_range(-140.0,140.0)+Vector2(0,rng.randf_range(-90.0,-30.0))
			piece.angular_velocity = spin*1.5+rng.randf_range(-6.0,6.0)

# Small dent along an outer face so surviving edges are not laser-straight.
func _add_face_notch(poly: PackedVector2Array, from: Vector2, to: Vector2, normal_dir: float, rng: RandomNumberGenerator) -> void:
	if from.distance_to(to) < 12.0: return
	var mid := (from+to)*0.5+Vector2(rng.randf_range(-2.0,2.0),normal_dir*rng.randf_range(0.8,1.8))
	poly.append(mid)

func _spawn_glass_shards(pos: Vector2, axis: Vector2, across: Vector2, grain_angle: float, length: float, width: float, inherited: Vector2, spin: float, rng: RandomNumberGenerator) -> void:
	var fracs: Array[float] = []
	fracs.assign([0.32,0.65] if length < 70.0 else [0.24,0.47,0.71])
	for i in fracs.size(): fracs[i] = clampf(fracs[i]+rng.randf_range(-0.035,0.035),0.12,0.88)
	fracs.sort()
	var tops: Array[float] = []
	var bottoms: Array[float] = []
	for f in fracs:
		tops.append((f-0.5)*length+rng.randf_range(-3.0,3.0))
		bottoms.append((f-0.5)*length+rng.randf_range(-3.0,3.0))
	var half_l := length*0.5
	var half_w := width*0.5
	var cols := fracs.size()+1
	var split_col := rng.randi_range(0,cols-1) if width >= 12.0 and cols >= 3 else -1
	var idx := 0
	for c in range(cols):
		var left_top: float = tops[c-1] if c > 0 else -half_l
		var right_top: float = tops[c] if c < tops.size() else half_l
		var left_bot: float = bottoms[c-1] if c > 0 else -half_l
		var right_bot: float = bottoms[c] if c < bottoms.size() else half_l
		var jit := func(v: Vector2) -> Vector2: return v+Vector2(rng.randf_range(-1.2,1.2),rng.randf_range(-1.2,1.2))
		if c == split_col:
			var d0 := Vector2(lerpf(left_top,right_top,0.35),-half_w)
			var d1 := Vector2(lerpf(left_bot,right_bot,0.7),half_w)
			var tl: Vector2 = jit.call(Vector2(left_top,-half_w))
			var tr: Vector2 = jit.call(Vector2(right_top,-half_w))
			var br: Vector2 = jit.call(Vector2(right_bot,half_w))
			var bl: Vector2 = jit.call(Vector2(left_bot,half_w))
			_launch_glass(pos,axis,across,grain_angle,PackedVector2Array([tl,tr,d1,d0]),PackedVector2Array([tr,d1,d0]),inherited,spin,rng,idx); idx += 1
			_launch_glass(pos,axis,across,grain_angle,PackedVector2Array([d0,d1,br,bl]),PackedVector2Array([d0,d1]),inherited,spin,rng,idx); idx += 1
		else:
			var quad := PackedVector2Array([
				jit.call(Vector2(left_top,-half_w)),jit.call(Vector2(right_top,-half_w)),
				jit.call(Vector2(right_bot,half_w)),jit.call(Vector2(left_bot,half_w))])
			_launch_glass(pos,axis,across,grain_angle,quad,PackedVector2Array([quad[3],quad[0]]),inherited,spin,rng,idx); idx += 1

func _launch_glass(pos: Vector2, axis: Vector2, across: Vector2, grain_angle: float, quad: PackedVector2Array, fresh: PackedVector2Array, inherited: Vector2, spin: float, rng: RandomNumberGenerator, idx: int) -> void:
	var center := _poly_center(quad)
	var away := (axis*center.x+across*center.y)
	if away.length() > 0.5: away = away.normalized()
	_place_shard("glass",quad,fresh,axis,across,grain_angle,pos,
		inherited.limit_length(700)*0.2+away*rng.randf_range(40.0,120.0)+Vector2(rng.randf_range(-30.0,30.0),rng.randf_range(-70.0,-20.0)),
		spin+rng.randf_range(-3.0,6.5) if rng.randf() < 0.5 else spin+rng.randf_range(-6.5,3.0),idx)

func _process(delta: float) -> void:
	for i in range(blasts.size()-1,-1,-1):
		blasts[i].life -= delta
		if blasts[i].life <= 0: blasts.remove_at(i)
	for i in range(labels.size()-1,-1,-1):
		labels[i].life -= delta
		labels[i].p.y -= delta*45
		if labels[i].life <= 0: labels.remove_at(i)
	for i in range(rings.size()-1,-1,-1):
		rings[i].life -= delta
		if rings[i].life <= 0: rings.remove_at(i)
	for i in range(particles.size() - 1, -1, -1):
		var p := particles[i]
		if illustrated:
			if p.kind in ["dust","smoke"]:
				p.v = p.v.lerp(Vector2(8,-18),minf(1,delta*1.3))
			else:
				p.v += Vector2(0,780)*delta
				p.v *= exp(-delta*0.5)
		else: p.v += Vector2(0, -25.0 if p.kind in ["dust","smoke"] else 420.0) * delta
		p.p += p.v * delta
		if illustrated and p.kind not in ["dust","smoke","confetti"] and p.p.y > 678:
			p.p.y = 678
			p.v.y = -absf(p.v.y)*0.20
			p.v.x *= 0.65
			p.rv *= 0.55
		p.rot += p.rv * delta * 0.5 # Slower rotation
		p.life -= delta
		particles[i] = p
		if p.life <= 0.0:
			particles.remove_at(i)
	queue_redraw()

func _draw() -> void:
	for p in particles:
		var alpha: float = clamp(p.life / p.max, 0.0, 1.0)
		var c: Color = p.color
		c.a *= alpha
		var size: float = p.size
		if p.kind == "confetti":
			draw_set_transform(p.p, p.rot, Vector2.ONE)
			draw_rect(Rect2(Vector2(-size * 0.5, -size * 0.22), Vector2(size, size * 0.44)), c, true)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		elif p.kind in ["dust","smoke"]:
			if illustrated:
				var age: float = 1-alpha
				var span: float = size*(1.0+age*2.6)*(3.4 if p.kind == "smoke" else 2.0)
				var opacity: float = minf(1,age*9)*pow(alpha,1.5)*0.36
				draw_set_transform(p.p,p.rot*0.18,Vector2(1.15,0.85))
				Art.paint(self,"smoke",Rect2(-Vector2.ONE*span*0.5,Vector2.ONE*span),Color(c.r,c.g,c.b,opacity))
				draw_set_transform(Vector2.ZERO)
			else: draw_circle(p.p,size*(2.0-alpha)*1.8,c)
		elif p.kind in ["wood","glass","stone"]:
			draw_set_transform(p.p,p.rot)
			if illustrated:
				var polygon := PackedVector2Array()
				for point in p.get("shape",PackedVector2Array([Vector2(-1,0),Vector2(1,-0.5),Vector2(0,1)])):
					polygon.append(point*Vector2(size*1.6,size*(0.4 if p.kind == "wood" else 1.0)))
				draw_colored_polygon(polygon,c)
				if p.kind == "glass": draw_line(polygon[0],polygon[1],Color(1,1,1,c.a*0.85),0.7,true)
			elif p.kind == "wood": draw_rect(Rect2(-size,-size*0.18,size*2,size*0.36),c)
			elif p.kind == "glass": draw_colored_polygon(PackedVector2Array([Vector2(-size,-size*0.5),Vector2(size,0),Vector2(0,size)]),c)
			else: draw_colored_polygon(PackedVector2Array([Vector2(-size*0.6,-size*0.5),Vector2(size*0.4,-size*0.6),Vector2(size*0.7,size*0.4),Vector2(-size*0.4,size*0.6)]),c)
			draw_set_transform(Vector2.ZERO)
		else:
			if illustrated:
				var streak: Vector2 = p.v.normalized()*minf(9,p.v.length()*0.025)
				draw_line(p.p,p.p-streak,Color(c.r,c.g,c.b,alpha*0.8),maxf(0.7,size*0.35),true)
			else: draw_circle(p.p, size * alpha, c)
	if not illustrated:
		for ring in rings:
			var a: float = ring.life/0.25
			draw_arc(ring.p,(1.0-a)*ring.power+5,0,TAU,32,Color(1,0.93,0.7,a),2.5,true)
	for blast in blasts:
		var age: float = 1.0-blast.life/blast.duration
		var span: float = 45.0+sin(minf(1,age*1.4)*PI*0.5)*145.0
		draw_set_transform(blast.p+Vector2(0,-age*35),blast.angle,Vector2(1,1+age*0.25))
		Art.paint(self,"fire",Rect2(-Vector2.ONE*span*0.5,Vector2.ONE*span),Color(1,1-age*0.15,1-age*0.4,pow(1.0-age,1.3)))
		draw_set_transform(Vector2.ZERO)
	for label in labels:
		var color := Color(1,0.95,0.7,minf(1,label.life*3))
		draw_string_outline(ThemeDB.fallback_font,label.p,label.text,HORIZONTAL_ALIGNMENT_CENTER,100,22,4,Color(0.2,0.16,0.12,color.a))
		draw_string(ThemeDB.fallback_font,label.p,label.text,HORIZONTAL_ALIGNMENT_CENTER,100,22,color)
