extends SceneTree
## One ordinary three-pass match. Only Battle's autopilot is enabled; do not
## enable Main's whole smoke tour (it schedules unrelated menus/matches).
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
	root.size = Vector2i(1280,720)
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await process_frame
	# This flag is read synchronously when constructing Battle. Clear it before
	# Main._process can start the unrelated multi-menu smoke sequence.
	main.smoke_mode = true
	main._start_match("arena",true)
	main.smoke_mode = false
	var start = Time.get_ticks_msec()
	var captures: Dictionary = {}
	while Time.get_ticks_msec()-start<100000 and not main.result_visible:
		await process_frame
		if not is_instance_valid(main.battle): break
		var model = main.battle.match_model
		var tag = ""
		if model.phase=="charge":
			var gap = absf(float(model.fighters[0].x)-float(model.fighters[1].x))
			if gap>1500: tag = "charge"
			elif gap<750 and gap>450: tag = "approach"
			if main.battle.camera_impact_age<.35: tag = "contact"
		if not tag.is_empty() and not captures.has(tag):
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(folder+"/"+tag+".png")
			captures[tag] = Time.get_ticks_msec()-start
	var result: Dictionary = main.pending_result.duplicate(true)
	var passed = main.result_visible and int(result.get("passes",0))>0
	if main.result_visible:
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(folder+"/result.png")
	var report = {"passed":passed,"result":result,"captures":captures,"elapsed_ms":Time.get_ticks_msec()-start,"scope":"Actual packaged Main/Battle, AI/autopilot arena practice; no forced contacts, no rewards/save writes, no OS input, human play or audio listening."}
	var file = FileAccess.open(folder+"/report.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	file.close()
	print("MATCH072 ",report)
	main.sounds.set_enabled(false)
	main.sounds.stop_all()
	main._close_battle()
	main.queue_free()
	await process_frame
	await create_timer(.2,true,false,true).timeout
	quit(0 if passed else 1)
