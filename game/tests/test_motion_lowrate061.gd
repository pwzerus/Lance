extends "test_horse_anatomy_v050.gd"
## The user's integrated-GPU laptop can miss 60 FPS. Keep the same geometry
## limits when visual updates arrive at 20/24/48 Hz, including gait transitions.
func run() -> void:
	var path = ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report-path="): path=arg.trim_prefix("--report-path=")
	if OS.get_environment("GALUMU_MEMORY_BOUND")!="1024" or not root.get_node("GameState").save_path.contains("qa_") or path.is_empty() or FileAccess.file_exists(path):
		quit(2)
		return
	for hz in [20,24,48]:
		for facing in [1,-1]:
			for speed in [110.0,210.0,340.0,480.0]:
				await steady_trial(speed,facing,hz)
			await transition_trial(facing,hz)
	var file = FileAccess.open(path,FileAccess.WRITE)
	if file==null:
		quit(2)
		return
	file.store_string(JSON.stringify({"passed":failures.is_empty(),"failures":failures,"steady":steady_rows,"transitions":transition_rows,"scope":"Same v050 anatomy and support limits at 20/24/48Hz. Does not claim low frame rate looks smooth."},"\t"))
	file.close()
	print("MOTION_LOWRATE061 "+str(failures.is_empty())+" "+str(failures))
	quit(0 if failures.is_empty() else 1)
