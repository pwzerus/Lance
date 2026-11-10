extends RefCounted
static var recorded=0
static var inspected=0
static func inspect(canvas: CanvasItem, points: PackedVector2Array) -> void:
	inspected+=1
	if recorded>=24 or not Geometry2D.triangulate_polygon(points).is_empty(): return
	recorded+=1
	var vertices=[]
	for point in points: vertices.append([point.x,point.y])
	var path="E:/GALUMU/docs/development/logs/perf083-polyprobe01-errors.jsonl"
	var output=FileAccess.open(path,FileAccess.READ_WRITE if FileAccess.file_exists(path) else FileAccess.WRITE)
	output.seek_end()
	output.store_line(JSON.stringify({"script":canvas.get_script().resource_path,"points":vertices,"stack":get_stack(),"frame":Engine.get_process_frames()}))
	output.close()
static func colored(canvas: CanvasItem, points: PackedVector2Array, color: Color) -> void:
	inspect(canvas,points)
	canvas.draw_colored_polygon(points,color)
static func textured(canvas: CanvasItem, points: PackedVector2Array, colors: PackedColorArray, uvs: PackedVector2Array=PackedVector2Array(), texture: Texture2D=null) -> void:
	inspect(canvas,points)
	canvas.draw_polygon(points,colors,uvs,texture)
