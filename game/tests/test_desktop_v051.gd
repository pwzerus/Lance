extends SceneTree
## Native desktop observation only. QA owns all items; no inputs are injected.
var qa_main: Node
func _initialize() -> void:
	call_deferred("run")
func _process(_delta: float) -> bool:
	if Time.get_ticks_msec()>=600000:
		quit()
	return false
func run() -> void:
	var state = root.get_node("GameState")
	if not state.save_path.contains("qa_"):
		quit(1)
		return
	var profile_name = "qa_desktop_v051_%d" % Time.get_ticks_usec()
	var resume = "--resume-qa" in OS.get_cmdline_user_args()
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--qa-profile="): profile_name = argument.trim_prefix("--qa-profile=")
	if not profile_name.begins_with("qa_desktop_v051_") or not profile_name.is_valid_identifier():
		push_error("QA basename must be a qa_desktop_v051_ identifier")
		quit(2)
		return
	state.save_path = "user://"+profile_name+".json"
	state.backup_path = state.save_path+".backup"
	state.profile = state.default_profile()
	state.profile.coins = 50000
	state.profile.renown = 100
	for item in state.items:
		if item.id not in state.profile.owned: state.profile.owned.append(item.id)
	state.profile.equipped.armor = "de_armor_3"
	state.profile.equipped.helmet = "it_helmet_3"
	state.profile.equipped.lance = "it_lance_stout_5"
	state.profile.owned.erase("eng_helmet_5") # One real UI purchase remains available.
	if resume:
		if not FileAccess.file_exists(state.save_path):
			push_error("Cannot resume a missing QA profile")
			quit(2)
			return
		state.load_profile()
	qa_main = load("res://scenes/main.tscn").instantiate()
	root.add_child(qa_main)
	qa_main.selected_era = -1
	var audit = load("res://scripts/core/desktop_input_audit.gd").new()
	audit.main = qa_main
	audit.log_path = "E:/GALUMU/docs/development/logs/v051/desktop01.jsonl"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--audit-log="): audit.log_path=argument.trim_prefix("--audit-log=")
	if FileAccess.file_exists(audit.log_path):
		push_error("Choose a fresh desktop audit log")
		audit.free()
		quit(2)
		return
	qa_main.add_child(audit)
	audit.write({"kind":"qa_identity","save_path":state.save_path,"executable":OS.get_executable_path(),"injection":false})
	root.title = "GALUMU v0.4.11 QA - Desktop observation"
