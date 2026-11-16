extends SceneTree
const Catalogue=preload("res://scripts/core/catalogue.gd")
var failures: Array=[]

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var folder=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): folder=arg.trim_prefix("--report=")
	var state=root.get_node("GameState")
	if folder.is_empty() or DirAccess.dir_exists_absolute(folder) or not state.save_path.contains("qa_") or OS.get_environment("GALUMU_MEMORY_BOUND")=="":
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(folder)
	state.save_path=folder+"/qa_profile.json"
	state.backup_path=folder+"/qa_profile.backup"
	state.profile=state.default_profile()
	state.profile.coins=9876
	state.profile.renown=70
	var ids: Array=[]
	for item in state.items:
		if item.slot in ["shield","crest"]:
			ids.append(str(item.id))
			if str(item.id) not in state.profile.owned: state.profile.owned.append(str(item.id))
	state.profile.equipped.shield="it_shield_5"
	state.profile.equipped.crest="crest_fleur"
	var owned=state.profile.owned.duplicate()
	if not state.save_profile(): failures.append("save failed: "+state.save_error)
	state.profile=state.default_profile()
	state.load_profile()
	for id in ids:
		if id not in state.profile.owned: failures.append("lost old item "+id)
	if state.profile.owned!=owned: failures.append("owned inventory changed")
	if state.profile.equipped.shield!="it_shield_5" or state.profile.equipped.crest!="crest_fleur": failures.append("equipped shield/crest changed")
	if state.profile.coins!=9876 or state.profile.renown!=70: failures.append("progress changed")
	if state.player_stats().shield_class!="heavy": failures.append("legacy equipped ID did not resolve new shield line")
	FileAccess.open(folder+"/report.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"failures":failures,"owned_ids":ids,"save_path":state.save_path},"  "))
	print("SAVE098 "+JSON.stringify(failures))
	quit(0 if failures.is_empty() else 1)
