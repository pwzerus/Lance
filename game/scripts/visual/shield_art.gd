extends RefCounted
## One shield face drawer shared by the battle RiderView and the armoury icons.
##
## REQ-098: alternating light/heavy lines use leather/planks versus iron
## strips, thick rims and hammered facing. Existing EQUIP-066 family arms
## remain authoritative until the user confirms the new crest-slot role.
## HORSE-065 had used field divisions (per pale, quartered, chief) for
## quality; those are heraldic statements and fought with the crest.
## Shape still varies by era through stats.shield_shape.
const Shield = preload("res://scripts/core/shield_geometry.gd")
const Heraldry = preload("res://scripts/visual/heraldry.gd")

# The projected face still moves every frame; only equipment-local clipping
# is immutable. Keep a small bounded cache across battle and armoury views.
static var _geometry: Dictionary = {}
const MAX_GEOMETRY = 48

static func geometry(shape: String, design: String, scale: float, facing: int) -> Dictionary:
	var key = [shape,design,scale,facing]
	if _geometry.has(key): return _geometry[key]
	var outline = Shield.outline(shape)
	var face = _scaled(outline,.87*scale)
	var planks: Array[PackedVector2Array] = []
	for x in [-14.0,6.0,24.0]:
		planks.append_array(Geometry2D.intersect_polyline_with_polygon(PackedVector2Array([Vector2(x,-70)*scale,Vector2(x+3,70)*scale]),face))
	# FEEL-093: painted diaper (damask lattice) in the field of better shields,
	# a common medieval way of enriching a plain field without changing arms.
	var diaper: Array[PackedVector2Array] = []
	var dots = PackedVector2Array()
	var spacing = 13.0
	for k in range(-9,10):
		for slope in [1.0,-1.0]:
			var line = PackedVector2Array([Vector2(k*spacing-90*slope,-90)*scale,Vector2(k*spacing+90*slope,90)*scale])
			diaper.append_array(Geometry2D.intersect_polyline_with_polygon(line,face))
		for j in range(-8,9):
			var point = Vector2(k*spacing+(spacing*.5 if j%2!=0 else 0.0),j*spacing*.5)*scale
			if Geometry2D.is_point_in_polygon(point,_scaled(outline,.80*scale)):
				dots.append(point)
	var overlays: Array[PackedVector2Array] = []
	var bands: Array[PackedVector2Array] = []
	for y in [-23.0,19.0]:
		bands.append_array(Geometry2D.intersect_polyline_with_polygon(PackedVector2Array([Vector2(-70,y)*scale,Vector2(70,y)*scale]),face))
	for polygon in Heraldry.overlay_polygons(design):
		var scaled = PackedVector2Array()
		for point in polygon:
			scaled.append(point*scale)
		for piece in Geometry2D.intersect_polygons(face,scaled):
			if piece.size()>=3: overlays.append(piece)
	var result = {"outline":outline,"face":face,"outer":_scaled(outline,scale),"charges":Heraldry.clipped_charges(design,face,scale,facing),"planks":planks,
		"diaper":diaper,"dots":dots,"overlays":overlays,"bands":bands}
	result.make_read_only()
	if _geometry.size()>=MAX_GEOMETRY: _geometry.erase(_geometry.keys()[0])
	_geometry[key]=result
	return result

static func _map(point: Vector2, projected: bool) -> Vector2:
	return Shield.project(point) if projected else point

static func _mapped(points: PackedVector2Array, center: Vector2, projected: bool, shift: Vector2) -> PackedVector2Array:
	var result = PackedVector2Array()
	for point in points:
		result.append(center+_map(point,projected)+shift)
	return result

