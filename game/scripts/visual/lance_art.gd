class_name LanceArt
extends RefCounted
## Extends the existing code-native lance. Geometry stays attached to the
## production hand/tip; decoration never contributes damage or collision.
const INK = Color("302923")
const WOOD = Color("aa7845")
const LIGHT_WOOD = Color("d4ab6c")
const STEEL = Color("9da9ad")
const DARK_STEEL = Color("4b5963")

static func surface(hand: Vector2, angle: float, distance: float, offset: float, length: float, broken: bool, recoil: float) -> Vector2:
	var axis = Vector2(cos(angle),sin(angle))
	var normal = Vector2(-axis.y,axis.x)
	var t = clampf(distance/maxf(1.0,length),0,1)
	var bend = 0.0 if broken else recoil*14.0*sin(PI*t)
	return hand+axis*distance+normal*(offset+bend)

static func radius(stats: Dictionary, distance: float, full_length: float) -> float:
	var kind = str(stats.get("lance_type","standard"))
	var quality = int(stats.get("lance_quality",0))
	var t = clampf(distance/full_length,0,1)
	if distance<14.0:
		return 2.8 if distance<0 else 3.3
	if kind=="light":
		return lerpf(3.4,1.65,t)
	if kind=="stout":
		var swelling = sin(PI*clampf((distance-14.0)/maxf(1,full_length-14.0),0,1))
		return lerpf(5.3,2.3,t)+swelling*(1.6 if quality<3 else 3.3)
	return lerpf(4.0 if kind=="long" else 4.6,2.0,t)

static func _mapped(points: Array, hand: Vector2, angle: float, length: float, broken: bool, recoil: float) -> PackedVector2Array:
	var result = PackedVector2Array()
	for point in points:
		result.append(surface(hand,angle,point.x,point.y,length,broken,recoil))
	return result

static func draw(canvas: CanvasItem, stats: Dictionary, hand: Vector2, angle: float, length: float, broken: bool, recoil: float, mode: String) -> void:
	var quality = clampi(int(stats.get("lance_quality",0)),0,5)
	var era = int(stats.get("lance_era",0))
	var full_length = maxf(120.0,float(stats.get("reach",247.0)))
	var kind = str(stats.get("lance_type","standard"))
	var shaft_end = length if broken else length-16.0
	var upper: Array = []
	var lower: Array = []
	var highlight = PackedVector2Array()
	for i in range(25):
		var d = lerpf(-67.0,shaft_end,float(i)/24.0)
		var r = radius(stats,d,full_length)
		upper.append(Vector2(d,-r))
		lower.push_front(Vector2(d,r))
		highlight.append(surface(hand,angle,d,-r*.48,length,broken,recoil))
	var silhouette = upper+lower
	var mapped = _mapped(silhouette,hand,angle,length,broken,recoil)
	canvas.draw_colored_polygon(mapped,WOOD)
	var closed = mapped.duplicate()
	closed.append(closed[0])
	canvas.draw_polyline(closed,INK,1.7,false)
	canvas.draw_polyline(highlight,LIGHT_WOOD,1.5,false)
	# Grip wrapping is different from a painted shaft; it remains on a stump.
	for d in range(-13,9,4):
		canvas.draw_line(surface(hand,angle,d,-3.4,length,broken,recoil),surface(hand,angle,d+2,3.4,length,broken,recoil),Color("5c3b2c"),2.0,false)
	var paint = Color(str(stats.get("lance_color","d2b179")))
	if quality>0:
		var region = str(stats.get("lance_region",""))
		var spacing = 30 if kind=="long" else 23
		for d in range(28,int(shaft_end)-5,spacing):
			var r = radius(stats,d,full_length)*.88
			var slant = 7.0 if region in ["意大利","法兰西"] else 0.0
			canvas.draw_line(surface(hand,angle,d,-r,length,broken,recoil),surface(hand,angle,d+slant,r,length,broken,recoil),paint,3.0 if quality<4 else 5.0,false)
		if kind=="stout" and quality>=2:
			var flute = PackedVector2Array()
			for i in range(17):
				var d = lerpf(20.0,shaft_end,float(i)/16.0)
				flute.append(surface(hand,angle,d,radius(stats,d,full_length)*.55,length,broken,recoil))
			canvas.draw_polyline(flute,WOOD.darkened(.28),1.8,false)
	# Compact conical guards appear only in the later chronological groups.
	# These are shared European design adaptations, not national inventions.
	if era>=2:
		var guard_height = (11.0 if kind=="light" else (21.0 if kind=="stout" else 15.0))+quality*.4
		var points = [Vector2(10,-guard_height),Vector2(24,-4),Vector2(26,0),Vector2(24,4),Vector2(10,guard_height),Vector2(7,guard_height-2),Vector2(7,-guard_height+2)]
		canvas.draw_colored_polygon(_mapped(points,hand,angle,length,broken,recoil),DARK_STEEL)
		canvas.draw_colored_polygon(_mapped([Vector2(10,-guard_height+2),Vector2(23,-3),Vector2(23,2),Vector2(10,guard_height-2)],hand,angle,length,broken,recoil),STEEL)
		canvas.draw_line(surface(hand,angle,9,-guard_height,length,broken,recoil),surface(hand,angle,9,guard_height,length,broken,recoil),Color("d2bc80") if quality>=4 else Color("d6d9cb"),2.0,false)
		if era>=3 and quality>=4:
			for offset in [-.65,0.0,.65]:
				canvas.draw_line(surface(hand,angle,12,guard_height*offset,length,broken,recoil),surface(hand,angle,20,guard_height*offset*.2,length,broken,recoil),Color("b6934e"),1.5,false)
	if broken:
		canvas.draw_polyline(_mapped([Vector2(length-4,-3),Vector2(length,0),Vector2(length-5,1),Vector2(length,3)],hand,angle,length,true,0),Color("e7cb8d"),2,false)
	else:
		draw_tip(canvas,surface(hand,angle,length,0,length,false,recoil),angle,mode,kind)

