extends RefCounted
## Connected torso / near-upper-limb skin. The saddle stays on the rigid trunk;
## shared vertices carry the coat continuously into the existing gait's joints.
## Source landmarks are measured on the v049 plate, not inferred from its prompt.
const TEXTURE = preload("res://assets/art/pixel_v049/horse_continuous_skin_v049_02.png")
const Gait = preload("res://scripts/visual/horse_gait.gd")
const PIVOT = Vector2(-18,-168)
const SOURCE_BODY = Rect2(120,50,1285,595)
const REST_BODY = Rect2(-155,-188,247,106)
# Leave the source plate's closed, dark tab-end outline out of the overlap;
# it is a cut-out boundary, not an anatomical cuff around the lower leg.
const SOURCE_BOUNDS = Rect2(100,40,1320,910)
const HIND = [Vector2(355,310),Vector2(392,571),Vector2(239,803),Vector2(284,942)]
const FORE = [Vector2(1200,300),Vector2(1183,580),Vector2(1341,830),Vector2(1316,946)]
const COLUMNS = 32
const ROWS = 30
const COAT_WIDTH_SCALE = .192

var mesh = ArrayMesh.new()
var source_points = PackedVector2Array()
var vertices = PackedVector2Array()
var uvs = PackedVector2Array()
var indices = PackedInt32Array()
var weights: Array[Vector3] = []
var rest_points = PackedVector2Array()
var hind_weights: Array[Vector3] = []
var fore_weights: Array[Vector3] = []

func _init(limb: String = "") -> void:
	var bounds = SOURCE_BOUNDS
	var columns = COLUMNS
	var rows = ROWS
	if not limb.is_empty():
		# Far legs use the same coat and joint landmarks. Their top cut is
		# buried under the trunk; no separate circular socket is visible.
		bounds = Rect2(100,405,500,545) if limb=="hind" else Rect2(1080,405,340,545)
		columns = 12
		rows = 20
	for row in range(rows+1):
		for column in range(columns+1):
			var source = bounds.position+bounds.size*Vector2(float(column)/columns,float(row)/rows)
			source_points.append(source)
			uvs.append(source/TEXTURE.get_size())
			vertices.append(rest_point(source))
			rest_points.append(rest_point(source))
			hind_weights.append(_limb_weights(source,HIND))
			fore_weights.append(_limb_weights(source,FORE))
			var hind = (1.0-smoothstep(520,680,source.x))*smoothstep(260,570,source.y)
			var fore = smoothstep(1020,1130,source.x)*smoothstep(270,585,source.y)
			if not limb.is_empty():
				hind = 1.0 if limb=="hind" else 0.0
				fore = 1.0-hind
			weights.append(Vector3(1.0-hind-fore,hind,fore))
	for row in range(rows):
		for column in range(columns):
			var a = row*(columns+1)+column
			var b = a+1
			var c = a+columns+1
			indices.append_array(PackedInt32Array([a,b,c,b,c+1,c]))
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,[],{},Mesh.ARRAY_FLAG_USE_2D_VERTICES|Mesh.ARRAY_FLAG_USE_DYNAMIC_UPDATE)
	mesh.custom_aabb = AABB(Vector3(-280,-250,-1),Vector3(560,320,2))

static func rest_point(source: Vector2) -> Vector2:
	return REST_BODY.position+(source-SOURCE_BODY.position)*REST_BODY.size/SOURCE_BODY.size

static func bone_point(source: Vector2, source_a: Vector2, source_b: Vector2, a: Vector2, b: Vector2, width_scale: float = COAT_WIDTH_SCALE) -> Vector2:
	var source_axis = (source_b-source_a).normalized()
	var source_side = Vector2(-source_axis.y,source_axis.x)
	var axis = (b-a).normalized()
	var side = Vector2(-axis.y,axis.x)
	var along = (source-source_a).dot(source_axis)
	var across = (source-source_a).dot(source_side)
	return a+axis*along*a.distance_to(b)/source_a.distance_to(source_b)+side*across*width_scale

