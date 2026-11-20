extends "test_earned109.gd"
## Reproduces the observed post-purchase panel rebuild, with a declared QA
## economy fixture. This is not an earned campaign or a human response-time test.
func run()->void:
	var folder=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--folder="):folder=arg.trim_prefix("--folder=")
	var state=root.get_node("GameState")
	if folder.is_empty() or DirAccess.dir_exists_absolute(folder) or not state.save_path.contains("qa_") or OS.get_environment("GALUMU_MEMORY_BOUND")!="1024" or DisplayServer.get_name()=="headless":quit(2);return
	DirAccess.make_dir_recursive_absolute(folder)
	state.save_path=folder+"/qa_profile.json";state.backup_path=folder+"/qa_backup.json";state.profile=state.default_profile()
	AudioServer.set_bus_mute(0,true);root.size=Vector2i(1280,720)
	var main=load("res://scenes/main.tscn").instantiate();root.add_child(main);current_scene=main
	for i in range(30):await process_frame
	var rows=[]
	for id in ["eng_lance_long_2","eng_helmet_5","eng_shield_5","fr_lance_long_2"]:
		var item=Catalogue109.find(state.items,id)
		state.profile.coins=int(item.price)+26;state.profile.renown=60
		main.selected_slot=item.slot;main.selected_era=-1;main.selected_region=0;main.selected_quality=0;main.selected_item={};main.show_armory()
		for i in range(8):await process_frame
		main.armory_cards[id].pressed.emit()
		for i in range(5):await process_frame
		var purchase=action_button(main.info_panel,"购买 ·")
		check(purchase!=null and not purchase.disabled,"Fixture purchase exists "+id)
		if not purchase or purchase.disabled:break
		click(purchase)
		var start=Time.get_ticks_usec();var frames=0;var ready_ms=-1.0;var frame10_ready=false
		while Time.get_ticks_usec()-start<1000000:
			await process_frame;frames+=1
			var ready=main.info_panel.get_meta("details_ready",false) and action_button(main.info_panel,"装备")!=null
			if frames==10:frame10_ready=ready;await capture(folder,id+"-frame10")
			if ready and ready_ms<0:ready_ms=(Time.get_ticks_usec()-start)/1000.0
			if ready and frames>=10:break
		check(ready_ms>=0 and ready_ms<1000,"Panel becomes usable within one second "+id)
		await capture(folder,id+"-ready")
		var equip=action_button(main.info_panel,"装备")
		check(equip!=null and not equip.disabled,"Owned item can be equipped after rebuild "+id)
		if equip and not equip.disabled:click(equip)
		for i in range(20):await process_frame
		check(state.profile.equipped.get(item.slot)==id and state.profile.coins==26 and not state.profile_save_pending,"Equip succeeds once and persists "+id)
		rows.append({"item":id,"ready_ms":ready_ms,"frames":frames,"ready_at_frame10":frame10_ready,"equipped":state.profile.equipped.get(item.slot),"coins":state.profile.coins})
	FileAccess.open(folder+"/report.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"failures":failures,"rows":rows,"scope":"Actual PCK post-purchase panel readiness, viewport purchase/equip clicks. Four explicitly funded UI fixtures; no campaign growth/quality claim. Original ten-frame timing retained for diagnosis."},"\t"))
	await main._shutdown_and_quit();quit(0 if failures.is_empty() else 1)
