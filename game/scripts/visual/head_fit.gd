extends RefCounted
## Rendering-only registration. Coordinates are in the rider's head-facing
## torso space; the combat head anchor remains (0,-111).
const Art = preload("res://scripts/visual/equipment_art.gd")
const Face = preload("res://scripts/visual/character_face.gd")
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
	var collar: Dictionary = _data.get("_collars",{}).get(str(stats.get("armor_art","")),{"center":[4,-83],"width":26,"lip_y":-83})
	return {"helmet":box,"face":face_box,"face_clip":Rect2(float(clip[0]),float(clip[1]),float(clip[2]),float(clip[3])),
		"collar":collar,"head_offset":float(collar.center[0]),"neck_x":float(fit.get("neck_x",3.0)),"open":bool(entry.get("open_face",false)),"authored":not entry.is_empty()}

static func draw_neck(canvas: CanvasItem, fit: Dictionary, appearance: Dictionary, facing: int) -> void:
	# Draw in TORSO space. The top turns with the head, while the root stays
	# inside the chest's asymmetric collar socket on both rider facings.
	var collar: Dictionary = fit.collar
	var center: Array = collar.center
	var base = Vector2(float(center[0]),float(center[1])+2.0)
	var half_width = float(collar.width)*.5
	var face: Rect2 = fit.face
	var top = Vector2((face.position.x+face.size.x*.515-3.0)*facing+float(fit.head_offset),face.position.y+face.size.y*.69)
	var neck_half = face.size.x*.14
	if not bool(fit.open):
		top = Vector2(float(fit.neck_x)*facing+float(fit.head_offset),-101)
		neck_half = 8.0
	# A low face aperture must not invert the small neck polygon on high collars.
	top.y = minf(top.y,base.y-6.0)
	var a = Face.Appearance.sanitize(appearance)
	var skin: Color = Face.SKIN[a.skin]
	var material = skin.darkened(.17) if bool(fit.open) else Color("51595d")
	var shadow = skin.darkened(.39) if bool(fit.open) else Color("353d42")
	var outline = Color("302a28")
	# Short neck and flared base, buried behind the original front collar lip.
	canvas.draw_colored_polygon(PackedVector2Array([top+Vector2(-neck_half-1,-3),top+Vector2(neck_half+1,-3),base+Vector2(half_width-3,-4),base+Vector2(half_width,0),base+Vector2(-half_width,0),base+Vector2(-half_width+3,-4)]),outline)
	canvas.draw_colored_polygon(PackedVector2Array([top+Vector2(-neck_half,-3),top+Vector2(neck_half,-3),base+Vector2(half_width-4,-4),base+Vector2(half_width-2,-1),base+Vector2(-half_width+2,-1),base+Vector2(-half_width+4,-4)]),material)
	canvas.draw_colored_polygon(PackedVector2Array([top+Vector2(-neck_half,-2),top+Vector2(-neck_half+4,-2),base+Vector2(-half_width+6,-1),base+Vector2(-half_width+2,-1)]),shadow)
	# Under-jaw occlusion shares the face's skin palette, not a grey peg.
	canvas.draw_line(top+Vector2(-neck_half,-1),top+Vector2(neck_half,-1),shadow,2)

static func draw_collar_lip(canvas: CanvasItem, fit: Dictionary, texture: Texture2D, deform: Callable) -> void:
	# Restore real chest pixels in front of the neck root. Never paint a new
	# generic ring over the material, and do not mirror the torso's UV space.
	var collar: Dictionary = fit.collar
	var center: Array = collar.center
	var x = float(center[0])
	var width = float(collar.width)*.5+3
	var y = float(collar.lip_y)
	var points = PackedVector2Array([Vector2(x-width,y),Vector2(x+width,y),Vector2(x+width,y+7),Vector2(x-width,y+7)])
	var uv = PackedVector2Array()
	for p in points:
		uv.append((p-Vector2(-47,-94))/Vector2(94,104))
	for i in range(points.size()):
		points[i] = deform.call(points[i])
	canvas.draw_polygon(points,PackedColorArray([Color.WHITE]),uv,texture)
