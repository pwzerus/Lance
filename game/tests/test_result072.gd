extends SceneTree
## Long contact summaries rendered in the actual Main result panel. Fixtures,
## not an earned match; verify scrolling never overlaps rewards at minimum size.
var folder = ""
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--folder="): folder = arg.trim_prefix("--folder=")
	var state = root.get_node("GameState")
	if OS.get_environment("GALUMU_MEMORY_BOUND")!="1024" or not state.save_path.contains("qa_") or folder.is_empty() or DirAccess.dir_exists_absolute(folder) or DisplayServer.get_name()=="headless":
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(folder)
	state.profile = state.default_profile()
	state.profile.settings.sound = false
	root.size = Vector2i(960,540)
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.set_process(false)
	main._start_match("arena",true)
	main.battle.set_process(false)
	main.battle.set_physics_process(false)
	main.battle.exchange_log.clear()
	for index in range(2):
		main.battle.exchange_log.append({"attacker":index,"defender":1-index,"zone":"body","damage":16,"balance_left":81,"points":2,"attaint":false,"drive":1.3,"broke":true,"ko":true,"ko_reason":"balance"})
	main.pending_result = {"winner":0,"reason":"terminal","player_hp":98,"enemy_hp":74,"player_score":2,"enemy_score":0}
	main.reward = {"coins":0,"renown":0}
	main.show_result()
	for frame in range(5): await process_frame
	var scroll: ScrollContainer = main.screen.find_child("ContactReport",true,false)
	var reward_label: Label = main.screen.find_child("ResultRewards",true,false)
	var failures: Array = []
	if scroll==null or reward_label==null:
		failures.append("Missing report or reward area")
	else:
		if scroll.get_global_rect().end.y>reward_label.get_global_rect().position.y: failures.append("Report overlaps rewards")
		if not scroll.clip_contents: failures.append("Report is not clipped to its own area")
		var bar = scroll.get_v_scroll_bar()
		if bar.max_value<=bar.page: failures.append("Long summary cannot scroll")
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(folder+"/top.png")
		scroll.scroll_vertical = int(bar.max_value)
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(folder+"/bottom.png")
	var report = {"passed":failures.is_empty(),"failures":failures,"viewport":[960,540],"scope":"Actual Main result panel with long synthetic contacts; no OS input or match balance evidence."}
	var file = FileAccess.open(folder+"/report.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	file.close()
	print("RESULT072 ",report)
	main.sounds.set_enabled(false)
	main.sounds.stop_all()
	main._close_battle()
	main.queue_free()
	await process_frame
	await create_timer(.2,true,false,true).timeout
	quit(0 if failures.is_empty() else 1)
