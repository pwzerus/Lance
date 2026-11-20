extends "test_earned109.gd"
## Segmented rendered campaign using a persistent isolated save. No coins,
## ownership, clears, stats or outcomes are granted. UI purchases and normal
## match rewards supply all growth. Finite scripted controls are not humans.
var navigation=[]
func profile_root110()->String:return "E:/GALUMU/docs/development/logs/ux110-"
func key110(code:int)->void:
	var event=InputEventKey.new();event.keycode=code;event.physical_keycode=code;event.pressed=true
	root.push_input(event,true);event=event.duplicate();event.pressed=false;root.push_input(event,true)
func press(main:Node,prefix:String)->bool:
	var button=action_button(main.screen,prefix)
	check(button!=null and not button.disabled,"Visible navigation: "+prefix)
	if not button or button.disabled:return false
	click(button)
	for i in range(8):await process_frame
	return true
func enter110(main:Node,n:int)->void:
	if is_instance_valid(main.battle):
		if not main.battle.is_finished:return # R already started this same level.
		if int(main.pending_result.winner)==0 and int(main.current_level.number)==n-1:
			if await press(main,"下一关"):
				navigation.append({"level":n,"route":"actual next-level button"});return
		key110(KEY_ESCAPE)
		for i in range(8):await process_frame
	if main.page!="home":await press(main,"返回营地")
	await press(main,"关卡挑战")
	var chapter=(n-1)/10
	if int(main.level_chapter)!=chapter:
		await press(main,str(chapter+1)+"　")
	# Card coordinates belong to the production grid; the button is found
	# from its containing card, not by calling _start_level.
	var select:Button=null
	var at=Vector2(60+((n-1)%5)*266,234+(((n-1)%10)/5)*176)
	for card in main.screen.get_children():
		if card is PanelContainer or card is Panel:
			if card.position.distance_to(at)<1:select=action_button(card,"选择")
	check(select!=null,"Unlocked level card reachable "+str(n))
	if select:
		click(select)
		for i in range(8):await process_frame
	await press(main,"出战")
	navigation.append({"level":n,"route":"camp, chapter tab, card, battle buttons"})
