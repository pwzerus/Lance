extends SceneTree
## Actual exported PCK inventory and loadable release assets, not a visual test.
var failures=[]
func _initialize()->void:call_deferred("run")
func check(ok:bool,why:String)->void:
	if not ok:failures.append(why)
func run()->void:
	var folder="";var expected="0.4.41"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--folder="):folder=a.trim_prefix("--folder=")
		if a.begins_with("--version="):expected=a.trim_prefix("--version=")
	var state=root.get_node("GameState")
	if folder.is_empty() or DirAccess.dir_exists_absolute(folder) or not state.save_path.contains("qa_") or OS.get_environment("GALUMU_MEMORY_BOUND")!="1024" or OS.has_feature("editor"):quit(2);return
	DirAccess.make_dir_recursive_absolute(folder)
	check(ProjectSettings.get_setting("application/config/version")==expected,"Wrong packed project version")
	check(Engine.get_version_info().hex==0x040501,"Wrong engine version")
	for path in ["res://tests/test_play087.gd","res://tools/package_v063.gd","res://assets/audio/impact_v050","res://assets/audio/impact_v056","res://art_sources"]:
		check(not FileAccess.file_exists(path) and not ResourceLoader.exists(path) and not DirAccess.dir_exists_absolute(path),"Developer or superseded content leaked into PCK: "+path)
	var catalogue=load("res://scripts/core/catalogue.gd")
	var art=load("res://scripts/visual/equipment_art.gd")
	var skin=load("res://scripts/visual/horse_skin.gd")
	check(state.items.size()==186,"Unexpected merged catalogue count")
	var art_paths=[];var armor_count=0;var lance_count=0
	for region in ["eng","fr","de","it"]:
		for tier in range(6):
			for slot in ["armor","helmet"]:
				var id="%s_%s_%d" % [region,slot,tier]
				var item=catalogue.find(state.items,id)
				check(not item.is_empty(),"Missing collectible "+id)
				if item.is_empty():continue
				var descriptor=art.descriptor(item.stats,slot)
				check(not descriptor.is_empty(),"Missing art descriptor "+id)
				var path=str(descriptor.get("image_path",""))
				check(ResourceLoader.exists(path),"Missing packed art "+path)
				art_paths.append(path)
				var texture=art.equipment_texture(item.stats,slot)
				check(texture!=null and texture.get_width()>0 and texture.get_height()>0,"Unloadable equipment texture "+id)
				armor_count+=1
				check(art._textures.size()<=art.MAX_CACHED_TEXTURES,"Equipment cache exceeded its bound")
			for kind in ["light","long","stout"]:
				var id="%s_lance_%s_%d" % [region,kind,tier]
				check(not catalogue.find(state.items,id).is_empty(),"Missing lance "+id)
				lance_count+=1
	for coat in ["bay","black","flaxen","grey"]:
		var texture=skin.coat_texture(coat)
		check(texture!=null and texture.get_width()>0,"Missing horse coat "+coat)
	for style in ["linen","wool","velvet"]:
		for design in ["bend","bend_l","chevron","cross","diamond"]:
			var texture=skin.caparison_texture(style,design)
			check(texture!=null and texture.get_width()>0,"Missing horse cloth "+style+design)
	var executable=OS.get_executable_path()
	var package=executable.get_base_dir().get_base_dir()
	check(FileAccess.get_file_as_string(package+"/licenses/GODOT-LICENSE.txt")==Engine.get_license_text(),"Bundled engine license differs from running engine")
	check(FileAccess.get_file_as_string(package+"/licenses/NOTO-SANS-SC-OFL.txt")==FileAccess.get_file_as_string("res://assets/fonts/OFL.txt"),"Bundled font notice differs from packed font notice")
	var report={"passed":failures.is_empty(),"failures":failures,"version":ProjectSettings.get_setting("application/config/version"),"executable":executable,"pck_sha256":FileAccess.get_sha256(executable.get_basename()+".pck"),"catalogue_count":state.items.size(),"armor_and_helmets":armor_count,"lances":lance_count,"art_paths":art_paths,"horse_coats":skin._coat_cache.size(),"horse_cloths":skin._caparison_cache.size(),"scope":"Actual release engine/PCK load and inventory, no source project or GPU animation acceptance. Separate external script is excluded from distribution."}
	FileAccess.open(folder+"/report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("BUNDLE087 ",failures)
	quit(0 if failures.is_empty() else 1)
