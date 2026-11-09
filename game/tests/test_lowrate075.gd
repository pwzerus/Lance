extends "test_horse_anatomy063.gd"
## Current six-joint anatomy, not the retired four-bone v050 length assertion.
func run() -> void:
	var path=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report-path="): path=arg.trim_prefix("--report-path=")
	if path.is_empty() or FileAccess.file_exists(path) or OS.get_environment("GALUMU_MEMORY_BOUND")=="" or not root.get_node("GameState").save_path.contains("qa_"):
		quit(2); return
	for hz in [20,24,48]:
		for facing in [1,-1]:
			for speed in [110.0,210.0,340.0,480.0]:
				await steady_trial(speed,facing,hz)
			await transition_trial(facing,hz)
	FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"failures":failures,"steady":steady_rows,"transitions":transition_rows},"\t"))
	print("LOWRATE075 ",failures)
	quit(0 if failures.is_empty() else 1)
