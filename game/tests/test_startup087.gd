extends SceneTree
const TimedRider=preload("res://tests/profile_rider087.gd")
var folder=""
func _initialize()->void:call_deferred("run")
func run()->void:
	var warm_equipment=false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--folder="):folder=a.trim_prefix("--folder=")
		if a=="--warm-equipment":warm_equipment=true
	var state=root.get_node("GameState")
	if folder.is_empty() or DirAccess.dir_exists_absolute(folder) or not state.save_path.contains("qa_") or OS.get_environment("GALUMU_MEMORY_BOUND")!="1024" or DisplayServer.get_name()=="headless":quit(2);return
	DirAccess.make_dir_recursive_absolute(folder)
	state.save_path=folder+"/qa_profile.json";state.backup_path=folder+"/qa_backup.json";state.load_profile()
	state.profile.region=2;state.profile.renown=60
	state.profile.equipped.merge({"armor":"de_armor_5","helmet":"de_helmet_5","shield":"de_shield_5","lance":"de_lance_stout_5","horse":"horse_courser","caparison":"caparison_velvet","crest":"crest_bend"},true)
	state.profile.settings.sound=true;AudioServer.set_bus_mute(0,true)
	root.size=Vector2i(1280,720)
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
	# Main depends on GameState autoload, so load after the tree is ready.
	var main=load("res://tests/profile_main087.gd").new();main.smoke_mode=true;root.add_child(main);current_scene=main;main.set_process(false)
	await process_frame;await RenderingServer.frame_post_draw
	var warm_start=Time.get_ticks_usec()
	while Time.get_ticks_usec()-warm_start<2000000:await process_frame
	var shared=ShaderMaterial.new();shared.shader=load("res://scripts/visual/mounted_pixel.gdshader")
	var rows=[]
	var warm_costs=[]
	if warm_equipment:
		var catalogue=load("res://scripts/core/catalogue.gd")
		var art=load("res://scripts/visual/equipment_art.gd")
		var enemy=catalogue.opponent_stats(state.items,catalogue.era_for_renown(state.profile.renown))
		for slot in ["armor","helmet"]:
			var load_start=Time.get_ticks_usec()
			art.equipment_texture(enemy,slot)
			warm_costs.append({"slot":slot,"ms":(Time.get_ticks_usec()-load_start)/1000.0})
			await process_frame;await RenderingServer.frame_post_draw
		var skin=load("res://scripts/visual/horse_skin.gd")
		var skin_start=Time.get_ticks_usec()
		skin.coat_texture(str(enemy.get("horse_coat","bay")))
		warm_costs.append({"slot":"horse_coat","ms":(Time.get_ticks_usec()-skin_start)/1000.0})
		await process_frame;await RenderingServer.frame_post_draw
		var design=str(enemy.get("heraldry","bend"))
		skin_start=Time.get_ticks_usec()
		skin.caparison_texture(str(enemy.get("caparison_style","none")),design+"_l" if design=="bend" else design)
		warm_costs.append({"slot":"caparison","ms":(Time.get_ticks_usec()-skin_start)/1000.0})
		await process_frame;await RenderingServer.frame_post_draw
	for cycle in range(8):
		var use_shared=cycle%4 in [1,2]
		main.shared_material=shared if use_shared else null
		main.costs={};TimedRider.samples.clear();TimedRider.enabled=true
		await process_frame
		var start=Time.get_ticks_usec()
		main._start_match("war",false)
		if root.focus_exited.is_connected(main.battle._on_focus_lost):root.focus_exited.disconnect(main.battle._on_focus_lost)
		var sync_ms=(Time.get_ticks_usec()-start)/1000.0
		var frames=[];var previous=start
		for f in range(40):
			await process_frame
			var now=Time.get_ticks_usec()
			frames.append({"frame":Engine.get_process_frames(),"ms":(now-previous)/1000.0,"render_cpu_ms":RenderingServer.viewport_get_measured_render_time_cpu(root.get_viewport_rid()),"render_gpu_ms":RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid()),"process_ms":Performance.get_monitor(Performance.TIME_PROCESS)*1000,"physics_ms":Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000})
			previous=now
		TimedRider.enabled=false
		rows.append({"cycle":cycle,"shared_material":use_shared,"sync_ms":sync_ms,"costs":main.costs.duplicate(),"frames":frames,"rider_samples":TimedRider.samples.duplicate(true)})
		main._close_battle();main.show_home()
		await create_timer(.45,true,false,true).timeout
	FileAccess.open(folder+"/report.json",FileAccess.WRITE).store_string(JSON.stringify({"scope":"Instrumented subclasses on isolated GPU; extra replacement overhead included and separately reported. ABBA shared immutable material experiment, not release FPS evidence.","warm_equipment":warm_equipment,"warm_costs":warm_costs,"rows":rows},"\t"))
	print("STARTUP087 complete")
	main.notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
