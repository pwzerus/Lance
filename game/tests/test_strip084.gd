extends SceneTree
const Lance=preload("res://scripts/visual/lance_art.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var report=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): report=arg.trim_prefix("--report=")
	if report.is_empty() or FileAccess.file_exists(report) or OS.get_environment("GALUMU_MEMORY_BOUND")=="": quit(2);return
	var rng=RandomNumberGenerator.new()
	rng.seed=840084
	var failures=[]
	var minimum_area=INF
	var maximum_area_error=0.0
	for sample in range(12000):
		var n=25 if sample%2==0 else 17
		var broken=sample%3==0
		var length=66.0 if broken else rng.randf_range(180,330)
		var start=-67.0 if sample%5==0 else 0.0
		var end=length if broken else length-16
		if sample%7==0: start=-67.0;end=0.0
		var stats={"lance_type":["standard","long","light","stout"][sample%4],"lance_quality":sample%6}
		var upper=[]
		var lower=[]
		for i in range(n):
			var d=lerpf(start,end,float(i)/(n-1))
			var radius=Lance.radius(stats,d,247.0)
			upper.append(Vector2(d,-radius));lower.push_front(Vector2(d,radius))
		var points=Lance._mapped(upper+lower,Vector2(rng.randf_range(-900,900),rng.randf_range(-900,900)),rng.randf_range(-PI,PI),length,broken,rng.randf_range(-1,1))
		var indices=Lance.strip_indices(n)
		var area=0.0
		for i in range(0,indices.size(),3):
			var triangle=(points[indices[i+1]]-points[indices[i]]).cross(points[indices[i+2]]-points[indices[i]])*.5
			minimum_area=minf(minimum_area,triangle)
			area+=triangle
		var contour=0.0
		for i in range(points.size()): contour+=(points[i]-points[0]).cross(points[(i+1)%points.size()]-points[0])*.5
		var error=absf(area-contour)
		maximum_area_error=maxf(maximum_area_error,error)
		if error>maxf(.03,absf(contour)*.0002) or area<=0:
			if failures.size()<8: failures.append({"sample":sample,"area_error":error,"area":area})
	if minimum_area<=0: failures.append("Triangle fold/degeneracy")
	var data={"passed":failures.is_empty(),"failures":failures,"ribbons":12000,"min_triangle_area":minimum_area,"max_area_rounding_error":maximum_area_error,"scope":"All samples/taper/flex preserved; fixed adjacent topology has positive nonoverlapping triangles and equal boundary area. Exact failing GPU case separately rendered before/after."}
	FileAccess.open(report,FileAccess.WRITE).store_string(JSON.stringify(data,"\t"))
	print("STRIP084 ",data)
	quit(0 if failures.is_empty() else 1)
