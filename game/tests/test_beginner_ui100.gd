extends "test_play087.gd"
const Campaign100=preload("res://scripts/core/campaign.gd")
const Model100=preload("res://scripts/core/joust_match.gd")
func shot(folder: String, label: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(folder+"/"+label+".png")
func run() -> void:
	var folder="";var level_numbers=[1,3];var sequential=false;var fixture_unlock_before=0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--folder="):folder=a.trim_prefix("--folder=")
		if a.begins_with("--qa-unlock-before="):fixture_unlock_before=clampi(int(a.trim_prefix("--qa-unlock-before=")),0,10)
		if a.begins_with("--levels="):
			sequential=true;level_numbers=[]
			for value in a.trim_prefix("--levels=").split(","):level_numbers.append(int(value))
	var state=root.get_node("GameState")
	if folder.is_empty() or DirAccess.dir_exists_absolute(folder) or not "qa_" in state.save_path or OS.get_environment("GALUMU_MEMORY_BOUND")!="1024" or DisplayServer.get_name()=="headless":quit(2);return
	DirAccess.make_dir_recursive_absolute(folder)
	state.save_path=folder+"/qa_profile.json";state.backup_path=folder+"/qa_backup.json"
	state.profile=state.default_profile()
	# Explicit single-level baseline probe; never counted as natural progression.
	for cleared in range(1,fixture_unlock_before):state.profile.campaign_cleared.append(cleared)
	state.profile.settings.combat_brief_v044=true
	state.profile.settings.sound=true
	AudioServer.set_bus_mute(0,true)
	root.size=Vector2i(1440,810)
	var main=load("res://scenes/main.tscn").instantiate();root.add_child(main);current_scene=main
	for i in range(60):await process_frame
	main.show_levels(0)
	for i in range(10):await process_frame
	await shot(folder,"opening-levels")
	var rows=[]
	for n in level_numbers:
		if n<1 or n>10:check(false,"Only beginner levels 1-10 allowed");break
		if n==3 and not sequential:state.profile.campaign_cleared=[1,2] # QA unlock only, not progression evidence for level 2.
		check(state.campaign_unlocked(n),"Previous natural result must unlock level "+str(n))
		if not state.campaign_unlocked(n):break
		main._start_level(n)
		check(is_instance_valid(main.battle),"Level starts directly")
		if not is_instance_valid(main.battle):break
		var b=main.battle
		if root.focus_exited.is_connected(b._on_focus_lost):root.focus_exited.disconnect(b._on_focus_lost)
		b.match_model.rng.seed=10001;b.ai_rng.seed=10432
		check(b.ai_controller.profile==Campaign100.level(state.items,n).ai,"Correct onboarding profile reaches battle")
		var began=Time.get_ticks_msec();var next_aim=0;var captured=false
		var max_enemy_speed=0.0
		while Time.get_ticks_msec()-began<115000 and not main.result_visible:
			await process_frame
			if not b.presentation_ready:continue
			b.mouse_held=true;b.ui_pointer_held=false
			if Time.get_ticks_msec()>=next_aim:
				next_aim=Time.get_ticks_msec()+850
				var p=b.match_model.fighters[0];var enemy=b.match_model.fighters[1]
				var target=Model100.body_position(enemy).y-10.0
				b.pointer_aim=asin(clampf((target-Model100.hand_position(p).y)/Model100.lance_length(p),-.629,.548))
			max_enemy_speed=maxf(max_enemy_speed,float(b.match_model.fighters[1].speed))
			if not captured and b.match_model.phase=="charge" and absf(float(b.match_model.fighters[0].x)-float(b.match_model.fighters[1].x))<950:
				await shot(folder,"level%d-approach"%n);captured=true
		check(main.result_visible,"Level reaches result")
		if main.result_visible:
			for i in range(4):await process_frame
			await shot(folder,"level%d-result"%n)
			var won=int(main.pending_result.winner)==0
			check(won,"Starter coarse chest aim can win opening level "+str(n))
			check(not won or n in state.profile.campaign_cleared,"Win unlock persists")
			check(not won or int(main.reward.coins)==Campaign100.reward_coins(n,false),"First clear reward unchanged")
			rows.append({"level":n,"elapsed_seconds":(Time.get_ticks_msec()-began)/1000.0,"winner":main.pending_result.winner,"reward":main.reward.duplicate(true),"max_enemy_speed":max_enemy_speed,"hits":b.exchange_log.duplicate(true)})
		main._close_battle()
		await process_frame
	var disk=state._read_save(state.save_path)
	# JSON numbers are floats; use the production load/sanitize path before
	# comparing the integer campaign IDs, rather than raw Array equality.
	var restored=state.sanitize(disk)
	check(not disk.is_empty() and restored.campaign_cleared==state.profile.campaign_cleared and restored.coins==state.profile.coins,"QA progress saved")
	FileAccess.open(folder+"/report.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"failures":failures,"version":ProjectSettings.get_setting("application/config/version"),"rows":rows,"levels":level_numbers,"sequential_unlocks":sequential and fixture_unlock_before==0,"fixture_unlock_before":fixture_unlock_before,"scope":"Isolated rendered Main, starter inventory, coarse chest aim and held spur injected in engine. No OS input/human play. Default 1/3 fixture supplies level-2 unlock; explicit --levels uses natural results only."},"\t"))
	main.notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
