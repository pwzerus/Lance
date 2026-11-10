extends SceneTree
var failures=[]
func _initialize() -> void: call_deferred("run")
func settle(seconds: float) -> void:
	var until=Time.get_ticks_usec()+int(seconds*1000000)
	while Time.get_ticks_usec()<until: await process_frame
func visible_icons(main) -> Dictionary:
	var count=0
	var loaded=0
	var details=[]
	for card in main.armory_cards.values():
		for child in card.get_children():
			if child is TextureRect and child.get_global_rect().intersects(main.armory_scroll.get_global_rect()):
				count+=1
				if child.texture!=null: loaded+=1
				details.append({"id":str(child.get("equipment").get("id","")) if child.get("equipment") is Dictionary else "eager","loaded":child.texture!=null,"processing":child.is_processing(),"first_frame":child.get("first_frame"),"rect":str(child.get_global_rect()),"clip":str(main.armory_scroll.get_global_rect())})
	if loaded!=count: failures.append("Visible icons incomplete %d/%d"%[loaded,count])
	return {"visible":count,"loaded":loaded,"frame":Engine.get_process_frames(),"can_draw":DisplayServer.window_can_draw(),"details":details}
func run() -> void:
	var folder=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--folder="): folder=arg.trim_prefix("--folder=")
	var state=root.get_node("GameState")
	if folder.is_empty() or DirAccess.dir_exists_absolute(folder) or OS.get_environment("GALUMU_MEMORY_BOUND")!="1024" or not state.save_path.contains("qa_"): quit(2);return
	DirAccess.make_dir_recursive_absolute(folder)
	state.save_path=folder+"/qa_profile.json"
	state.backup_path=folder+"/qa_backup.json"
	state.profile=state.default_profile()
	state.profile.settings.sound=false
	root.size=Vector2i(960,540)
	var main=load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene=main
	# Finish the boot frame before a UI latency timer: its large startup delta
	# would otherwise expire a newly created .8s SceneTreeTimer immediately.
	await process_frame
	await RenderingServer.frame_post_draw
	var rows=[]
	for slot in ["armor","helmet"]:
		main.selected_slot=slot
		main.selected_item={}
		main.show_armory()
		await settle(.8)
		rows.append(visible_icons(main))
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(folder+"/"+slot+"_top.png")
		main.armory_scroll.scroll_vertical=99999
		await settle(.8)
		rows.append(visible_icons(main))
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(folder+"/"+slot+"_bottom.png")
	for i in range(15):
		main.show_armory()
		main.show_home()
		await process_frame
	await settle(.5)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(folder+"/home.png")
	FileAccess.open(folder+"/report.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"failures":failures,"visible_checks":rows,"rapid_changes":15,"scope":"Isolated viewport render, scroll state injection, full quality textures, no OS input"},"\t"))
	print("ICONS084 ",failures)
	main.notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
