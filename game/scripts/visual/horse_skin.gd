extends RefCounted
## One continuous coat from muzzle to hooves. Bone landmarks are measured on
## the complete v050 plate; front and hind limbs have separate anatomy.
## ART-063: the four coats are repainted from that one master plate
## (tools/horse_coat_v063.gd) and share its exact alignment. UVs stay in the
## 1536x1024 source space, independent of the 1024x683 runtime size.
const SOURCE_TEXTURE_SIZE = Vector2(1536,1024)
const COAT_DIR = "res://assets/art/horse_coats063/"
const COAT_KEYS = ["bay","grey","flaxen","black"]
# The plate is drawn at .18-.45 of its source size (camera .68-1.65). Nearest
# sampling without mipmaps skipped 2-5 texels per screen pixel, so fine coat
# strokes aliased into crawling crack patterns. Coats are mip-mapped and
# linearly filtered; mounted_pixel still cuts the silhouette at alpha .5.
static var _coat_cache: Dictionary = {}
var coat: Texture2D = coat_texture("bay")
const Gait = preload("res://scripts/visual/horse_gait.gd")
const PIVOT = Vector2(-18,-168)
const SOURCE_SADDLE = Vector2(749,326)
const SCALE = 180.0/666.0
const SOURCE_BOUNDS = Rect2(64,8,1436,986)
# hip/shoulder, stifle/elbow, hock/carpus, fetlock, coronet, sole. The
# coronet (v050 landmark) lets a planted hoof stay flat while the fetlock sinks.
const HIND = [Vector2(450,400),Vector2(500,560),Vector2(322,730),Vector2(330,891),Vector2(364,940),Vector2(376,986)]
const FORE = [Vector2(1080,450),Vector2(1011,585),Vector2(1013,752),Vector2(1009,902),Vector2(1036,948),Vector2(1056,992)]
# Far legs: only the limb itself plus a root buried under the trunk. The old
# rectangle also carried the chest front and belly edge, which swung out with
# the far foreleg as a dark sliver in front of the chest and under the girth.
const FAR_FORE_POLYGON = [Vector2(952,432),Vector2(1092,432),Vector2(1098,560),Vector2(1092,640),Vector2(1078,700),Vector2(1062,760),Vector2(1058,860),Vector2(1066,925),Vector2(1108,975),Vector2(1108,998),Vector2(998,998),Vector2(972,925),Vector2(976,850),Vector2(980,770),Vector2(970,700),Vector2(958,640),Vector2(952,560)]
const NECK_BASE = Vector2(1090,390)
const POLL = Vector2(1317,100)
const MUZZLE = Vector2(1394,269)
const TAIL_ROOT = Vector2(293,340)
const COLUMNS = 52
const ROWS = 40
const COAT_WIDTH_SCALE = SCALE
const FAR_HIND_POLYGON = [Vector2(380,370),Vector2(552,420),Vector2(548,535),Vector2(490,590),Vector2(440,650),Vector2(390,700),Vector2(380,830),Vector2(430,995),Vector2(300,995),Vector2(280,890),Vector2(280,790),Vector2(269,730),Vector2(276,687),Vector2(311,640),Vector2(335,590),Vector2(325,545),Vector2(320,500),Vector2(350,455)]

var mesh = ArrayMesh.new()
var source_points = PackedVector2Array()
var vertices = PackedVector2Array()
var uvs = PackedVector2Array()
var indices = PackedInt32Array()
var weights: Array[Vector3] = []
var rest_points = PackedVector2Array()
var neck_weights = PackedFloat32Array()
var head_weights = PackedFloat32Array()
var tail_weights = PackedFloat32Array()
var tail_bends = PackedFloat64Array()
var limb_name = ""
var hind_weights: Array[PackedFloat32Array] = []
var fore_weights: Array[PackedFloat32Array] = []

