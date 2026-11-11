extends "test_ui082.gd"
## Actual viewport clicks through first-run brief, learning choice and cancel.
func click_text(value:String)->void:
	for button in buttons(main):
		if button.text!=value or button.disabled:continue
		var e=InputEventMouseButton.new();e.button_index=MOUSE_BUTTON_LEFT;e.pressed=true;e.position=button.get_global_rect().get_center()
		root.push_input(e,true);e=e.duplicate();e.pressed=false;root.push_input(e,true)
		return
	check(false,"Missing clickable action: "+value)
func run()->void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--folder="):folder=a.trim_prefix("--folder=")
	state=root.get_node("GameState")
	if folder.is_empty() or DirAccess.dir_exists_absolute(folder) or not state.save_path.contains("qa_") or OS.get_environment("GALUMU_MEMORY_BOUND")!="1024" or DisplayServer.get_name()=="headless":quit(2);return
	DirAccess.make_dir_recursive_absolute(folder)
	state.save_path=folder+"/qa_profile.json";state.backup_path=folder+"/qa_backup.json"
	state.profile=state.default_profile();state.profile.settings.sound=false
	root.size=Vector2i(960,540)
	main=load("res://scenes/main.tscn").instantiate();root.add_child(main);current_scene=main
	for mouse in [false,true]:
		state.profile.settings.mouse_only=mouse
		main.show_match_setup();await process_frame
		click_text("进入竞技场");await capture("01_brief_mouse_"+str(mouse))
		check(is_instance_valid(main.brief_overlay),"First match skipped introduction")
		var text=str(labels(main.brief_overlay))
		check(text.contains("滚轮 / 中键") if mouse else text.contains("W / S"),"Brief describes the wrong posture controls")
		check(not text.contains("W / S") if mouse else true,"Mouse-only brief tells player to use keyboard posture")
		check(root.gui_get_focus_owner() is Button and root.gui_get_focus_owner().text=="先做分步练习","First-run focus does not offer guided learning")
		click_text("先做分步练习");await capture("02_learning_choice_"+str(mouse))
		check(main.page=="practice_setup" and not is_instance_valid(main.battle),"Learning choice unexpectedly started a competitive battle")
		check(not state.profile.settings.combat_brief_v044,"Choosing practice falsely acknowledged controls")
		main.show_match_setup();await process_frame;click_text("进入实战");await process_frame
		var e=InputEventKey.new();e.keycode=KEY_ESCAPE;e.physical_keycode=KEY_ESCAPE;e.pressed=true
		root.push_input(e,true);e=e.duplicate();e.pressed=false;root.push_input(e,true)
		await process_frame
		check(not is_instance_valid(main.brief_overlay) and main.page=="setup","Escape failed to return to mode selection")
	main.show_help();await capture("03_control_reference")
	for card in main.screen.find_children("help_card_*","Panel",true,false):
		for child in card.get_children():
			if child is Label:check(child.position.y+child.size.y<=card.size.y-10,"Expanded control reference overflows its card")
	main.show_match_setup();await process_frame;click_text("进入竞技场");await process_frame
	click_text("明白了，出战");await process_frame
	check(is_instance_valid(main.battle) and main.page=="battle" and not main.practice_match,"Skipping practice no longer starts the requested match")
	check(state.profile.settings.combat_brief_v044 and not state.profile.settings.guided_practice_v087,"Direct start completion flags are wrong")
	FileAccess.open(folder+"/report.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"failures":failures,"captures":captures,"scope":"Actual background GPU and viewport mouse/Escape injection at minimum window; first-run choices, controls, cancel and direct start. No OS input or human learning assessment."},"\t"))
	print("INTRO087 ",failures)
	main.notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