func run()->void:
	var folder="";var profile_folder="";var first=1;var last=5;var heavy=false;var max_attempts=3
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--folder="):folder=arg.trim_prefix("--folder=")
		if arg.begins_with("--profile="):profile_folder=arg.trim_prefix("--profile=")
		if arg.begins_with("--first="):first=int(arg.trim_prefix("--first="))
		if arg.begins_with("--last="):last=int(arg.trim_prefix("--last="))
		if arg.begins_with("--attempts="):max_attempts=clampi(int(arg.trim_prefix("--attempts=")),1,3)
		if arg=="--heavy":heavy=true
	var state=root.get_node("GameState")
	if folder.is_empty() or DirAccess.dir_exists_absolute(folder) or not profile_folder.begins_with(profile_root110()) or not profile_folder.ends_with("qa_journey") or not state.save_path.contains("qa_") or OS.get_environment("GALUMU_MEMORY_BOUND")!="1024" or DisplayServer.get_name()=="headless" or first<1 or last>80 or last<first:quit(2);return
	DirAccess.make_dir_recursive_absolute(folder);DirAccess.make_dir_recursive_absolute(profile_folder)
	state.save_path=profile_folder+"/qa_profile.json";state.backup_path=profile_folder+"/qa_backup.json";state.load_profile()
	if state.recovery_required:quit(2);return
	if first==1:check(state.profile.matches==0 and state.profile.coins==520 and state.profile.campaign_cleared.is_empty(),"Journey begins with untouched starter economy")
	check(state.campaign_unlocked(first),"Persistent earned save unlocks segment start")
	if not failures.is_empty():quit(2);return
	state.profile.settings.combat_brief_v044=true;state.profile.settings.mouse_only=false
	check(state.save_profile(),"Save QA preferences")
	var initial=state.profile.duplicate(true)
	root.size=Vector2i(1280,720);AudioServer.set_bus_mute(0,true)
	var main=load("res://scenes/main.tscn").instantiate();root.add_child(main);current_scene=main
	for i in range(30):await process_frame
	var rows=[];var completed=true
	for n in range(first,last+1):
		check(state.campaign_unlocked(n),"No synthetic unlock "+str(n))
		if not state.campaign_unlocked(n):completed=false;break
		if n>=6:
			var q=0
			for candidate in range(6):
				if Catalogue109.required_renown(Catalogue109.find(state.items,"eng_lance_long_%d"%candidate))<=int(state.profile.renown):q=candidate
			var desired=["eng_lance_%s_%d"%["stout" if heavy else "long",q],"eng_armor_%d"%q,"eng_helmet_%d"%q,(["horse_cob","horse_chestnut","horse_e2","horse_e2","horse_steady","horse_steady"] if heavy else ["horse_bay","horse_grey","horse_e1","horse_e2","horse_e4","horse_e4"])[q],"eng_shield_%d"%(clampi(q/2,0,2)*2+(1 if heavy else 0))]
			for id in desired:
				var item=Catalogue109.find(state.items,id)
				if item.is_empty() or state.profile.equipped.get(item.slot)==id:continue
				if id not in state.profile.owned and (Catalogue109.required_renown(item)>int(state.profile.renown) or int(item.price)>int(state.profile.coins)):continue
				if is_instance_valid(main.battle):await press(main,"返回营地")
				await buy_equipment(main,state,id,folder)
		var won=false
		for attempt in range(max_attempts):
			var before=state.profile.duplicate(true)
			await enter110(main,n)
			check(is_instance_valid(main.battle),"Earned level started "+str(n))
			if not is_instance_valid(main.battle):break
			var b=main.battle
			if root.focus_exited.is_connected(b._on_focus_lost):root.focus_exited.disconnect(b._on_focus_lost)
			b.match_model.rng.seed=10301+attempt*97;b.ai_rng.seed=10732+attempt*97
			var began=Time.get_ticks_msec();var next_input=-1.0;var holding=false;var hit_captured=false
			var strategy=["forward","reserve","coast"][attempt]
			while Time.get_ticks_msec()-began<115000 and not main.result_visible:
				await process_frame
				if not b.presentation_ready:continue
				var p=b.match_model.fighters[0];var enemy=b.match_model.fighters[1];var gap=absf(p.x-enemy.x)
				b.mouse_held=(gap<1500 if strategy=="reserve" else (gap>1500 if strategy=="coast" else gap<3000));b.ui_pointer_held=false
				var want=gap<1600 and b.match_model.phase=="charge"
				if want!=holding:holding=want;forward_key(holding)
				if b.match_model.time_elapsed>=next_input:
					next_input=b.match_model.time_elapsed+.6
					var target=Model103.flank_position(enemy) if float(enemy.guard)>.55 else Model103.head_position(enemy)
					b.pointer_aim=asin(clampf((target.y-8-Model103.hand_position(p).y)/Model103.lance_length(p),-.629,.548))
					var incoming=Model103.tip_position(enemy).y
					var wanted_guard=0 if incoming<Model103.body_position(p).y-30 else (2 if incoming>Model103.body_position(p).y+22 else 1)
					if b.guard_slot!=wanted_guard:b._select_guard(wanted_guard)
				if not hit_captured and not b.exchange_log.is_empty():
					hit_captured=true;await capture(folder,"level%d-attempt%d-hit"%[n,attempt+1])
			if holding:forward_key(false)
			check(main.result_visible,"Earned match reaches result "+str(n))
			if not main.result_visible:main._close_battle();completed=false;break
			for i in range(5):await process_frame
			check(int(main.current_level.number)==n,"Navigation starts the intended opponent")
			check(main.result_rewards.text.contains(str(main.reward.coins)) if int(main.reward.coins)>0 else main.result_rewards.text.contains("不计奖励"),"Visible reward agrees with actual receipt")
			if main.current_mode=="arena":
				var score=main.screen.find_child("ResultScore",true,false)
				check(score!=null and score.text=="比分 %s : %s"%[main.pending_result.player_score,main.pending_result.enemy_score],"Visible arena score matches actual outcome")
			else:check(main.screen.find_child("ResultScore",true,false)==null,"War does not claim tournament score")
			if n%10==0:
				var concise=main.result_progress.text
				key110(KEY_H)
				for i in range(4):await process_frame
				check(main.result_detail_scroll.visible,"Champion report details open")
				key110(KEY_H)
				for i in range(4):await process_frame
				check(main.result_progress.text==concise,"Champion report restores advice")
			await capture(folder,"level%d-attempt%d-result"%[n,attempt+1])
			won=int(main.pending_result.winner)==0
			check(state.profile.matches==int(before.matches)+1,"Exactly one match recorded")
			check(state.profile.coins==int(before.coins)+int(main.reward.coins) and state.profile.renown==int(before.renown)+int(main.reward.renown),"Result receipt matches purse")
			check(state.profile.owned==before.owned and state.profile.equipped==before.equipped,"Battle preserves collection even on death")
			check(not state.profile_save_pending,"Natural match reward saved")
			var disk=state.sanitize(state._read_save(state.save_path))
			check(disk==state.profile,"Natural result matches disk")
			rows.append({"level":n,"attempt":attempt+1,"strategy":strategy,"result":main.pending_result.duplicate(true),"reward":main.reward.duplicate(true),"coins":state.profile.coins,"renown":state.profile.renown,"equipped":state.profile.equipped.duplicate(),"hits":b.exchange_log.duplicate(true)})
			FileAccess.open(folder+"/partial.json",FileAccess.WRITE).store_string(JSON.stringify({"rows":rows,"purchases":purchase_log,"ui_waits":ui_wait_log,"profile":state.profile},"\t"))
			if won:break
			if attempt+1<max_attempts:
				key110(KEY_R)
				for i in range(8):await process_frame
				check(is_instance_valid(main.battle) and not main.result_visible,"R opens exactly one retry")
				navigation.append({"level":n,"route":"viewport R retry"})
		if not won:completed=false;break
	if is_instance_valid(main.battle):await press(main,"返回营地")
	check(main.page=="home" and not is_instance_valid(main.battle),"Segment exits battle through visible camp button")
	check(is_equal_approx(Engine.time_scale,1),"Navigation restores normal time")
	await press(main,"关卡挑战")
	for i in range(8):await process_frame
	await capture(folder,"earned-progress")
	FileAccess.open(folder+"/report.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"failures":failures,"completed_requested_segment":completed,"initial_profile":initial,"final_profile":state.profile,"first":first,"last":last,"heavy":heavy,"rows":rows,"purchases":purchase_log,"ui_waits":ui_wait_log,"navigation":navigation,"scope":"Actual menu/chapter/card/next/R/camp viewport navigation with finite engine-local aim/guard/W; UI purchases and natural growth in persistent isolated save. Card selection in armory still uses its existing pressed signal; combat is scripted, not human. No granted coins/items/clears/outcomes, no OS input/human skill claim. A lost segment remains incomplete, never replaced by an invented win."},"\t"))
	await main._shutdown_and_quit()
	quit(0 if failures.is_empty() else 1)
