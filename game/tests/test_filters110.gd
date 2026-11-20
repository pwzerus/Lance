extends "test_ux_baseline110.gd"
func tab110(main:Node,caption:String)->void:
	var b=action_button(main.screen,caption)
	check(b!=null and not b.disabled,"Visible tab "+caption)
	if b:click(b)
	for i in range(20):await process_frame
func options110(main:Node)->Array:
	var values=[]
	for node in main.screen.get_children():
		if node is OptionButton:values.append({"disabled":node.disabled,"selected":node.selected,"text":node.get_item_text(node.selected)})
	return values
func run()->void:
	var folder=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--folder="):folder=arg.trim_prefix("--folder=")
	var state=root.get_node("GameState")
	if folder.is_empty() or DirAccess.dir_exists_absolute(folder) or not state.save_path.contains("qa_") or OS.get_environment("GALUMU_MEMORY_BOUND")!="1024" or DisplayServer.get_name()=="headless":quit(2);return
	DirAccess.make_dir_recursive_absolute(folder)
	state.save_path=folder+"/qa_profile.json";state.backup_path=folder+"/qa_backup.json";state.profile=state.default_profile()
	root.size=Vector2i(960,540);AudioServer.set_bus_mute(0,true)
	var main=load("res://scenes/main.tscn").instantiate();root.add_child(main);current_scene=main
	for i in range(25):await process_frame
	main.selected_slot="armor";main.selected_quality=6;main.selected_region=3;main.selected_era=4;main.selected_item={};main.show_armory()
	for i in range(20):await process_frame
	var armor_ids=main.armory_cards.keys();armor_ids.sort()
	check(armor_ids==["de_armor_5"],"Initial highest German armor filter is meaningful")
	var before=state.profile.duplicate(true)
	await tab110(main,"家族纹章")
	check(main.armory_cards.size()==12,"Inapplicable inherited filters do not hide family arms")
	var disabled=options110(main)
	check(disabled.size()==3 and disabled.all(func(v):return v.disabled),"All three irrelevant filters visibly disabled")
	await capture(folder,"01-family-filters")
	await tab110(main,"胸甲")
	var after_ids=main.armory_cards.keys();after_ids.sort()
	check(after_ids==armor_ids and main.selected_quality==6 and main.selected_region==3 and main.selected_era==4,"Returning to armor restores exact prior selection")
	check(options110(main).all(func(v):return not v.disabled),"Gear filters reenabled")
	await capture(folder,"02-restored-armor")
	await tab110(main,"坐骑")
	check(main.armory_cards.is_empty(),"Country-specific horse filter reports empty rather than invented national horses")
	await capture(folder,"03-horse-empty")
	await tab110(main,"清除筛选")
	check(main.armory_cards.size()==10,"Clear filters restores all shared horses")
	await tab110(main,"马衣")
	check(main.armory_cards.size()==4,"Three cloth types plus no-cloth option remain visible")
	await capture(folder,"04-cloth")
	await tab110(main,"盾牌")
	check(main.armory_cards.size()>=24,"Independent shield catalog remains available")
	await tab110(main,"返回营地")
	await tab110(main,"设置")
	check(str(labels110(main.screen)).contains("结算详情"),"Settings explains H after battle")
	await capture(folder,"05-settings-context")
	await tab110(main,"返回营地")
	await tab110(main,"玩法与制作说明")
	check(str(labels110(main.screen)).contains("结算详情"),"Help matches result H behavior")
	await capture(folder,"06-help-context")
	await tab110(main,"返回营地")
	await tab110(main,"历史手记")
	check(str(labels110(main.screen)).contains("军械库详情") and not str(labels110(main.screen)).contains("项目 docs"),"Packaged history guidance points to visible player content")
	await capture(folder,"07-history-context")
	check(state.profile==before,"Navigation does not mutate purchases, choices or save progress")
	FileAccess.open(folder+"/report.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"failures":failures,"family_filter_states":disabled,"armor_ids":armor_ids,"scope":"Actual isolated GPU slot-tab and clear-filter clicks; initial restrictive filter is a declared fixture. No purchases or profile mutation, no OS input."},"\t"))
	await main._shutdown_and_quit();quit(0 if failures.is_empty() else 1)
