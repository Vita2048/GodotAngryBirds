extends RefCounted
## Regions share one frozen generated atlas. Faces and damage remain live layers.
static var atlas: Texture2D
const REGIONS := {
	"bird": Rect2(20, 30, 401, 365), "pig": Rect2(467, 58, 320, 332),
	"wood": Rect2(851, 179, 385, 121), "glass": Rect2(30, 595, 393, 116),
	"crate": Rect2(461, 417, 333, 376), "boulder": Rect2(854, 446, 375, 368),
	"sling": Rect2(78, 810, 310, 407), "smoke": Rect2(431, 830, 380, 388),
	"fire": Rect2(836, 814, 404, 411)
}

static func texture() -> Texture2D:
	if atlas == null:
		atlas = load("res://assets/painted-atlas.png") as Texture2D
	return atlas

static func region(kind: String) -> Rect2:
	var rect: Rect2 = REGIONS[kind]
	var scale := texture().get_size() / Vector2(1280, 1280)
	return Rect2(rect.position * scale, rect.size * scale)

static func paint(canvas: CanvasItem, kind: String, rect: Rect2, tint := Color.WHITE) -> void:
	canvas.draw_texture_rect_region(texture(), rect, region(kind), tint)

# Classic size color-coding on top of the hybrid look: the baked atlas bird is
# crimson, so yellow (bird_m) and dark-red (bird_l) variants are derived once
# by hue-shifting just the bird cell. Saturation/value (shading, brushwork)
# and the near-white belly survive, and the vector face layer is untouched.
static var bird_variants := {}
const BIRD_HUES := {"bird_m": 0.12, "bird_l": 0.0}

static func bird_texture(bird_type: String) -> Texture2D:
	if bird_type in BIRD_HUES and not bird_variants.has(bird_type):
		bird_variants[bird_type] = _shift_bird_hue(bird_type)
	return bird_variants.get(bird_type, texture())

static func paint_bird(canvas: CanvasItem, bird_type: String, rect: Rect2, tint := Color.WHITE) -> void:
	var tex := bird_texture(bird_type)
	var scale := tex.get_size() / Vector2(1280, 1280)
	var base: Rect2 = REGIONS["bird"]
	canvas.draw_texture_rect_region(tex, rect, Rect2(base.position * scale, base.size * scale), tint)

static func _shift_bird_hue(bird_type: String) -> Texture2D:
	var img := texture().get_image().duplicate() as Image
	var scale := Vector2(img.get_width(), img.get_height()) / Vector2(1280, 1280)
	var cell: Rect2 = REGIONS["bird"]
	var r := Rect2(cell.position * scale, cell.size * scale).abs()
	r = r.intersection(Rect2(Vector2.ZERO, Vector2(img.get_width(), img.get_height())))
	var saturated := bird_type == "bird_l"
	for y in range(int(r.position.y), int(r.end.y)):
		for x in range(int(r.position.x), int(r.end.x)):
			var c := img.get_pixel(x, y)
			if c.a < 0.05:
				continue
			var v: float = c.v
			# Dark bird: deepen vivid reds, spare the pale belly.
			if saturated:
				v *= 0.62 if c.s > 0.3 else 0.85
				img.set_pixel(x, y, Color.from_hsv(0.0, minf(c.s * 1.05, 1.0), v, c.a))
			else:
				img.set_pixel(x, y, Color.from_hsv(float(BIRD_HUES[bird_type]), c.s, minf(v * 1.04, 1.0), c.a))
	return ImageTexture.create_from_image(img)

static func hit_material() -> ShaderMaterial:
	var result := ShaderMaterial.new()
	result.shader = load("res://shaders/painted-hit.gdshader")
	return result

static func face(canvas: CanvasItem, radius: float, pig: bool, gaze: Vector2, hurt: float, clock: float) -> void:
	var r := radius
	var blink := fmod(clock, 3.8) < 0.11
	var direction := gaze.limit_length(1.0) * r * 0.075
	for side in [-1.0, 1.0]:
		var pos := Vector2(side * r * 0.31, -r * 0.26)
		if blink:
			canvas.draw_line(pos-Vector2(r*0.19,0),pos+Vector2(r*0.19,0),Color("#293325"),2.4,true)
		else:
			canvas.draw_circle(pos, r*0.23, Color("#30372d"))
			canvas.draw_circle(pos-Vector2(0,r*0.018),r*0.205,Color("#fffbe8"))
			canvas.draw_circle(pos+direction,r*0.095,Color("#27312d"))
			canvas.draw_circle(pos+direction-Vector2(r*0.025,r*0.035),r*0.031,Color.WHITE)
		var brow := pos + Vector2(0,-r*0.29)
		var slope := (0.12 if pig else -0.12) + hurt * 0.15
		canvas.draw_line(brow+Vector2(-r*0.20,-side*r*slope),brow+Vector2(r*0.20,side*r*slope),Color("#335024") if pig else Color("#69241e"),3.0,true)
	if pig:
		canvas.draw_set_transform(Vector2(0,r*0.14),0,Vector2(1.2,0.85))
		canvas.draw_circle(Vector2.ZERO,r*0.37,Color("#466934"))
		canvas.draw_circle(Vector2(0,-r*0.025),r*0.32,Color("#b7df7b"))
		for x in [-0.12,0.12]: canvas.draw_circle(Vector2(r*x,0),r*0.07,Color("#496936"))
		canvas.draw_set_transform(Vector2.ZERO)
		canvas.draw_arc(Vector2(0,r*0.43),r*0.16,0.1,PI-0.1,16,Color("#426231"),2,true)
		if hurt > 0.1:
			canvas.draw_circle(Vector2(-r*0.68,-r*0.03),r*0.17,Color(0.39,0.3,0.49,hurt*0.8))
	else:
		var beak := PackedVector2Array([Vector2(-r*0.05,-r*0.02),Vector2(r*0.69,r*0.15),Vector2(-r*0.01,r*0.32)])
		canvas.draw_colored_polygon(beak,Color("#74381d"))
		canvas.draw_colored_polygon(PackedVector2Array([beak[0]+Vector2(2,1),beak[1]-Vector2(3,1),beak[2]-Vector2(-2,3)]),Color("#ffb83c"))
		canvas.draw_line(beak[0]+Vector2(2,3),beak[1]-Vector2(3,0),Color("#ffe28a"),1.6,true)
