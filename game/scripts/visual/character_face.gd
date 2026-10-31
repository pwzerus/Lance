extends RefCounted
## Original code-native pixel clusters on a 32x40 grid; no bitmap recolouring.
## Coordinates face right. The caller owns pose/facing and the CanvasItem transform.
const Appearance = preload("res://scripts/core/character_appearance.gd")
const Equipment = preload("res://scripts/visual/equipment_art.gd")
const SKIN = [Color("e9bc8b"),Color("dca270"),Color("c78a56"),Color("ad885c"),Color("91613e"),Color("63432f")]
const HAIR = [Color("543726"),Color("282a27"),Color("914b2d"),Color("ba985b")]
const EYES = [Color("744625"),Color("508db2"),Color("5d8b4e"),Color("929c9c"),Color("c49837")]
const INK = Color("2b2926")

class FaceSurface:
	extends RefCounted
	var target: CanvasItem
	var bounds: Rect2
	func _init(canvas: CanvasItem, clip: Rect2) -> void:
		target = canvas
		bounds = clip
	func draw_rect(rectangle: Rect2, color: Color) -> void:
		var visible = rectangle.intersection(bounds) if bounds.has_area() else rectangle
		if visible.has_area():
			target.draw_rect(visible,color)

static func block(canvas: Object, rect: Rect2, x: float, y: float, w: float, h: float, color: Color) -> void:
	var unit = rect.size/Vector2(32,40)
	canvas.draw_rect(Rect2(rect.position+Vector2(x,y)*unit,Vector2(w,h)*unit),color)

static func face_span(shape: int, row: int) -> Vector2i:
	# Skull, cheek plane and jaw are separate steps, not a rectangular mask.
	# Exclusive right edge. All shapes retain the existing neck/helmet aperture.
	match shape:
		1: # wider masseter and a short, square chin
			if row<11: return Vector2i(8,24)
			if row<22: return Vector2i(6,25)
			if row<26: return Vector2i(7,25)
			if row<28: return Vector2i(8,24)
			return Vector2i(10,23)
		2: # longer oval, narrower temples; no pinched triangular chin
			if row<11: return Vector2i(9,23)
			if row<22: return Vector2i(8,24)
			if row<27: return Vector2i(9,24)
			if row<30: return Vector2i(10,23)
			return Vector2i(12,22)
		3: # higher cheekbone and a more defined jaw angle
			if row<12: return Vector2i(8,24)
			if row<18: return Vector2i(7,25)
			if row<22: return Vector2i(6,25)
			if row<25: return Vector2i(8,24)
			if row<28: return Vector2i(9,24)
			return Vector2i(11,22)
		_:
			if row<11: return Vector2i(8,24)
			if row<17: return Vector2i(7,25)
			if row<22: return Vector2i(6,25)
			if row<25: return Vector2i(7,25)
			if row<27: return Vector2i(8,24)
			if row<29: return Vector2i(10,23)
			return Vector2i(12,22)

