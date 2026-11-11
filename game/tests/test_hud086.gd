extends SceneTree
## Staged injury states through the production HUD. Actual rendered layout,
## not a gameplay input or a claim that the injuries arose in this scene.
var failures=[]
func _initialize():call_deferred("run")
func run():
	var folder=""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--folder="):folder=a.trim_prefix("--folder=")
	var state=root.get_node("GameState")
	if folder.is_empty() or DirAccess.dir_exists_absolute(folder) or not state.save_path.contains("qa_") or OS.get_environment("GALUMU_MEMORY_BOUND")!="1024" or DisplayServer.get_name()=="headless":quit(2);return
	DirAccess.make_dir_recursive_absolute(folder)
	state.save_path=folder+"/qa_profile.json";state.backup_path=folder+"/qa_backup.json"
	state.profile=state.default_profile();state.profile.settings.sound=false
	root.size=Vector2i(1280,720)
	var main=load("res://scenes/main.tscn").instantiate();root.add_child(main);current_scene=main
	main.set_process(false)
	var rows=[]
	for mode in ["war","arena"]:
		main._start_match(mode,true)
		var b=main.battle
		b.set_process(false);b.set_physics_process(false);b.set_process_input(false);b.set_process_unhandled_input(false)
		if root.focus_exited.is_connected(b._on_focus_lost):root.focus_exited.disconnect(b._on_focus_lost)
		b.match_model.phase="charge";b.match_model.fighters[0].x=-850;b.match_model.fighters[1].x=850
		var f=b.match_model.fighters[0]
		for wounded in [false,true]:
			f.head_load=33.0 if wounded else 0.0;f.hp=75.0
			f.broken=wounded;f.arm=20.0 if wounded else 100.0;f.balance=30.0 if wounded else 100.0
			b.approach_slow=wounded;b.guard_slot=0;f.guard=1.0
			b._update_hud();b._update_views()
			for i in range(4):await process_frame
			await RenderingServer.frame_post_draw
			var label=b.tactics_label
			var text_width=label.get_theme_font("font").get_string_size(label.text,HORIZONTAL_ALIGNMENT_LEFT,-1,label.get_theme_font_size("font_size")).x
			if mode=="war" and wounded and not label.text.contains("头部重创"):failures.append("Missing lasting head injury warning")
			if mode=="arena" and label.text.contains("头部重创"):failures.append("War trauma warning leaked into arena")
			if text_width>label.size.x:failures.append("Tactical text clipped: "+mode)
			var tag=mode+("-injured" if wounded else "-fresh")
			root.get_texture().get_image().save_png(folder+"/"+tag+".png")
			rows.append({"case":tag,"text":label.text,"text_width":text_width,"available_width":label.size.x})
		f.ko=true;f.dead=mode=="war";b.match_model.phase="ended"
		b._update_hud()
		if b.tactics_label.text.contains("谨防") or not b.tactics_label.text.contains("阵亡" if mode=="war" else "落马"):
			failures.append("Terminal rider still receives defensive advice: "+mode)
		await process_frame;await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(folder+"/"+mode+"-terminal.png")
		rows.append({"case":mode+"-terminal","text":b.tactics_label.text})
		main._close_battle();await process_frame
	FileAccess.open(folder+"/report.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"failures":failures,"rows":rows,"scope":"Staged production injury HUD, both modes, max overlapping statuses, actual GPU. No OS input or player approval."},"\t"))
	print("HUD086 ",failures)
	main.notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
