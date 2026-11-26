extends "test_support115.gd"
func run() -> void:
	var path="";var reference="";var candidate=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):path=arg.trim_prefix("--report=")
		if arg.begins_with("--reference="):reference=arg.trim_prefix("--reference=")
		if arg.begins_with("--candidate="):candidate=arg.trim_prefix("--candidate=")
	if path.is_empty() or FileAccess.file_exists(path) or reference.is_empty() or candidate.is_empty() or not "--test-profile" in OS.get_cmdline_user_args():quit(2);return
	var old=load(reference);var current=load(candidate)
	var rng=RandomNumberGenerator.new();rng.seed=116063
	var old_us=0;var new_us=0;var error=0.0;var count=0
	for index in range(2048):
		var knee=Vector2(rng.randf_range(-300,300),rng.randf_range(-300,300))
		var pose={"knee":knee,"ankle":knee+Vector2(rng.randf_range(25,70),0).rotated(rng.randf_range(-PI,PI)),"foot_angle115":0.0 if index%11==0 else rng.randf_range(-.5,.5)}
		var a;var b
		for which in ([old,current] if index%2==0 else [current,old]):
			var start=Time.get_ticks_usec();var points=which.boot_skin_outline115(pose)
			var elapsed=Time.get_ticks_usec()-start
			if which==old:a=points;old_us+=elapsed
			else:b=points;new_us+=elapsed
		if a.size()!=b.size():failures.append("Vertex count changed");break
		for i in range(a.size()):error=maxf(error,a[i].distance_to(b[i]));count+=1
	if error!=0.0:failures.append("Boot projection differs")
	FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"failures":failures,"poses":2048,"vertices":count,"maximum_error":error,"old_us":old_us,"new_us":new_us},"\t"))
	quit(0 if failures.is_empty() else 1)
