extends SceneTree

func _initialize() -> void:
	var scene: Node = load("res://scenes/Main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	scene.load_level(0)
	await create_timer(1.0).timeout
	quit()
