extends "test_fall_v057.gd"
## Alternating old/new work in one protected process controls thermal/load
## differences. Reference must be an explicitly supplied preserved source.
func run() -> void:
	var reference_path=""
	var candidate_path=""
	var exact=true
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):report_path=arg.trim_prefix("--report=")
		if arg.begins_with("--reference="):reference_path=arg.trim_prefix("--reference=")
		if arg.begins_with("--candidate="):candidate_path=arg.trim_prefix("--candidate=")
		if arg=="--measure-only":exact=false
	if report_path.is_empty() or FileAccess.file_exists(report_path) or reference_path.is_empty() or not "--test-profile" in OS.get_cmdline_user_args():quit(2);return
	var reference=load(reference_path)
	if reference==null:quit(2);return
	var rows=[]
	for facing in [-1,1]:
		for zone in ["head","body","shield"]:
			var stage=Node2D.new();root.add_child(stage)
			var current=make_actor(stage,zone,facing,false,false)
			var old=make_actor(stage,zone,facing,false,false)
			old.body=clone_body115(old.body,reference)
			if not candidate_path.is_empty():current.body=clone_body115(current.body,load(candidate_path))
			var time_old=0;var time_new=0;var error=0.0
			for tick in range(720):
				for which in ([old,current] if tick%2==0 else [current,old]):
					var started=Time.get_ticks_usec()
					which.advance(1.0/120.0)
					var elapsed=Time.get_ticks_usec()-started
					if which==old:time_old+=elapsed
					else:time_new+=elapsed
				if tick%30==0:
					error=maxf(error,old.body.x.distance_to(current.body.x))
					for i in range(9):error=maxf(error,old.body.p[i].distance_to(current.body.p[i]))
			if exact:check(error==0.0,"Compiled joint registration preserves exact trajectory",{"zone":zone,"facing":facing,"error":error})
			rows.append({"facing":facing,"zone":zone,"old_us":time_old,"new_us":time_new,"error":error})
			stage.free()
	FileAccess.open(report_path,FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"failures":failures,"rows":rows,"exact_required":exact,"scope":"Alternating CPU comparison; measure-only mode does not assert trajectory acceptance."},"\t"))
	quit(0 if failures.is_empty() else 1)


static func clone_body115(source,script):
	var target=script.new()
	for property in target.get_property_list():
		if not (int(property.usage)&PROPERTY_USAGE_SCRIPT_VARIABLE) or property.name in ["posterior_pairs115","fast_joints115","fast_bones115"]:continue
		var value=source.get(property.name)
		if value==null:continue
		target.set(property.name,value.duplicate(true) if value is Array or value is Dictionary else value)
	if target.has_method("compile_joints115"):target.compile_joints115()
	else:target.posterior_pairs115=[[target.joints[4],target.joints[5]],[target.joints[6],target.joints[7]]]
	if target.has_method("prepare_angles115"):target.prepare_angles115()
	return target
