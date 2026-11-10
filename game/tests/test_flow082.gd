extends "test_ui082.gd"
## Menu/save regressions and actual Battle HUD/input boundaries.
func key(code: int) -> void:
	var event=InputEventKey.new()
	event.keycode=code
	event.physical_keycode=code
	event.pressed=true
	root.push_input(event,true)
	event=event.duplicate()
	event.pressed=false
	root.push_input(event,true)

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--folder="): folder=arg.trim_prefix("--folder=")
	state=root.get_node("GameState")
	if folder.is_empty() or DirAccess.dir_exists_absolute(folder) or not state.save_path.contains("qa_") or OS.get_environment("GALUMU_MEMORY_BOUND")!="1024" or DisplayServer.get_name()=="headless":
		quit(2); return
	DirAccess.make_dir_recursive_absolute(folder)
	state.save_path=folder+"/qa_profile.json"
	state.backup_path=folder+"/qa_backup.json"
	state.profile=state.default_profile()
	state.profile.settings.sound=false
	check(state.save_profile(),"Initial QA save failed")
	root.size=Vector2i(1280,720)
	main=load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene=main
	await process_frame
	main.show_match_setup()
	main._begin_match("arena")
	await process_frame
	key(KEY_ESCAPE)
	await process_frame
	check(main.page=="setup" and not is_instance_valid(main.brief_overlay),"Escape should dismiss briefing to mode selection")
	check(not state.profile.settings.combat_brief_v044,"Cancelled briefing was marked complete")
	main.show_saves()
	press("保存到此槽")
	await process_frame
	state.profile.coins=17
	main.show_saves()
	press("读取进度")
	await process_frame
	check(state.profile.coins==520,"Manual slot did not restore current progress")
	check(FileAccess.file_exists(state.backup_path),"Manual load lost automatic backup")
	main.show_settings()
	state.save_path=folder+"/missing/qa_profile.json"
	for button in buttons(main):
		if button.text=="镜头震动": button.set_pressed(false)
	check(not state.profile.settings.shake,"Setting should still apply to the current session")
	check(main.settings_notice.text.contains("暂未保存"),"Settings save failure is not visible")
	await capture("settings_save_failure")
	state.save_path=folder+"/qa_profile.json"
	for button in buttons(main):
		if button.text=="镜头震动": button.set_pressed(true)
	check(main.settings_notice.text=="已保存设置","Successful setting retry retains old error")
	main.show_match_setup()
	state.save_path=folder+"/missing/qa_profile.json"
	press("老练对手")
	await process_frame
	check(state.profile.settings.difficulty==2 and main.message_label.text.contains("暂未保存"),"Setup difficulty write failure is hidden")
	state.save_path=folder+"/qa_profile.json"
	press("正规骑士")
	await process_frame
	check(main.message_label.text.is_empty(),"Setup save retry retains obsolete failure")
	main.selected_slot="horse"
	main.selected_era=-1
	main.selected_region=1
	main.show_armory()
	await process_frame
	press("清除筛选")
	await process_frame
	check(main.armory_cards.size()>0 and main.selected_region==0,"Clearing filters did not restore shared horses")
	main.selected_slot="armor"
	main.selected_item={}
	main.show_armory()
	await process_frame
	var candidate: Dictionary={}
	for item in state.items:
		if item.slot=="armor" and item.id in main.armory_cards and item.id!=state.profile.equipped.armor:
			candidate=item
	if not candidate.is_empty():
		state.profile.owned.append(candidate.id)
		main.selected_item=candidate
		main._update_item_panel()
		main.armory_scroll.scroll_vertical=300
		for _i in range(3): await process_frame
		press("装备")
		for _i in range(5): await process_frame
		check(state.profile.equipped.armor==candidate.id,"Owned equipment failed to equip")
		check(main.armory_scroll.scroll_vertical>=250,"Equipping unexpectedly returned inventory to top")
		check(main.armory_cards[candidate.id].button_pressed,"Selected item highlight was lost")
		await capture("scroll_after_equip")
	state.profile=state.default_profile()
	state.profile.settings.sound=false
	main._start_match("arena",true)
	var battle=main.battle
	if root.focus_exited.is_connected(battle._on_focus_lost): root.focus_exited.disconnect(battle._on_focus_lost)
	battle.set_physics_process(false)
	battle.set_process(false)
	await process_frame
	battle._update_hud()
	check(not battle.speed_label.text.contains("巡航"),"Ready phase incorrectly claims cruising")
	var model=battle.match_model
	model.phase="charge"
	var f: Dictionary=model.fighters[0]
	f.stats.speed=1.30
	f.speed=model.TROT_SPEED*float(f.stats.speed)*model.Condition.load_speed_factor(f.stats)
	f.boost=false
	f.acceleration=0.0
	battle._update_hud()
	check(not battle.speed_label.text.contains("收速"),"Fast horse at its own cruise speed incorrectly claims braking")
	f.acted=true
	model.fighters[1].acted=true
	battle._update_hud()
	check(not battle.aim_label.text.contains("间隙"),"Both lances acted before passing but HUD says between passes")
	f.broken=true
	battle._update_hud()
	check(battle.tactics_label.text.contains("枪已断"),"Normal HUD hides broken lance state")
	await capture("combat_states")
	battle._toggle_pause()
	await process_frame
	check(battle.paused and paused,"Pause did not stop SceneTree")
	state.save_path=folder+"/missing/qa_profile.json"
	battle._pause_setting("shake",false)
	check(battle.pause_save_notice.text.contains("暂未保存"),"Pause setting save failure is not visible")
	await capture("pause_save_failure")
	state.save_path=folder+"/qa_profile.json"
	battle._pause_setting("shake",true)
	key(KEY_ESCAPE)
	await process_frame
	check(not battle.paused and not paused,"Escape did not resume after pause")
	key(KEY_R)
	await process_frame
	check(main.battle!=battle and not main.battle.paused and is_equal_approx(Engine.time_scale,1.0),"Restart retained old battle/pause/time scale")
	main._close_battle()
	main.show_home()
	await capture("return_after_restart")
	main.sounds.set_enabled(false)
	main.sounds.stop_all()
	main.queue_free()
	await process_frame
	var report={"passed":failures.is_empty(),"failures":failures,"captures":captures,"scope":"Direct menu signals and engine viewport Escape/R, explicit fast-horse and phase fixtures, isolated disk saves; no OS input or human feel claim."}
	FileAccess.open(folder+"/report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("FLOW082 ",failures)
	quit(0 if failures.is_empty() else 1)
