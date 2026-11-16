extends SceneTree
const Catalogue=preload("res://scripts/core/catalogue.gd")
const Shield=preload("res://scripts/visual/shield_art.gd")
const Family=preload("res://scripts/visual/heraldry.gd")
const Arms=preload("res://scripts/visual/shield_arms098.gd")
var failures: Array=[]
var folder=""
var main

func _initialize() -> void: call_deferred("run")
func check(value: bool,message: String) -> void:
	if not value and message not in failures: failures.append(message)
func shot(label: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(folder+"/"+label+".png")==OK,"capture failed "+label)

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): folder=arg.trim_prefix("--report=")
	var state=root.get_node("GameState")
	if folder.is_empty() or DirAccess.dir_exists_absolute(folder) or not "qa_" in state.save_path or OS.get_environment("GALUMU_MEMORY_BOUND")!="1024": quit(2);return
	DirAccess.make_dir_recursive_absolute(folder)
	state.save_path=folder+"/qa_profile.json"
	state.backup_path=folder+"/qa_backup.json"
	state.profile=state.default_profile()
	state.profile.settings.sound=false
	var items=Catalogue.load_items()
	var kit=state.profile.equipped.duplicate(true)
	var shape_hashes={}
	var shield_count=0
	var family_count=0
	for item in items:
		if item.slot=="crest":
			family_count+=1
			if item.id not in state.profile.owned: state.profile.owned.append(item.id)
			for facing in [1,-1]:
				var design=Family.mirrored_key(str(item.stats.heraldry),facing)
				for style in ["linen","wool","velvet"]:
					check(ResourceLoader.exists("res://assets/art/caparison066/%s_%s.png" % [style,design]),"missing family cloth "+style+"/"+design)
				check(ResourceLoader.exists("res://assets/art/battle090/armor/eng_armor_1__%s.png" % design),"missing surcoat "+design)
		if item.slot!="shield": continue
		shield_count+=1
		kit.shield=item.id
		check(Arms.DESIGNS.has(item.stats.shield_heraldry),"missing fixed shield design "+item.id)
		if item.id not in state.profile.owned: state.profile.owned.append(item.id)
		var fingerprint=str(Arms.polygons(item.id))+str(Arms.polygons(item.id,true))+str(Arms.details(item.id))
		check(not shape_hashes.has(fingerprint),"duplicate device geometry "+item.id)
		shape_hashes[fingerprint]=item.id
		for crest in items:
			if crest.slot!="crest": continue
			kit.crest=crest.id
			var stats=Catalogue.stats(items,kit)
			check(Shield.device(stats)==item.id,"family overwrote shield "+item.id)
			check(stats.heraldry==crest.stats.heraldry,"shield overwrote family "+crest.id)
			var reverse={}
			var keys=kit.keys();keys.reverse()
			for key in keys: reverse[key]=kit[key]
			check(Catalogue.stats(items,reverse)==stats,"slot ordering changes equipment "+item.id)
		for facing in [1,-1]:
			var geometry=Shield.geometry(item.stats.shield_shape,item.id,item.stats.shield_scale,facing)
			check(not geometry.charges.is_empty(),"blank shield "+item.id)
			for part in [geometry.charges,geometry.overlays,geometry.details]:
				for polygon in part: check(not Geometry2D.triangulate_polygon(polygon).is_empty(),"invalid clipped shape "+item.id)
	check(shield_count==25 and family_count==12,"missing old shield or family items")
	check(Shield._geometry.size()<=Shield.MAX_GEOMETRY,"unbounded shield cache")
	state.profile.equipped.merge({"shield":"fr_shield_1","crest":"crest_bend","caparison":"caparison_linen","armor":"eng_armor_1","lance":"eng_lance_long_5"},true)
	state.profile.renown=80
	for id in state.profile.equipped.values():
		if id not in state.profile.owned: state.profile.owned.append(id)
	var inventory=state.profile.owned.duplicate()
	check(state.equip("crest_fleur"),"cannot equip owned family")
	check(state.player_stats().shield_heraldry=="fr_shield_1","family equip changed shield device")
	state.load_profile()
	check(state.profile.owned==inventory and state.profile.equipped.crest=="crest_fleur","family save migration lost inventory/selection")
	if "--render" in OS.get_cmdline_user_args():
		check(DisplayServer.get_name()!="headless","render requested on headless display")
		root.size=Vector2i(1440,810)
		root.content_scale_size=Vector2i(1440,810)
		main=load("res://scenes/main.tscn").instantiate()
		root.add_child(main)
		for crest in ["crest_bend","crest_chevron"]:
			check(state.equip(crest),"family equip in main failed")
			main.show_home()
			await create_timer(.7).timeout
			await shot("camp-"+crest)
		main.selected_slot="crest";main.selected_era=-1;main.selected_region=0;main.selected_quality=0
		main.show_armory()
		await create_timer(.8).timeout
		await shot("family-armory")
		main.selected_slot="shield"
		main.show_armory()
		await create_timer(.8).timeout
		await shot("shield-armory")
		main.queue_free()
		for tick in range(5): await process_frame
	FileAccess.open(folder+"/report.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"failures":failures,"shields":shield_count,"families":family_count,"combinations":shield_count*family_count,"rendered":"--render" in OS.get_cmdline_user_args(),"scope":"Catalogue and old inventory roundtrip; fixed devices, independent family assets, slot order and bounded geometry. Optional actual Main screenshots, no OS input."},"  "))
	print("HERALDRY098 ",failures)
	quit(0 if failures.is_empty() else 1)
