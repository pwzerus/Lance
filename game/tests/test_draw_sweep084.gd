extends SceneTree
const Model=preload("res://scripts/core/joust_match.gd")
const Rider=preload("res://scripts/visual/rider_view.gd")
const Catalogue=preload("res://scripts/core/catalogue.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	if not ResourceLoader.exists("res://scripts/visual/probe_dispatch083.gd"):
		print("SKIP: requires a separately instrumented diagnostic copy")
		quit(2)
		return
	var folder=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--folder="): folder=arg.trim_prefix("--folder=")
	if folder.is_empty() or DirAccess.dir_exists_absolute(folder) or OS.get_environment("GALUMU_MEMORY_BOUND")!="1024" or not root.get_node("GameState").save_path.contains("qa_"): quit(2);return
	DirAccess.make_dir_recursive_absolute(folder)
	var probe=load("res://scripts/visual/probe_dispatch083.gd")
	probe.output_path=folder+"/errors.jsonl"
	root.size=Vector2i(1280,720)
	var rng=RandomNumberGenerator.new()
	rng.seed=840031
	var items=Catalogue.load_items()
	var variants=[]
	for region in ["eng","fr","de","it"]:
		for q in range(6):
			variants.append(Catalogue.stats(items,{"armor":"%s_armor_%d"%[region,q],"helmet":"%s_helmet_%d"%[region,q],"lance":"%s_lance_stout_%d"%[region,q],"shield":"%s_shield_%d"%[region,q]}))
	variants.append(Catalogue.stats(items,{"armor":"mail_basic","helmet":"helm_nasal","lance":"lance_ash","horse":"horse_bay","crest":"crest_chevron"}))
	var views=[]
	for i in range(4):
		var v=Rider.new()
		v.fighter=Model.new("war",variants[0],variants[0]).fighters[i%2]
		v.mode="war"
		v.fighter.x=0.0
		v.fighter.lane_y=0.0
		v.position=Vector2(300+(i%2)*650,340+(i/2)*350)
		v.scale=Vector2.ONE*.7
		root.add_child(v)
		v.set_process(false)
		views.append(v)
	for step in range(1600):
		for i in range(views.size()):
			var v=views[i]
			v.fighter.stats=variants[(step+i)%variants.size()].duplicate(true)
			v.fighter.lean=rng.randf_range(-1,1)
			v.fighter.aim=rng.randf_range(-.68,.58)
			v.fighter.reaction_neck=rng.randf_range(-.18,.18)
			v.fighter.guard=rng.randf()
			v.fighter.broken=step%3==0
			v.fighter.gait_phase=step*.13
			v.fighter.speed=480.0
			v.fighter.gait_moving=true
			v.lance_recoil=rng.randf_range(-1,1)
			v.shield_recoil=rng.randf_range(-1,1)
			v.impact_recoil=rng.randf_range(-1,1)
			v._process(0.0)
		await process_frame
		await RenderingServer.frame_post_draw
		if probe.failures>0:
			root.get_texture().get_image().save_png(folder+"/failure.png")
			break
	FileAccess.open(folder+"/report.json",FileAccess.WRITE).store_string(JSON.stringify({"checked":probe.inspected,"invalid":probe.failures,"scope":"GPU geometry stress within mounted input/recoil limits; synthetic independent poses, not gameplay or motion acceptance."},"\t"))
	quit(0 if probe.failures==0 else 1)
