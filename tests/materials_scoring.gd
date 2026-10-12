extends SceneTree

var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		push_error(message)
		failures += 1

func _initialize() -> void:
	var game = load("res://scenes/Main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.load_level(0)
	var victim = game.pigs[0]
	game._on_pig_popped(victim, victim.position)
	game._on_pig_popped(victim, victim.position)
	check(game.attempt_score == 50, "Pig scored twice")
	game._finish_attempt(true)
	var bank: int = game.score
	check(bank == 550, "Unused bird bonus excluded slingshot or counted incorrectly")
	check(game.result_destruction_score == 50 and game.result_bonus == 500 and game.result_level_score == 550, "Win breakdown does not add up")
	check(game._displayed_total() == 0, "Transfer did not start from previous total")
	game.result_elapsed = 1.2
	check(game._displayed_total() > 0 and game._displayed_total() < bank, "Transfer did not animate total")
	game.result_elapsed = 2.0
	check(game._displayed_total() == bank, "Transfer did not reach committed total")
	game._finish_attempt(true)
	check(game.score == bank, "Win awarded twice")
	game._award_points(7)
	check(game.score == bank, "Late points changed win result")
	game.load_level(1)
	for retry in 3:
		game._award_points(57)
		game._finish_attempt(false)
		check(game.score == bank and game.attempt_score == 0, "Failed attempt was banked")
		check(game.result_level_score == 57 and game._displayed_total() == bank, "Loss did not retain level score with unchanged total")
		game._award_points(50)
		check(game.score == bank, "Late points changed loss result")
		game.load_level(1)
		check(game.score == bank and game.attempt_score == 0, "Retry retained attempt points")
		check(game.result_level_score == 0 and game.result_bonus == 0, "Retry retained result presentation")
	game._award_points(7)
	game.load_level(1)
	check(game.score == bank, "Restart retained unfinished attempt")
	# Every scoring path uses the same reduced units, including falling pigs.
	var fallen = game.pigs[0]
	fallen.position.y = 1100
	game._cleanup_fallen()
	check(game.attempt_score == 50, "Fallen pig did not award 50")
	game._on_pig_popped(fallen, Vector2.ZERO)
	check(game.attempt_score == 50, "Fallen pig scored twice")
	var destroyed_block = game.blocks[0]
	game._on_block_destroyed(destroyed_block, destroyed_block.material_type, destroyed_block.position)
	check(game.attempt_score == 57, "Block did not award 7")
	check(game.fx.labels.back().text == "+7", "Block popup differs from awarded points")
	var crate = load("res://scripts/SpecialProp.gd").new()
	crate.position = Vector2(2500,300)
	crate.setup("crate")
	game.world_root.add_child(crate)
	game.props.append(crate)
	game._resolve_explosion(crate, crate.position)
	check(game.attempt_score == 67, "Crate did not award 10")
	check(game.fx.labels.back().text == "+10", "Crate popup differs from awarded points")
	game.load_level(1)
	# An old delayed result must not finish a newly loaded attempt.
	game.pigs.clear()
	game._check_win_lose()
	game.load_level(1)
	await create_timer(1.2).timeout
	check(game.game_state == "PLAYING", "Stale result timer ended new attempt")
	game.load_level(0)
	check(game.score == 0 and game.level_start_score == 0, "New campaign did not reset")
	for level in 5:
		game.load_level(level)
		await create_timer(2.0).timeout
		check(game.game_state == "PLAYING", "Untouched level ended: %d" % level)
		check(game.attempt_score == 0, "Untouched level scored: %d" % level)
		for block in game.blocks:
			check(block.health == block.max_health, "Settling damaged %s on level %d" % [block.material_type, level])
		game.drag_bird.position = game.SLING - Vector2(80, 30)
		game.is_dragging = true
		game._handle_release()
		for block in game.blocks: check(block.collision_damage_enabled, "Launch did not arm block damage")
		await create_timer(3.0).timeout
	var Block = load("res://scripts/BreakableBlock.gd")
	for kind in ["wood", "glass", "stone"]:
		var block = Block.new()
		block.illustrated = true
		block.setup(kind, Vector2(180,40))
		check(block.impact_damage(500, 2.0) > block.impact_damage(500, 0.2), "Mass has no effect: "+kind)
		check(block.impact_damage(15, 2.0) == 0, "Gentle contact damages: "+kind)
		root.add_child(block)
		block.freeze = true
		block.take_blast(block.max_health*0.12, block.to_global(Vector2(-25,0)))
		var first: float = block.fractures[0].strength
		for hit in 9: block.take_blast(block.max_health*0.06, block.to_global(Vector2(-25,0)))
		check(block.fractures[0].strength > first, "Repeated hits did not deepen cracks: "+kind)
		check(block.wounds.size() == 1, "Nearby hits did not grow existing wound: "+kind)
		check(block.fractures.size() <= 7, "Unbounded fracture count")
		block.queue_free()
	# Physical projectile impacts exercise the contact callback and solver data.
	var strike_damage: Array[float] = []
	for projectile_mass in [0.2, 3.0]:
		var target = Block.new()
		target.setup("wood", Vector2(80,80))
		target.position = Vector2(2000,200)
		target.gravity_scale = 0
		root.add_child(target)
		var projectile := RigidBody2D.new()
		projectile.mass = projectile_mass
		projectile.gravity_scale = 0
		projectile.position = Vector2(1860,200)
		var col := CollisionShape2D.new()
		var shape := CircleShape2D.new()
		shape.radius = 15
		col.shape = shape
		projectile.add_child(col)
		projectile.linear_velocity = Vector2(600,0)
		root.add_child(projectile)
		await create_timer(0.35).timeout
		check(target.health < target.max_health, "Physical strike caused no damage")
		strike_damage.append(target.max_health-target.health)
		target.queue_free()
		projectile.queue_free()
		await process_frame
	check(strike_damage[1] > strike_damage[0]*1.5, "Heavy physical strike was not stronger than light strike")
	game.queue_free()
	await create_timer(2).timeout
	print("MATERIAL AND SCORING TESTS: ", "PASS" if failures == 0 else "FAIL (%d)" % failures)
	quit(failures)
