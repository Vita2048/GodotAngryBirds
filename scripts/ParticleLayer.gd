extends Node2D

var particles: Array[Dictionary] = []
var labels: Array[Dictionary] = []
var rings: Array[Dictionary] = []

func burst(pos: Vector2, palette: Array, count: int, power := 1.0, kind := "spark") -> void:
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
	rings.append({"p":pos,"life":0.25,"power":clampf(power,12,70)})

func _process(delta: float) -> void:
	for i in range(labels.size()-1,-1,-1):
		labels[i].life -= delta
		labels[i].p.y -= delta*45
		if labels[i].life <= 0: labels.remove_at(i)
	for i in range(rings.size()-1,-1,-1):
		rings[i].life -= delta
		if rings[i].life <= 0: rings.remove_at(i)
	for i in range(particles.size() - 1, -1, -1):
		var p := particles[i]
		p.v += Vector2(0, -25.0 if p.kind == "dust" else 420.0) * delta
		p.p += p.v * delta
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
		elif p.kind == "dust":
			draw_circle(p.p,size*(2.0-alpha)*1.8,c)
		elif p.kind in ["wood","glass","stone"]:
			draw_set_transform(p.p,p.rot)
			if p.kind == "wood": draw_rect(Rect2(-size,-size*0.18,size*2,size*0.36),c)
			elif p.kind == "glass": draw_colored_polygon(PackedVector2Array([Vector2(-size,-size*0.5),Vector2(size,0),Vector2(0,size)]),c)
			else: draw_colored_polygon(PackedVector2Array([Vector2(-size*0.6,-size*0.5),Vector2(size*0.4,-size*0.6),Vector2(size*0.7,size*0.4),Vector2(-size*0.4,size*0.6)]),c)
			draw_set_transform(Vector2.ZERO)
		else:
			draw_circle(p.p, size * alpha, c)
	for ring in rings:
		var a: float = ring.life / 0.25
		draw_arc(ring.p, (1.0-a)*ring.power+5,0,TAU,32,Color(1,0.93,0.7,a),2.5,true)
	for label in labels:
		var color := Color(1,0.95,0.7,minf(1,label.life*3))
		draw_string_outline(ThemeDB.fallback_font,label.p,label.text,HORIZONTAL_ALIGNMENT_CENTER,100,22,4,Color(0.2,0.16,0.12,color.a))
		draw_string(ThemeDB.fallback_font,label.p,label.text,HORIZONTAL_ALIGNMENT_CENTER,100,22,color)
