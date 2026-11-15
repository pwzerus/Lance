extends RefCounted
## EQUIP-066 heraldry: the crest item owns the arms (field tincture + charge),
## so the shield, the caparison and the armoury icon all show the same arms.
## Before, the shield item's regional colour painted the field and the charge
## was a fixed-colour line on top, so "赤地银山形" (red field, silver chevron)
## appeared on a blue shield, and crest icons were blank coloured shields.
##
## Charges are built in shield-local units (outline spans about 80 x 104) and
## clipped to the shield, so they read as heraldry, not as stickers.

const ARMS = {
	"bend":{"field":"27568a","charge":"e2bb4f","name":"蓝地金斜带"},
	"chevron":{"field":"a63a2c","charge":"ece7da","name":"赤地银山形"},
	"cross":{"field":"ece7da","charge":"2f5b86","name":"银地蓝十字"},
	"diamond":{"field":"d9a73a","charge":"2a2620","name":"金地黑菱形"},
	# FEEL-093 (user: more shield patterns). Bold ordinaries and simple
	# charges that stay readable when a shield is 30-80 screen pixels tall.
	"saltire":{"field":"ece7da","charge":"a63a2c","name":"银地红斜十字"},
	"quarterly":{"field":"27568a","charge":"e2bb4f","name":"蓝金四分"},
	"pale":{"field":"a63a2c","charge":"e2bb4f","name":"赤地金竖带"},
	"fess":{"field":"2f6b45","charge":"ece7da","name":"绿地银横带"},
	"chequy":{"field":"ece7da","charge":"2f5b86","name":"蓝银方格"},
	"roundels":{"field":"e2bb4f","charge":"a63a2c","name":"金地三红圆"},
	"chief":{"field":"ece7da","charge":"2a2620","name":"银地黑首三星"},
	"fleur":{"field":"27568a","charge":"e2bb4f","name":"蓝地金百合"}}
## Designs that are not left-right symmetric. Riders facing left are drawn
## mirrored, so these use pre-mirrored cloth ("<design>_l") and mirrored
## charges, keeping dexter chief on the viewer's left either way.
const ASYMMETRIC = ["bend","quarterly","chequy"]

static func mirrored_key(design: String, facing: int) -> String:
	return design+"_l" if facing<0 and design in ASYMMETRIC else design

static func arms(design: String) -> Dictionary:
	return ARMS.get(design,ARMS.bend)

static func field_color(design: String) -> Color:
	return Color(str(arms(design).field))

static func charge_color(design: String) -> Color:
	return Color(str(arms(design).charge))

