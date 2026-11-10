extends RefCounted
## Temporary diagnostic copy lives under scripts/visual only in a probe pack.
## One latest submission, no retained stream or geometry changes.
static var output_path=""
static var failures=0
static var inspected=0
static var last_tag=""
static var last_points=PackedVector2Array()
static var last_canvas=""
static func capture_submission(tag: String, canvas: CanvasItem, points: PackedVector2Array) -> void:
	last_tag=tag
	last_points=points
	last_canvas=canvas.get_script().resource_path
	inspected+=1
	if not Geometry2D.triangulate_polygon(points).is_empty(): return
	failures+=1
	if failures>8 or output_path.is_empty(): return
	var file=FileAccess.open(output_path,FileAccess.READ_WRITE if FileAccess.file_exists(output_path) else FileAccess.WRITE)
	file.seek_end()
	file.store_line(JSON.stringify(snapshot()))
static func snapshot() -> Dictionary:
	var vertices=[]
	for point in last_points: vertices.append([point.x,point.y])
	return {"tag":last_tag,"canvas_script":last_canvas,"points":vertices}
static func colored(tag: String, canvas: CanvasItem, points: PackedVector2Array, color: Color) -> void:
	capture_submission(tag,canvas,points)
	canvas.draw_colored_polygon(points,color)
static func textured(tag: String, canvas: CanvasItem, points: PackedVector2Array, colors: PackedColorArray, uvs: PackedVector2Array=PackedVector2Array(), texture: Texture2D=null) -> void:
	capture_submission(tag,canvas,points)
	canvas.draw_polygon(points,colors,uvs,texture)
