extends RefCounted
## Rendering-only registration. Coordinates are in the rider's head-facing
## torso space; the combat head anchor remains (0,-111).
const Art = preload("res://scripts/visual/equipment_art.gd")
const Face = preload("res://scripts/visual/character_face.gd")
const DATA_PATH = "res://data/equipment_fit_v052.json"
static var _data: Dictionary = {}
# Width/height factors for the helmets that read widest (equip067-helmets01).
const SLIM = {
	"fr_helmet_4":Vector2(.84,.95),  # short-tail sallet, 77 px wide
	"it_helmet_0":Vector2(.87,.94),  # nasal helm over a full mail hood
	"eng_helmet_4":Vector2(.89,.95), "eng_helmet_5":Vector2(.89,.95),  # Greenwich close helmets
	# Great helms ("bucket" helms). ART-090: user still found them too wide at
	# .90; a great helm sits close over a padded arming cap, about as wide as
	# the neck-and-shoulder line, so .78 with the lower edge kept in place.
	"eng_helmet_1":Vector2(.78,.95), "eng_helmet_2":Vector2(.78,.95), "fr_helmet_1":Vector2(.78,.95), "de_helmet_1":Vector2(.78,.95),
	"fr_helmet_0":Vector2(.95,.97)}  # kettle hat: the brim is meant to be wide
static var _loaded = false
const FACE_ASPECT = .80   # the face grid is 32 x 40 cells
const NOSE_COLUMN = .64   # nose bridge column 20.5 of 32

static func face_clip_polygon(clip: Rect2, face: Rect2) -> PackedVector2Array:
	# The fitted back/top/collar limits stay exactly as calibrated per helmet
	# (they keep hair inside the skull and the chin off the breastplate). The
	# FRONT is opened past the nose, and the lower front corner follows a jaw
	# line instead of a square cut.
	var right = maxf(clip.end.x,face.end.x+6.0)
	var jaw = minf(clip.size.y*.24,13.0)
	# Keep the jaw corner right of the back corner so a narrow clip cannot
	# fold the polygon over itself.
	jaw = clampf(minf(jaw,(right-clip.position.x-6.0)/1.4),0.0,jaw)
	return PackedVector2Array([clip.position,Vector2(right,clip.position.y),Vector2(right,clip.end.y-jaw),
		Vector2(right-jaw*1.4,clip.end.y),Vector2(clip.position.x+5.0,clip.end.y),Vector2(clip.position.x,clip.end.y-5.0)])
# Layout depends only on the two equipment art IDs, never on pose/appearance.
# Bounded shared read-only data; live head/neck transforms still run each frame.
static var _layouts: Dictionary = {}
const MAX_LAYOUTS = 64

static func layout(stats: Dictionary) -> Dictionary:
	if not _loaded:
		_loaded = true
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
		if parsed is Dictionary:
			_data = parsed
	var key = str(stats.get("helmet_art",""))+"/"+str(stats.get("armor_art",""))
	if _layouts.has(key): return _layouts[key]
	var id = str(stats.get("helmet_art",""))
	var entry = Art.descriptor(stats,"helmet")
	var fit: Dictionary = _data.get(id,{})
	var size: Array = fit.get("size",[62.0,72.0])
	var offset: Array = fit.get("offset",[0.0,-147.0])
	# EQUIP-067: the user found some helmets "fat". At 62-77 px wide a head was
	# about 2/3 of the shoulders; slim all helmets a little and the widest more,
	# keeping each helmet's lower edge (neck and collar joint) where it was.
	var slim = SLIM.get(id,Vector2(.93,.95))
	var width = float(size[0])*slim.x
	var height = float(size[1])*slim.y
	var box = Rect2(float(offset[0])-width*.5,float(offset[1])+float(size[1])-height,width,height)
	var face: Array = fit.get("face",entry.get("face_rect",[.2,.22,.6,.72]))
	var face_raw = Rect2(box.position+Vector2(float(face[0]),float(face[1]))*box.size,Vector2(float(face[2]),float(face[3]))*box.size)
	# PHYS-114 (user: "a short rectangular head"): the 32x40 face grid had
	# been stretched into boxes about as wide as tall (aspect ~1.0 instead of
	# .8), and a rectangular clip cut the nose and chin flat. Keep each fit's
	# height and nose position (the helmet's aperture registration) and give
	# the face its own proportions.
	var face_width = minf(face_raw.size.x,face_raw.size.y*FACE_ASPECT)
	var nose_x = face_raw.position.x+face_raw.size.x*NOSE_COLUMN
	var face_box = Rect2(Vector2(nose_x-face_width*NOSE_COLUMN,face_raw.position.y),Vector2(face_width,face_raw.size.y))
	var clip: Array = fit.get("face_clip",[-26.0,-144.0,59.0,54.0])
	var clip_rect = Rect2(float(clip[0]),float(clip[1]),float(clip[2]),float(clip[3]))
	var collar: Dictionary = _data.get("_collars",{}).get(str(stats.get("armor_art","")),{"center":[4,-83],"width":26,"lip_y":-83})
	var result = {"helmet":box,"face":face_box,"face_clip":clip_rect,"clip_polygon":face_clip_polygon(clip_rect,face_box),
		"coif":bool(fit.get("coif",false)),
		"collar":collar,"head_offset":float(collar.center[0]),"neck_x":float(fit.get("neck_x",3.0)),"open":bool(entry.get("open_face",false)),"authored":not entry.is_empty()}
	result.make_read_only()
	if _layouts.size()>=MAX_LAYOUTS: _layouts.erase(_layouts.keys()[0])
	_layouts[key]=result
	return result

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
