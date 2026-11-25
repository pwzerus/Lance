extends "test_fall_v057.gd"
## Diagnostic instrumentation is supplied explicitly, never active in a game.
func run() -> void:
	var instrument=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--instrument="):instrument=arg.trim_prefix("--instrument=")
		if arg.begins_with("--report="):report_path=arg.trim_prefix("--report=")
	if instrument.is_empty() or report_path.is_empty() or FileAccess.file_exists(report_path) or not "--test-profile" in OS.get_cmdline_user_args():quit(2);return
	var script=load(instrument)
	var rows=[]
	for facing in [-1,1]:
		for zone in ["head","body","shield"]:
			var stage=Node2D.new();root.add_child(stage)
			var actor=make_actor(stage,zone,facing,false,false)
			actor.body=load("res://tests/test_solver_pair115.gd").clone_body115(actor.body,script)
			for tick in range(600):actor.advance(1.0/120.0)
			rows.append({"facing":facing,"zone":zone,"times_us_calls":actor.body.profile115,"settled":actor.settled,"age":actor.age})
			stage.free()
	FileAccess.open(report_path,FileAccess.WRITE).store_string(JSON.stringify({"diagnostic":true,"rows":rows,"scope":"Instrumented methods overlap; measures CPU hot functions, not production frame rate."},"\t"))
	quit(0)
