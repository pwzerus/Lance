extends SceneTree
## Inventory/identity geometry diagnostics. No GPU or historical authenticity claim.
const Catalogue=preload("res://scripts/core/catalogue.gd")
const Campaign=preload("res://scripts/core/campaign.gd")
const Appearance=preload("res://scripts/core/character_appearance.gd")
const Art=preload("res://scripts/visual/equipment_art.gd")
const Fit=preload("res://scripts/visual/head_fit.gd")
const Heraldry=preload("res://scripts/visual/heraldry.gd")
var failures=[]
func _initialize()->void:call_deferred("run")
func check(ok:bool,why:String)->void:
	if not ok:failures.append(why)
func run()->void:
	var report_path="";var require_identities=false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--report="):report_path=a.trim_prefix("--report=")
		if a=="--require-identities":require_identities=true
	if report_path.is_empty() or FileAccess.file_exists(report_path) or not root.get_node("GameState").save_path.contains("qa_") or OS.get_environment("GALUMU_MEMORY_BOUND").is_empty():quit(2);return
	var items=Catalogue.load_items();var faces={};var identities=[];var equipment=[];var hashes={};var armour_ids=[];var helmet_ids=[]
	for n in range(1,81):
		var level=Campaign.level(items,n);var stats=Catalogue.stats(items,level.equipment)
		var fallback=Appearance.variant(hash(str(stats.get("armor_color",""))+str(stats.get("shield_color",""))))
		var appearance=Appearance.sanitize(level.get("appearance",fallback))
		var key=JSON.stringify(appearance);faces[key]=int(faces.get(key,0))+1
		identities.append({"level":n,"name":level.opponent,"appearance":appearance,"explicit":level.has("appearance"),"fallback":fallback})
		if require_identities:check(level.has("appearance"),"Missing stable identity %d"%n)
	for region in ["eng","fr","de","it"]:
		for tier in range(6):
			for slot in ["armor","helmet"]:
				var id="%s_%s_%d"%[region,slot,tier];var item=Catalogue.find(items,id)
				check(not item.is_empty(),"Missing equipment "+id)
				if item.is_empty():continue
				var descriptor=Art.descriptor(item.stats,slot);var path=str(descriptor.get("image_path",""))
				check(ResourceLoader.exists(path),"Missing source texture "+id)
				var battle_path=Art.BATTLE_DIR+slot+"/"+id+".png"
				check(ResourceLoader.exists(battle_path),"Missing battle texture "+id)
				var sha=FileAccess.get_sha256(path)
				check(not sha.is_empty() and not hashes.has(sha),"Missing/identical source texture "+id)
				hashes[sha]=id
				check(not str(item.get("source_url","")).is_empty() and not str(item.get("historical_note","")).is_empty(),"Missing history metadata "+id)
				# Exact alpha-mask duplicates flag shared silhouettes for review.
				# Different hashes alone never establish readable or authentic art.
				# This source-inventory audit intentionally reads original PNG bytes;
				# release-package resource loading is covered by test_bundle087.
				var bitmap=Image.new()
				var decoded=bitmap.load_png_from_buffer(FileAccess.get_file_as_bytes(battle_path))
				var alpha=PackedByteArray();var bitmap_size=Vector2i.ZERO;var alpha_sha=""
				if decoded==OK:
					bitmap_size=bitmap.get_size()
					for y in range(bitmap.get_height()):
						for x in range(bitmap.get_width()):alpha.append(1 if bitmap.get_pixel(x,y).a>.5 else 0)
					var hasher=HashingContext.new();hasher.start(HashingContext.HASH_SHA256);hasher.update(alpha);alpha_sha=hasher.finish().hex_encode()
				check(not alpha_sha.is_empty(),"Unreadable battle texture "+id)
				equipment.append({"id":id,"sha256":sha,"battle_sha256":FileAccess.get_sha256(battle_path),"battle_size":[bitmap_size.x,bitmap_size.y],"battle_alpha_sha256":alpha_sha,"source_url":item.get("source_url",""),"window":item.get("historical_window",""),"open_face":descriptor.get("open_face",false)})
				if slot=="armor":armour_ids.append(id)
				else:helmet_ids.append(id)
	var fit_pairs=0
	for helmet in helmet_ids:
		for armour in armour_ids:
			var stats=Catalogue.stats(items,{"helmet":helmet,"armor":armour});var fit=Fit.layout(stats)
			check(fit.helmet.size.x>20 and fit.helmet.size.y>20,"Invalid helmet registration "+helmet)
			check(float(fit.collar.width)>0,"Invalid collar "+armour)
			fit_pairs+=1
	check(Fit._layouts.size()<=Fit.MAX_LAYOUTS,"Unbounded fit cache")
	var cloth_paths=[]
	for style in ["linen","wool","velvet"]:
		for design in Heraldry.ARMS:
			for facing in [1,-1]:
				var path="res://assets/art/caparison066/%s_%s.png"%[style,Heraldry.mirrored_key(design,facing)]
				check(ResourceLoader.exists(path),"Missing cloth "+path)
				if not path in cloth_paths:cloth_paths.append(path)
	if require_identities:check(faces.size()==80,"Campaign identities duplicate: "+str(faces.size()))
	var result={"passed":failures.is_empty(),"failures":failures,"unique_faces":faces.size(),"face_groups":faces,"identities":identities,"equipment":equipment,"fit_pairs":fit_pairs,"cloth_paths":cloth_paths,"scope":"Inventory, valid registrations and deterministic cosmetic identity only; inspect GPU separately; URLs are recorded, not automatically verified."}
	FileAccess.open(report_path,FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("ART108 inventory ",failures," unique faces=",faces.size()," fit pairs=",fit_pairs)
	quit(0 if failures.is_empty() else 1)
