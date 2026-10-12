extends RigidBody2D
const Art := preload("res://scripts/PaintedArt.gd")
var material_kind := "wood"
var dimensions := Vector2(18, 8)
var lifetime := 0.0
var source := Rect2()
var outline := PackedVector2Array()
var fresh_edge := PackedVector2Array()
var uv := PackedVector2Array()

# Jagged torn shard in piece-local space (origin near the piece center).
# `fresh` marks the newly torn surface along the outline: pale exposed fibers
# on wood, bright glints on glass. Collision stays a sturdy box built from the
# bounds because the torn silhouette can be concave; it is cosmetic only.
func setup_shard(kind: String, polygon: PackedVector2Array, piece_size: Vector2, index: int, fresh: PackedVector2Array = PackedVector2Array()) -> void:
	material_kind = kind
	outline = _clean_polygon(polygon)
	fresh_edge = _clean_fresh(fresh)
	dimensions = Vector2(maxf(piece_size.x,2.0),maxf(piece_size.y,2.0))
	mass = 0.12
	collision_layer = 4
	collision_mask = 2 # Ground only: cosmetic fragments cannot destabilize targets.
	linear_damp = 0.3
	angular_damp = 0.7
	physics_material_override = PhysicsMaterial.new()
	physics_material_override.friction = 0.8
	physics_material_override.bounce = 0.12 if kind == "wood" else 0.22
	var col := CollisionShape2D.new()
	var bounds := _bounds(polygon)
	var box := RectangleShape2D.new()
	box.size = Vector2(maxf(bounds.size.x,2.0),maxf(bounds.size.y,2.0))
	col.shape = box
	col.position = bounds.get_center()
	add_child(col)
	var rect := Art.region(kind)
	source = Rect2(rect.position+Vector2(rect.size.x*0.2*float(index % 5),0),Vector2(rect.size.x*0.2,rect.size.y))
	for point in outline:
		uv.append((source.position+(point/dimensions+Vector2.ONE*0.5)*source.size)/Art.texture().get_size())

func _bounds(polygon: PackedVector2Array) -> Rect2:
	var bounds := Rect2(polygon[0],Vector2.ZERO)
	for p in polygon: bounds = bounds.expand(p)
	return bounds

# Torn silhouettes are generated, so guarantee renderable geometry: drop
# stacked points and fall back to the convex hull (then a box) whenever the
# polygon would not triangulate. Cosmetic shards must never error.
func _clean_polygon(polygon: PackedVector2Array) -> PackedVector2Array:
	var clean := PackedVector2Array()
	for p in polygon:
		if clean.is_empty() or clean[clean.size()-1].distance_to(p) > 0.75:
			clean.append(p)
	while clean.size() > 1 and clean[0].distance_to(clean[clean.size()-1]) < 0.75:
		clean.remove_at(clean.size()-1)
	if clean.size() < 3:
		return PackedVector2Array([Vector2(-4,-3),Vector2(4,-3),Vector2(4,3),Vector2(-4,3)])
	if Geometry2D.triangulate_polygon(clean).is_empty():
		var hull := Geometry2D.convex_hull(clean)
		if hull.size() >= 3 and not Geometry2D.triangulate_polygon(hull).is_empty():
			return hull
		var bounds := _bounds(clean)
		var half := Vector2(maxf(bounds.size.x*0.5,2.0),maxf(bounds.size.y*0.5,2.0))
		var center := bounds.get_center()
		return PackedVector2Array([center+Vector2(-half.x,-half.y),center+Vector2(half.x,-half.y),center+Vector2(half.x,half.y),center+Vector2(-half.x,half.y)])
	return clean

func _clean_fresh(fresh: PackedVector2Array) -> PackedVector2Array:
	var clean := PackedVector2Array()
	for p in fresh:
		if clean.is_empty() or clean[clean.size()-1].distance_to(p) > 0.5:
			clean.append(p)
	return clean

func _physics_process(delta: float) -> void:
	lifetime += delta
	if lifetime > 4.0: modulate.a = maxf(0,1.0-(lifetime-4.0)/1.5)
	if lifetime > 5.5: queue_free()

func _draw() -> void:
	if outline.size() < 3: return
	draw_polygon(outline,PackedColorArray([Color.WHITE]),uv,Art.texture())
	var edge := PackedVector2Array(outline)
	edge.append(outline[0])
	draw_polyline(edge,Color(0.85,0.98,1,0.7) if material_kind == "glass" else Color(0.36,0.19,0.07,0.65),0.8,true)
	if fresh_edge.size() >= 2:
		if material_kind == "glass":
			draw_polyline(fresh_edge,Color(0.94,1.0,1.0,0.9),1.2,true)
		else:
			# Freshly torn wood reads paler than the weathered face, with dark
			# crevices where the fibers pulled apart.
			draw_polyline(fresh_edge,Color(0.93,0.76,0.50,0.95),2.4,true)
			draw_polyline(fresh_edge,Color(0.23,0.11,0.04,0.85),0.9,true)
			var side := 1.0
			for i in range(1,fresh_edge.size()-1):
				if i % 2 == 0:
					var d := fresh_edge[mini(i+1,fresh_edge.size()-1)]-fresh_edge[i-1]
					if d.length() < 0.01: continue
					var nrm := Vector2(-d.y,d.x).normalized()*side
					draw_line(fresh_edge[i],fresh_edge[i]+nrm*2.2,Color(0.25,0.12,0.045,0.7),0.9,true)
					side = -side
