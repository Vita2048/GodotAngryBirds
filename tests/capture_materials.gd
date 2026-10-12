extends SceneTree

func label_at(text: String, position: Vector2, font_size := 24) -> void:
	var label := Label.new()
	label.text = text
	label.position = position
	label.add_theme_font_size_override("font_size",font_size)
	root.add_child(label)

func _initialize() -> void:
	root.size = Vector2i(1280,720)
	RenderingServer.set_default_clear_color(Color("#354751"))
	label_at("MATERIAL DAMAGE  /  impact-driven progressive fractures", Vector2(50,30),30)
	for col in 3:
		label_at(["LIGHT DAMAGE", "WEAKENED", "NEAR BREAKING"][col],Vector2(230+col*340,105),20)
	for row in 3:
		var kind: String = ["wood","glass","stone"][row]
		label_at(kind.to_upper(),Vector2(45,200+row*170),22)
		for col in 3:
			var block = load("res://scripts/BreakableBlock.gd").new()
			block.illustrated = true
			block.setup(kind, Vector2(245,65))
			block.position = Vector2(345+col*340,225+row*170)
			root.add_child(block)
			block.freeze = true
			block.take_blast(block.max_health*[0.12,0.48,0.86][col], block.to_global(Vector2(-55,-10)))
	await create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/material-damage-preview.png")
	quit()
