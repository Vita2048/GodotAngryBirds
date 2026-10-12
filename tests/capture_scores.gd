extends SceneTree

func capture(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_jpg("res://tests/score-"+name+".jpg", 0.9)

func _initialize() -> void:
	root.size = Vector2i(1280,720)
	var game = load("res://scenes/Main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.load_level(1)
	game.level_start_score = 550
	game._award_points(157)
	await create_timer(1.0).timeout
	game.set_process(false)
	await capture("hud")
	game._finish_attempt(true)
	game.result_elapsed = 1.2
	game.ui.queue_redraw()
	await capture("transfer")
	game.result_elapsed = 2.0
	game.ui.queue_redraw()
	await capture("win")
	game.load_level(1)
	game._award_points(57)
	game._finish_attempt(false)
	game.ui.queue_redraw()
	await capture("loss")
	quit()
