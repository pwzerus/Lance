extends SceneTree
## HORSE-065 readability captures: armoury cards and detail panel for lance,
## shield, armour and helmet (English line, all eras), plus the appearance
## screen with the refined face. Real main scene, isolated QA profile.
const Catalogue = preload("res://scripts/core/catalogue.gd")
var folder = ""

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--armory-report="): folder = arg.trim_prefix("--armory-report=")
	if OS.get_environment("GALUMU_MEMORY_BOUND")!="1024" or not root.get_node("GameState").save_path.contains("qa_") or folder.is_empty() or DisplayServer.get_name()=="headless" or DirAccess.dir_exists_absolute(folder):
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(folder)
	root.size = Vector2i(1440,810)
	var items = Catalogue.load_items()
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	for _i in range(3):
		await process_frame
	for slot in ["lance","shield","armor","helmet"]:
		main.selected_slot = slot
		main.selected_era = -1
		main.selected_region = 1
		main.selected_quality = 0
		main.selected_item = {}
		for item in items:
			if item.slot==slot and str(item.get("region",""))=="英格兰" and int(item.get("quality",-1))==5:
				main.selected_item = item
		main.show_armory()
		await _capture(folder+"/armory_%s.png"%slot)
	main.show_character()
	await _capture(folder+"/character.png")
	print("ARMORY065_DONE "+folder)
	main.queue_free()
	await process_frame
	quit()

func _capture(path: String) -> void:
	for _i in range(4):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)
