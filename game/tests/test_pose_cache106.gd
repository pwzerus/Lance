extends SceneTree
## Exact shared-anchor regression and bounded hot-path microbenchmark.
## The reference is the task's saved baseline script, not another copy of
## the optimized function. It preloads the same production gait curves.
const Model = preload("res://scripts/core/joust_match.gd")
var failures: Array[String] = []
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok and message not in failures: failures.append(message)
func anchors(script, fighter: Dictionary) -> Array:
	return [script.gait_pose(fighter),script.head_position(fighter),script.body_position(fighter),script.flank_position(fighter),script.hand_position(fighter),script.tip_position(fighter),script.shield_transform(fighter),script.shield_grip(fighter)]
func measure(script, poses: Array) -> Dictionary:
	var started = Time.get_ticks_usec()
	var sink = 0.0
	for repeat in range(8):
		for pose in poses:
			var out = anchors(script,pose)
			sink += Vector2(out[1]).y
	return {"us":Time.get_ticks_usec()-started,"sink":sink}
func run() -> void:
	var folder=""; var reference_path=""; var require_cache=false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--folder="): folder=arg.trim_prefix("--folder=")
		if arg.begins_with("--reference="): reference_path=arg.trim_prefix("--reference=")
		if arg=="--require-cache": require_cache=true
	if folder.is_empty() or DirAccess.dir_exists_absolute(folder) or reference_path.is_empty() or not "--test-profile" in OS.get_cmdline_user_args() or OS.get_environment("GALUMU_MEMORY_BOUND")!="1024": quit(2); return
	DirAccess.make_dir_recursive_absolute(folder)
	var reference = load(reference_path)
	check(reference!=null,"Baseline script loads")
	if reference==null: quit(2); return
	var model=Model.new(); var poses=[]
	var rng=RandomNumberGenerator.new(); rng.seed=10611
	for i in range(320):
		var f: Dictionary=model.fighters[i%2].duplicate(true)
		f.gait_phase=rng.randf_range(-3.0,1000.0); f.speed=rng.randf_range(0.0,620.0)
		f.gait_moving=i%9!=0; f.motion_drive=rng.randf_range(-1,1); f.seat_drive=rng.randf_range(-1,1)
		f.stamina=rng.randf_range(0,100); f.stats.stability=rng.randf_range(.7,1.4)
		f.lean=rng.randf_range(-1,1); f.aim=rng.randf_range(-.7,.6); f.guard=rng.randf()
		f.reaction_angle=rng.randf_range(-.3,.3); f.reaction_shift=rng.randf_range(-6,6)
		f.lance_compression=rng.randf_range(0,16); f.shield_compression=rng.randf_range(0,16)
		f.shield_twist=rng.randf_range(-.3,.3); f.unsteady=rng.randf(); f.sway=rng.randf_range(-.17,.17)
		poses.append(f)
	var checked=0
	for f in poses:
		check(anchors(Model,f)==anchors(reference,f),"All shared anchors equal baseline")
		for key in ["gait_phase","speed","motion_drive","seat_drive","stamina"]:
			f[key]=float(f[key])+.000001
			check(anchors(Model,f)==anchors(reference,f),"Tiny same-frame change invalidates: "+key)
			checked+=1
		f.stats.stability+=.000001
		check(anchors(Model,f)==anchors(reference,f),"Nested horse stability invalidates")
		f.gait_moving=not f.gait_moving
		check(anchors(Model,f)==anchors(reference,f),"Moving/idle invalidates")
		if require_cache:
			check(Model.gait_pose(f).is_read_only(),"Shared pose cannot be accidentally modified")
			var frozen=f.duplicate(true)
			f.gait_phase+=.17
			check(anchors(Model,frozen)==anchors(reference,frozen),"Captured fighter has independent cached state")
	var timings=[]
	for i in range(3):
		# Alternate ordering to expose warmup and scheduler noise.
		if i%2==0: timings.append({"reference":measure(reference,poses),"current":measure(Model,poses)})
		else:
			var current=measure(Model,poses)
			timings.append({"current":current,"reference":measure(reference,poses)})
	var out={"passed":failures.is_empty(),"failures":failures,"poses":poses.size(),"tiny_mutations":checked,"timings":timings,"reference_sha256":FileAccess.get_sha256(reference_path),"scope":"Exact anchor outputs and local CPU work; not whole-game FPS or feel."}
	FileAccess.open(folder+"/report.json",FileAccess.WRITE).store_string(JSON.stringify(out,"\t"))
	print("POSE_CACHE106 ",JSON.stringify(out))
	quit(0 if failures.is_empty() else 1)
