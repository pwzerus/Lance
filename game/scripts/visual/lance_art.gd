class_name LanceArt
extends RefCounted
## Extends the existing code-native lance. Geometry stays attached to the
## production hand/tip; decoration never contributes damage or collision.
##
## ART-090 readability (user: "lances look completely alike"; reference: chunky
## but distinct pixel weapons). In a match the old shaft was 2-5 units thick,
## i.e. 1-2 screen px, so stripes and guards vanished. Now, visual only:
##  * shafts are drawn 1.3x thicker; type reads from the profile
##    (light: slim straight / long: long fine taper / standard / stout: thick
##    with a swollen grip and flutes);
##  * paint by quality, in the rider's own arms tinctures where known:
##    q0 bare ash  q1 painted rings  q2 one-colour spiral  q3 two-colour spiral
##    q4 + gilt rings and a pennon  q5 + a larger pennon bearing the charge;
##  * the hand guard by period: none, flat rondel, small cone, large cone,
##    fluted cone;
##  * larger, distinct tips: three-prong coronel (arena) or leaf head (war).
const Heraldry = preload("res://scripts/visual/heraldry.gd")
const INK = Color("2a231d")
const WOOD = Color("aa7845")
const LIGHT_WOOD = Color("d4ab6c")
const STEEL = Color("a9b4b8")
const DARK_STEEL = Color("4b5963")
const GILT = Color("e0bb4c")
const VISUAL_SCALE = 1.3
enum Layer { WHOLE, REAR, FRONT }

static func strip_indices(samples: int) -> PackedInt32Array:
	var result = PackedInt32Array()
	for i in range(samples-1):
		var lower = samples*2-1-i
		result.append_array(PackedInt32Array([i,i+1,lower-1,i,lower-1,lower]))
	return result

static var _shaft_indices = strip_indices(25)
static var _fragment_indices = strip_indices(17)
static var _pennon_devices: Dictionary = {}

static func pennon_device(design: String) -> Dictionary:
	# Only the 12 authored families are cache keys. Geometry is authored and
	# triangulated once; flutter transforms vertices, never re-clips per frame.
	if not Heraldry.ARMS.has(design): design="bend"
	if _pennon_devices.has(design): return _pennon_devices[design]
	var face=PackedVector2Array([Vector2(-40,-50),Vector2(40,-50),Vector2(40,50),Vector2(-40,50)])
	var charges=Heraldry.clipped_charges(design,face,1.0)
	var overlays: Array[PackedVector2Array]=[]
	for polygon in Heraldry.overlay_polygons(design):
		for piece in Geometry2D.intersect_polygons(face,polygon):
			if piece.size()>=3: overlays.append(piece)
	var result={"charges":charges,"overlays":overlays}
	for part in ["charges","overlays"]:
		var indices: Array[PackedInt32Array]=[]
		for piece in result[part]: indices.append(Geometry2D.triangulate_polygon(piece))
		result[part+"_triangles"]=indices
	result.make_read_only()
	_pennon_devices[design]=result
	return result

static func draw_strip(canvas: CanvasItem, points: PackedVector2Array, triangles: PackedInt32Array, color: Color = WOOD) -> void:
	# This is an authored ribbon: upper samples followed by reversed lower
	# samples. Ear clipping the almost-collinear shaft at every pose can fail
	# from float rounding (PERF-084 exact GPU reproduction). Keep ALL vertices,
	# flex, taper and outline; submit the known adjacent-strip connectivity.
	RenderingServer.canvas_item_add_triangle_array(canvas.get_canvas_item(),triangles,points,PackedColorArray([color]))

static func surface(hand: Vector2, angle: float, distance: float, offset: float, length: float, broken: bool, recoil: float) -> Vector2:
	var axis = Vector2(cos(angle),sin(angle))
	var normal = Vector2(-axis.y,axis.x)
	var t = clampf(distance/maxf(1.0,length),0,1)
	# Compression now also reaches the real grip/arm through the shared pose.
	# Keep a short elastic shaft flex, not a rubber bow; grip and tip stay exact.
	var bend = 0.0 if broken else clampf(recoil,-1,1)*6.5*sin(PI*t)
	return hand+axis*distance+normal*(offset+bend)

static func radius(stats: Dictionary, distance: float, full_length: float) -> float:
	var kind = str(stats.get("lance_type","standard"))
	var quality = int(stats.get("lance_quality",0))
	var t = clampf(distance/full_length,0,1)
	var r: float
	if distance<14.0:
		# Continuous at the hand (d=0): the old 2.8->3.3 step sat exactly on the
		# rear section's last vertex; at 1.3x it notched that outline and failed
		# the lance polygon tests (art090-lance01/polygons01).
		r = 2.8 if distance<=0 else lerpf(2.8,3.3,clampf(distance/4.0,0,1))
	elif kind=="light":
		r = lerpf(3.0,1.45,t)
	elif kind=="stout":
		var swelling = sin(PI*clampf((distance-14.0)/maxf(1,full_length-14.0),0,1))
		r = lerpf(5.3,2.3,t)+swelling*(1.6 if quality<3 else 3.3)
	elif kind=="long":
		r = lerpf(3.8,1.7,pow(t,.8))
	else:
		r = lerpf(4.6,2.0,t)
	return r*VISUAL_SCALE

