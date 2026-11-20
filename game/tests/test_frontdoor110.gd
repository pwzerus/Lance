extends "test_ux_baseline110.gd"
## Fresh-user routing, cancel, interrupted lesson and optional practice.
func press110(main:Node,prefix:String)->bool:
	var b=action_button(main,prefix)
	check(b!=null and not b.disabled,"Visible button "+prefix)
	if not b or b.disabled:return false
	click(b)
	for i in range(10):await process_frame
	return true
func ready110(b:Node)->void:
	var start=Time.get_ticks_msec()
	while not b.presentation_ready and Time.get_ticks_msec()-start<30000:await process_frame
	check(b.presentation_ready,"Battle preparation finishes")
	if root.focus_exited.is_connected(b._on_focus_lost):root.focus_exited.disconnect(b._on_focus_lost)
func run()->void:
	var folder="";var compact=false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--folder="):folder=arg.trim_prefix("--folder=")
		if arg=="--compact":compact=true
	var state=root.get_node("GameState")
	if folder.is_empty() or DirAccess.dir_exists_absolute(folder) or not state.save_path.contains("qa_") or OS.get_environment("GALUMU_MEMORY_BOUND")!="1024" or DisplayServer.get_name()=="headless":quit(2);return
	DirAccess.make_dir_recursive_absolute(folder)
	state.save_path=folder+"/qa_profile.json";state.backup_path=folder+"/qa_backup.json";state.profile=state.default_profile();state.profile.settings.mouse_only=compact
	check(state.save_profile(),"Fresh QA profile persisted")
	root.size=Vector2i(960,540) if compact else Vector2i(1280,720);AudioServer.set_bus_mute(0,true)
	var main=load("res://scenes/main.tscn").instantiate();root.add_child(main);current_scene=main
	for i in range(30):await process_frame
	await press110(main,"关卡挑战");await press110(main,"出战")
	check(is_instance_valid(main.brief_overlay) and not is_instance_valid(main.battle),"First entry explains controls before battle")
	await capture(folder,"01-first-brief")
	key110(KEY_ESCAPE)
	for i in range(6):await process_frame
	check(not is_instance_valid(main.brief_overlay) and not bool(state.profile.settings.get("combat_brief_v044",false)),"Cancel does not accept first briefing")
	await press110(main,"出战");await press110(main,"先做分步练习")
	check(main.page=="practice_setup","Briefing links to optional practice")
	await press110(main,"第一次上马");await ready110(main.battle)
	var guide=main.active_guide
	var event=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.position=Vector2(720,400);event.pressed=true;root.push_input(event,true)
	var start=Time.get_ticks_msec()
	while guide.step==0 and Time.get_ticks_msec()-start<15000:await process_frame
	event=event.duplicate();event.pressed=false;root.push_input(event,true)
	check(guide.step>=1,"Actual held input completes first urging step")
	key110(KEY_ESCAPE)
	for i in range(6):await process_frame
	check(main.battle.paused,"Escape pauses optional lesson")
	await capture(folder,"02-lesson-pause")
	await press110(main,"返回营地");await press110(main,"练习场")
	check(str(labels110(main.screen)).contains("分步上马"),"Practice choice available")
	await capture(folder,"03-continue-choice")
	await press110(main,"继续练习");await ready110(main.battle)
	check(main.active_guide==guide and guide.step>=1,"Leaving to camp retains this session's incomplete lesson")
	key110(KEY_ESCAPE)
	for i in range(6):await process_frame
	await press110(main,"返回营地");await press110(main,"练习场");await press110(main,"进入自由练习")
	if is_instance_valid(main.brief_overlay):await press110(main,"明白了，出战")
	await ready110(main.battle)
	check(main.practice_match and main.active_guide==null,"Free practice is optional and separate from step guide")
	key110(KEY_ESCAPE)
	for i in range(6):await process_frame
	await press110(main,"返回营地")
	check(not bool(state.profile.settings.get("guided_practice_v087",false)),"Skipping unfinished guide never marks completion")
	check(state.profile.coins==520 and state.profile.matches==0,"Interrupted/free practice gives no rewards or match count")
	await capture(folder,"04-home-after-skip")
	FileAccess.open(folder+"/report.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"failures":failures,"compact":compact,"completed_steps":guide.step,"profile":state.profile,"scope":"Actual isolated GPU fresh-user buttons and viewport controls, optional tutorial interruption/skip. No forced steps, coins, wins, OS input or human-user claim."},"\t"))
	await main._shutdown_and_quit();quit(0 if failures.is_empty() else 1)
