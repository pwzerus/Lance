extends SceneTree
## FIX-085 async armoury action readiness; same production save-failure checks.
## Original UI085 one-frame synchronous assumption is retained in its old file.
var folder = ""
var main
var state
var failures: Array[String] = []
var captures: Array = []
var compact = false
var action_ready_ms = 0.0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok and message not in failures:
		failures.append(message)
		print("UI085_FINDING ",message)

func buttons(node: Node) -> Array:
	var found: Array = []
	for child in node.get_children():
		if child is Button and child.is_visible_in_tree() and not child.is_queued_for_deletion(): found.append(child)
		found.append_array(buttons(child))
	return found

func press(text: String) -> bool:
	for button in buttons(main):
		if button.text==text and not button.disabled:
			# Signal path isolates menu business logic; not OS or GUI hit-testing.
			button.pressed.emit()
			return true
	check(false,"Missing enabled button: "+text)
	return false

func labels(node: Node) -> Array:
	var rows: Array = []
	for child in node.get_children():
		if child is Label and child.is_visible_in_tree() and not child.is_queued_for_deletion():
			var rect = child.get_global_rect()
			rows.append({"text":child.text,"x":rect.position.x,"y":rect.position.y,"w":rect.size.x,"h":rect.size.y})
		rows.append_array(labels(child))
	return rows

func capture(tag: String) -> void:
	for _i in range(4): await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(folder+"/"+tag+".png")==OK,"Screenshot save failed")
	captures.append({"tag":tag,"page":main.page,"labels":labels(main.screen),"nodes":get_node_count()})
	print("UI085_CAPTURE ",tag)

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--folder="): folder=arg.trim_prefix("--folder=")
		if arg=="--compact": compact=true
	state=root.get_node("GameState")
	if folder.is_empty() or DirAccess.dir_exists_absolute(folder) or not state.save_path.contains("qa_") or OS.get_environment("GALUMU_MEMORY_BOUND")!="1024" or DisplayServer.get_name()=="headless":
		quit(2); return
	DirAccess.make_dir_recursive_absolute(folder)
	state.save_path=folder+"/qa_profile.json"
	state.backup_path=folder+"/qa_backup.json"
	state.profile=state.default_profile()
	state.profile.settings.sound=false
	state.save_profile()
	root.size=Vector2i(960,540) if compact else Vector2i(1280,720)
	main=load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene=main
	await capture("01_home")
	press("开始游戏")
	await capture("02_setup")
	press("进入竞技场")
	await capture("03_brief")
	press("返回选择")
	main.show_character()
	await capture("04_character")
	main.show_settings()
	await capture("05_settings")
	main.show_saves()
	await capture("06_saves")
	main.selected_slot="horse"
	main.selected_region=1
	main.selected_era=-1
	main.selected_quality=0
	main.selected_item={}
	main.show_armory()
	await capture("07_empty_filter")
	main.selected_slot="armor"
	main.selected_region=0
	main.selected_item={}
	main.show_armory()
	await capture("08_armory")
	var candidate: Dictionary={}
	for item in state.items:
		if item.slot=="armor" and item.id!=state.profile.equipped.armor:
			candidate=item; break
	check(not candidate.is_empty(),"Missing alternative armor fixture")
	if not candidate.is_empty():
		if candidate.id not in state.profile.owned: state.profile.owned.append(candidate.id)
		main.selected_item=candidate
		main.show_armory()
		var start=Time.get_ticks_usec()
		while not main.info_panel.get_meta("details_ready",false) and Time.get_ticks_usec()-start<500000:
			await process_frame
		action_ready_ms=(Time.get_ticks_usec()-start)/1000.0
		check(main.info_panel.get_meta("details_ready",false),"Armoury action unavailable after 500ms")
		var prior=state.profile.equipped.armor
		state.save_path=folder+"/missing/qa_profile.json"
		press("装备")
		await capture("09_equip_save_failure")
		check(state.profile.equipped.armor==prior,"Failed equipment save changed equipped item")
		var notice=main.message_label.text if is_instance_valid(main.message_label) else ""
		check(notice.contains("失败") or notice.contains("未") and notice.contains("存档"),"Equipment save failure has no visible explanation")
		state.save_path=folder+"/qa_profile.json"
		state.save_error=""
	main.show_home()
	await capture("10_return")
	main.sounds.set_enabled(false)
	main.sounds.stop_all()
	main.queue_free()
	await process_frame
	var report={"action_ready_ms":action_ready_ms,"passed":failures.is_empty(),"failures":failures,"captures":captures,"scope":"Actual GPU menus, direct button signals for menu logic, isolated workspace save paths. No OS input, human experience or performance claim."}
	FileAccess.open(folder+"/report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("UI085 ",failures)
	quit(0 if failures.is_empty() else 1)
