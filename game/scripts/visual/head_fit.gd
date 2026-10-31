extends RefCounted
## Rendering-only registration. Coordinates are in the rider's head-facing
## torso space; the combat head anchor remains (0,-111).
const Art = preload("res://scripts/visual/equipment_art.gd")
const DATA_PATH = "res://data/equipment_fit_v052.json"
static var _data: Dictionary = {}
static var _loaded = false

static func layout(stats: Dictionary) -> Dictionary:
	if not _loaded:
		_loaded = true
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
		if parsed is Dictionary:
			_data = parsed
	var id = str(stats.get("helmet_art",""))
	var entry = Art.descriptor(stats,"helmet")
	var fit: Dictionary = _data.get(id,{})
	var size: Array = fit.get("size",[62.0,72.0])
	var offset: Array = fit.get("offset",[0.0,-147.0])
	var box = Rect2(float(offset[0])-float(size[0])*.5,float(offset[1]),float(size[0]),float(size[1]))
	var face: Array = fit.get("face",entry.get("face_rect",[.2,.22,.6,.72]))
	var face_box = Rect2(box.position+Vector2(float(face[0]),float(face[1]))*box.size,Vector2(float(face[2]),float(face[3]))*box.size)
	var clip: Array = fit.get("face_clip",[-26.0,-144.0,59.0,54.0])
	return {"helmet":box,"face":face_box,"face_clip":Rect2(float(clip[0]),float(clip[1]),float(clip[2]),float(clip[3])),
		"neck_x":float(fit.get("neck_x",3.0)),"open":bool(entry.get("open_face",false)),"authored":not entry.is_empty()}

static func draw_neck(canvas: CanvasItem, fit: Dictionary, front: bool = false) -> void:
	# An arming collar is behind BOTH the cuirass and the head. The same
	# transform drives the whole junction, including detached riders.
	var x = float(fit.neck_x)
	var outline = Color("282d30")
	var cloth = Color("51595d")
	var shade = Color("353d42")
	if front:
		# The source cuirasses contain an opaque dark collar opening. Fill only
		# its upper socket; leave the front lip and chest pixels in front.
		canvas.draw_colored_polygon(PackedVector2Array([Vector2(x-8,-103),Vector2(x+8,-103),Vector2(x+9,-89),Vector2(x+6,-87),Vector2(x-7,-88)]),outline)
		canvas.draw_colored_polygon(PackedVector2Array([Vector2(x-6,-102),Vector2(x+6,-102),Vector2(x+7,-90),Vector2(x-5,-90)]),cloth)
		canvas.draw_rect(Rect2(x-6,-101,3,11),shade)
		canvas.draw_line(Vector2(x-4,-94),Vector2(x+6,-93),Color("6c7475"),1)
		return
	canvas.draw_colored_polygon(PackedVector2Array([Vector2(x-9,-103),Vector2(x+10,-103),Vector2(x+12,-85),Vector2(x+20,-77),Vector2(x-19,-77),Vector2(x-11,-85)]),outline)
	canvas.draw_colored_polygon(PackedVector2Array([Vector2(x-7,-101),Vector2(x+8,-101),Vector2(x+10,-84),Vector2(x+16,-79),Vector2(x-15,-79),Vector2(x-9,-85)]),cloth)
	canvas.draw_rect(Rect2(x-7,-100,4,17),shade)
	for y in [-95,-90,-85]:
		canvas.draw_line(Vector2(x-5,y),Vector2(x+8,y+1),Color("6c7475"),1)
