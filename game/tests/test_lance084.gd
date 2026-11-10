extends SceneTree
const Lance=preload("res://scripts/visual/lance_art.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var report=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): report=arg.trim_prefix("--report=")
	if report.is_empty() or FileAccess.file_exists(report) or OS.get_environment("GALUMU_MEMORY_BOUND")=="": quit(2);return
	var rng=RandomNumberGenerator.new()
	rng.seed=830011
	var bad=[]
	var checked=0
	for i in range(500000):
		var stats={"lance_type":["standard","long","stout","light"][i%4],"lance_quality":i%6}
		var length=rng.randf_range(150,330)
		var angle=rng.randf_range(-3.14,3.14)
		var hand=Vector2(rng.randf_range(-900,900),rng.randf_range(-900,900))
		var recoil=rng.randf_range(-1,1)
		var broken=i%4==0
		if broken: length=66.0
		var rear=i%3==0
		var start=-67.0 if rear or i%3==2 else 0.0
		var end=0.0 if rear else (length if broken else length-16)
		var upper=[]
		var lower=[]
		for step in range(25):
			var d=lerpf(start,end,step/24.0)
			var radius=Lance.radius(stats,d,length)
			upper.append(Vector2(d,-radius))
			lower.push_front(Vector2(d,radius))
		var polygon=Lance._mapped(upper+lower,hand,angle,length,broken,recoil)
		checked+=1
		if Geometry2D.triangulate_polygon(polygon).is_empty():
			if bad.size()<8: bad.append({"stats":stats,"hand":str(hand),"angle":angle,"length":length,"recoil":recoil,"rear":rear,"points":str(polygon)})
		if bad.size()>=8: break
	FileAccess.open(report,FileAccess.WRITE).store_string(JSON.stringify({"checked":checked,"invalid_examples":bad},"\t"))
	print("LANCE_POLYGONS083 checked=",checked," invalid_examples=",bad.size())
	quit(0 if bad.is_empty() else 1)
