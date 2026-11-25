extends "test_boot113.gd"
## Independently read opaque atlas edges, including the nonlinear ankle band.
## A deformed convex-hull vertex set alone can miss an edge's curved extremum.
func visible_boot_hull113() -> PackedVector2Array:
	var corners=super.visible_boot_hull113()
	var result=PackedVector2Array()
	for index in range(corners.size()):
		var a=corners[index];var b=corners[(index+1)%corners.size()]
		var count=maxi(1,ceili(a.distance_to(b)/2.0))
		for step in range(count):result.append(a.lerp(b,float(step)/count))
	return result

func boot_point113(pixel:Vector2,pose:Dictionary)->Vector2:
	# Independent barycentric sampling of the actual 30-vertex drawn mesh,
	# not the solver's vertex hull or a continuous deformation approximation.
	var rows=[736.0,835.0,847.0,860.0,875.0,933.0]
	var columns=[744.0,784.0,823.0,852.0,892.0]
	for y in range(rows.size()-1):
		for x in range(columns.size()-1):
			if pixel.x<columns[x]-.001 or pixel.x>columns[x+1]+.001 or pixel.y<rows[y]-.001 or pixel.y>rows[y+1]+.001:continue
			var u=(pixel.x-columns[x])/(columns[x+1]-columns[x]);var v=(pixel.y-rows[y])/(rows[y+1]-rows[y])
			var a=Vector2(columns[x],rows[y]);var c=Vector2(columns[x+1],rows[y+1])
			var b=Vector2(columns[x+1],rows[y]) if u>=v else Vector2(columns[x],rows[y+1])
			var weights=Vector3(1-u,u-v,v) if u>=v else Vector3(1-v,v-u,u)
			var point=Vector2.ZERO;var triangle=[a,b,c]
			for index in range(3):point+=Rider.Rig115.foot_deform115(super.boot_point113(triangle[index],pose),pose)*weights[index]
			return point
	push_error("Opaque atlas point outside boot mesh")
	return Vector2.INF
