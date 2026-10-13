extends SceneTree

var failures := 0

func check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		failures += 1

func _initialize() -> void:
	var scene = load("res://scenes/Main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	check(scene.audio.bank.size() == 10, "Sound bank did not initialize")
	for level in 5:
		scene.load_level(level)
		await create_timer(2.0).timeout
		check(scene.game_state == "PLAYING", "Level ended before a shot: %d" % level)
		check(scene.props.size() == scene.levels[level].props.size(), "Prop exploded during settling: %d" % level)
		for prop in scene.props:
			check(not prop.spent, "Spent prop on untouched board")
			check(prop.linear_velocity.length() < 30, "Unstable starting prop on level %d: %s" % [level, prop.linear_velocity])
	# Isolate two crates and a pig to verify chains and one-time scoring.
	scene.load_level(0)
	await create_timer(1).timeout
	for prop in scene.props: prop.queue_free()
	scene.props.clear()
	for block in scene.blocks: block.queue_free()
	scene.blocks.clear()
	for pig in scene.pigs: pig.queue_free()
	scene.pigs.clear()
	await process_frame
	for x in [900, 960]:
		var prop = load("res://scripts/SpecialProp.gd").new()
		prop.position = Vector2(x,656)
		prop.setup("crate")
		prop.exploded.connect(scene._on_exploded)
		scene.world_root.add_child(prop)
		scene.props.append(prop)
	var pig = load("res://scripts/Pig.gd").new()
	pig.position = Vector2(1020,650)
	pig.setup(25)
	pig.popped.connect(scene._on_pig_popped)
	scene.world_root.add_child(pig)
	scene.pigs.append(pig)
	var before: int = scene.score
	scene.props[0].detonate()
	scene.props[0].detonate()
	await create_timer(0.2).timeout
	check(scene.props.is_empty(), "Explosion did not chain")
	check(scene.pigs.is_empty(), "Explosion did not damage nearby pig")
	check(scene.score-before == 70, "Explosion scored twice or incorrectly: %d" % (scene.score-before))
	check(scene.fx.particles.size() <= 500, "Particle cap exceeded")
	await create_timer(1.1).timeout
	check(scene.game_state == "WIN", "Chain reaction did not complete the level")
	# A moving boulder must trigger a real physical impact on a crate.
	scene.load_level(0)
	await create_timer(1).timeout
	# Campaign layouts no longer contain props; create the collision fixture.
	var target = load("res://scripts/SpecialProp.gd").new()
	target.setup("crate")
	# Keep this isolated collision fixture beyond the campaign structures.
	target.position = Vector2(1800,646)
	target.exploded.connect(scene._on_exploded)
	scene.world_root.add_child(target)
	scene.props.append(target)
	await create_timer(0.8).timeout # Allow the crate's spawn protection to expire.
	var boulder = load("res://scripts/SpecialProp.gd").new()
	boulder.setup("boulder")
	boulder.position = Vector2(1880,646)
	boulder.linear_velocity = Vector2(-500,0)
	scene.world_root.add_child(boulder)
	scene.props.append(boulder)
	await create_timer(0.7).timeout
	check(not is_instance_valid(target) or target.spent, "Rolling boulder did not detonate crate")
	scene.queue_free()
	await process_frame
	# Let outstanding level-result timers finish before closing the test tree.
	await create_timer(1.2).timeout
	print("ENHANCEMENT TESTS: ", "PASS" if failures == 0 else "FAIL (%d)" % failures)
	quit(failures)
