extends SceneTree
var failures=[]
func _initialize()->void:call_deferred("run")
func wait_wall(seconds:float)->void:
	var deadline=Time.get_ticks_usec()+int(seconds*1000000)
	while Time.get_ticks_usec()<deadline:await process_frame
func check(ok:bool,why:String)->void:
	if not ok and why not in failures:failures.append(why)
func run()->void:
	var folder=""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--folder="):folder=a.trim_prefix("--folder=")
	var state=root.get_node("GameState")
	if folder.is_empty() or DirAccess.dir_exists_absolute(folder) or not state.save_path.contains("qa_") or OS.get_environment("GALUMU_MEMORY_BOUND")!="1024" or DisplayServer.get_name()=="headless":quit(2);return
	DirAccess.make_dir_recursive_absolute(folder)
	state.save_path=folder+"/qa_profile.json";state.backup_path=folder+"/qa_backup.json";state.load_profile();state.profile.settings.sound=false;state.profile.renown=60
	root.size=Vector2i(1280,720)
	var main=load("res://scenes/main.tscn").instantiate();root.add_child(main);current_scene=main
	var queue=main.screen.get_node("OpponentArtPreparation")
	check(queue.jobs.size()==4,"Preparation should have exactly four bounded jobs")
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED)
	await wait_wall(1.0)
	check(not DisplayServer.window_can_draw(),"QA window did not minimize")
	var pending=queue.jobs.size();var draws=Engine.get_frames_drawn()
	await wait_wall(8.0)
	check(queue.jobs.size()==pending,"Hidden preparation kept loading")
	check(Engine.get_frames_drawn()==draws,"Hidden game kept drawing")
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	await wait_wall(1.2)
	check(queue.jobs.is_empty() and not queue.is_processing(),"Visible preparation did not finish and stop")
	var skin=load("res://scripts/visual/horse_skin.gd")
	var catalogue=load("res://scripts/core/catalogue.gd")
	var enemy=catalogue.opponent_stats(state.items,catalogue.era_for_renown(state.profile.renown))
	check(skin._coat_cache.has(enemy.horse_coat),"Next opponent coat not prepared")
	var cloth_key=str(enemy.caparison_style)+"_"+str(enemy.heraldry)+("_l" if enemy.heraldry=="bend" else "")
	check(skin._caparison_cache.has(cloth_key),"Next opponent cloth not prepared")
	var retired=[]
	for i in range(12):
		main.show_match_setup();retired.append(weakref(main.screen.get_node("OpponentArtPreparation")))
		main.show_practice_setup();retired.append(weakref(main.screen.get_node("OpponentArtPreparation")))
		main.show_settings()
	await wait_wall(.5)
	for job in retired:check(job.get_ref()==null,"A departed page retained its preparation queue")
	main.show_home();await wait_wall(.5)
	check(skin._coat_cache.size()<=4 and skin._caparison_cache.size()<=15,"Preparation exceeded the finite art catalogue")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(folder+"/restored.png")
	FileAccess.open(folder+"/report.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"failures":failures,"hidden_pending":pending,"retired_queues":retired.size(),"coats":skin._coat_cache.size(),"cloths":skin._caparison_cache.size(),"scope":"Actual isolated GPU and window minimization, monotonic waits; bounded queue stops hidden, resumes and is freed on page departure. No OS input."},"\t"))
	print("PREWARM087 ",failures)
	main.notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
