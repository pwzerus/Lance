extends "test_play087.gd"
## Rendering-only fixture: normal result construction, shortened match waiting.
func snap(folder:String,name:String)->void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(folder+"/"+name+".png")
func redraw_tree(node:Node)->void:
	if node is CanvasItem:node.queue_redraw()
	for child in node.get_children():redraw_tree(child)
func run()->void:
	var folder=""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--folder="):folder=a.trim_prefix("--folder=")
	var state=root.get_node("GameState")
	if folder.is_empty() or DirAccess.dir_exists_absolute(folder) or not state.save_path.contains("qa_") or DisplayServer.get_name()=="headless" or OS.get_environment("GALUMU_MEMORY_BOUND")!="1024":quit(2);return
	DirAccess.make_dir_recursive_absolute(folder)
	state.save_path=folder+"/qa_profile.json";state.backup_path=folder+"/qa_backup.json";state.load_profile()
	state.profile.campaign_cleared=range(1,26);state.profile.settings.combat_brief_v044=true
	AudioServer.set_bus_mute(0,true);root.size=Vector2i(1280,720)
	var main=load("res://scenes/main.tscn").instantiate();root.add_child(main);current_scene=main
	for i in range(100):await process_frame
	for cycle in range(3):
		main._start_level(23+cycle);var b=main.battle
		if b==null:quit(3);return
		if root.focus_exited.is_connected(b._on_focus_lost):root.focus_exited.disconnect(b._on_focus_lost)
		while not b.presentation_ready:await process_frame
		b.match_model._finish("score");b._consume_events(b.match_model.drain_events())
		b.terminal_at=maxi(1,Time.get_ticks_msec()-7000);b.is_finished=true;Engine.time_scale=1
		while not main.result_visible:await process_frame
		for i in range(5):await process_frame
		await snap(folder,str(cycle)+"-early")
		for i in range(60):await process_frame
		await snap(folder,str(cycle)+"-late")
		redraw_tree(main)
		for i in range(5):await process_frame
		await snap(folder,str(cycle)+"-redraw")
		if "--diagnostic-variants" in OS.get_cmdline_user_args():
			b.visible=false
			for i in range(5):await process_frame
			await snap(folder,str(cycle)+"-no-battle")
			var font=load("res://assets/fonts/NotoSansSC.ttf")
			font.subpixel_positioning=TextServer.SUBPIXEL_POSITIONING_DISABLED
			redraw_tree(main)
			for i in range(5):await process_frame
			await snap(folder,str(cycle)+"-no-subpixel")
			main.screen.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
			for i in range(5):await process_frame
			await snap(folder,str(cycle)+"-linear")
			root.size=Vector2i(1440,810)
			for i in range(5):await process_frame
			await snap(folder,str(cycle)+"-native")
			root.size=Vector2i(1280,720)
		check(not state.profile_save_pending,"Result persisted")
		main._close_battle();await process_frame
	FileAccess.open(folder+"/report.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"failures":failures,"scope":"Three shortened result render cycles: early, late, explicit redraw; no gameplay inference or OS input."},"\t"))
	main.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
