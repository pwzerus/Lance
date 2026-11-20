extends "test_earned109.gd"
## A new player spends on decoration first, cannot afford an entry lance,
## then earns the missing money through actual free arena results. Deliberate
## poor aim is finite control, not a forced result or a grant of currency.
func run()->void:
	var folder=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--folder="):folder=arg.trim_prefix("--folder=")
	var state=root.get_node("GameState")
	if folder.is_empty() or DirAccess.dir_exists_absolute(folder) or not state.save_path.contains("qa_") or OS.get_environment("GALUMU_MEMORY_BOUND")!="1024" or DisplayServer.get_name()=="headless":quit(2);return
	DirAccess.make_dir_recursive_absolute(folder)
	state.save_path=folder+"/qa_profile.json";state.backup_path=folder+"/qa_backup.json";state.load_profile();state.profile=state.default_profile()
	state.profile.settings.combat_brief_v044=true
	check(state.save_profile(),"New recovery journey saved")
	root.size=Vector2i(1280,720);AudioServer.set_bus_mute(0,true)
	var main=load("res://scenes/main.tscn").instantiate();root.add_child(main);current_scene=main
	for i in range(30):await process_frame
	for id in ["crest_diamond","crest_cross","crest_quarterly"]:await buy_equipment(main,state,id,folder)
	check(state.profile.coins==30 and state.profile.campaign_cleared.is_empty(),"Cosmetic detour genuinely spent starter purse")
	var target=Catalogue109.find(state.items,"eng_lance_long_0")
	main.selected_slot="lance";main.selected_era=-1;main.selected_region=0;main.selected_quality=0;main.selected_item={};main.show_armory()
	for i in range(8):await process_frame
	main.armory_cards[target.id].pressed.emit()
	for i in range(6):await process_frame
	var cannot_buy=action_button(main.info_panel,"还差")
	check(cannot_buy!=null and cannot_buy.disabled,"Insufficient coins shown on disabled purchase")
	await capture(folder,"cannot-afford-entry-lance")
	var rows=[]
	for attempt in range(3):
		if int(state.profile.coins)>=int(target.price):break
		var before=state.profile.duplicate(true)
		main.show_match_setup()
		for i in range(4):await process_frame
		var enter=action_button(main.screen,"进入竞技场")
		check(enter!=null and not enter.disabled,"Free arena remains accessible without an entry fee")
		if not enter:break
		click(enter)
		for i in range(4):await process_frame
		check(is_instance_valid(main.battle),"Free arena UI starts a real battle")
		if not is_instance_valid(main.battle):break
		var b=main.battle
		if root.focus_exited.is_connected(b._on_focus_lost):root.focus_exited.disconnect(b._on_focus_lost)
		b.match_model.rng.seed=10901+97*attempt;b.ai_rng.seed=11332+97*attempt
		var began=Time.get_ticks_msec();var captured=false
		while Time.get_ticks_msec()-began<115000 and not main.result_visible:
			await process_frame
			if not b.presentation_ready:continue
			b.mouse_held=true;b.ui_pointer_held=false;b.pointer_aim=.54
			if b.guard_slot!=2:b._select_guard(2)
			if not captured and not b.exchange_log.is_empty():
				captured=true;await capture(folder,"recovery%d-hit"%(attempt+1))
		check(main.result_visible,"Recovery match finishes naturally")
		if not main.result_visible:main._close_battle();break
		for i in range(5):await process_frame
		await capture(folder,"recovery%d-result"%(attempt+1))
		var winner=int(main.pending_result.winner)
		var expected=180 if winner==0 else (110 if winner==-1 else 55)
		check(main.reward.coins==expected and state.profile.coins==int(before.coins)+expected,"Natural free-play outcome pays its advertised amount")
		check(state.profile.owned==before.owned and state.profile.equipped==before.equipped and state.profile.campaign_cleared.is_empty(),"Recovery preserves purchases and does not grant campaign clears")
		check(not state.profile_save_pending,"Free-play recovery reward persisted")
		rows.append({"attempt":attempt+1,"result":main.pending_result.duplicate(true),"reward":main.reward.duplicate(true),"coins_before":before.coins,"coins_after":state.profile.coins,"hits":b.exchange_log.duplicate(true)})
		main._close_battle();await process_frame
	check(int(state.profile.coins)>=int(target.price),"Real earned money can recover from cosmetic spending")
	await buy_equipment(main,state,target.id,folder)
	check(target.id in state.profile.owned and state.profile.equipped.lance==target.id,"Recovered purchase can be equipped")
	check(state.profile.owned.has("lance_ash"),"Starter weapon is still owned")
	var before_reload=state.profile.duplicate(true)
	state.load_profile()
	check(state.profile==before_reload,"Recovered money and collection survive reload")
	main.show_home()
	for i in range(8):await process_frame
	await capture(folder,"recovered-camp")
	FileAccess.open(folder+"/report.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"failures":failures,"purchases":purchase_log,"rows":rows,"final_profile":state.profile,"scope":"Real UI purchases, disabled unaffordable button, free-arena UI entry, deliberately poor finite engine-local aim/guard/spur, natural battle results and earnings, QA save/reload. No forced winner, currency grant, OS input or human feel claim."},"\t"))
	await main._shutdown_and_quit()
	quit(0 if failures.is_empty() else 1)