static func draw(canvas: CanvasItem, stats: Dictionary, center: Vector2, projected: bool, tint: Color = Color.WHITE, recoil: float = 0.0, scale: float = 1.0, facing: int = 1, condition: float = 1.0) -> void:
	scale *= float(stats.get("shield_scale",1.0))
	var shape = str(stats.get("shield_shape","kite"))
	var quality = int(stats.get("shield_quality",0))
	var heavy = str(stats.get("shield_class",""))=="heavy"
	var light = str(stats.get("shield_class",""))=="light"
	var tier = int(stats.get("shield_line_tier",1))
	var has_arms = stats.has("heraldry")
	var design = str(stats.get("heraldry","bend"))
	var prepared = geometry(shape,design,scale,facing)
	var outline: PackedVector2Array = prepared.outline
	var field = Heraldry.field_color(design) if has_arms else Color(str(stats.get("shield_color","27568a")))
	if heavy and tier==3:
		# Thin paint over a complete iron facing; the highlights and hammered
		# groups distinguish the plate from the lower tier's exposed planks.
		field = field.lerp(Color("76888b"),.58)
	var shift = Vector2(-2.5,0)*recoil
	var face_local: PackedVector2Array = prepared.face
	var outer = _mapped(prepared.outer,center,projected,Vector2.ZERO)
	var inner = _mapped(face_local,center,projected,shift)
	canvas.draw_colored_polygon(outer,Color("292b25"))
	canvas.draw_colored_polygon(inner,field*tint)
	if heavy and tier==3:
		var sheen = PackedVector2Array([Vector2(-17,-31),Vector2(-20,-8),Vector2(-15,18)])
		canvas.draw_polyline(_mapped(_scaled(sheen,scale),center,projected,shift),field.lightened(.34)*tint,maxf(1,2*scale))
	if (light and tier==1) or heavy or (not light and quality<=1):
		# Painted planks show through on the cheap shields only.
		for piece in prepared.planks:
			canvas.draw_polyline(_mapped(piece,center,projected,shift),field.darkened(.16)*tint,maxf(1.0,1.2*scale))
	if (light and tier>=2) or (not light and not heavy and quality>=2):
		var lattice = field.darkened(.16) if field.get_luminance()>.35 else field.lightened(.14)
		for piece in prepared.diaper:
			canvas.draw_polyline(_mapped(piece,center,projected,shift),lattice*tint,maxf(1.0,1.0*scale))
		if quality>=4:
			var dot = Color("e8c862") if quality>=5 else field.lightened(.30)
			for point in prepared.dots:
				canvas.draw_rect(Rect2(center+_map(point,projected)+shift-Vector2(1,1)*scale,Vector2(2,2)*scale),dot*tint)
	if has_arms:
		for piece in prepared.charges:
			var mapped = _mapped(piece,center,projected,shift)
			canvas.draw_colored_polygon(mapped,Heraldry.charge_color(design)*tint)
			var edge = mapped.duplicate()
			edge.append(mapped[0])
			canvas.draw_polyline(edge,Color(0,0,0,.42)*tint,maxf(1.0,1.1*scale))
		for piece in prepared.overlays:
			var mapped = _mapped(piece,center,projected,shift)
			canvas.draw_colored_polygon(mapped,field*tint)
	if heavy:
		# Reinforced transverse strips and rivets distinguish construction,
		# not just colour. Top iron-faced shields retain hammered pixel groups.
		for band in prepared.bands:
			var mapped=_mapped(band,center,projected,shift)
			canvas.draw_polyline(mapped,Color("222d2c")*tint,6.0*scale)
			canvas.draw_polyline(mapped,Color("778783")*tint,3.0*scale)
			for end in [mapped[0],mapped[-1]]:
				canvas.draw_rect(Rect2(end-Vector2.ONE*1.4*scale,Vector2.ONE*2.8*scale),Color("cad0be")*tint)
		if tier==3:
			for point in prepared.dots:
				canvas.draw_rect(Rect2(center+_map(point,projected)+shift,Vector2(2,1)*scale),Color(.8,.85,.8,.22)*tint)
	if quality>=5:
		# Thin gilt fillet inside the rim; decoration, not a heraldic bordure.
		var fillet = _mapped(_scaled(outline,.80*scale),center,projected,shift)
		fillet.append(fillet[0])
		canvas.draw_polyline(fillet,Color("e8c862")*tint,maxf(1.0,1.2*scale))
	var rim = inner.duplicate()
	rim.append(inner[0])
	var rim_colors = [Color("7a5f3f"),Color("c2a675"),Color("8f959b"),Color("9aa1a7"),Color("b99a52"),Color("e0bb4c")]
	var rim_widths = [2.5,4.0,3.5,3.5,3.5,4.0]
	if light:
		rim_colors = [Color("806040"),Color("806040"),Color("9c7851"),Color("9c7851"),Color("b49568"),Color("b49568")]
		rim_widths = [2.0,2.0,2.0,2.0,2.5,2.5]
	elif heavy:
		rim_colors = [Color("83908a"),Color("83908a"),Color("9aa69e"),Color("9aa69e"),Color("b8c2b8"),Color("b8c2b8")]
		rim_widths = [5.0,5.0,5.5,5.5,6.0,6.0]
	canvas.draw_polyline(rim,rim_colors[clampi(quality,0,5)]*tint,maxf(2.0,rim_widths[clampi(quality,0,5)]*scale))
	if quality==1:
		for corner in [inner[0],inner[1]]:
			canvas.draw_rect(Rect2(corner-Vector2(1.5,1.5)*scale,Vector2(3,3)*scale),Color("4a4036")*tint)
	if quality>=3:
		var stud = Color("d9dde0") if quality==3 else (Color("e6d08a") if quality==4 else Color("fff0a8"))
		for i in range(inner.size()):
			var a = inner[i]
			var b = inner[(i+1)%inner.size()]
			for t in ([0.0,.5] if a.distance_to(b)>22.0*scale else [0.0]):
				canvas.draw_rect(Rect2(a.lerp(b,t)-Vector2(1.5,1.5)*scale,Vector2(3,3)*scale),stud*tint)
	if quality>=2:
		var boss = center+_map(Vector2(0,-4)*scale,projected)+shift
		var metal = Color("9fa3a0") if quality<4 else (Color("c9a85a") if quality==4 else Color("e7c55a"))
		canvas.draw_circle(boss,7.0*scale,Color("2c2a26")*tint)
		canvas.draw_circle(boss,5.5*scale,metal*tint)
		if quality>=4:
			canvas.draw_arc(boss,3.6*scale,0,TAU,12,metal.darkened(.35)*tint,maxf(1.0,1.0*scale))
		canvas.draw_circle(boss+Vector2(-1.6,-1.6)*scale,1.8*scale,Color("f4f2e8")*tint)
	if condition<.55:
		# Damage stays on the shield face, inside every supported silhouette.
		# No new texture or global cache entry for each durability value.
		var cracks = [PackedVector2Array([Vector2(-13,-28),Vector2(-5,-14),Vector2(-10,-2),Vector2(2,10),Vector2(-3,28)])]
		if condition<.30:
			cracks.append(PackedVector2Array([Vector2(2,10),Vector2(14,15),Vector2(11,27)]))
			cracks.append(PackedVector2Array([Vector2(-5,-14),Vector2(7,-22),Vector2(12,-31)]))
		for crack in cracks:
			var line=_mapped(_scaled(crack,scale),center,projected,shift)
			canvas.draw_polyline(line,Color("151d1b")*tint,maxf(1.0,2.4*scale))

static func _scaled(points: PackedVector2Array, factor: float) -> PackedVector2Array:
	var result = PackedVector2Array()
	for point in points:
		result.append(point*factor)
	return result
