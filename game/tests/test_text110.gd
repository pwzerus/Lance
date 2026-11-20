extends "test_ux_baseline110.gd"
func filter_text(node:Node)->void:
	if node is Label or node is Button:node.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
	for child in node.get_children():filter_text(child)
func verify_text(node:Node)->void:
	if node is Label or node is Button:check(node.texture_filter==CanvasItem.TEXTURE_FILTER_LINEAR,"Text-only filter applies to "+str(node.name))
	for child in node.get_children():verify_text(child)
func run()->void:
	var folder=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--folder="):folder=arg.trim_prefix("--folder=")
	var state=root.get_node("GameState")
	if folder.is_empty() or DirAccess.dir_exists_absolute(folder) or not state.save_path.contains("qa_") or OS.get_environment("GALUMU_MEMORY_BOUND")!="1024" or DisplayServer.get_name()=="headless":quit(2);return
	DirAccess.make_dir_recursive_absolute(folder);state.save_path=folder+"/qa_profile.json";state.backup_path=folder+"/qa_backup.json";state.profile=state.default_profile();AudioServer.set_bus_mute(0,true)
	var main=load("res://scenes/main.tscn").instantiate();root.add_child(main);current_scene=main
	for i in range(20):await process_frame
	var rows=[]
	for width in [960,1280,1440]:
		root.size=Vector2i(width,width*9/16);main.show_settings()
		for i in range(30):await process_frame
		var before=labels110(main.screen)
		verify_text(main.screen)
		await capture(folder,"settings-%d-production"%width)
		filter_text(main.screen)
		for i in range(30):await process_frame
		await capture(folder,"settings-%d-explicit-linear"%width)
		check(before==labels110(main.screen),"Filtering does not change text content")
		rows.append({"width":width,"labels":before})
	FileAccess.open(folder+"/report.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"failures":failures,"rows":rows,"scope":"Isolated GPU checks of production text-only filtering at three actual sizes, plus explicit-filter control. Earlier text01 contains the original nearest-versus-linear baseline. No world-art filter or OS input changes."},"\t"))
	await main._shutdown_and_quit();quit(0 if failures.is_empty() else 1)