func _init(limb: String = "") -> void:
	limb_name = limb
	var bounds = SOURCE_BOUNDS
	var columns = COLUMNS
	var rows = ROWS
	if not limb.is_empty():
		# Far legs use the same coat and joint landmarks. Their top cut is
		# buried under the trunk; no separate circular socket is visible.
		bounds = Rect2(269,370,285,625) if limb=="hind" else Rect2(950,430,185,565)
		columns = 18
		rows = 32
	for row in range(rows+1):
		for column in range(columns+1):
			var source = bounds.position+bounds.size*Vector2(float(column)/columns,float(row)/rows)
			source_points.append(source)
			uvs.append(source/SOURCE_TEXTURE_SIZE)
			vertices.append(rest_point(source))
			rest_points.append(rest_point(source))
			hind_weights.append(_limb_weights(source,HIND))
			fore_weights.append(_limb_weights(source,FORE))
			# The tail and the hock are close in the plate but separated by
			# transparent pixels. A broad X blend incorrectly pinned the back
			# edge of the hock to the tail, stretching it into a triangular flap.
			var tail_boundary = lerpf(330,263,smoothstep(420,680,source.y))
			var tail_weight = (1.0-smoothstep(tail_boundary-8,tail_boundary+8,source.x))*smoothstep(340,470,source.y)
			var neck_weight = smoothstep(0,.85,(source-NECK_BASE).dot(POLL-NECK_BASE)/(POLL-NECK_BASE).length_squared())*smoothstep(860,1000,source.x)
			neck_weights.append(neck_weight if limb.is_empty() else 0.0)
			head_weights.append(head_weight(source) if limb.is_empty() else 0.0)
			tail_weights.append(tail_weight if limb.is_empty() else 0.0)
			tail_bends.append(smoothstep(340,930,source.y))
			var hind = (1.0-smoothstep(520,640,source.x))*smoothstep(390,620,source.y)*(1.0-tail_weight)
			var fore = smoothstep(900,965,source.x)*(1.0-smoothstep(1130,1200,source.x))*smoothstep(440,610,source.y)
			if not limb.is_empty():
				# Far thighs share the fixed croup/shoulder at their buried root.
				# Rotating the whole copied haunch produced a broad orange flap.
				hind = smoothstep(420,620,source.y) if limb=="hind" else 0.0
				fore = smoothstep(450,610,source.y) if limb=="fore" else 0.0
			weights.append(Vector3(1.0-hind-fore,hind,fore))
	var far_hind_polygon = PackedVector2Array(FAR_HIND_POLYGON)
	var far_fore_polygon = PackedVector2Array(FAR_FORE_POLYGON)
	for row in range(rows):
		for column in range(columns):
			var a = row*(columns+1)+column
			var b = a+1
			var c = a+columns+1
			for triangle in [[a,b,c],[b,c+1,c]]:
				var center = (source_points[triangle[0]]+source_points[triangle[1]]+source_points[triangle[2]])/3.0
				if limb=="hind" and not Geometry2D.is_point_in_polygon(center,far_hind_polygon):
					continue
				if limb=="fore" and not Geometry2D.is_point_in_polygon(center,far_fore_polygon):
					continue
				indices.append_array(PackedInt32Array(triangle))
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,[],{},Mesh.ARRAY_FLAG_USE_2D_VERTICES|Mesh.ARRAY_FLAG_USE_DYNAMIC_UPDATE)
	mesh.custom_aabb = AABB(Vector3(-320,-330,-1),Vector3(650,440,2))

static func rest_point(source: Vector2) -> Vector2:
	return PIVOT+(source-SOURCE_SADDLE)*SCALE

static func bone_point(source: Vector2, source_a: Vector2, source_b: Vector2, a: Vector2, b: Vector2, width_scale: float = COAT_WIDTH_SCALE) -> Vector2:
	var source_axis = (source_b-source_a).normalized()
	var source_side = Vector2(-source_axis.y,source_axis.x)
	var axis = (b-a).normalized()
	var side = Vector2(-axis.y,axis.x)
	var along = (source-source_a).dot(source_axis)
	var across = (source-source_a).dot(source_side)
	return a+axis*along*a.distance_to(b)/source_a.distance_to(source_b)+side*across*width_scale

static func limb_point(source: Vector2, anchors: Array, pose: Dictionary) -> Vector2:
	var transforms = _limb_transforms(anchors,pose)
	var blend = _limb_weights(source,anchors)
	var point = Vector2.ZERO
	for k in range(blend.size()):
		point += transforms[k]*source*blend[k]
	return point

