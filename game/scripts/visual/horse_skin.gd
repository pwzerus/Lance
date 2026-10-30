extends RefCounted
## One continuous coat from muzzle to hooves. Bone landmarks are measured on
## the complete v050 plate; front and hind limbs have separate anatomy.
const TEXTURE = preload("res://assets/art/pixel_v050/horse_complete_skin_v050_01.png")
const Gait = preload("res://scripts/visual/horse_gait.gd")
const PIVOT = Vector2(-18,-168)
const SOURCE_SADDLE = Vector2(749,326)
const SCALE = 180.0/666.0
const SOURCE_BOUNDS = Rect2(64,8,1436,986)
const HIND = [Vector2(450,400),Vector2(500,560),Vector2(322,730),Vector2(330,891),Vector2(376,986)]
const FORE = [Vector2(1080,450),Vector2(1011,585),Vector2(1013,752),Vector2(1009,902),Vector2(1056,992)]
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
var tail_weights = PackedFloat32Array()
var limb_name = ""
var hind_weights: Array[Vector4] = []
var fore_weights: Array[Vector4] = []

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
			uvs.append(source/TEXTURE.get_size())
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
			tail_weights.append(tail_weight if limb.is_empty() else 0.0)
			var hind = (1.0-smoothstep(520,640,source.x))*smoothstep(390,620,source.y)*(1.0-tail_weight)
			var fore = smoothstep(900,965,source.x)*(1.0-smoothstep(1130,1200,source.x))*smoothstep(440,610,source.y)
			if not limb.is_empty():
				# Far thighs share the fixed croup/shoulder at their buried root.
				# Rotating the whole copied haunch produced a broad orange flap.
				hind = smoothstep(420,620,source.y) if limb=="hind" else 0.0
				fore = smoothstep(450,610,source.y) if limb=="fore" else 0.0
			weights.append(Vector3(1.0-hind-fore,hind,fore))
	for row in range(rows):
		for column in range(columns):
			var a = row*(columns+1)+column
			var b = a+1
			var c = a+columns+1
			for triangle in [[a,b,c],[b,c+1,c]]:
				var center = (source_points[triangle[0]]+source_points[triangle[1]]+source_points[triangle[2]])/3.0
				if limb=="hind" and not Geometry2D.is_point_in_polygon(center,PackedVector2Array(FAR_HIND_POLYGON)):
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
	return transforms[0]*source*blend.x+transforms[1]*source*blend.y+transforms[2]*source*blend.z+transforms[3]*source*blend.w

static func _limb_weights(source: Vector2, anchors: Array) -> Vector4:
	var first: Vector2 = anchors[1]-anchors[0]
	var second: Vector2 = anchors[2]-anchors[1]
	var third: Vector2 = anchors[3]-anchors[2]
	var a = smoothstep(.76,1.12,(source-Vector2(anchors[0])).dot(first)/first.length_squared())
	var b = smoothstep(.80,1.12,(source-Vector2(anchors[1])).dot(second)/second.length_squared())
	var c = smoothstep(.82,1.10,(source-Vector2(anchors[2])).dot(third)/third.length_squared())
	return Vector4((1-a)*(1-b)*(1-c),a*(1-b)*(1-c),b*(1-c),c)

static func _bone_transform(source_a: Vector2, source_b: Vector2, a: Vector2, b: Vector2, width: float) -> Transform2D:
	var source_axis = (source_b-source_a).normalized()
	var source_side = Vector2(-source_axis.y,source_axis.x)
	var axis = (b-a).normalized()*a.distance_to(b)/source_a.distance_to(source_b)
	var side = Vector2(-(b-a).normalized().y,(b-a).normalized().x)*width
	var x = axis*source_axis.x+side*source_side.x
	var y = axis*source_axis.y+side*source_side.y
	return Transform2D(x,y,a-x*source_a.x-y*source_a.y)

static func _limb_transforms(anchors: Array, pose: Dictionary) -> Array[Transform2D]:
	return [_bone_transform(anchors[0],anchors[1],pose.hip,pose.proximal,SCALE),
		_bone_transform(anchors[1],anchors[2],pose.proximal,pose.knee,SCALE),
		_bone_transform(anchors[2],anchors[3],pose.knee,pose.ankle,SCALE),
		_bone_transform(anchors[3],anchors[4],pose.ankle,pose.foot,SCALE)]

static func neck_point(source: Vector2, body_pose: Dictionary) -> Vector2:
	var weight = smoothstep(0,.85,(source-NECK_BASE).dot(POLL-NECK_BASE)/(POLL-NECK_BASE).length_squared())*smoothstep(860,1000,source.x)
	var pivot = rest_point(NECK_BASE)
	var local = pivot+(rest_point(source)-pivot).rotated(float(body_pose.neck)*weight)+Vector2(body_pose.neck_offset)*weight
	return PIVOT+(local-PIVOT).rotated(float(body_pose.pitch))+Vector2(body_pose.offset)

static func muzzle_point(body_pose: Dictionary) -> Vector2:
	return neck_point(MUZZLE,body_pose)

func update(body_pose: Dictionary, hind_pose: Dictionary, fore_pose: Dictionary) -> void:
	var rigid_pose = Transform2D(float(body_pose.pitch),Vector2.ZERO)
	rigid_pose.origin = PIVOT+Vector2(body_pose.offset)-rigid_pose.basis_xform(PIVOT)
	var hind = _limb_transforms(HIND,hind_pose)
	var fore = _limb_transforms(FORE,fore_pose)
	for i in range(source_points.size()):
		var source = source_points[i]
		var weight = weights[i]
		var rest = rest_points[i]
		var neck_weight = neck_weights[i]
		if neck_weight>0:
			var pivot = rest_point(NECK_BASE)
			rest = pivot+(rest-pivot).rotated(float(body_pose.neck)*neck_weight)+Vector2(body_pose.neck_offset)*neck_weight
		var tail_weight = tail_weights[i]
		if tail_weight>0:
			var tail_pivot = rest_point(TAIL_ROOT)
			rest = rest.lerp(tail_pivot+(rest-tail_pivot).rotated(float(body_pose.tail)*smoothstep(340,930,source.y)),tail_weight)
		var point = (rigid_pose*rest)*weight.x
		if weight.y>0.0:
			var blend = hind_weights[i]
			point += ((hind[0]*source)*blend.x+(hind[1]*source)*blend.y+(hind[2]*source)*blend.z+(hind[3]*source)*blend.w)*weight.y
		if weight.z>0.0:
			var blend = fore_weights[i]
			point += ((fore[0]*source)*blend.x+(fore[1]*source)*blend.y+(fore[2]*source)*blend.z+(fore[3]*source)*blend.w)*weight.z
		vertices[i] = point
	# Only the vertex buffer changes. UVs, topology, material and source bitmap
	# stay fixed; two horses do not allocate thousands of draw calls per frame.
	mesh.surface_update_vertex_region(0,0,vertices.to_byte_array())

func draw(canvas: CanvasItem, tint: Color) -> void:
	canvas.draw_mesh(mesh,TEXTURE,Transform2D.IDENTITY,tint)