static func draw_fragment(canvas: CanvasItem, stats: Dictionary, source_start: float, section_length: float, full_length: float, pointed: bool, mode: String) -> void:
	# Distances stay in the original shaft coordinate system: taper and paint
	# do not restart at the new fragment's left edge after a break.
	var half = section_length*.5
	var end = source_start+section_length-(16.0 if pointed else 0.0)
	var upper: Array = []
	var lower: Array = []
	var highlight = PackedVector2Array()
	for i in range(17):
		var d = lerpf(source_start,end,float(i)/16.0)
		var x = d-source_start-half
		var r = radius(stats,d,full_length)
		upper.append(Vector2(x,-r))
		lower.push_front(Vector2(x,r))
		highlight.append(Vector2(x,-r*.48))
	var contour = PackedVector2Array(upper+lower)
	canvas.draw_colored_polygon(contour,WOOD)
	contour.append(contour[0])
	canvas.draw_polyline(contour,INK,1.7,false)
	canvas.draw_polyline(highlight,LIGHT_WOOD,1.5,false)
	var kind = str(stats.get("lance_type","standard"))
	var quality = int(stats.get("lance_quality",0))
	if quality>0:
		var spacing = 30 if kind=="long" else 23
		var slant = 7.0 if str(stats.get("lance_region","")) in ["意大利","法兰西"] else 0.0
		for d in range(28,int(full_length)-21,spacing):
			if d<source_start or d+slant>end: continue
			var x = d-source_start-half
			var r = radius(stats,d,full_length)*.88
			canvas.draw_line(Vector2(x,-r),Vector2(x+slant,r),Color(str(stats.get("lance_color","d2b179"))),3.0 if quality<4 else 5.0,false)
		if kind=="stout" and quality>=2:
			var flute = PackedVector2Array()
			for i in range(17):
				var d = lerpf(source_start,end,float(i)/16.0)
				flute.append(Vector2(d-source_start-half,radius(stats,d,full_length)*.55))
			canvas.draw_polyline(flute,WOOD.darkened(.28),1.8,false)
	var break_radius = radius(stats,source_start,full_length)
	for offset in [-.6,0.0,.6]:
		canvas.draw_line(Vector2(-half,offset*break_radius),Vector2(-half-6,offset*break_radius-2),Color("e4c287"),1.5,false)
	if pointed:
		draw_tip(canvas,Vector2(half,0),0,mode,kind)

static func draw_tip(canvas: CanvasItem, tip: Vector2, angle: float, mode: String, kind: String = "standard") -> void:
	# Maximum forward extent is exactly tip, the same point used by the model.
	var axis = Vector2(cos(angle),sin(angle))
	var normal = Vector2(-axis.y,axis.x)
	var points: Array
	if mode=="war":
		var breadth = 4.0 if kind=="light" else (7.0 if kind=="stout" else 5.0)
		points = [Vector2(-24,-2),Vector2(-17,-2),Vector2(-13,-breadth),Vector2(0,0),Vector2(-13,breadth),Vector2(-17,2),Vector2(-24,2)]
	else:
		points = [Vector2(-22,-3),Vector2(-11,-4),Vector2(-7,-8),Vector2(0,-8),Vector2(0,-5),Vector2(-6,-4),Vector2(-6,4),Vector2(0,5),Vector2(0,8),Vector2(-7,8),Vector2(-11,4),Vector2(-22,3)]
	var vertices = PackedVector2Array()
	for p in points:
		vertices.append(tip+axis*p.x+normal*p.y)
	canvas.draw_colored_polygon(vertices,STEEL)
	vertices.append(vertices[0])
	canvas.draw_polyline(vertices,INK,1.6,false)
	canvas.draw_line(tip-axis*20-normal,tip-axis*4-normal,Color("e2e1c8"),1.7,false)