static func _limb_weights(source: Vector2, anchors: Array) -> PackedFloat32Array:
	var first: Vector2 = anchors[1]-anchors[0]
	var second: Vector2 = anchors[2]-anchors[1]
	var third: Vector2 = anchors[3]-anchors[2]
	var fourth: Vector2 = anchors[4]-anchors[3]
	var a = smoothstep(.76,1.12,(source-Vector2(anchors[0])).dot(first)/first.length_squared())
	var b = smoothstep(.80,1.12,(source-Vector2(anchors[1])).dot(second)/second.length_squared())
	var c = smoothstep(.82,1.10,(source-Vector2(anchors[2])).dot(third)/third.length_squared())
	# The hoof capsule is rigid: a short blend just at the coronet band.
	var d = smoothstep(.86,1.04,(source-Vector2(anchors[3])).dot(fourth)/fourth.length_squared())
	return PackedFloat32Array([(1-a)*(1-b)*(1-c)*(1-d),a*(1-b)*(1-c)*(1-d),b*(1-c)*(1-d),c*(1-d),d])

static func _bone_transform(source_a: Vector2, source_b: Vector2, a: Vector2, b: Vector2, width: float) -> Transform2D:
	var source_axis = (source_b-source_a).normalized()
	var source_side = Vector2(-source_axis.y,source_axis.x)
	var direction = (b-a).normalized()
	var axis = direction*a.distance_to(b)/source_a.distance_to(source_b)
	var side = Vector2(-direction.y,direction.x)*width
	var x = axis*source_axis.x+side*source_side.x
	var y = axis*source_axis.y+side*source_side.y
	return Transform2D(x,y,a-x*source_a.x-y*source_a.y)

static func _limb_transforms(anchors: Array, pose: Dictionary) -> Array[Transform2D]:
	# Older pose dictionaries without a coronet split the distal vector at the
	# coronet's rest fraction, which reproduces the former rigid segment.
	var coronet: Vector2 = pose.get("coronet",Vector2(pose.ankle).lerp(pose.foot,_coronet_fraction(anchors)))
	return [_bone_transform(anchors[0],anchors[1],pose.hip,pose.proximal,SCALE),
		_bone_transform(anchors[1],anchors[2],pose.proximal,pose.knee,SCALE),
		_bone_transform(anchors[2],anchors[3],pose.knee,pose.ankle,SCALE),
		_bone_transform(anchors[3],anchors[4],pose.ankle,coronet,SCALE),
		_bone_transform(anchors[4],anchors[5],coronet,pose.foot,SCALE)]

static func _coronet_fraction(anchors: Array) -> float:
	var distal: Vector2 = anchors[5]-anchors[3]
	return clampf((Vector2(anchors[4])-Vector2(anchors[3])).dot(distal)/distal.length_squared(),0.0,1.0)

static func neck_point(source: Vector2, body_pose: Dictionary) -> Vector2:
	var weight = smoothstep(0,.85,(source-NECK_BASE).dot(POLL-NECK_BASE)/(POLL-NECK_BASE).length_squared())*smoothstep(860,1000,source.x)
	var pivot = rest_point(NECK_BASE)
	var local = pivot+(rest_point(source)-pivot).rotated(float(body_pose.neck)*weight)+Vector2(body_pose.neck_offset)*weight
	local = local.lerp(head_transform(body_pose)*rest_point(source),head_weight(source))
	return PIVOT+(local-PIVOT).rotated(float(body_pose.pitch))+Vector2(body_pose.offset)

static func head_weight(source: Vector2) -> float:
	# Preserve a rigid skull past the poll; the neck keeps its smooth bend.
	return smoothstep(1220,1300,source.x)*(1.0-smoothstep(300,380,source.y))

static func head_transform(body_pose: Dictionary) -> Transform2D:
	var pivot = rest_point(NECK_BASE)
	var poll = rest_point(POLL)
	var base = pivot+(poll-pivot).rotated(float(body_pose.neck))+Vector2(body_pose.neck_offset)
	var transform = Transform2D(float(body_pose.neck)+float(body_pose.get("head",0.0)),Vector2.ZERO)
	transform.origin = base-transform.basis_xform(poll)
	return transform

static func muzzle_point(body_pose: Dictionary) -> Vector2:
	return neck_point(MUZZLE,body_pose)