static func _mapped(points: Array, hand: Vector2, angle: float, length: float, broken: bool, recoil: float) -> PackedVector2Array:
	var result = PackedVector2Array()
	for point in points:
		result.append(surface(hand,angle,point.x,point.y,length,broken,recoil))
	return result

static func _tinctures(stats: Dictionary) -> Array:
	# Livery in the rider's arms when known (battle), else the item's colour.
	if stats.has("heraldry"):
		var design = str(stats.heraldry)
		return [Heraldry.field_color(design),Heraldry.charge_color(design)]
	var paint = Color(str(stats.get("lance_color","d2b179")))
	return [paint,paint.lightened(.55)]

static func draw(canvas: CanvasItem, stats: Dictionary, hand: Vector2, angle: float, length: float, broken: bool, recoil: float, mode: String, layer: int = Layer.WHOLE, motion_time: float = 0.0) -> void:
	var quality = clampi(int(stats.get("lance_quality",0)),0,5)
	var era = int(stats.get("lance_era",0))
	var full_length = maxf(120.0,float(stats.get("reach",247.0)))
	var kind = str(stats.get("lance_type","standard"))
	var shaft_end = length if broken else length-16.0
	# Mounted riders occlude the butt with their neck/head. Detached lances
	# retain the whole draw path. Both sections use the same hand/axis/bend.
	var section_start = 0.0 if layer==Layer.FRONT else -67.0
	var section_end = 0.0 if layer==Layer.REAR else shaft_end
	var upper: Array = []
	var lower: Array = []
	var highlight = PackedVector2Array()
	for i in range(25):
		var d = lerpf(section_start,section_end,float(i)/24.0)
		var r = radius(stats,d,full_length)
		upper.append(Vector2(d,-r))
		lower.push_front(Vector2(d,r))
		highlight.append(surface(hand,angle,d,-r*.45,length,broken,recoil))
	var silhouette = upper+lower
	var mapped = _mapped(silhouette,hand,angle,length,broken,recoil)
	draw_strip(canvas,mapped,_shaft_indices,WOOD if quality<3 else Color(_tinctures(stats)[0]).darkened(.05))
	var map = func(d: float, y: float) -> Vector2: return surface(hand,angle,d,y,length,broken,recoil)
	if layer!=Layer.REAR:
		_paint(canvas,stats,map,maxf(section_start,24.0),shaft_end-4.0,full_length)
	# Do not draw an artificial end cap at the split inside the hand.
	canvas.draw_polyline(_mapped(upper,hand,angle,length,broken,recoil),INK,2.0,false)
	canvas.draw_polyline(_mapped(lower,hand,angle,length,broken,recoil),INK,2.0,false)
	if layer!=Layer.FRONT:
		canvas.draw_line(mapped[0],mapped[-1],INK,2.0,false)
	if layer!=Layer.REAR:
		canvas.draw_line(mapped[24],mapped[25],INK,2.0,false)
	canvas.draw_polyline(highlight,LIGHT_WOOD if quality<3 else Color(1,1,1,.45),1.5,false)
	# Grip wrapping is different from a painted shaft; it remains on a stump.
	for d in range(-13,9,4):
		var start = maxf(d,section_start)
		var end = minf(d+2,section_end)
		if end<=start: continue
		var grip = 3.3*VISUAL_SCALE
		var start_y = lerpf(-grip,grip,(start-d)/2.0)
		var end_y = lerpf(-grip,grip,(end-d)/2.0)
		canvas.draw_line(surface(hand,angle,start,start_y,length,broken,recoil),surface(hand,angle,end,end_y,length,broken,recoil),Color("5c3b2c"),2.4,false)
	if layer==Layer.REAR:
		return
	_draw_guard(canvas,stats,map,era,kind,quality)
	if broken:
		canvas.draw_polyline(_mapped([Vector2(length-4,-4),Vector2(length,0),Vector2(length-5,1),Vector2(length,4)],hand,angle,length,true,0),Color("e7cb8d"),2,false)
	else:
		if quality>=4:
			_draw_pennon(canvas,stats,map,length,quality,motion_time)
		draw_tip(canvas,surface(hand,angle,length,0,length,false,recoil),angle,mode,kind)

