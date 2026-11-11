extends "test_ui082.gd"
func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--folder="):folder=arg.trim_prefix("--folder=")
		if arg=="--compact":compact=true
	state=root.get_node("GameState")
	if folder.is_empty() or DirAccess.dir_exists_absolute(folder) or not str(state.save_path).contains("qa_") or DisplayServer.get_name()=="headless" or OS.get_environment("GALUMU_MEMORY_BOUND")!="1024":quit(2);return
	DirAccess.make_dir_recursive_absolute(folder)
	state.save_path=folder+"/qa_profile.json";state.backup_path=folder+"/qa_backup.json";state.load_profile();state.profile.settings.sound=false
	root.size=Vector2i(960,540) if compact else Vector2i(1280,720)
	main=load("res://scenes/main.tscn").instantiate();root.add_child(main);current_scene=main
	await capture("00_home_help_entry")
	check(press("玩法与制作说明"),"Camp lacks help entry")
	await capture("01_rules")
	check_cards()
	check(press("制作与许可"),"Credits tab missing")
	await capture("02_credits")
	check_cards()
	check(press("返回营地"),"Help return missing")
	main.show_history();await capture("03_history")
	check(not str(labels(main.screen)).contains("三轮与 HP 决胜"),"History still describes obsolete arena HP-only rule")
	FileAccess.open(folder+"/report.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"failures":failures,"captures":captures,"scope":"Background production GPU/menu callbacks; text boundary checks. No external website/folder opened; no OS input."},"\t"))
	print("HELP087 ",failures)
	main.notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)

func check_cards() -> void:
	for card in main.screen.find_children("help_card_*","Panel",true,false):
		for child in card.get_children():
			if child is Label:
				check(child.position.y+child.size.y<=card.size.y-10,"Help card text overflows: "+str(card.name)+" "+child.text.left(18))
