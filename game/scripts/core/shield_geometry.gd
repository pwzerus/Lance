extends RefCounted
## Shared silhouette for drawing, current-line feedback and swept shield contact.

static func outline(shape: String = "kite") -> PackedVector2Array:
	if shape=="heater":
		return PackedVector2Array([Vector2(-37,-43),Vector2(35,-43),Vector2(32,15),Vector2(0,49),Vector2(-33,15)])
	if shape=="targe":
		return PackedVector2Array([Vector2(-36,-43),Vector2(16,-43),Vector2(17,-28),Vector2(35,-24),Vector2(36,28),Vector2(5,44),Vector2(-34,32)])
	return PackedVector2Array([Vector2(-31,-46),Vector2(29,-48),Vector2(36,-29),Vector2(21,24),Vector2(0,51),Vector2(-28,17)])

static func project(point: Vector2) -> Vector2:
	return Vector2(point.x*.62+point.y*.13,point.y)

static func polygon(shape: String = "kite") -> PackedVector2Array:
	var result = PackedVector2Array()
	for point in outline(shape):
		result.append(project(point))
	return result

static func world_polygon(center: Vector2, angle: float, facing: int, shape: String = "kite") -> PackedVector2Array:
	var result = PackedVector2Array()
	for point in polygon(shape):
		result.append(center+point.rotated(angle)*Vector2(facing,1))
	return result

static func segment_fraction(start: Vector2, finish: Vector2, points: PackedVector2Array) -> float:
	if Geometry2D.is_point_in_polygon(start,points):
		return 0.0
	var ray = finish-start
	if ray.length_squared()<.000001:
		return -1.0
	var earliest = INF
	for i in range(points.size()):
		var edge = points[(i+1)%points.size()]-points[i]
		var offset = points[i]-start
		var denominator = ray.cross(edge)
		if absf(denominator)<.0000001:
			if absf(offset.cross(ray))>.00001*ray.length():
				continue
			var ta = offset.dot(ray)/ray.length_squared()
			var tb = (points[(i+1)%points.size()]-start).dot(ray)/ray.length_squared()
			if maxf(ta,tb)>=0 and minf(ta,tb)<=1:
				earliest = minf(earliest,maxf(0,minf(ta,tb)))
			continue
		# Explicit parametric bounds avoid Geometry2D's long-segment tolerance
		# turning a near miss just outside a shield corner into a preview hit.
		var t = offset.cross(edge)/denominator
		var u = offset.cross(ray)/denominator
		if t>=0 and t<=1 and u>=0 and u<=1:
			earliest = minf(earliest,t)
	return earliest if is_finite(earliest) else -1.0

static func sweep(old_hand: Vector2, hand: Vector2, old_aim: float, aim: float, old_reach: float, reach: float, facing: int, old_center: Vector2, center: Vector2, old_pose: float, pose: float, defender_facing: int, shape: String, delta: float) -> Dictionary:
	# Trace the weapon arc in the moving shield's local frame. Four-pixel
	# substeps also cover rotating lances, shield turns and short broken grips.
	var previous = old_hand+Vector2(cos(old_aim)*facing,sin(old_aim))*old_reach
	var end_tip = hand+Vector2(cos(aim)*facing,sin(aim))*reach
	var relative_radius = maxf(previous.distance_to(old_center),end_tip.distance_to(center))
	var travel = absf(aim-old_aim)*maxf(old_reach,reach)+absf(pose-old_pose)*relative_radius
	var segments = maxi(1,ceili(travel/4))
	var points = polygon(shape)
	var local_previous = ((previous-old_center)*Vector2(defender_facing,1)).rotated(-old_pose)
	for i in range(segments):
		var t0 = float(i)/segments
		var t1 = float(i+1)/segments
		var angle = lerpf(old_aim,aim,t1)
		var current = old_hand.lerp(hand,t1)+Vector2(cos(angle)*facing,sin(angle))*lerpf(old_reach,reach,t1)
		var local_current = ((current-old_center.lerp(center,t1))*Vector2(defender_facing,1)).rotated(-lerpf(old_pose,pose,t1))
		var fraction = segment_fraction(local_previous,local_current,points)
		if fraction>=0:
			return {"fraction":lerpf(t0,t1,fraction),"point":previous.lerp(current,fraction),"velocity":(current-previous)/maxf(delta/segments,.00001)}
		previous = current
		local_previous = local_current
	return {}
