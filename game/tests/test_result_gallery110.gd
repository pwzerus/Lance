extends "test_ux_baseline110.gd"
const Campaign110=preload("res://scripts/core/campaign.gd")
func archived(batch:int,number:int,attempt:int)->Dictionary:
	var path="E:/GALUMU/docs/development/logs/econ109-earned%02d/screens/report.json"%batch
	var data=JSON.parse_string(FileAccess.get_file_as_string(path))
	for row in data.rows:
		if int(row.level)==number and int(row.attempt)==attempt:
			var copy=row.duplicate(true);copy.source=path;return copy
	check(false,"Missing actual archived match");return {}
func run()->void:
	var folder="";var compact=false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--folder="):folder=arg.trim_prefix("--folder=")
		if arg=="--compact":compact=true
	var state=root.get_node("GameState")
	if folder.is_empty() or DirAccess.dir_exists_absolute(folder) or not state.save_path.contains("qa_") or OS.get_environment("GALUMU_MEMORY_BOUND")!="1024" or DisplayServer.get_name()=="headless":quit(2);return
	DirAccess.make_dir_recursive_absolute(folder)
	state.save_path=folder+"/qa_profile.json";state.backup_path=folder+"/qa_backup.json";state.profile=state.default_profile();state.profile.settings.combat_brief_v044=true
	root.size=Vector2i(960,540) if compact else Vector2i(1280,720);AudioServer.set_bus_mute(0,true)
	var main=load("res://scenes/main.tscn").instantiate();root.add_child(main);current_scene=main;main.set_process(false)
	for i in range(30):await process_frame
	var cases=[]
	for entry in [[13,64,1],[15,75,2],[16,80,1]]:
		var row=archived(entry[0],entry[1],entry[2]);row.tag="actual-record-%d-%d"%[row.level,row.attempt];cases.append(row)
	var gap=cases[2].duplicate(true);gap.tag="negative-missing-prior-clears";gap.incomplete=true;cases.append(gap)
	var replay=archived(1,2,1);replay.tag="earlier-replay-after-completion";replay.reward={"coins":33,"renown":0,"first_clear":false};cases.append(replay)
	var double=cases[1].duplicate(true);double.tag="supplied-simultaneous-death";double.result.winner=-1;double.result.player_dead=true;double.result.enemy_dead=true;double.reward={"coins":0,"renown":0};double.hits=[{"attacker":1,"defender":0,"zone":"head","ko":true,"dead":true,"damage":80,"balance_left":0,"points":0,"ko_reason":"fatal"},{"attacker":0,"defender":1,"zone":"body","ko":true,"dead":true,"damage":80,"balance_left":0,"points":0,"ko_reason":"fatal"}];double.source="Explicit simultaneous-outcome presentation fixture";cases.append(double)
	var shield=cases[0].duplicate(true);shield.tag="supplied-shield-impulse";shield.hits=[{"attacker":1,"defender":0,"zone":"shield","ko":true,"dead":false,"damage":2,"balance_left":40,"points":1,"ko_reason":"impact","unsteady":.4,"impulse":100}];shield.source="Explicit shield impulse presentation fixture";cases.append(shield)
	var rows=[]
	for row in cases:
		state.profile.campaign_cleared=range(1,81)
		main._start_level(int(row.level))
		var b=main.battle;var start=Time.get_ticks_msec()
		while not b.presentation_ready and Time.get_ticks_msec()-start<30000:await process_frame
		check(b.presentation_ready,"Fixture reaches rendered Battle")
		b.set_process(false);b.set_physics_process(false);b.is_finished=true
		b.exchange_log.assign(row.hits.duplicate(true))
		b._update_hud()
		b.match_model.fighters[0].hp=row.result.get("player_hp",0);b.match_model.fighters[1].hp=row.result.get("enemy_hp",0)
		if row.get("incomplete",false):state.profile.campaign_cleared=[80]
		main.pending_result=row.result.duplicate(true);main.reward=row.reward.duplicate(true);main.show_result()
		for i in range(12):await process_frame
		var labels=labels110(main.screen)
		var title=main.screen.find_child("ResultTitle",true,false)
		check(title!=null,"Result title present")
		if row.tag=="actual-record-80-1":check(title.text=="八章挑战完成","Full eighty clear feedback")
		if row.tag in ["negative-missing-prior-clears","earlier-replay-after-completion"]:check(title.text!="八章挑战完成","No false full-campaign celebration")
		if row.tag=="actual-record-64-1":check(str(labels).contains("累积伤势"),"Accumulated injury visible without H")
		if row.tag=="supplied-simultaneous-death":check(str(labels).contains("双方阵亡"),"Both deaths visible")
		if row.tag=="supplied-shield-impulse":check(str(labels).contains("虽用盾挡住"),"Shield impulse cause visible")
		await capture(folder,str(row.tag))
		var concise=main.result_progress.text
		key110(KEY_H)
		for i in range(6):await process_frame
		check(main.result_detail_scroll.visible,"Detailed evidence accessible")
		if main.current_mode=="war":check(not main.result_details.text.contains("比分"),"War details omit irrelevant tournament score")
		await capture(folder,str(row.tag)+"-details")
		key110(KEY_H)
		for i in range(4):await process_frame
		check(main.result_progress.text==concise,"Normal advice survives H round trip")
		rows.append({"tag":row.tag,"source":row.source,"labels":labels,"result":row.result,"reward":row.reward})
		if int(row.result.winner)==1:
			var adjust=action_button(main.screen,"调整装备")
			check(adjust!=null,"Loss offers direct equipment adjustment")
			if adjust:click(adjust)
			for i in range(12):await process_frame
			check(main.page=="armory" and not is_instance_valid(main.battle),"Equipment recovery closes finished Battle")
			await capture(folder,str(row.tag)+"-adjust")
		else:
			key110(KEY_ESCAPE)
			for i in range(6):await process_frame
			check(main.page=="home" and not is_instance_valid(main.battle),"Result escape goes to camp")
		main.show_home()
	check(int(state.profile.matches)==0,"Presentation fixtures never award matches")
	FileAccess.open(folder+"/report.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"failures":failures,"rows":rows,"compact":compact,"scope":"Actual isolated rendering and viewport navigation of archived natural results plus labeled supplied edge states. No newly played match, reward, physical fall or human testimony is claimed."},"\t"))
	await main._shutdown_and_quit();quit(0 if failures.is_empty() else 1)