static func draw_face(source_canvas: CanvasItem, appearance: Dictionary, rect: Rect2, clip: Rect2 = Rect2(), include_neck: bool = true) -> void:
	# Mounted faces are clipped to their aperture/jaw. Their collar is drawn
	# behind the cuirass, rather than painting a second neck over the armour.
	var canvas = FaceSurface.new(source_canvas,clip)
	var a = Appearance.sanitize(appearance)
	var skin: Color = SKIN[a.skin]
	var shade = skin.darkened(.21)
	var soft_shade = skin.darkened(.10)
	var light = skin.lightened(.09)
	var contour = skin.darkened(.48)
	var hair: Color = HAIR[a.hair]
	var iris: Color = EYES[a.eyes]
	var shape = int(a.face_shape)
	var chin_row = 31 if shape==2 else 29
	# Short neck behind the jaw. Mounted callers provide their own fitted neck.
	if include_neck:
		block(canvas,rect,11,28,11,11,contour)
		block(canvas,rect,12,28,9,11,shade)
		block(canvas,rect,16,30,5,8,soft_shade)
	block(canvas,rect,10,3,10,1,INK)
	block(canvas,rect,7,4,16,2,INK)
	block(canvas,rect,5,6,21,9,INK)
	block(canvas,rect,6,6,19,8,hair)
	block(canvas,rect,8,5,14,4,hair)
	block(canvas,rect,11,4,9,2,hair)
	block(canvas,rect,9,6,7,2,hair.lightened(.12))
	block(canvas,rect,17,7,5,2,hair.lightened(.07))
	for row in range(8,chin_row+1):
		var span = face_span(shape,row)
		block(canvas,rect,span.x-1,row,span.y-span.x+2,1,contour)
		block(canvas,rect,span.x,row,span.y-span.x,1,skin)
		var rear_width = 3 if row>=16 and row<25 else 2
		block(canvas,rect,span.x,row,rear_width,1,shade)
		block(canvas,rect,span.x+rear_width,row,1,1,soft_shade)
		if row>=27:
			block(canvas,rect,span.x,row,span.y-span.x,1,soft_shade)
	# Cheek and brow ridge use coherent planes, not noise or a bright face border.
	var near_x = 12 if shape==2 else 11
	var eye_y = 17 if shape==2 else 16
	block(canvas,rect,near_x,12,6,2,light)
	block(canvas,rect,near_x,20,5,2,light)
	block(canvas,rect,near_x+1,22,4,1,light)
	if shape==3:
		block(canvas,rect,9,22,3,2,shade)
		block(canvas,rect,11,24,3,1,soft_shade)
	block(canvas,rect,16,28 if shape!=2 else 30,5,1,skin)
	# Near ear and cropped hairline, both behind the eye plane.
	block(canvas,rect,5 if shape!=2 else 7,16,3,6,contour)
	block(canvas,rect,6 if shape!=2 else 8,16,2,5,shade)
	block(canvas,rect,6 if shape!=2 else 8,17,1,2,skin)
	block(canvas,rect,7 if shape!=2 else 8,9,2,7,hair)
	block(canvas,rect,9,8,5,2,hair)
	block(canvas,rect,14,9,5,2,hair)
	block(canvas,rect,19,10,4,1,hair)
	# Upper lids and a single row of sclera: no black rectangles around the eyes.
	# The far eye is narrower. Both pupils look toward the opponent.
	var lid = hair.lerp(INK,.45)
	block(canvas,rect,near_x,eye_y,5,1,lid)
	block(canvas,rect,near_x+1,eye_y+1,4,1,Color("e0d4bd"))
	block(canvas,rect,near_x+2,eye_y+1,1,1,iris)
	block(canvas,rect,near_x+3,eye_y+1,1,1,INK)
	block(canvas,rect,near_x+1,eye_y+2,1,1,light)
	block(canvas,rect,near_x+2,eye_y+2,1,1,iris.darkened(.10))
	block(canvas,rect,near_x+3,eye_y+2,1,1,lid)
	block(canvas,rect,21,eye_y,3,1,lid)
	block(canvas,rect,21,eye_y+1,3,1,Color("d4c5ab"))
	block(canvas,rect,22,eye_y+1,1,1,iris.darkened(.35))
	var brow_color = hair.lerp(skin,.38) if a.brows==3 else hair
	var brow_y = eye_y-2
	block(canvas,rect,near_x,brow_y,5,1,brow_color)
	block(canvas,rect,20,brow_y,3,1,brow_color)
	block(canvas,rect,near_x-1,brow_y+1,1,1,brow_color)
	if a.brows==1:
		block(canvas,rect,near_x+1,brow_y-1,4,1,brow_color)
		block(canvas,rect,21,brow_y-1,2,1,brow_color)
	elif a.brows==2:
		block(canvas,rect,near_x+1,brow_y-1,3,1,brow_color)
		block(canvas,rect,near_x,brow_y,1,1,skin)
		block(canvas,rect,20,brow_y,1,1,skin)
	# Small nose planes with a broken base shadow, not a bright L-shaped block.
	block(canvas,rect,19,eye_y+2,1,4,soft_shade)
	block(canvas,rect,20,eye_y+2,1,3,light)
	block(canvas,rect,20,22 if shape!=2 else 23,3,1,skin)
	block(canvas,rect,20,23 if shape!=2 else 24,2,1,shade)
	var mouth_y = 27 if shape==2 else 26
	block(canvas,rect,16,mouth_y-1,1,1,soft_shade)
	block(canvas,rect,17,mouth_y,5,1,skin.darkened(.34))
	block(canvas,rect,22,mouth_y-1,1,1,shade)
	block(canvas,rect,18,mouth_y+1,3,1,skin.lightened(.05))
	# Facial hair follows the jaw and keeps the mouth readable.
	match int(a.beard):
		1:
			block(canvas,rect,15,mouth_y-2,4,1,hair)
			block(canvas,rect,20,mouth_y-2,3,1,hair)
			block(canvas,rect,14,mouth_y-1,3,1,hair)
			block(canvas,rect,22,mouth_y-1,2,1,hair)
		2:
			for row in range(21,chin_row+2):
				var span = face_span(shape,mini(row,chin_row))
				block(canvas,rect,span.x,row,3,1,hair)
				if row>=mouth_y+2:
					block(canvas,rect,span.x+2,row,span.y-span.x-2,1,hair)
			block(canvas,rect,15,mouth_y-2,4,1,hair)
			block(canvas,rect,20,mouth_y-2,3,1,hair)
			block(canvas,rect,22,mouth_y-1,2,3,hair)
			block(canvas,rect,13,chin_row,4,1,hair.lightened(.16))
		3:
			block(canvas,rect,15,mouth_y-2,4,1,hair)
			block(canvas,rect,20,mouth_y-2,3,1,hair)
			block(canvas,rect,17,mouth_y+2,5,3,hair)
			block(canvas,rect,18,mouth_y+5,3,1,hair)
			block(canvas,rect,17,mouth_y+3,1,1,hair.lightened(.16))
		4:
			for row in range(21,28):
				var span = face_span(shape,row)
				block(canvas,rect,span.x,row,3,1,hair)
			block(canvas,rect,15,mouth_y-2,4,1,hair)
			block(canvas,rect,20,mouth_y-2,3,1,hair)
			block(canvas,rect,22,mouth_y-1,2,3,hair)
			for row in range(mouth_y+2,37):
				var taper = maxi(0,row-30)/2
				block(canvas,rect,10+taper,row,14-taper*2,1,hair)
			block(canvas,rect,13,29,2,3,hair.lightened(.14))
			block(canvas,rect,15,32,1,3,hair.lightened(.10))