static func _paint(canvas: CanvasItem, stats: Dictionary, map: Callable, start: float, end: float, full_length: float) -> void:
	var quality = clampi(int(stats.get("lance_quality",0)),0,5)
	var kind = str(stats.get("lance_type","standard"))
	var colors = _tinctures(stats)
	var field: Color = colors[0]
	var charge: Color = colors[1]
	if quality==0:
		# Bare ash: one long grain line.
		var grain = PackedVector2Array()
		for i in range(9):
			var d = lerpf(start,end,float(i)/8.0)
			grain.append(map.call(d,radius(stats,d,full_length)*.25))
		canvas.draw_polyline(grain,WOOD.darkened(.22),1.2,false)
		return
	var period = 30.0 if kind=="long" else 24.0
	var d = start
	while d<end-2.0:
		var r = radius(stats,d,full_length)*.96
		var slant = r*2.1
		if quality==1:
			# Painted rings (straight bands).
			_band(canvas,map,d,minf(d+period*.28,end),0.0,r,field)
		elif quality==2:
			_band(canvas,map,d,minf(d+period*.5,end),slant,r,field)
		else:
			_band(canvas,map,d,minf(d+period*.5,end),slant,r,charge)
		d += period
	if kind=="stout" and quality>=2:
		var flute = PackedVector2Array()
		for i in range(17):
			var x = lerpf(start,end,float(i)/16.0)
			flute.append(map.call(x,radius(stats,x,full_length)*.55))
		canvas.draw_polyline(flute,Color(0,0,0,.30),1.8,false)
	if quality>=4:
		for x in [start+2.0,end-18.0]:
			var r = radius(stats,x,full_length)
			_band(canvas,map,x,x+4.0,0.0,r,GILT)

static var _quad_indices = PackedInt32Array([0,1,2,0,2,3])

static func _band(canvas: CanvasItem, map: Callable, a: float, b: float, slant: float, r: float, color: Color) -> void:
	if b-a<.5:
		return
	# Known two-triangle connectivity, like the shaft strip (PERF-084): thin
	# bands must not depend on per-frame ear clipping.
	RenderingServer.canvas_item_add_triangle_array(canvas.get_canvas_item(),_quad_indices,PackedVector2Array([map.call(a,-r),map.call(b,-r),map.call(b+slant,r),map.call(a+slant,r)]),PackedColorArray([color]))

static func _draw_guard(canvas: CanvasItem, stats: Dictionary, map: Callable, era: int, kind: String, quality: int) -> void:
	var size = {"light":.8,"long":.95,"stout":1.2}.get(kind,1.0)
	if era<=0:
		# Early lances: a leather grip and a raised burr ring, no plate.
		var r = 4.6*VISUAL_SCALE*size
		_band(canvas,map,9.0,13.0,0.0,r,Color("6b4a33"))
		canvas.draw_line(map.call(9,-r),map.call(9,r),INK,1.6,false)
		canvas.draw_line(map.call(13,-r),map.call(13,r),INK,1.6,false)
		return
	if era==1:
		# Flat rondel disc seen edge-on.
		var h = 12.0*size+quality*.4
		var plate = PackedVector2Array([map.call(8,-h),map.call(12,-h),map.call(12,h),map.call(8,h)])
		_band(canvas,map,8.0,12.0,0.0,h,DARK_STEEL)
		canvas.draw_line(map.call(10,-h+1),map.call(10,h-1),STEEL,2.0,false)
		plate.append(plate[0])
		canvas.draw_polyline(plate,INK,1.6,false)
		return
	# Cones: small (era 2), large (era 3), fluted with rim (era 4).
	var height = ({2:13.0,3:18.0}.get(era,23.0))*size+quality*.5
	var reach = 16.0 if era==2 else (24.0 if era==3 else 30.0)
	var cone = PackedVector2Array([map.call(8,-height),map.call(8+reach,-5),map.call(10+reach,0),map.call(8+reach,5),map.call(8,height),map.call(5,height-2),map.call(5,-height+2)])
	canvas.draw_colored_polygon(cone,DARK_STEEL)
	canvas.draw_colored_polygon(PackedVector2Array([map.call(8,-height+2),map.call(7+reach,-4),map.call(7+reach,1),map.call(8,height*.25)]),STEEL)
	var outline = cone.duplicate()
	outline.append(cone[0])
	canvas.draw_polyline(outline,INK,1.8,false)
	var rim = GILT if quality>=4 else Color("d6d9cb")
	canvas.draw_line(map.call(7,-height),map.call(7,height),rim,2.4,false)
	if era>=4:
		for offset in [-.62,-.2,.2,.62]:
			canvas.draw_line(map.call(10,height*offset),map.call(6+reach,height*offset*.18),Color(0,0,0,.40),1.4,false)