func update(body_pose: Dictionary, hind_pose: Dictionary, fore_pose: Dictionary) -> void:
	var rigid_pose = Transform2D(float(body_pose.pitch),Vector2.ZERO)
	rigid_pose.origin = PIVOT+Vector2(body_pose.offset)-rigid_pose.basis_xform(PIVOT)
	var hind = _limb_transforms(HIND,hind_pose)
	var fore = _limb_transforms(FORE,fore_pose)
	# Read pose data once per mesh, not once per neck/tail vertex. Tail bend
	# weights depend only on source coordinates and are baked in _init.
	var neck_angle = float(body_pose.neck)
	var neck_offset = Vector2(body_pose.neck_offset)
	var tail_angle = float(body_pose.tail)
	var neck_pivot = rest_point(NECK_BASE)
	var tail_pivot = rest_point(TAIL_ROOT)
	var head_pose = head_transform(body_pose)
	for i in range(source_points.size()):
		var source = source_points[i]
		var weight = weights[i]
		var rest = rest_points[i]
		var neck_weight = neck_weights[i]
		if neck_weight>0:
			rest = neck_pivot+(rest-neck_pivot).rotated(neck_angle*neck_weight)+neck_offset*neck_weight
		if head_weights[i]>0:
			rest = rest.lerp(head_pose*rest_points[i],head_weights[i])
		var tail_weight = tail_weights[i]
		if tail_weight>0:
			rest = rest.lerp(tail_pivot+(rest-tail_pivot).rotated(tail_angle*tail_bends[i]),tail_weight)
		var point = (rigid_pose*rest)*weight.x
		if weight.y>0.0:
			var blend: PackedFloat32Array = hind_weights[i]
			point += ((hind[0]*source)*blend[0]+(hind[1]*source)*blend[1]+(hind[2]*source)*blend[2]+(hind[3]*source)*blend[3]+(hind[4]*source)*blend[4])*weight.y
		if weight.z>0.0:
			var blend: PackedFloat32Array = fore_weights[i]
			point += ((fore[0]*source)*blend[0]+(fore[1]*source)*blend[1]+(fore[2]*source)*blend[2]+(fore[3]*source)*blend[3]+(fore[4]*source)*blend[4])*weight.z
		vertices[i] = point
	# Only the vertex buffer changes. UVs, topology, material and source bitmap
	# stay fixed; two horses do not allocate thousands of draw calls per frame.
	mesh.surface_update_vertex_region(0,0,vertices.to_byte_array())

static func coat_texture(key: String) -> Texture2D:
	var name = key if COAT_KEYS.has(key) else "bay"
	if _coat_cache.has(name):
		return _coat_cache[name]
	# Standard lossless import with mipmaps; the CanvasTexture only overrides
	# the filter for the coat, the rider keeps the canvas's nearest filter.
	var source = load(COAT_DIR+name+".png") as Texture2D
	if source==null:
		push_error("Horse coat missing: "+COAT_DIR+name+".png")
		return null
	var texture = CanvasTexture.new()
	texture.diffuse_texture = source
	texture.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_coat_cache[name] = texture
	return texture

func set_coat(key: String) -> void:
	coat = coat_texture(key)

## EQUIP-066: caparison cloth painted in the same UV space as the coats
## (tools/caparison_v066.gd), drawn as a second pass over this same mesh.
const CAPARISON_DIR = "res://assets/art/caparison066/"
static var _caparison_cache: Dictionary = {}
var caparison: Texture2D = null

static func caparison_texture(style: String, design: String) -> Texture2D:
	if style.is_empty() or style=="none":
		return null
	var name = "%s_%s" % [style,design]
	if _caparison_cache.has(name):
		return _caparison_cache[name]
	var path = CAPARISON_DIR+name+".png"
	if not ResourceLoader.exists(path):
		_caparison_cache[name] = null
		return null
	var texture = CanvasTexture.new()
	texture.diffuse_texture = load(path) as Texture2D
	texture.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_caparison_cache[name] = texture
	return texture

func set_caparison(style: String, design: String) -> void:
	caparison = caparison_texture(style,design)

func draw(canvas: CanvasItem, tint: Color) -> void:
	canvas.draw_mesh(mesh,coat,Transform2D.IDENTITY,tint)
	if caparison!=null:
		canvas.draw_mesh(mesh,caparison,Transform2D.IDENTITY,tint)
