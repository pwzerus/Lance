extends SceneTree
## Finite headless lifetime/clock probe; no full game, drawing or real input.
const Rider = preload("res://scripts/visual/rider_view.gd")
const Model = preload("res://scripts/core/joust_match.gd")
const Bank = preload("res://scripts/visual/sound_bank.gd")
var failures: Array[String] = []

func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok and message not in failures: failures.append(message)

func run() -> void:
	var folder = ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--folder="): folder = arg.trim_prefix("--folder=")
	if folder.is_empty() or DirAccess.dir_exists_absolute(folder) or not "--test-profile" in OS.get_cmdline_user_args() or OS.get_environment("GALUMU_MEMORY_BOUND")!="1024": quit(2); return
	DirAccess.make_dir_recursive_absolute(folder)
	AudioServer.set_bus_mute(0,true)
	var empty = Rider.new()
	empty._process(1.0/60)
	check(empty.fighter.is_empty(),"An unconfigured rider must remain unconfigured")
	check(empty.armor_previous_height==INF,"An unconfigured rider must not invent a compression history")
	empty.free()
	var rows = []
	var warmed_nodes = 0
	var warmed_streams = 0
	for iteration in range(32):
		var rider = Rider.new(); rider.fighter = Model.new().fighters[0]
		rider.lance_only = iteration%2==0
		if not rider.lance_only:
			rider.detached_pose=Rider.arm_pose(rider.fighter)
			rider.detached_legs=Rider.seated_leg_pose(rider.fighter)
		rider.visible=false # Lifetime/clock probe must not invoke drawing.
		rider.clock = 12.3
		root.add_child(rider); rider.set_process(false)
		var bank = Bank.new(); bank.enabled=false;root.add_child(bank)
		bank.enabled=true
		for frame in range(30):
			rider._process(1.0/60)
			bank.play("armor_plate_0",-24)
		check(absf(rider.clock-12.8)<.000001,"Detached/loose flags must advance in game time")
		var paused_clock = rider.clock
		rider._process(0.0)
		check(rider.clock==paused_clock,"Zero game time must freeze detached flags")
		check(bank.voices.size()<=Bank.MAX_VOICES,"Repeated movement cues must retain the voice cap")
		var tracked = [weakref(rider),weakref(bank)]
		for voice in bank.voices: tracked.append(weakref(voice))
		bank.stop_all();bank.queue_free();rider.queue_free()
		await process_frame
		await process_frame
		for reference in tracked: check(reference.get_ref()==null,"Rider/bank/voices must release after teardown")
		var nodes = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
		var streams = Bank.shared_streams.size()
		if iteration==2: warmed_nodes=nodes;warmed_streams=streams
		if iteration>2:
			check(nodes==warmed_nodes,"Repeated local scene teardown must not accumulate nodes")
			check(streams==warmed_streams,"Shared sound variants must remain a fixed set")
		rows.append({"iteration":iteration,"nodes":nodes,"shared_streams":streams,"static_bytes":OS.get_static_memory_usage()})
	# AudioServer releases its stopped playback on the next mix boundary.
	# Let that thread drain before exiting this very short-lived QA process.
	await create_timer(.25).timeout
	var report={"passed":failures.is_empty(),"failures":failures,"rows":rows,"scope":"32 bounded local rider/audio lifetimes and detached game clocks; no full scene/GPU/OS input or hearing verdict."}
	FileAccess.open(folder+"/report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("LIFECYCLE106 ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
