extends SceneTree
## Render real battle HUD at four fatigue states without a main-menu tree.
## Direct state fixtures (not a natural match), QA save, isolated desktop.
var folder = ""
var failures: Array = []
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--folder="): folder = arg.trim_prefix("--folder=")
	var state = root.get_node("GameState")
	if OS.get_environment("GALUMU_MEMORY_BOUND")!="1024" or not state.save_path.contains("qa_") or DisplayServer.get_name()=="headless" or folder.is_empty() or DirAccess.dir_exists_absolute(folder):
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(folder)
	state.profile = state.default_profile()
	state.profile.settings.sound = false
	state.profile.equipped.caparison = "caparison_wool"
	state.profile.equipped.crest = "crest_chevron"
	root.size = Vector2i(960,540)
	root.content_scale_size = Vector2i(1440,810)
	var battle = load("res://scripts/battle.gd").new()
	root.add_child(battle)
	battle.set_process(false)
	battle.set_physics_process(false)
	battle.set_process_input(false)
	battle.set_process_unhandled_input(false)
	root.focus_exited.disconnect(battle._on_focus_lost)
	battle.match_model.phase = "charge"
	for index in range(2):
		var f: Dictionary = battle.match_model.fighters[index]
		f.x = -220 if index==0 else 220
		f.speed = 430
		f.boost = true
		f.gait_moving = true
		battle.riders[index].set_process(false)
	var rows: Array = []
	for stamina in [100.0,45.0,20.0,0.0]:
		battle.match_model.fighters[0].stamina = stamina
		battle._update_views()
		for rider in battle.riders: rider._process(0.0)
		for frame in range(60): battle._update_camera(1.0/60.0,Time.get_ticks_msec())
		battle._update_hud()
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(folder+"/fatigue-%d.png"%int(stamina))
		var label: Label = battle.fatigue_label
		var font = label.get_theme_font("font")
		var text_width = font.get_string_size(label.text,HORIZONTAL_ALIGNMENT_LEFT,-1,label.get_theme_font_size("font_size")).x
		if text_width>label.size.x: failures.append("Fatigue label clips at %d"%int(stamina))
		rows.append({"stamina":stamina,"text":label.text,"text_width":text_width,"available_width":label.size.x,"bar_width":battle.stamina_bar.size.x})
	battle.sound.stop_all()
	battle.queue_free()
	await process_frame
	Engine.time_scale = 1.0
	var file = FileAccess.open(folder+"/report.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":failures.is_empty(),"failures":failures,"rows":rows},"\t"))
	print("HUD072 "+str(failures))
	quit(0 if failures.is_empty() else 1)
