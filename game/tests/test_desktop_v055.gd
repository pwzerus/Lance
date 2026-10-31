extends "test_desktop_v051.gd"
## Actual release UI, OS input only. Parent initializes a dedicated QA profile.
## F8 is a capture shortcut for this external observer, not a gameplay command.
class PoseObserver extends Node:
	var main: Node
	var path = ""
	var output: FileAccess
	var next_sample = 0
	var image_index = 0
	var last_page = ""
	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS
		DirAccess.make_dir_recursive_absolute(path)
		output = FileAccess.open(path.path_join("observed.jsonl"),FileAccess.WRITE)
		write({"kind":"identity","version":ProjectSettings.get_setting("application/config/version"),"source":"OS-only manual play; read-only observer; F8 GPU captures"})
	func write(row: Dictionary) -> void:
		if output:
			row.ticks_ms = Time.get_ticks_msec()
			output.store_line(JSON.stringify(row))
			output.flush()
	func snapshot() -> Dictionary:
		var state = get_tree().root.get_node("GameState")
		var row = {"page":main.page,"equipped":state.profile.equipped.duplicate(true),"appearance":state.profile.appearance.duplicate(true)}
		if main.battle:
			row.phase = main.battle.match_model.phase
			row.paused = main.battle.paused
			row.fighters = []
			for f in main.battle.match_model.fighters:
				row.fighters.append({"direction":f.direction,"lean":f.lean,"aim":f.aim,"guard":f.guard,"speed":f.speed,"helmet":f.stats.get("helmet_art"),"armor":f.stats.get("armor_art"),"appearance":f.stats.get("appearance",{})})
		return row
	func _input(event: InputEvent) -> void:
		if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_F8:
			capture.call_deferred()
	func _process(_delta: float) -> void:
		if Time.get_ticks_msec()<next_sample or not is_instance_valid(main): return
		next_sample = Time.get_ticks_msec()+250
		var row = snapshot()
		row.kind = "state"
		write(row)
	func capture() -> void:
		await RenderingServer.frame_post_draw
		image_index += 1
		var row = snapshot()
		row.kind = "capture"
		row.image = "%02d_%s.png" % [image_index,main.page]
		row.saved = get_viewport().get_texture().get_image().save_png(path.path_join(row.image))==OK
		write(row)

func run() -> void:
	var captures = ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--captures="): captures = arg.trim_prefix("--captures=")
	if captures.is_empty() or DirAccess.dir_exists_absolute(captures):
		push_error("Use a fresh --captures directory for manual QA")
		quit(2)
		return
	super.run()
	if not is_instance_valid(qa_main): return
	root.title = "GALUMU v"+str(ProjectSettings.get_setting("application/config/version","?"))+" QA - Manual face and helmet play"
	var observer = PoseObserver.new()
	observer.main = qa_main
	observer.path = captures
	qa_main.add_child(observer)