## Charge polygons in shield-local units. `facing` mirrors the bend so that
## the viewer always sees dexter chief -> sinister base, whichever way the
## rider faces (the battle canvas is mirrored for riders facing left).
static func charge_polygons(design: String, facing: int = 1) -> Array[PackedVector2Array]:
	var result: Array[PackedVector2Array] = []
	match design:
		"chevron":
			result.append(PackedVector2Array([Vector2(-70,52),Vector2(0,-14),Vector2(70,52),Vector2(70,74),Vector2(0,8),Vector2(-70,74)]))
		"cross":
			result.append(PackedVector2Array([Vector2(-70,-14),Vector2(70,-14),Vector2(70,4),Vector2(-70,4)]))
			result.append(PackedVector2Array([Vector2(-9,-80),Vector2(9,-80),Vector2(9,80),Vector2(-9,80)]))
		"diamond":
			result.append(PackedVector2Array([Vector2(0,-32),Vector2(21,-3),Vector2(0,26),Vector2(-21,-3)]))
		"saltire":
			for sign_value in [-1.0,1.0]:
				var start = Vector2(-60*sign_value,-78)
				var end = Vector2(60*sign_value,78)
				var normal = (end-start).normalized().orthogonal()*9.0
				result.append(PackedVector2Array([start+normal,end+normal,end-normal,start-normal]))
		"quarterly":
			result.append(_box(Vector2(-70*facing,-80),Vector2(0,-8)))
			result.append(_box(Vector2(0,-8),Vector2(70*facing,80)))
		"pale":
			result.append(_box(Vector2(-12,-80),Vector2(12,80)))
		"fess":
			result.append(_box(Vector2(-70,-20),Vector2(70,6)))
		"chequy":
			var size = 20.0
			for row in range(-4,4):
				for column in range(-3,3):
					if (row+column)%2==0:
						var corner = Vector2(column*size*facing,row*size)
						result.append(_box(corner,corner+Vector2(size*facing,size)))
		"roundels":
			for center in [Vector2(-16,-24),Vector2(16,-24),Vector2(0,10)]:
				result.append(_circle(center,11.5,14))
		"chief":
			# Three field-coloured mullets sit on it: see overlay_polygons().
			# A chief is about a third of the shield's height.
			result.append(_box(Vector2(-70,-80),Vector2(70,-14)))
		"fleur":
			result.append(PackedVector2Array([Vector2(0,-40),Vector2(7,-30),Vector2(9,-16),Vector2(5,-4),Vector2(-5,-4),Vector2(-9,-16),Vector2(-7,-30)]))
			for sign_value in [-1.0,1.0]:
				result.append(PackedVector2Array([Vector2(4*sign_value,-6),Vector2(12*sign_value,-18),Vector2(22*sign_value,-22),Vector2(29*sign_value,-14),Vector2(26*sign_value,-2),Vector2(17*sign_value,4),Vector2(20*sign_value,-8),Vector2(15*sign_value,-12),Vector2(9*sign_value,-2)]))
				result.append(PackedVector2Array([Vector2(3*sign_value,8),Vector2(12*sign_value,12),Vector2(16*sign_value,20),Vector2(9*sign_value,18),Vector2(3*sign_value,14)]))
			result.append(_box(Vector2(-16,-2),Vector2(16,6)))
			result.append(PackedVector2Array([Vector2(-4,6),Vector2(4,6),Vector2(6,22),Vector2(0,28),Vector2(-6,22)]))
		_:
			var start = Vector2(-60*facing,-78)
			var end = Vector2(60*facing,78)
			var normal = (end-start).normalized().orthogonal()*10.5
			result.append(PackedVector2Array([start+normal,end+normal,end-normal,start-normal]))
	return result

static func _box(a: Vector2, b: Vector2) -> PackedVector2Array:
	var low = Vector2(minf(a.x,b.x),minf(a.y,b.y))
	var high = Vector2(maxf(a.x,b.x),maxf(a.y,b.y))
	return PackedVector2Array([low,Vector2(high.x,low.y),high,Vector2(low.x,high.y)])

static func _circle(center: Vector2, radius: float, sides: int) -> PackedVector2Array:
	var points = PackedVector2Array()
	for i in range(sides):
		points.append(center+Vector2.from_angle(TAU*i/sides)*radius)
	return points

## Small field-coloured marks drawn ON TOP of a charge (the mullets on the
## chief). Shield-local units, same clipping as charges.
static func overlay_polygons(design: String) -> Array[PackedVector2Array]:
	var result: Array[PackedVector2Array] = []
	if design=="chief":
		for x in [-21.0,0.0,21.0]:
			result.append(_star(Vector2(x,-29),9.0,3.8))
	return result

## Point test in shield-local units (outline about 80 x 104): inside a charge
## and not under an overlay. Used by the cloth bakers (surcoats, caparisons).
static func charge_contains(design: String, local: Vector2, facing: int = 1) -> bool:
	for polygon in overlay_polygons(design):
		if Geometry2D.is_point_in_polygon(local,polygon):
			return false
	for polygon in charge_polygons(design,facing):
		if Geometry2D.is_point_in_polygon(local,polygon):
			return true
	return false

static func _star(center: Vector2, outer: float, inner: float) -> PackedVector2Array:
	var points = PackedVector2Array()
	for i in range(10):
		var radius = outer if i%2==0 else inner
		points.append(center+Vector2.from_angle(-PI/2+TAU*i/10.0)*radius)
	return points

## Clip each charge to `outline` (shield-local, already scaled) and return the
## pieces, still in shield-local units.
static func clipped_charges(design: String, outline: PackedVector2Array, scale: float, facing: int = 1) -> Array[PackedVector2Array]:
	var pieces: Array[PackedVector2Array] = []
	for polygon in charge_polygons(design,facing):
		var scaled = PackedVector2Array()
		for point in polygon:
			scaled.append(point*scale)
		for piece in Geometry2D.intersect_polygons(outline,scaled):
			if piece.size()>=3:
				pieces.append(piece)
	return pieces
