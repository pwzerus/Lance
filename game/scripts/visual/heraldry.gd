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
	"diamond":{"field":"d9a73a","charge":"2a2620","name":"金地黑菱形"}}

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
		_:
			var start = Vector2(-60*facing,-78)
			var end = Vector2(60*facing,78)
			var normal = (end-start).normalized().orthogonal()*10.5
			result.append(PackedVector2Array([start+normal,end+normal,end-normal,start-normal]))
	return result

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
