extends RefCounted
## Texture-free landmarks shared by the coat mesh and mounted support.
## All coats retain the same source silhouette; decorative mane fringe is
## outside the load-bearing crest. This is a presentation contact surface.
const PIVOT = Vector2(-18,-168)
const SOURCE_SADDLE = Vector2(749,326)
const SCALE = 180.0/666.0
const NECK_BASE = Vector2(1090,390)
const POLL = Vector2(1317,100)
const CREST = [Vector2(800,292),Vector2(900,272),Vector2(950,240),Vector2(1000,199),Vector2(1050,164),Vector2(1100,130),Vector2(1150,105),Vector2(1200,85),Vector2(1250,70)]

static func rest_point(source: Vector2) -> Vector2:
	return PIVOT+(source-SOURCE_SADDLE)*SCALE

static func head_weight(source: Vector2) -> float:
	return smoothstep(1220,1300,source.x)*(1.0-smoothstep(300,380,source.y))

static func head_transform(body_pose: Dictionary) -> Transform2D:
	var pivot = rest_point(NECK_BASE)
	var poll = rest_point(POLL)
	var base = pivot+(poll-pivot).rotated(float(body_pose.neck))+Vector2(body_pose.neck_offset)
	var transform = Transform2D(float(body_pose.neck)+float(body_pose.get("head",0.0)),Vector2.ZERO)
	transform.origin = base-transform.basis_xform(poll)
	return transform

static func neck_point(source: Vector2, body_pose: Dictionary) -> Vector2:
	var weight = smoothstep(0,.85,(source-NECK_BASE).dot(POLL-NECK_BASE)/(POLL-NECK_BASE).length_squared())*smoothstep(860,1000,source.x)
	var pivot = rest_point(NECK_BASE)
	var local = pivot+(rest_point(source)-pivot).rotated(float(body_pose.neck)*weight)+Vector2(body_pose.neck_offset)*weight
	local = local.lerp(head_transform(body_pose)*rest_point(source),head_weight(source))
	return PIVOT+(local-PIVOT).rotated(float(body_pose.pitch))+Vector2(body_pose.offset)

static func crest_points(body_pose: Dictionary) -> PackedVector2Array:
	var result = PackedVector2Array()
	for point in CREST: result.append(neck_point(point,body_pose))
	return result

static func crest_height(points: PackedVector2Array, x: float) -> float:
	for index in range(1,points.size()):
		if x<=points[index].x:
			var a = points[index-1]
			var b = points[index]
			return lerpf(a.y,b.y,clampf((x-a.x)/maxf(.001,b.x-a.x),0,1))
	return points[-1].y
