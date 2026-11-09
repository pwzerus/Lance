extends RefCounted
## One shield face drawer shared by the battle RiderView and the armoury icons.
##
## EQUIP-066: the crest owns the arms. Field tincture and charge come from
## Heraldry (stats.heraldry); the shield item decides only how the shield is
## BUILT, so arms stay the same on every shield the player owns while quality
## remains readable at icon size:
##  q0 painted planks, wooden rim          q1 rawhide-bound edge, corner nails
##  q2 iron rim and iron boss              q3 + riveted rim
##  q4 latten (brass) rim, studs, rosette  q5 gilt rim, studs, boss and fillet
## HORSE-065 had used field divisions (per pale, quartered, chief) for
## quality; those are heraldic statements and fought with the crest.
## Shape still varies by era through stats.shield_shape.
const Shield = preload("res://scripts/core/shield_geometry.gd")
const Heraldry = preload("res://scripts/visual/heraldry.gd")

static func _map(point: Vector2, projected: bool) -> Vector2:
	return Shield.project(point) if projected else point

static func _mapped(points: PackedVector2Array, center: Vector2, projected: bool, shift: Vector2) -> PackedVector2Array:
	var result = PackedVector2Array()
	for point in points:
		result.append(center+_map(point,projected)+shift)
	return result

static func draw(canvas: CanvasItem, stats: Dictionary, center: Vector2, projected: bool, tint: Color = Color.WHITE, recoil: float = 0.0, scale: float = 1.0, facing: int = 1) -> void:
	var outline = Shield.outline(str(stats.get("shield_shape","kite")))
	var quality = int(stats.get("shield_quality",0))
	var has_arms = stats.has("heraldry")
	var design = str(stats.get("heraldry","bend"))
	var field = Heraldry.field_color(design) if has_arms else Color(str(stats.get("shield_color","27568a")))
	var shift = Vector2(-2.5,0)*recoil
	var face_local = _scaled(outline,.87*scale)
	var outer = _mapped(_scaled(outline,scale),center,projected,Vector2.ZERO)
	var inner = _mapped(face_local,center,projected,shift)
	canvas.draw_colored_polygon(outer,Color("292b25"))
	canvas.draw_colored_polygon(inner,field*tint)
	if quality<=1:
		# Painted planks show through on the cheap shields only.
		for x in [-14.0,6.0,24.0]:
			var plank = Geometry2D.intersect_polyline_with_polygon(PackedVector2Array([Vector2(x,-70)*scale,Vector2(x+3,70)*scale]),face_local)
			for piece in plank:
				canvas.draw_polyline(_mapped(piece,center,projected,shift),field.darkened(.16)*tint,maxf(1.0,1.2*scale))
	if has_arms:
		for piece in Heraldry.clipped_charges(design,face_local,scale,facing):
			var mapped = _mapped(piece,center,projected,shift)
			canvas.draw_colored_polygon(mapped,Heraldry.charge_color(design)*tint)
			var edge = mapped.duplicate()
			edge.append(mapped[0])
			canvas.draw_polyline(edge,Color(0,0,0,.42)*tint,maxf(1.0,1.1*scale))
	if quality>=5:
		# Thin gilt fillet inside the rim; decoration, not a heraldic bordure.
		var fillet = _mapped(_scaled(outline,.80*scale),center,projected,shift)
		fillet.append(fillet[0])
		canvas.draw_polyline(fillet,Color("e8c862")*tint,maxf(1.0,1.2*scale))
	var rim = inner.duplicate()
	rim.append(inner[0])
	var rim_colors = [Color("7a5f3f"),Color("c2a675"),Color("8f959b"),Color("9aa1a7"),Color("b99a52"),Color("e0bb4c")]
	var rim_widths = [2.5,4.0,3.5,3.5,3.5,4.0]
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

static func _scaled(points: PackedVector2Array, factor: float) -> PackedVector2Array:
	var result = PackedVector2Array()
	for point in points:
		result.append(point*factor)
	return result
