extends "test_body114.gd"
## Reproduce supported-arm collapse after a limp forward slip; optional solver.
func final_shape(actor) -> Dictionary:
	var value=super.final_shape(actor)
	value.spine=actor.body.spine_flex()
	value.contacts=actor.body.contacts.keys()
	value.shield_roll=actor.body.shield_roll
	return value

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):report_path=arg.trim_prefix("--report=")
	if report_path.is_empty() or FileAccess.file_exists(report_path) or not "--test-profile" in OS.get_cmdline_user_args():quit(2);return
	for facing in [1,-1]:
		rows.append(run_case("body",facing,40.0,"balance",true,Vector2(400,400)))
		rows.append(run_case("body",facing,40.0,"slip",false,Vector2(300,300)))
	FileAccess.open(report_path,FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"rows":rows,"failures":failures,"examples":examples},"\t"))
	quit(0 if failures.is_empty() else 1)
