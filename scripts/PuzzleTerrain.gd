extends StaticBody2D
## Visible terrain and its collision share the exact same authored polygon.
var outline := PackedVector2Array()
var kind := "rock"

func setup(points: PackedVector2Array, style: String) -> void:
	outline = points
	kind = style
	collision_layer = 3
	physics_material_override = PhysicsMaterial.new()
	physics_material_override.friction = 0.65
	var shape := CollisionPolygon2D.new()
	shape.polygon = outline
	add_child(shape)

func _draw() -> void:
	if outline.is_empty(): return
	draw_colored_polygon(outline, Color("#65513f") if kind == "frame" else Color("#687477"))
	var edge := outline.duplicate()
	edge.append(outline[0])
	draw_polyline(edge,Color("#39454b"),4,true)
	draw_line(outline[0]+Vector2(0,3),outline[1]+Vector2(0,3),Color("#c5c5a5"),5,true)
	# Small inset strata keep the terrain quieter than the destructible blocks.
	for i in range(1,5):
		var t := float(i)/5.0
		var left := outline[0].lerp(outline[3],t)
		var right := outline[1].lerp(outline[2],t)
		draw_line(left.lerp(right,0.12),left.lerp(right,0.88),Color(0.16,0.20,0.21,0.35),2,true)
