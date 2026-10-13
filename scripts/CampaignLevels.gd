extends RefCounted
## Authored puzzle layouts. Coordinates use the 1280 x 720 gameplay canvas.

static func block(x: float, y: float, w: float, h: float, kind := "wood", id := "") -> Dictionary:
	return {"x":x, "y":y, "w":w, "h":h, "type":kind, "id":id}

static func pig(x: float, y: float) -> Dictionary:
	return {"x":x, "y":y, "r":25}

static func terrain(points: Array, kind := "rock") -> Dictionary:
	return {"points":PackedVector2Array(points), "kind":kind}

static func shelter(x: float, floor_y: float, height: float, span: float, post_kind := "stone", roof_kind := "wood") -> Array:
	return [block(x-span/2,floor_y-height/2,20,height,post_kind),
		block(x+span/2,floor_y-height/2,20,height,post_kind),
		block(x,floor_y-height-12,span+44,24,roof_kind)]

static func build() -> Array[Dictionary]:
	var farm: Array = []
	for x in [720.0,950.0,1180.0]:
		farm.append_array([block(x-45,625,36,110,"stone"),
			block(x+45,625,24,110),block(x,556,144,28,"stone")])
	var bridge: Array = [block(980,595,32,110,"wood","bridge_support"),
		block(880,530,200,20),block(1080,530,200,20)]
	bridge.append_array(shelter(1225,420,80,80))
	var quarry: Array = [block(821,466,18,140,"wood","stopper")]
	quarry.append_array(shelter(1060,680,120,100,"wood","stone"))
	quarry.append_array(shelter(1225,450,80,80))
	var barn: Array = [block(835,580,22,200,"wood","counterweight_release")]
	barn.append_array([block(660,625,24,110,"wood"),block(740,625,20,110,"stone"),block(700,558,124,24)])
	# Rock overhangs isolate both lower rooms from the upper collapse.
	# Their timber doors must be attacked through the low entrance slots.
	var fortress: Array = [block(680,620,22,120),block(1080,620,18,120),
		block(750,487.5,28,95),block(1150,487.5,32,95,"stone"),block(950,425,440,30,"glass"),
		block(910,360,20,100,"glass"),block(990,360,20,100,"glass"),block(950,297.5,124,25),
		block(910,250,20,70),block(990,250,20,70),block(950,205,124,20,"stone")]
	var result: Array[Dictionary] = [
		{"name":"STONE FARM", "hint":"4 birds. Three shelters; thick stone shields their fronts.",
		 "birds":["bird_m","bird_s","bird_l","bird_s"],
		 "pigs":[pig(720,655),pig(950,655),pig(1180,655)], "blocks":farm, "props":[]},
		{"name":"BRIDGE KEEP", "hint":"2 birds. The bridge and the high keep are separate targets.",
		 "birds":["bird_s","bird_m"],
		 "pigs":[pig(900,495),pig(1050,495),pig(1225,395)], "blocks":bridge, "props":[],
		 "gap":Vector2(850,1110),
		 "terrain":[terrain([Vector2(760,540),Vector2(825,540),Vector2(850,680),Vector2(750,680)]),
			terrain([Vector2(1135,540),Vector2(1200,540),Vector2(1210,680),Vector2(1110,680)]),
			terrain([Vector2(965,650),Vector2(995,650),Vector2(1008,760),Vector2(952,760)]),
			terrain([Vector2(1170,420),Vector2(1280,420),Vector2(1290,680),Vector2(1210,680)])]},
		{"name":"QUARRY SIEGE", "hint":"3 birds. The boulder cannot reach the upper shelter.",
		 "birds":["bird_s","bird_m","bird_m"],
		 "pigs":[pig(1060,655),pig(1225,425)], "blocks":quarry,
		 "props":[{"type":"boulder","x":777,"y":473}],
		 "terrain":[terrain([Vector2(700,460),Vector2(1000,650),Vector2(1000,680),Vector2(700,680)]),
			terrain([Vector2(1135,365),Vector2(1155,365),Vector2(1155,680),Vector2(1135,680)]),
			terrain([Vector2(1170,450),Vector2(1280,450),Vector2(1290,680),Vector2(1180,680)])]},
		{"name":"COUNTERWEIGHT FORT", "hint":"2 birds. Clear the guardhouse and release the loaded platform.",
		 "birds":["bird_s","bird_m"],
		 "pigs":[pig(700,655),pig(1075,435),pig(1130,435)], "blocks":barn,
		 "props":[], "counterweight":Vector2(975,470), "gap":Vector2(850,930),
		 "terrain":[terrain([Vector2(785,535),Vector2(805,535),Vector2(805,680),Vector2(785,680)]),
			terrain([Vector2(966,482),Vector2(984,482),Vector2(1010,680),Vector2(940,680)],"frame")]},
		{"name":"DOUBLE KEEP", "hint":"3 birds. Two shielded bunkers and an upper fortress.",
		 "birds":["bird_s","bird_m","bird_l"],
		 "pigs":[pig(750,655),pig(1170,655),pig(950,385),pig(950,260)],
		 "blocks":fortress, "props":[],
		 "terrain":[terrain([Vector2(660,535),Vector2(830,535),Vector2(830,560),Vector2(660,560)]),
			terrain([Vector2(805,560),Vector2(830,560),Vector2(830,680),Vector2(805,680)]),
			terrain([Vector2(1060,535),Vector2(1260,535),Vector2(1260,560),Vector2(1060,560)]),
			terrain([Vector2(1235,560),Vector2(1260,560),Vector2(1260,680),Vector2(1235,680)])]}
	]
	for level in result:
		level["challenge"] = true
	return result
