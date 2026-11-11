extends SceneTree
var failures=[]
func _initialize() -> void: call_deferred("run")
func settle(seconds: float) -> void:
	var until=Time.get_ticks_usec()+int(seconds*1000000)
	while Time.get_ticks_usec()<until: await process_frame
func prepare_details(main) -> void:
	# COMM-087 retains provenance behind an explicit tab. Open it before the
	# original complete-paragraph checks; hidden deferred jobs should NOT run.
	var tab=main.info_panel.get_node_or_null("DetailsTab")
	if tab!=null:
		tab.pressed.emit()
		await settle(.35)
func visible_icons(main) -> Dictionary:
	var visible_cards=0
	var ready_cards=0
	var count=0
	var loaded=0
	var details=[]
	for card in main.armory_cards.values():
		if card.get_global_rect().intersects(main.armory_scroll.get_global_rect()):
			visible_cards+=1
			if card.get_meta("content_ready",false):ready_cards+=1
		for child in card.get_children():
			if child is TextureRect and child.get_global_rect().intersects(main.armory_scroll.get_global_rect()):
				count+=1
				if child.texture!=null: loaded+=1
				details.append({"id":str(child.get("equipment").get("id","")) if child.get("equipment") is Dictionary else "eager","loaded":child.texture!=null,"processing":child.is_processing(),"first_frame":child.get("first_frame"),"rect":str(child.get_global_rect()),"clip":str(main.armory_scroll.get_global_rect())})
	if visible_cards==0 or ready_cards!=visible_cards or count!=visible_cards: failures.append("Deferred card content incomplete %d/%d icons=%d"%[ready_cards,visible_cards,count])
	if loaded!=count: failures.append("Visible icons incomplete %d/%d"%[loaded,count])
	var detail_scroll=main.info_panel.get_node_or_null("ProvenanceScroll")
	if detail_scroll==null:
		failures.append("Equipment detail panel incomplete")
	else:
		var paragraphs=[]
		for child in detail_scroll.get_child(0).get_children():
			if child is Label:paragraphs.append(child.text)
		var item=main.selected_item
		var expected=2+(1 if item.slot=="armor" else 0)+(1 if item.has("manufacture") else 0)+(1 if not str(item.get("use_context","")).is_empty() else 0)+(1 if not str(item.get("historical_note","")).is_empty() else 0)
		if paragraphs.size()!=expected:failures.append("Deferred provenance paragraphs missing or duplicated")
		if not str(item.get("historical_note","")).is_empty() and str(item.historical_note) not in paragraphs:failures.append("Provenance callback captured wrong item/text")

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
		await prepare_details(main)
		rows.append(visible_icons(main))
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(folder+"/"+slot+"_top.png")
		main.armory_scroll.scroll_vertical=99999
		main.armory_cards.values()[-1].grab_focus()
		await settle(.8)
		await prepare_details(main)
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
	FileAccess.open(folder+"/report.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"failures":failures,"visible_checks":rows,"rapid_changes":15,"deferred_content_checked":true,"scope":"Isolated viewport render, scroll state injection, full quality textures, no OS input"},"\t"))
	print("ICONS085 ",failures)
	main.notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
