extends "test_live084.gd"
## Normal Main including results, rewards, saves and replay buttons. Only the
## actual Battle autoplay input is substituted for a person; rules stay live.
var failures=[]
func check(ok:bool,why:String)->void:
	if not ok and why not in failures:failures.append(why)
func find_replay(node:Node)->Button:
	if node is Button and node.text.begins_with("再次对冲"):return node
	for child in node.get_children():
		var found=find_replay(child)
		if found:return found
	return null
func click(button:Button)->void:
	var e=InputEventMouseButton.new();e.button_index=MOUSE_BUTTON_LEFT;e.pressed=true;e.position=button.get_global_rect().get_center()
	root.push_input(e,true);e=e.duplicate();e.pressed=false;root.push_input(e,true)
func prepare(battle,seed_value:int)->void:
	battle.autoplay=true
	battle.match_model.rng.seed=seed_value
	battle.ai_rng.seed=seed_value+431
	if root.focus_exited.is_connected(battle._on_focus_lost):root.focus_exited.disconnect(battle._on_focus_lost)
func run()->void:
	var folder="";var seconds=420.0;var mode="arena";var difficulty=1;var kit="starter";var blood=false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--folder="):folder=a.trim_prefix("--folder=")
		if a.begins_with("--seconds="):seconds=clampf(float(a.trim_prefix("--seconds=")),60,480)
		if a.begins_with("--mode="):mode=a.trim_prefix("--mode=")
		if a.begins_with("--difficulty="):difficulty=clampi(int(a.trim_prefix("--difficulty=")),0,2)
		if a.begins_with("--kit="):kit=a.trim_prefix("--kit=")
		if a=="--blood":blood=true
	var state=root.get_node("GameState")
	if folder.is_empty() or DirAccess.dir_exists_absolute(folder) or not state.save_path.contains("qa_") or OS.get_environment("GALUMU_MEMORY_BOUND")!="1024" or DisplayServer.get_name()=="headless" or mode not in ["arena","war"]:quit(2);return
	DirAccess.make_dir_recursive_absolute(folder)
	state.save_path=folder+"/qa_profile.json";state.backup_path=folder+"/qa_backup.json";state.load_profile()
	state.profile.settings.sound=true;state.profile.settings.blood=blood;state.profile.settings.difficulty=difficulty
	AudioServer.set_bus_mute(0,true)
	if kit=="heavy":
		state.profile.renown=60;state.profile.region=2
		state.profile.equipped.merge({"armor":"de_armor_5","helmet":"de_helmet_5","shield":"de_shield_5","lance":"de_lance_stout_5","horse":"horse_courser","caparison":"caparison_velvet","crest":"crest_bend"},true)
	elif kit=="steady":
		state.profile.renown=32;state.profile.equipped.horse="horse_steady"
		state.profile.equipped.armor="eng_armor_2";state.profile.equipped.helmet="eng_helmet_2";state.profile.equipped.caparison="caparison_wool"
	for id in state.profile.equipped.values():
		check(not load("res://scripts/core/catalogue.gd").find(state.items,id).is_empty(),"Unknown test loadout item "+str(id))
		if id not in state.profile.owned:state.profile.owned.append(id)
	if not failures.is_empty():print(failures);quit(2);return
	root.size=Vector2i(1280,720)
	var main=load("res://scenes/main.tscn").instantiate();root.add_child(main);current_scene=main
	# Wall-clock warmup is explicit; the boot frame cannot consume a timer.
	var warm=Time.get_ticks_usec()
	while Time.get_ticks_usec()-warm<2000000:await process_frame
	main._start_match(mode,false);prepare(main.battle,87000)
	var equipped=state.profile.equipped.duplicate(true)
	var start=Time.get_ticks_usec();var previous=start;var next_sample=0.0;var last_result=-1;var result_at=-1.0
	var frame_ms:Array[float]=[];var by_phase={};var rows=[];var samples=[]
	while (Time.get_ticks_usec()-start)/1000000.0<seconds:
		await process_frame
		var now=Time.get_ticks_usec();var elapsed=(now-start)/1000000.0;var ms=(now-previous)/1000.0;previous=now
		frame_ms.append(ms)
		var b=main.battle
		var phase="result" if main.result_visible else str(b.match_model.phase)
		if b.exchange_state.get("impact_active",false) and not main.result_visible:phase="contact"
		if not by_phase.has(phase):by_phase[phase]=[]
		by_phase[phase].append(ms)
		for fighter in b.match_model.fighters:
			for key in ["x","speed","hp","stamina","arm","aim","guard","lean"]:check(is_finite(float(fighter[key])),"Nonfinite fighter "+key)
			check(float(fighter.stamina)>=0 and float(fighter.stamina)<=100,"Horse stamina escaped its bounds")
			check(mode!="arena" or not fighter.dead,"Arena produced a death")
		if main.result_visible and last_result!=b.get_instance_id():
			last_result=b.get_instance_id();result_at=elapsed
			rows.append({"seed":87000+(rows.size()*97),"seconds":elapsed,"result":main.pending_result.duplicate(true),"hits":b.exchange_log.duplicate(true),"coins":state.profile.coins,"renown":state.profile.renown,"profile_matches":state.profile.matches,"save_pending":state.profile_save_pending,"bus_count":AudioServer.bus_count})
			check(state.profile.matches==rows.size(),"Duplicate or missing match reward")
			check(not state.profile_save_pending,"Normal match reward was not persisted")
			check(AudioServer.bus_count==5,"Replay created extra audio buses")
			check(find_replay(main.screen)!=null,"Visible result lacks replay button")
		if main.result_visible and elapsed-result_at>=1.3:
			var old=b
			var button=find_replay(main.screen)
			if button:click(button)
			check(main.battle!=old,"Replay click did not create the next match")
			if main.battle==old:break
			prepare(main.battle,87000+(rows.size()*97))
			check(not main.result_visible,"Replay retained the result overlay")
		if elapsed>=next_sample:
			next_sample+=1
			samples.append({"seconds":elapsed,"phase":phase,"resources":Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT),"nodes":Performance.get_monitor(Performance.OBJECT_NODE_COUNT),"fps":Engine.get_frames_per_second(),"matches":state.profile.matches})
	var summaries={}
	for phase in by_phase:summaries[phase]=stats(by_phase[phase])
	check(rows.size()>0,"No complete result was reached")
	var saved=state._read_save(state.save_path)
	check(not saved.is_empty() and saved.matches==state.profile.matches and saved.coins==state.profile.coins,"Actual disk progress differs from current rewards")
	var output={"passed":failures.is_empty(),"failures":failures,"mode":mode,"difficulty":difficulty,"kit":kit,"blood":blood,"wall_seconds":(Time.get_ticks_usec()-start)/1000000.0,"version":ProjectSettings.get_setting("application/config/version"),"executable":OS.get_executable_path(),"equipped":equipped,"matches":rows,"samples":samples,"all_frames":stats(frame_ms),"phases":summaries,"scope":"Actual Main/Battle GPU and normal result/reward/persistence path; production autoplay, varied seeded match/AI, viewport replay clicks, audio mixed but hardware-facing Master muted. No injected damage or OS input; not human win rates."}
	FileAccess.open(folder+"/report.json",FileAccess.WRITE).store_string(JSON.stringify(output,"\t"))
	print("PLAY087 results=",rows.size()," failures=",failures)
	main.notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
