extends "test_earned109.gd"
## Observe the current UI before changing it. Findings are observations,
## not assertions that the old behavior is desirable. Only private QA state.
const Comparison110=preload("res://scripts/ui/equipment_comparison.gd")
func labels110(node:Node)->Array:
	var values=[]
	if node is Label:values.append(node.text)
	for child in node.get_children():values.append_array(labels110(child))
	return values
func key110(code:int)->void:
	var e=InputEventKey.new();e.keycode=code;e.physical_keycode=code;e.pressed=true
	root.push_input(e,true);e=e.duplicate();e.pressed=false;root.push_input(e,true)
func run()->void:
	var folder=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--folder="):folder=arg.trim_prefix("--folder=")
	var state=root.get_node("GameState")
	if folder.is_empty() or DirAccess.dir_exists_absolute(folder) or not state.save_path.contains("qa_") or OS.get_environment("GALUMU_MEMORY_BOUND")!="1024" or DisplayServer.get_name()=="headless":quit(2);return
	DirAccess.make_dir_recursive_absolute(folder)
	state.save_path=folder+"/qa_profile.json";state.backup_path=folder+"/qa_backup.json";state.load_profile()
	state.profile=state.default_profile();state.profile.settings.combat_brief_v044=true;state.profile.settings.mouse_only=false
	check(state.save_profile(),"Baseline QA profile saved")
	root.size=Vector2i(1280,720);AudioServer.set_bus_mute(0,true)
	var main=load("res://scenes/main.tscn").instantiate();root.add_child(main);current_scene=main
	for i in range(30):await process_frame
	var observations={}
	main.selected_slot="crest";main.selected_quality=6;main.selected_region=0;main.selected_era=-1;main.selected_item={};main.show_armory()
	for i in range(25):await process_frame
	observations.crest_inherited_quality={"cards":main.armory_cards.size(),"labels":labels110(main.screen)}
	await capture(folder,"crest-inherited-quality")
	main.selected_quality=0;main.selected_region=5;main.selected_item={};main.show_armory()
	for i in range(25):await process_frame
	observations.crest_common_region={"cards":main.armory_cards.size(),"labels":labels110(main.screen)}
	await capture(folder,"crest-common-region")
	var helmet=Catalogue109.find(state.items,"eng_helmet_5")
	main.selected_slot="helmet";main.selected_quality=0;main.selected_region=0;main.selected_era=-1;main.selected_item=helmet
	var began=Time.get_ticks_msec();main.show_armory()
	var first_line_ms=-1;var all_lines_ms=-1;var ten_frame_lines=[];var frames=0
	var expected=Comparison110.summarize(state.items,state.profile.equipped,helmet).lines
	while Time.get_ticks_msec()-began<2000:
		await process_frame;frames+=1
		var overview=main.info_panel.get_node_or_null("ComparisonScroll")
		if not overview:continue
		var actual=labels110(overview)
		if frames==10:ten_frame_lines=actual.duplicate()
		var count=0
		for line in expected:
			if line in actual:count+=1
		if count>0 and first_line_ms<0:first_line_ms=Time.get_ticks_msec()-began
		if count==expected.size():all_lines_ms=Time.get_ticks_msec()-began;break
	observations.comparison_delay={"first_line_ms":first_line_ms,"all_lines_ms":all_lines_ms,"ten_frame_labels":ten_frame_lines,"expected":expected}
	await capture(folder,"helmet-comparison-ready")
	# A presentation-state fixture; real storage rollback was covered in
	# ECON109. Do not manufacture a disk fault just to inspect a static label.
	state.profile_save_pending=true;state.profile_save_error="QA：尚未保存"
	main.show_home()
	for i in range(15):await process_frame
	observations.pending_home={"labels":labels110(main.screen),"state_supplied":true}
	await capture(folder,"pending-home")
	state.load_profile()
	main._start_level(1)
	check(is_instance_valid(main.battle),"Actual starter level begins")
	if is_instance_valid(main.battle):
		var b=main.battle;prepare(b,11001)
		var start=Time.get_ticks_msec()
		while Time.get_ticks_msec()-start<115000 and not main.result_visible:await process_frame
		check(main.result_visible,"Natural baseline battle reaches result")
		if main.result_visible:
			for i in range(8):await process_frame
			observations.result={"result":main.pending_result.duplicate(true),"reward":main.reward.duplicate(true),"hits":b.exchange_log.duplicate(true),"labels":labels110(main.screen)}
			await capture(folder,"result-before-escape")
			key110(KEY_ESCAPE)
			for i in range(8):await process_frame
			observations.escape={"page":main.page,"battle_exists":is_instance_valid(main.battle),"result_visible":main.result_visible,"paused":bool(main.battle.paused) if is_instance_valid(main.battle) else false}
			await capture(folder,"result-after-escape")
	main._close_battle()
	FileAccess.open(folder+"/report.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"failures":failures,"baseline":true,"observations":observations,"scope":"Current source isolated GPU UI baseline. Pending-save UI state supplied; actual level1 battle outcome and viewport Escape input. No forced win, OS input, human blind test or new package claim."},"\t"))
	await main._shutdown_and_quit()
	quit(0 if failures.is_empty() else 1)
