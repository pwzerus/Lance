extends SceneTree
## Actual Main previews and GameState.equip, with explicitly granted QA
## ownership. This is an art/lifetime check, not earned economy progression.
const HorseSkin=preload("res://scripts/visual/horse_skin.gd")
const Art=preload("res://scripts/visual/equipment_art.gd")
const Family=preload("res://scripts/visual/heraldry.gd")
var folder=""
var failures=[]
var rows=[]
var main
var state
func _initialize()->void:call_deferred("run")
func check(ok:bool,message:String)->void:
	if not ok and message not in failures:failures.append(message)
func display_item(id:String,label:String,capture:bool=false)->void:
	check(state.equip(id),"Cannot equip QA-owned item "+id)
	var old=weakref(main.preview)
	var started=Time.get_ticks_usec()
	main.show_home()
	await process_frame;await RenderingServer.frame_post_draw
	var ready_ms=(Time.get_ticks_usec()-started)/1000.0
	# Permit the authored idle pose, flags and preview lifecycle to run.
	await create_timer(.7).timeout
	check(old.get_ref()==null,"Previous mounted preview leaked at "+label)
	check(main.preview.fighter.stats==state.player_stats(),"Preview stats differ at "+label)
	if capture:
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(folder+"/"+label+".png")==OK,"Capture failed "+label)
	rows.append({"id":id,"label":label,"ready_ms":ready_ms,"nodes":int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),"static_bytes":OS.get_static_memory_usage(),"coats":HorseSkin._coat_cache.size(),"cloths":HorseSkin._caparison_cache.size()})
func run()->void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--folder="):folder=arg.trim_prefix("--folder=")
	state=root.get_node("GameState")
	if folder.is_empty() or DirAccess.dir_exists_absolute(folder) or OS.get_environment("GALUMU_MEMORY_BOUND")!="1024" or DisplayServer.get_name()=="headless" or not "qa_" in state.save_path:quit(2);return
	DirAccess.make_dir_recursive_absolute(folder)
	state.save_path=folder+"/qa_profile.json";state.backup_path=folder+"/qa_backup.json"
	state.profile=state.default_profile();state.profile.renown=100;state.profile.settings.sound=false
	for item in state.items:
		if item.id not in state.profile.owned:state.profile.owned.append(item.id)
	check(state.save_profile(),"QA setup save failed")
	AudioServer.set_bus_mute(0,true)
	root.size=Vector2i(1440,810);root.content_scale_size=root.size
	main=load("res://scenes/main.tscn").instantiate();root.add_child(main)
	await create_timer(.5).timeout
	var seen={}
	for item in state.items:
		await display_item(item.id,"item-"+item.id,not seen.has(item.slot))
		seen[item.slot]=true
		if rows.size()%24==0:print("WARDROBE108 items=",rows.size())
	# Every family/style asset in actual Main, including directional variants
	# already covered by the independent mounted double-facing sheet.
	for style in ["linen","wool","velvet"]:
		check(state.equip("caparison_"+style),"Cloth equip failed")
		for family in Family.ARMS:
			await display_item("crest_"+family,"cloth-"+style+"-"+family,family in ["bend","chequy","fleur"])
	var before=rows[-1].static_bytes
	for id in ["eng_armor_0","fr_armor_2","de_armor_4","it_armor_5","eng_helmet_0","fr_helmet_4","de_helmet_4","it_helmet_3","horse_bay","horse_grey","horse_e3","horse_steady"]:
		await display_item(id,"warm-"+id)
	check(HorseSkin._coat_cache.size()==4,"All four coat assets should be reached")
	check(HorseSkin._caparison_cache.size()<=45,"Cloth cache exceeds authored variants")
	check(rows[-1].static_bytes<before+16*1024*1024,"Small warmed revisit keeps allocating resources")
	var report={"passed":failures.is_empty(),"failures":failures,"rows":rows,"scope":"Actual Main and GameState.equip for every catalogue item plus 36 family/cloth combinations and 12 warm revisits. QA-granted ownership, live preview; not purchases or OS input. Whole-process memory is in wrapper log; static bytes excludes GPU/driver."}
	FileAccess.open(folder+"/report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("WARDROBE108 ",failures)
	# Production shutdown includes the stopped audio mixer drain.
	if failures.is_empty():await main._shutdown_and_quit()
	else:quit(1)
