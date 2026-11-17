extends "test_play087.gd"
const Campaign103=preload("res://scripts/core/campaign.gd")
const Model103=preload("res://scripts/core/joust_match.gd")
func capture(folder:String,name:String)->void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(folder+"/"+name+".png")
func run()->void:
	var folder="";var nums=[23,24,25]
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--folder="):folder=a.trim_prefix("--folder=")
		if a.begins_with("--levels="):
			nums=[]
			for value in a.trim_prefix("--levels=").split(","):nums.append(int(value))
	var state=root.get_node("GameState")
	if folder.is_empty() or DirAccess.dir_exists_absolute(folder) or not "qa_" in state.save_path or OS.get_environment("GALUMU_MEMORY_BOUND")!="1024" or DisplayServer.get_name()=="headless":quit(2);return
	DirAccess.make_dir_recursive_absolute(folder)
	state.save_path=folder+"/qa_profile.json";state.backup_path=folder+"/qa_backup.json"
	state.profile=state.default_profile();state.profile.settings.combat_brief_v044=true
	state.profile.equipped.merge({"armor":"eng_armor_1","helmet":"eng_helmet_1","shield":"eng_shield_0","lance":"eng_lance_long_1","horse":"horse_grey","crest":"crest_bend"},true)
	for id in state.profile.equipped.values():
		if id not in state.profile.owned:state.profile.owned.append(id)
	AudioServer.set_bus_mute(0,true);root.size=Vector2i(1280,720)
	var main=load("res://scenes/main.tscn").instantiate();root.add_child(main);current_scene=main
	for i in range(30):await process_frame
	var rows=[]
	for n in nums:
		var expected=Campaign103.level(state.items,n)
		if n>=18 and n<=28:check(is_equal_approx(float(expected.ai.get("pressure_ease",0)),.88),"Published teaching pace "+str(n))
		if n==24:check(expected.archetype=="balanced","Published level 24 recovery opponent")
		if n>=21 and n<=28:check(expected.ai.get("lesson_change_passes",[])==([2] if n<=24 else [2,3]),"Published line-change rounds")
		state.profile.campaign_cleared=range(1,n)
		main.level_selected=n
		main.show_levels(2)
		for i in range(4):await process_frame
		await capture(folder,"level%d-menu"%n)
		main._start_level(n);var b=main.battle
		if root.focus_exited.is_connected(b._on_focus_lost):root.focus_exited.disconnect(b._on_focus_lost)
		b.match_model.rng.seed=10301;b.ai_rng.seed=10732
		check(b.ai_controller.profile==Campaign103.level(state.items,n).ai,"Actual level profile "+str(n))
		var began=Time.get_ticks_msec();var next_input=-1.0;var lines=[];var last_line="";var captured_hit=false
		while Time.get_ticks_msec()-began<120000 and not main.result_visible:
			await process_frame
			if not b.presentation_ready:continue
			var p=b.match_model.fighters[0];var enemy=b.match_model.fighters[1]
			b.mouse_held=absf(p.x-enemy.x)<3000;b.ui_pointer_held=false
			if b.match_model.time_elapsed>=next_input:
				next_input=b.match_model.time_elapsed+.6
				var target=Model103.flank_position(enemy) if float(enemy.guard)>.55 else Model103.head_position(enemy)
				b.pointer_aim=asin(clampf((target.y-8-Model103.hand_position(p).y)/Model103.lance_length(p),-.629,.548))
				var incoming=Model103.tip_position(enemy).y
				b._select_guard(0 if incoming<Model103.body_position(p).y-30 else (2 if incoming>Model103.body_position(p).y+22 else 1))
			if b.match_model.phase=="charge" and b.ai_controller.last_observation_time>=0:
				var line=str(b.match_model.pass_number)+":"+b.ai_zone
				if line!=last_line:
					last_line=line;lines.append(line)
					await capture(folder,"level%d-line%d"%[n,lines.size()])
			if not captured_hit and not b.exchange_log.is_empty():
				captured_hit=true;await capture(folder,"level%d-hit"%n)
		check(main.result_visible,"Normal result reached "+str(n))
		if main.result_visible:
			for i in range(5):await process_frame
			await capture(folder,"level%d-result"%n)
			var won=main.pending_result.winner==0
			check(not won or n in state.profile.campaign_cleared,"Clear saved")
			check(not won or main.reward.coins==Campaign103.reward_coins(n,false),"Reward correct")
			rows.append({"level":n,"result":main.pending_result.duplicate(true),"reward":main.reward.duplicate(true),"lines":lines,"hits":b.exchange_log.duplicate(true)})
		main._close_battle();await process_frame
		check(is_equal_approx(Engine.time_scale,1.0),"Close restores time")
		FileAccess.open(folder+"/partial.json",FileAccess.WRITE).store_string(JSON.stringify(rows,"\t"))
	var disk=state.sanitize(state._read_save(state.save_path))
	check(disk.coins==state.profile.coins and disk.campaign_cleared==state.profile.campaign_cleared,"QA disk progress matches")
	FileAccess.open(folder+"/report.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"failures":failures,"version":ProjectSettings.get_setting("application/config/version"),"rows":rows,"scope":"Actual Main/Battle GPU with fixed q1 purchased kit, engine-injected 600ms visible-line input. Normal result/reward/disk-save, isolated QA, no OS input or human acceptance."},"\t"))
	main.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