static func _draw_pennon(canvas: CanvasItem, stats: Dictionary, map: Callable, length: float, quality: int, motion_time: float = 0.0) -> void:
	# A small swallow-tailed pennon streaming back along the upper side of the
	# shaft just behind the head, in the rider's livery. Gentle flutter only.
	var colors = _tinctures(stats)
	var field: Color = colors[0]
	var charge: Color = colors[1]
	var span = 46.0 if quality>=5 else 36.0
	var depth = 15.0 if quality>=5 else 12.0
	var front = length-30.0
	var back = front-span
	# The rider supplies game time, so paused/slow-motion cloth does not jump
	# to wall-clock time when it is drawn again. Inventory defaults to rest.
	var phase = motion_time*6.0
	var wave = func(x: float) -> float: return sin(phase+x*.18)*2.2*clampf((front-x)/span,0,1)
	var top = PackedVector2Array()
	for i in range(6):
		var x = lerpf(front,back,float(i)/5.0)
		top.append(map.call(x,-3.0-depth+wave.call(x)))
	var flag = PackedVector2Array([map.call(front,-3.0)])
	flag.append_array(top)
	flag.append(map.call(back+span*.22,-3.0-depth*.5+wave.call(back)))
	flag.append(map.call(back,-3.0+wave.call(back)))
	canvas.draw_colored_polygon(flag,field)
	if quality>=5:
		# REQ-098: the family choice should also distinguish two families with
		# identical colours (bend/fleur/quartered), not just recolour one stripe.
		var device=pennon_device(str(stats.get("heraldry","bend")))
		for part in ["charges","overlays"]:
			for i in range(device[part].size()):
				var points=PackedVector2Array()
				for point in device[part][i]:
					var x=front-20+point.x*.30
					points.append(map.call(x,-3-depth*.5+point.y*.105+wave.call(x)))
				RenderingServer.canvas_item_add_triangle_array(canvas.get_canvas_item(),device[part+"_triangles"][i],points,PackedColorArray([charge if part=="charges" else field]))
	var edge = flag.duplicate()
	edge.append(flag[0])
	canvas.draw_polyline(edge,INK,1.4,false)

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
		highlight.append(Vector2(x,-r*.45))
	var contour = PackedVector2Array(upper+lower)
	var quality = clampi(int(stats.get("lance_quality",0)),0,5)
	draw_strip(canvas,contour,_fragment_indices,WOOD if quality<3 else Color(_tinctures(stats)[0]).darkened(.05))
	var map = func(d: float, y: float) -> Vector2: return Vector2(d-source_start-half,y)
	_paint(canvas,stats,map,maxf(source_start,24.0),end,full_length)
	contour.append(contour[0])
	canvas.draw_polyline(contour,INK,2.0,false)
	canvas.draw_polyline(highlight,LIGHT_WOOD if quality<3 else Color(1,1,1,.45),1.5,false)
	var break_radius = radius(stats,source_start,full_length)
	for offset in [-.6,0.0,.6]:
		canvas.draw_line(Vector2(-half,offset*break_radius),Vector2(-half-6,offset*break_radius-2),Color("e4c287"),1.5,false)
	if pointed:
		draw_tip(canvas,Vector2(half,0),0,mode,str(stats.get("lance_type","standard")))

static func draw_tip(canvas: CanvasItem, tip: Vector2, angle: float, mode: String, kind: String = "standard") -> void:
	# Maximum forward extent is exactly tip, the same point used by the model.
	var axis = Vector2(cos(angle),sin(angle))
	var normal = Vector2(-axis.y,axis.x)
	var points: Array
	if mode=="war":
		# Leaf-shaped war head with a socket; broader on stout lances.
		var breadth = 5.5 if kind=="light" else (9.0 if kind=="stout" else 7.0)
		points = [Vector2(-26,-2.5),Vector2(-19,-2.5),Vector2(-15,-breadth),Vector2(-7,-breadth*.7),Vector2(0,0),Vector2(-7,breadth*.7),Vector2(-15,breadth),Vector2(-19,2.5),Vector2(-26,2.5)]
	else:
		# Three-prong coronel: blunt crown that spreads the blow.
		points = [Vector2(-22,-4),Vector2(-12,-5),Vector2(-8,-10),Vector2(0,-11),Vector2(-3,-7),Vector2(-1,-4),Vector2(0,-2),Vector2(0,2),Vector2(-1,4),Vector2(-3,7),Vector2(0,11),Vector2(-8,10),Vector2(-12,5),Vector2(-22,4)]
	var vertices = PackedVector2Array()
	for p in points:
		vertices.append(tip+axis*p.x+normal*p.y)
	canvas.draw_colored_polygon(vertices,STEEL)
	vertices.append(vertices[0])
	canvas.draw_polyline(vertices,INK,1.8,false)
	canvas.draw_line(tip-axis*20-normal,tip-axis*4-normal,Color("eef0e0"),1.7,false)