static func draw_portrait(canvas: CanvasItem, appearance: Dictionary, rect: Rect2) -> void:
	# Only the character editor owns this shoulder crop. Mounted/legacy helmet
	# callers still use draw_face, so no tunic can leak into a helmet aperture.
	var skin: Color = SKIN[Appearance.sanitize(appearance).skin]
	block(canvas,rect,11,28,11,8,skin.darkened(.48))
	block(canvas,rect,12,28,9,7,skin.darkened(.21))
	block(canvas,rect,16,30,5,5,skin.darkened(.10))
	var cloth = Color("59605a")
	for row in range(34,40):
		var inset = maxi(3,10-(row-34)*2)
		block(canvas,rect,inset-1,row,34-inset*2,1,Color("2b3432"))
		block(canvas,rect,inset,row,32-inset*2,1,cloth)
		block(canvas,rect,inset,row,3,1,cloth.darkened(.19))
	block(canvas,rect,11,34,11,1,Color("3c4541"))
	block(canvas,rect,12,35,9,1,Color("3c4541"))
	block(canvas,rect,14,34,6,1,skin.darkened(.17))
	block(canvas,rect,15,36,2,4,cloth.darkened(.17))
	block(canvas,rect,20,37,5,1,cloth.lightened(.07))
	# Beard tips belong in front of the collar, including the long-face goatee.
	draw_face(canvas,appearance,rect,Rect2(),false)

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
