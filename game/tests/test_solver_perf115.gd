extends "test_fall_v057.gd"
## Fixed inputs and trajectories make solver optimizations reviewable.
## Headless CPU timings are not the rendered game's frame-rate evidence.
func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):report_path=arg.trim_prefix("--report=")
	if report_path.is_empty() or FileAccess.file_exists(report_path) or not "--test-profile" in OS.get_cmdline_user_args():quit(2);return
	var rows=[]
	for facing in [-1,1]:
		for zone in ["head","body","shield"]:
			var stage=Node2D.new();root.add_child(stage)
			var actor=make_actor(stage,zone,facing,false,false)
			var samples=[];var costs=[];var started=Time.get_ticks_usec()
			for tick in range(720):
				var before=Time.get_ticks_usec()
				actor.advance(1.0/120.0)
				costs.append(Time.get_ticks_usec()-before)
				if tick%30==0:
					var b=actor.body
					samples.append({"t":tick,"p":vector_rows(b.p),"x":[b.x.x,b.x.y],"theta":b.theta,"pelvis":[b.pelvis_x.x,b.pelvis_x.y,b.pelvis_theta],"settled":actor.settled})
			var elapsed=Time.get_ticks_usec()-started
			costs.sort()
			rows.append({"zone":zone,"facing":facing,"elapsed_ms":elapsed/1000.0,"step_p50_us":costs[360],"step_p95_us":costs[684],"samples":samples})
			stage.free()
	FileAccess.open(report_path,FileAccess.WRITE).store_string(JSON.stringify({"rows":rows,"passed":failures.is_empty(),"failures":failures},"\t"))
	quit(0 if failures.is_empty() else 1)
