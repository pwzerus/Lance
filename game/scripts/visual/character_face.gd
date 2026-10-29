extends RefCounted
## Original code-native pixel clusters on a 32x40 grid; no bitmap recolouring.
## Coordinates face right. The caller owns pose/facing and the CanvasItem transform.
const Appearance = preload("res://scripts/core/character_appearance.gd")
const Equipment = preload("res://scripts/visual/equipment_art.gd")
const SKIN = [Color("e9bc8b"),Color("dca270"),Color("c78a56"),Color("ad885c"),Color("91613e"),Color("63432f")]
const HAIR = [Color("543726"),Color("282a27"),Color("914b2d"),Color("ba985b")]
const EYES = [Color("744625"),Color("508db2"),Color("5d8b4e"),Color("929c9c"),Color("c49837")]
const INK = Color("2b2926")

static func block(canvas: CanvasItem, rect: Rect2, x: float, y: float, w: float, h: float, color: Color) -> void:
	var unit = rect.size/Vector2(32,40)
	canvas.draw_rect(Rect2(rect.position+Vector2(x,y)*unit,Vector2(w,h)*unit),color)

static func face_span(shape: int, row: int) -> Vector2i:
	match shape:
		1: # broad cheek and squared chin
			return Vector2i(7 if row<10 else (6 if row<26 else 8),24 if row<27 else 23)
		2: # longer narrow face
			return Vector2i(9 if row<10 else (8 if row<27 else 10),23 if row<28 else 21)
		3: # high cheekbones, tapered jaw
			var taper = maxi(0,(row-21)/2)
			return Vector2i(6+taper,25-taper/2)
		_:
			var taper = maxi(0,(row-23)/2)
			return Vector2i((8 if row<10 else 6)+taper,24-taper)

static func draw_face(canvas: CanvasItem, appearance: Dictionary, rect: Rect2) -> void:
	var a = Appearance.sanitize(appearance)
	var skin: Color = SKIN[a.skin]
	var shade = skin.darkened(.23)
	var light = skin.lightened(.16)
	var hair: Color = HAIR[a.hair]
	var iris: Color = EYES[a.eyes]
	var chin_row = 31 if a.face_shape==2 else 29
	# Neck, hair silhouette and a stepped face contour.
	block(canvas,rect,11,28,11,11,INK)
	block(canvas,rect,12,28,9,11,shade)
	block(canvas,rect,16,29,5,8,skin)
	block(canvas,rect,8,3,15,2,INK)
	block(canvas,rect,5,5,21,11,INK)
	block(canvas,rect,6,5,18,10,hair)
	block(canvas,rect,9,4,12,3,hair.lightened(.12))
	for row in range(8,chin_row+1):
		var span = face_span(int(a.face_shape),row)
		block(canvas,rect,span.x-1,row,span.y-span.x+2,1,INK)
		block(canvas,rect,span.x,row,span.y-span.x,1,skin)
		block(canvas,rect,span.x,row,2,1,shade)
		if row<23:
			block(canvas,rect,span.y-3,row,2,1,light)
	# The visible ear stays on the shadowed side of the three-quarter face.
	block(canvas,rect,4,15,4,7,INK)
	block(canvas,rect,5,16,3,5,shade)
	block(canvas,rect,6,17,1,3,skin)
	block(canvas,rect,7,8,3,6,hair)
	block(canvas,rect,10,7,14,4,hair)
	block(canvas,rect,20,10,4,2,hair)
	# Whites, irises and pupils are real independent pixel clusters.
	block(canvas,rect,10,16,5,3,INK)
	block(canvas,rect,11,16,4,2,Color("e5ded0"))
	block(canvas,rect,13,16,2,2,iris)
	block(canvas,rect,14,17,1,1,INK)
	block(canvas,rect,19,16,5,3,INK)
	block(canvas,rect,20,16,4,2,Color("eee4d3"))
	block(canvas,rect,21,16,2,2,iris)
	block(canvas,rect,22,17,1,1,INK)
	var brow_color = hair.lightened(.25) if a.brows==3 else hair
	var brow_height = 2 if a.brows==1 else 1
	block(canvas,rect,10,14,5,brow_height,brow_color)
	block(canvas,rect,19,14,5,brow_height,brow_color)
	if a.brows==2:
		block(canvas,rect,11,13,3,1,brow_color)
		block(canvas,rect,20,13,3,1,brow_color)
	# Nose points toward the opponent; the mouth is below, never part of beard texture.
	block(canvas,rect,18,18,2,5,shade)
	block(canvas,rect,20,20,4,2,light)
	block(canvas,rect,19,23,4,1,shade)
	block(canvas,rect,13,26,9,1,skin.darkened(.45))
	block(canvas,rect,16,27,5,1,skin.lightened(.08))
	match int(a.beard):
		1:
			block(canvas,rect,12,24,10,2,hair)
			block(canvas,rect,11,25,2,2,hair)
			block(canvas,rect,21,25,2,2,hair)
		2:
			block(canvas,rect,7,21,3,7,hair)
			block(canvas,rect,10,27,13,3,hair)
			block(canvas,rect,13,30,8,2,hair)
			block(canvas,rect,12,24,10,2,hair)
			block(canvas,rect,13,28,7,1,hair.lightened(.18))
		3:
			block(canvas,rect,13,24,9,2,hair)
			block(canvas,rect,15,28,7,4,hair)
			block(canvas,rect,17,32,3,2,hair)
		4:
			block(canvas,rect,7,22,3,7,hair)
			block(canvas,rect,11,24,12,2,hair)
			block(canvas,rect,10,28,14,4,hair)
			block(canvas,rect,12,32,10,3,hair)
			block(canvas,rect,15,35,5,2,hair)
			block(canvas,rect,13,29,2,4,hair.lightened(.2))

