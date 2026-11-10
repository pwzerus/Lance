extends "res://tests/test_fall_v057.gd"
func _initialize() -> void:
	# Diagnostic-only: the temporary probe is deliberately absent from releases.
	if not ResourceLoader.exists("res://scripts/visual/probe_dispatch083.gd"):
		print("SKIP: requires a separately instrumented diagnostic copy")
		quit(2)
		return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--errors="): load("res://scripts/visual/probe_dispatch083.gd").output_path=arg.trim_prefix("--errors=")
	super._initialize()
