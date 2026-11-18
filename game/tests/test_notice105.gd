extends "test_flow082.gd"
## Visible production HUD for explicit state fixtures, not gameplay outcomes.
func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--folder="):folder=arg.trim_prefix("--folder=")
	state=root.get_node("GameState")
	if folder.is_empty() or DirAccess.dir_exists_absolute(folder) or not state.save_path.contains("qa_") or OS.get_environment("GALUMU_MEMORY_BOUND")!="1024" or DisplayServer.get_name()=="headless":quit(2);return
	DirAccess.make_dir_recursive_absolute(folder)
	state.save_path=folder+"/qa_profile.json";state.backup_path=folder+"/qa_backup.json"
	state.profile=state.default_profile();state.profile.settings.sound=false
	main=load("res://scenes/main.tscn").instantiate();root.add_child(main);current_scene=main
	await process_frame
	main._start_match("arena",false)
	var battle=main.battle
	if root.focus_exited.is_connected(battle._on_focus_lost):root.focus_exited.disconnect(battle._on_focus_lost)
	if not await wait_battle(battle):quit(2);return
	battle.set_process(false);battle.set_physics_process(false)
	var model=battle.match_model
	var original:Dictionary=model.fighters[0].duplicate(true)
	var rows=[]
	var cases=[
		{"name":"healthy","values":{},"text":"","mode":"arena"},
		{"name":"broken_early","values":{"broken":true},"text":"枪已断 · 下轮换新枪","mode":"arena"},
		{"name":"broken_final","values":{"broken":true},"text":"枪已断 · 先护住身体","mode":"arena","pass":3},
		{"name":"war_stub","values":{"broken":true},"text":"枪已断 · 残柄射程与冲力下降","mode":"war"},
		{"name":"shield_broken","values":{"shield":0.0,"broken":true},"text":"盾已破 · 用俯仰避开来枪","mode":"arena"},
		{"name":"head_trauma","values":{"head_load":30.0},"text":"头部重创 · 提前护头","mode":"war"},
		{"name":"unsteady","values":{"unsteady":.6},"text":"重心不稳 · 减少急摆","mode":"arena"},
		{"name":"unbalanced","values":{"balance":20.0},"text":"坐姿失衡 · 稳住身体","mode":"arena"},
		{"name":"tired_arm","values":{"arm":25.0},"text":"手臂酸软 · 放缓调枪","mode":"arena"},
		{"name":"fallen","values":{"ko":true,"broken":true,"shield":0.0},"text":"落马出局","mode":"arena"},
		{"name":"dead","values":{"ko":true,"dead":true,"head_load":60.0},"text":"骑手阵亡","mode":"war"},
		{"name":"ended","values":{"broken":true,"arm":0.0},"text":"","mode":"arena","phase":"ended"}
	]
	for dimensions in [Vector2i(1280,720),Vector2i(960,540)]:
		root.size=dimensions
		for cues in [true,false]:
			state.profile.settings.aim_cues=cues
			for c in cases:
				var f:Dictionary=model.fighters[0]
				f.clear();f.merge(original.duplicate(true));f.merge(c.values,true)
				model.phase=c.get("phase","charge");model.pass_number=c.get("pass",1)
				battle.mode=c.mode;model.mode=c.mode
				battle._update_hud()
				for _i in range(2):await process_frame
				var label:Label=battle.aim_label
				check(battle._combat_notice()==c.text,"Notice priority: "+c.name)
				check(label.is_visible_in_tree()==(cues or not c.text.is_empty()),"Notice visibility: "+c.name)
				if bool(f.get("ko",false)) or model.phase=="ended":
					check(not battle.hint.is_visible_in_tree(),"No obsolete riding instructions after knockout/end: "+c.name)
				if not c.text.is_empty():
					check(label.text==c.text,"Actual visible notice matches state: "+c.name)
					var font:Font=label.get_theme_font("font")
					var text_width=font.get_string_size(label.text,HORIZONTAL_ALIGNMENT_LEFT,-1,label.get_theme_font_size("font_size")).x
					check(text_width<=label.size.x,"No clipped notice: "+c.name)
					for character in label.text:
						check(font.has_char(character.unicode_at(0)),"Notice font covers character: "+character)
				rows.append({"case":c.name,"width":dimensions.x,"cues":cues,"visible":label.is_visible_in_tree(),"text":label.text})
				if not cues and c.name in ["war_stub","shield_broken","head_trauma","tired_arm","fallen"]:
					await capture(str(dimensions.x)+"_"+c.name)
	# Explicit overlapping contact readout: a background painted in the
	# gauges' foreground can hide this text despite all Labels being visible.
	model.phase="charge";battle.mode="arena";model.mode="arena"
	model.fighters[0].merge(original.duplicate(true),true)
	battle.contact_until=Time.get_ticks_msec()+10000
	battle.contact_label.text="盾心重击"
	battle.enemy_contact_label.text="头 命中"
	battle._update_hud()
	for _i in range(3):await process_frame
	check(battle.contact_label.is_visible_in_tree() and battle.enemy_contact_label.is_visible_in_tree(),"Contact labels remain visible")
	check(battle.status_gauges._backdrop.z_index<0,"Status backdrop stays behind contact labels")
	await capture("960_contact_overlap")
	main._close_battle();main.sounds.stop_all();main.queue_free();await process_frame
	FileAccess.open(folder+"/report.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"failures":failures,"rows":rows,"captures":captures,"scope":"48 explicit HUD states rendered at two window sizes; no OS input or human readability verdict."},"\t"))
	print("NOTICE105 ",failures);quit(0 if failures.is_empty() else 1)