static func draw_head(canvas: CanvasItem, appearance: Dictionary, helmet_tier: int, helmet_color: Color, head_rect: Rect2) -> void:
	if helmet_tier>0:
		# Enclosed helmets still obscure the real face, as they should.
		canvas.draw_texture_rect(Equipment.helmet(helmet_tier),head_rect,false)
		return
	var metal = Color("8e999b").lerp(helmet_color,.22)
	var unit = head_rect.size/Vector2(32,40)
	# Coif under the face and cap. Large colour groups avoid procedural noise.
	block(canvas,head_rect,6,9,22,27,INK)
	block(canvas,head_rect,7,13,20,23,Color("56616b"))
	block(canvas,head_rect,4,29,25,10,INK)
	block(canvas,head_rect,5,30,23,8,Color("586470"))
	draw_face(canvas,appearance,Rect2(head_rect.position+Vector2(4,5)*unit,Vector2(27,33)*unit))
	block(canvas,head_rect,5,14,4,20,Color("44515c"))
	block(canvas,head_rect,6,16,2,17,Color("899197"))
	block(canvas,head_rect,25,15,3,20,Color("44515c"))
	for row in range(4):
		block(canvas,head_rect,7,19+row*4,2,1,Color("afafb0"))
		block(canvas,head_rect,25,19+row*4,2,1,Color("949da1"))
	# Stepped conical nasal helmet, metal band and nasal guard.
	block(canvas,head_rect,16,1,4,2,INK)
	block(canvas,head_rect,13,3,10,3,INK)
	block(canvas,head_rect,10,6,16,3,INK)
	block(canvas,head_rect,7,9,21,6,INK)
	block(canvas,head_rect,16,3,3,2,metal.lightened(.25))
	block(canvas,head_rect,14,5,7,3,metal)
	block(canvas,head_rect,11,8,13,3,metal)
	block(canvas,head_rect,8,11,18,3,metal.darkened(.15))
	block(canvas,head_rect,14,6,2,6,metal.lightened(.28))
	block(canvas,head_rect,7,14,22,3,INK)
	block(canvas,head_rect,8,14,20,2,Color("b59851"))
	for x in [10,15,24,27]:
		block(canvas,head_rect,x,14,1,1,Color("e8c57c"))
	block(canvas,head_rect,18,16,3,10,INK)
	block(canvas,head_rect,19,16,2,9,metal)
	block(canvas,head_rect,19,17,1,6,metal.lightened(.28))
