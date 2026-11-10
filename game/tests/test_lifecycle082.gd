extends SceneTree
## Compare the actual close handler with an intentionally abrupt QA teardown.
## Only the latter skips the production audio-mixer release interval.
var folder=""
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var steps=60
	var interval=.2
	var abrupt=false
	var prime_audio=false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--folder="): folder=arg.trim_prefix("--folder=")
		if arg.begins_with("--steps="): steps=clampi(int(arg.trim_prefix("--steps=")),3,300)
		if arg.begins_with("--interval="): interval=clampf(float(arg.trim_prefix("--interval=")),.1,1.5)
		if arg=="--abrupt": abrupt=true
		if arg=="--prime-audio": prime_audio=true
	var state=root.get_node("GameState")
	if folder.is_empty() or DirAccess.dir_exists_absolute(folder) or not state.save_path.contains("qa_") or OS.get_environment("GALUMU_MEMORY_BOUND")!="1024" or DisplayServer.get_name()=="headless":
		quit(2); return
	DirAccess.make_dir_recursive_absolute(folder)
	state.save_path=folder+"/qa_profile.json"
	state.backup_path=folder+"/qa_backup.json"
	state.profile=state.default_profile()
	var main=load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene=main
	var rows: Array=[]
	for index in range(steps):
		if index%3==0: main.show_armory()
		elif index%3==1: main.show_history()
		else: main.show_home()
		await create_timer(interval,true,false,true).timeout
		if index%3==2:
			rows.append({"step":index,"nodes":Performance.get_monitor(Performance.OBJECT_NODE_COUNT),"resources":Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)})
	# Close immediately after a UI sound, as on an actual menu click. Both
	# control groups do this; only the teardown path differs.
	if prime_audio: main.sounds.play("click",-12)
	FileAccess.open(folder+"/report.json",FileAccess.WRITE).store_string(JSON.stringify({"steps":steps,"recent_click":prime_audio,"exit":"abrupt QA teardown" if abrupt else "production window-close handler","rows":rows,"scope":"Actual GPU menus on isolated desktop with QA saves. Process exit and warnings must be read from supervisor/engine logs; no self-certified pass."},"\t"))
	if abrupt:
		main.queue_free()
		await process_frame
		quit()
	else:
		main.notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
