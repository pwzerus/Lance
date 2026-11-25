extends SceneTree
## Inspect the exported PCK itself, not a development checkout.
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var path=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):path=arg.trim_prefix("--report=")
	if path.is_empty() or FileAccess.file_exists(path) or not "--test-profile" in OS.get_cmdline_user_args():quit(2);return
	var checks={
		"release_template":not OS.has_feature("editor"),
		"version":str(ProjectSettings.get_setting("application/config/version"))=="0.5.0-c1",
		"physics_120":int(ProjectSettings.get_setting("physics/common/physics_ticks_per_second"))==120,
		"fps_cap_60":int(ProjectSettings.get_setting("application/run/max_fps"))==60,
		"qa_profile":str(root.get_node("GameState").save_path).contains("qa_"),
		"protected":OS.get_environment("GALUMU_MEMORY_BOUND")=="1024",
		"qa_excluded":not FileAccess.file_exists("res://tests/test_physical_fuzz115.gd"),
		"generator_excluded":not FileAccess.file_exists("res://tools/caparison_v066.gd"),
		"head_contacts":FileAccess.file_exists("res://data/head_contacts_v115.json")}
	for file in ["core/rider_rig115","core/mounted_body115","visual/rider_body114","visual/fallen_rider","visual/rider_view","battle","main"]:
		var script=load("res://scripts/"+file+".gd")
		checks[file]=script!=null and script.can_instantiate()
	var failures=[]
	for key in checks:
		if not checks[key]:failures.append(key)
	FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"failures":failures,"checks":checks,"executable":OS.get_executable_path(),"version":ProjectSettings.get_setting("application/config/version")},"\t"))
	quit(0 if failures.is_empty() else 1)
