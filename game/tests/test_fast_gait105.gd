extends "test_horse_anatomy063.gd"
## Extend the existing anatomy envelope beyond the neutral 480-unit gallop:
## 560 covers fast light mounts, 640 is an explicitly above-normal stress case.
func run()->void:
	var path=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report-path="):path=arg.trim_prefix("--report-path=")
	if path.is_empty() or FileAccess.file_exists(path) or OS.get_environment("GALUMU_MEMORY_BOUND")!="1024" or not root.get_node("GameState").save_path.contains("qa_"):quit(2);return
	for hz in [30,60,120]:
		for facing in [1,-1]:
			for speed in [560.0,640.0]:await steady_trial(speed,facing,hz)
	FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"failures":failures,"steady":steady_rows,"scope":"Additional 560/640 game-unit steady speeds at 30/60/120Hz, both directions. The latter is a conservative above-normal stress case, not a claim that ordinary horses reach that speed. Same six-node geometry/support/sink limits; not GPU or human motion review."},"\t"))
	print("FAST_GAIT105 ",failures);quit(0 if failures.is_empty() else 1)
