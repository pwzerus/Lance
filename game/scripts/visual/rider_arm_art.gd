extends RefCounted
## Dedicated anatomical left/right sleeves and grips; source pixels measured
## from arms_atlas.png. The source sheet is retained without destructive edits.
const ATLAS = preload("res://assets/art/pixel_v047/arms_atlas.png")
const PARTS = {
	"left_upper": {"region":Rect2(248,90,272,505),"a":Vector2(385,225),"b":Vector2(398,540),"width":250.0},
	"right_upper": {"region":Rect2(729,90,280,510),"a":Vector2(873,225),"b":Vector2(856,540),"width":250.0},
	"left_forearm": {"region":Rect2(32,610,555,255),"a":Vector2(150,745),"b":Vector2(536,776),"width":214.0},
	"right_forearm": {"region":Rect2(684,621,511,243),"a":Vector2(780,747),"b":Vector2(1130,779),"width":214.0},
	"left_hand": {"region":Rect2(130,925,401,249),"a":Vector2(201,1077),"b":Vector2(447,1054),"width":226.0},
	"right_hand": {"region":Rect2(717,960,420,222),"a":Vector2(790,1074),"b":Vector2(1000,1075),"width":210.0}
}

static func draw_segment(canvas: CanvasItem, part: String, start: Vector2, end: Vector2, width: float, tint: Color, mirror_cross: bool = false) -> void:
	var data: Dictionary = PARTS[part]
	var source: Rect2 = data.region
	var source_axis: Vector2 = (data.b-data.a).normalized()
	var source_side = Vector2(-source_axis.y,source_axis.x)
	var axis = (end-start).normalized()
	var side = Vector2(-axis.y,axis.x)*(-1 if mirror_cross else 1)
	var longitudinal = start.distance_to(end)/(data.b-data.a).length()
	var thickness = width/float(data.width)
	var points = PackedVector2Array()
	var uv = PackedVector2Array()
	for corner in [source.position,Vector2(source.end.x,source.position.y),source.end,Vector2(source.position.x,source.end.y)]:
		var relative: Vector2 = corner-data.a
		points.append(start+axis*relative.dot(source_axis)*longitudinal+side*relative.dot(source_side)*thickness)
		uv.append(corner/ATLAS.get_size())
	canvas.draw_polygon(points,PackedColorArray([tint]),uv,ATLAS)
