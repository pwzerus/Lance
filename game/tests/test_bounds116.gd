extends "test_fall_v057.gd"
func run() -> void:
	var path=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):path=arg.trim_prefix("--report=")
	if path.is_empty() or FileAccess.file_exists(path) or not "--test-profile" in OS.get_cmdline_user_args():quit(2);return
	var maximum=0.0;var old_us=0;var new_us=0;var count=0
	var rng=RandomNumberGenerator.new();rng.seed=116930
	for facing in [-1,1]:
		var stage=Node2D.new();root.add_child(stage)
		var actor=make_actor(stage,"head",facing,false,false)
		for tick in range(480):
			actor.advance(1.0/120.0)
			var points=actor.body_points()
			var turn=rng.randf_range(-12,12)
			var old_points=PackedFloat32Array();var new_points=PackedFloat32Array()
			var stamp=Time.get_ticks_usec()
			for repeat in range(8):
				old_points.clear()
				for point in points:old_points.append(point.rotated(turn).y)
			old_us+=Time.get_ticks_usec()-stamp
			stamp=Time.get_ticks_usec()
			for repeat in range(8):
				new_points.clear()
				var basis=Transform2D(turn,Vector2.ZERO)
				var vertical=Vector2(basis.x.y,basis.y.y)
				for point in points:new_points.append(point.dot(vertical))
			new_us+=Time.get_ticks_usec()-stamp
			for i in range(points.size()):maximum=maxf(maximum,absf(old_points[i]-new_points[i]));count+=1
		stage.free()
	FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify({"passed":maximum<=.0001,"max_y_error":maximum,"count":count,"old_us":old_us,"new_us":new_us,"scope":"Identical visible hull vertices, random orientations in both directions; no reduced outline or physical precision."},"\t"))
	quit(0 if maximum<=.0001 else 1)