static func limb_point(source: Vector2, anchors: Array, pose: Dictionary) -> Vector2:
	var width_scale = .178 if bool(pose.front) else COAT_WIDTH_SCALE
	var upper = bone_point(source,anchors[0],anchors[1],pose.hip,pose.proximal,width_scale)
	var middle = bone_point(source,anchors[1],anchors[2],pose.proximal,pose.knee,width_scale)
	var lower = bone_point(source,anchors[2],anchors[3],pose.knee,Vector2(pose.knee).lerp(pose.ankle,.24),width_scale*.72)
	var first_axis: Vector2 = anchors[1]-anchors[0]
	var second_axis: Vector2 = anchors[2]-anchors[1]
	var first_t = (source-Vector2(anchors[0])).dot(first_axis)/first_axis.length_squared()
	var second_t = (source-Vector2(anchors[1])).dot(second_axis)/second_axis.length_squared()
	return upper.lerp(middle,smoothstep(.72,1.16,first_t)).lerp(lower,smoothstep(.88,1.16,second_t))

static func _limb_weights(source: Vector2, anchors: Array) -> Vector3:
	var first: Vector2 = anchors[1]-anchors[0]
	var second: Vector2 = anchors[2]-anchors[1]
	var a = smoothstep(.72,1.16,(source-Vector2(anchors[0])).dot(first)/first.length_squared())
	var b = smoothstep(.88,1.16,(source-Vector2(anchors[1])).dot(second)/second.length_squared())
	return Vector3((1.0-a)*(1.0-b),a*(1.0-b),b)

static func _bone_transform(source_a: Vector2, source_b: Vector2, a: Vector2, b: Vector2, width: float) -> Transform2D:
	var source_axis = (source_b-source_a).normalized()
	var source_side = Vector2(-source_axis.y,source_axis.x)
	var axis = (b-a).normalized()*a.distance_to(b)/source_a.distance_to(source_b)
	var side = Vector2(-(b-a).normalized().y,(b-a).normalized().x)*width
	var x = axis*source_axis.x+side*source_side.x
	var y = axis*source_axis.y+side*source_side.y
	return Transform2D(x,y,a-x*source_a.x-y*source_a.y)

static func _limb_transforms(anchors: Array, pose: Dictionary) -> Array[Transform2D]:
	var width = .178 if bool(pose.front) else COAT_WIDTH_SCALE
	return [_bone_transform(anchors[0],anchors[1],pose.hip,pose.proximal,width),
		_bone_transform(anchors[1],anchors[2],pose.proximal,pose.knee,width),
		_bone_transform(anchors[2],anchors[3],pose.knee,Vector2(pose.knee).lerp(pose.ankle,.24),width*.72)]

func update(body_pose: Dictionary, hind_pose: Dictionary, fore_pose: Dictionary) -> void:
	var rigid_pose = Transform2D(float(body_pose.pitch),Vector2.ZERO)
	rigid_pose.origin = PIVOT+Vector2(body_pose.offset)-rigid_pose.basis_xform(PIVOT)
	var hind = _limb_transforms(HIND,hind_pose)
	var fore = _limb_transforms(FORE,fore_pose)
	for i in range(source_points.size()):
		var source = source_points[i]
		var weight = weights[i]
		var point = (rigid_pose*rest_points[i])*weight.x
		if weight.y>0.0:
			var blend = hind_weights[i]
			point += ((hind[0]*source)*blend.x+(hind[1]*source)*blend.y+(hind[2]*source)*blend.z)*weight.y
		if weight.z>0.0:
			var blend = fore_weights[i]
			point += ((fore[0]*source)*blend.x+(fore[1]*source)*blend.y+(fore[2]*source)*blend.z)*weight.z
		vertices[i] = point
	# Only the vertex buffer changes. UVs, topology, material and source bitmap
	# stay fixed; two horses do not allocate thousands of draw calls per frame.
	mesh.surface_update_vertex_region(0,0,vertices.to_byte_array())

func draw(canvas: CanvasItem, tint: Color) -> void:
	canvas.draw_mesh(mesh,TEXTURE,Transform2D.IDENTITY,tint)
