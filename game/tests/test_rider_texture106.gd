extends SceneTree
const Rider106=preload("res://scripts/visual/rider_view.gd")
const Model=preload("res://scripts/core/joust_match.gd")
const Art=preload("res://scripts/visual/equipment_art.gd")
const Catalogue=preload("res://scripts/core/catalogue.gd")
var failures=[]
var captured_details={}
func _initialize()->void:call_deferred("run")
func check(ok:bool,message:String)->void:
	if not ok and message not in failures:failures.append(message)
func capture(script,stats:Dictionary,facing:int)->Image:
	var m=Model.new("arena",stats,stats)
	var f:Dictionary=m.fighters[0];f.direction=facing;f.x=0.0;f.lane_y=0.0
	f.speed=410.0;f.gait_moving=true;f.gait_phase=1.7;f.lean=.20;f.aim=-.19;f.guard=.65
	var rider=script.new();rider.fighter=f;rider.position=Vector2(420,490);rider.moving=true
	root.add_child(rider);rider.set_process(false);rider._process(0.0)
	await process_frame;await RenderingServer.frame_post_draw
	var image=root.get_texture().get_image()
	captured_details={"torso_type":rider.torso_texture.get_class(),"authored":rider.get("torso_has_authored_detail"),"art_id":stats.get("armor_art",""),"catalogue_exists":not Art.descriptor(stats,"armor").is_empty()}
	rider.queue_free();await process_frame
	return image
func run()->void:
	var folder="";var reference_path=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--folder="):folder=arg.trim_prefix("--folder=")
		if arg.begins_with("--reference="):reference_path=arg.trim_prefix("--reference=")
	if folder.is_empty() or DirAccess.dir_exists_absolute(folder) or reference_path.is_empty() or DisplayServer.get_name()=="headless" or not "--test-profile" in OS.get_cmdline_user_args() or OS.get_environment("GALUMU_MEMORY_BOUND")!="1024":quit(2);return
	DirAccess.make_dir_recursive_absolute(folder)
	root.size=Vector2i(840,560);root.content_scale_size=Vector2i(840,560);root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	var baseline=load(reference_path);var items=Catalogue.load_items();var rows=[]
	for region in ["eng","fr","de","it"]:
		for tier in range(6):
			var id="%s_armor_%d"%[region,tier]
			var stats=Catalogue.stats(items,{"armor":id,"helmet":"%s_helmet_%d"%[region,tier],"shield":"%s_shield_%d"%[region,tier],"lance":"%s_lance_long_%d"%[region,tier],"horse":"horse_courser"})
			# Chest/head comparison must not compare wall-clock pennon frames.
			# Keep the complete rider but use the same non-pennon lance quality.
			stats.lance_quality=3
			for facing in [1,-1]:
				Art._textures.clear()
				var fresh=await capture(Rider106,stats,facing)
				var fresh_details=captured_details.duplicate()
				var unused_loaded=Art._textures.size()
				check(unused_loaded==0,"Draw loaded a catalogue plate: "+id)
				var original=await capture(baseline,stats,facing)
				var identical=fresh.get_data()==original.get_data()
				check(identical,"Changed rider pixels: %s/%d"%[id,facing])
				var changed=0;var bounds=Rect2i()
				if not identical:
					for y in range(fresh.get_height()):
						for x in range(fresh.get_width()):
							if fresh.get_pixel(x,y)!=original.get_pixel(x,y):
								bounds=Rect2i(x,y,1,1) if changed==0 else bounds.expand(Vector2i(x,y));changed+=1
					if region=="eng":original.save_png(folder+"/%s_%d_old.png"%[id,facing]);fresh.save_png(folder+"/%s_%d_new.png"%[id,facing])
				rows.append({"armor":id,"facing":facing,"identical":identical,"new_catalogue_loads":unused_loaded,"old_catalogue_loads":Art._textures.size(),"changed":changed,"bounds":str(bounds),"fresh_details":fresh_details,"old_details":captured_details})
				if tier in [0,5] and facing==1:fresh.save_png(folder+"/%s.png"%id)
	# Legacy source sheets still get their authored/fallback decoration.
	var legacy={"armor_tier":0,"helmet_tier":0,"armor_color":"337744","armor_quality":3}
	var a=await capture(Rider106,legacy,1);var b=await capture(baseline,legacy,1)
	check(a.get_data()==b.get_data(),"Legacy torso details changed")
	FileAccess.open(folder+"/report.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"failures":failures,"rows":rows,"legacy_equal":a.get_data()==b.get_data(),"reference_sha256":FileAccess.get_sha256(reference_path),"scope":"Isolated real GPU, 24 chest/helmet pairs both facings, bit-exact viewport against baseline draw; no OS input."},"\t"))
	print("RIDER_TEXTURE106 ",failures);quit(0 if failures.is_empty() else 1)
