extends Node2D

var particles: Array[Dictionary] = []

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

func _process(delta: float) -> void:
	for i in range(particles.size() - 1, -1, -1):
		var p := particles[i]
		p.v += Vector2(0, 420.0) * delta
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
		else:
			draw_circle(p.p, size * alpha, c)
