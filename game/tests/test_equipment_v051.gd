extends SceneTree
## Real catalogue, purchases/saves, rendered parts and shop. Programmatic QA, not OS input.
const Catalogue = preload("res://scripts/core/catalogue.gd")
const Art = preload("res://scripts/visual/equipment_art.gd")
const Model = preload("res://scripts/core/joust_match.gd")
const Rider = preload("res://scripts/visual/rider_view.gd")
const UI = preload("res://scripts/ui/ui_factory.gd")
const Bank = preload("res://scripts/visual/sound_bank.gd")
var failures: Array[String] = []
var rows: Array = []
var items: Array = []
var report = "E:/GALUMU/docs/development/logs/v051/equipment01.json"
var captures = "E:/GALUMU/docs/development/screenshots/v051/catalogue01"
var surface: Control

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String, detail: Dictionary = {}) -> void:
	if not ok:
		failures.append(message)
		rows.append({"failure":message,"detail":detail})
		push_error(message+" "+str(detail))

func asset_checks() -> void:
	var source = JSON.parse_string(FileAccess.get_file_as_string("res://data/equipment_expansion.json"))
	var hashes: Array = []
	for country in ["eng","fr","de","it"]:
		for slot in ["helmet","armor"]:
			for tier in range(6):
				var id = "%s_%s_%d" % [country,slot,tier]
				var item = Catalogue.find(items,id)
				check(not item.is_empty(),"Regional item exists",{"id":id})
				if item.is_empty(): continue
				var old = Catalogue.find(source,id)
				check(not old.is_empty(),"Existing progression ID is retained",{"id":id})
				if not old.is_empty():
					check(Catalogue.required_renown(item)==Catalogue.required_renown(old),"Historical date correction preserves actual unlock gate",{"id":id})
					for key in ["price","quality","renown"]:
						check(item.get(key)==old.get(key),"Price/quality/renown unchanged",{"id":id,"key":key})
					for key in old.stats:
						if old.stats[key] is float or old.stats[key] is int:
							check(item.stats.get(key)==old.stats[key],"Numerical equipment balance unchanged",{"id":id,"key":key})
				for key in ["source_url","historical_window","historical_note","manufacture","use_context"]:
					check(not str(item.get(key,"")).is_empty(),"Provenance field exists",{"id":id,"key":key})
				check(item.stats.get(slot+"_art")==id,"Every regional item selects its own asset",{"id":id})
				var entry = Art.descriptor(item.stats,slot)
				check(not entry.is_empty(),"Runtime manifest contains equipment",{"id":id})
				var texture = Art.equipment_texture(item.stats,slot)
				check(texture!=null,"Engine imported actual asset; no fallback",{"id":id})
				if entry.is_empty() or texture==null: continue
				var hash_value = str(entry.get("source_sha256",""))
				check(hash_value.length()==64 and hash_value not in hashes,"Distinct asset bytes; visual distinction still requires inspection",{"id":id})
				hashes.append(hash_value)
				var image = texture.get_image()
				check(image!=null and image.get_width()>0,"Cropped texture is available to renderer",{"id":id})
				check(item.stats.has(slot+"_material"),"Impact surface follows actual armor material",{"id":id})
				var family = Bank.impact_material("head" if slot=="helmet" else "body",item.stats)
				var authored_material = str(item.stats[slot+"_material"])
				var expected_family = "helmet" if slot=="helmet" and authored_material in ["plate","steel","iron","metal"] else authored_material
				check(family==expected_family,"Contact audio follows authored surface",{"id":id,"family":family,"expected":expected_family})
	check(hashes.size()==48,"All 48 independent assets loaded",{"loaded":hashes.size()})

func persistence_checks(state: Node) -> void:
	state.save_path = "user://qa_equipment_v051_profile.json"
	state.backup_path = "user://qa_equipment_v051_profile.backup.json"
	state.profile = state.default_profile()
	state.profile.coins = 100000
	state.profile.renown = 200
	for country in ["eng","fr","de","it"]:
		for tier in range(6):
			for slot in ["helmet","armor"]:
				var id = "%s_%s_%d" % [country,slot,tier]
				var item = Catalogue.find(items,id)
				if item.is_empty(): continue
				var coins = int(state.profile.coins)
				var gate = Catalogue.required_renown(item)
				if gate>0:
					state.profile.renown = gate-1
					check(state.purchase(id)!="已收入军械库" and id not in state.profile.owned and int(state.profile.coins)==coins,"Below-gate purchase remains blocked without charge",{"id":id,"renown":gate-1})
				state.profile.renown = gate
				check(state.purchase(id)=="已收入军械库","Purchase succeeds through real save path",{"id":id})
				check(int(state.profile.coins)==coins-int(item.price),"Purchase debits exactly the item price",{"id":id})
				check(state.equip(id),"Equipment can be selected",{"id":id})
				state.load_profile()
				check(state.profile.equipped[slot]==id and id in state.profile.owned,"Automatic reload retains equipment",{"id":id})
	check(state.save_slot(2),"New equipment can be manually saved")
	state.profile = state.default_profile()
	check(state.load_slot(2),"Manual equipment slot reloads")
	check(state.profile.equipped.armor=="it_armor_5" and state.profile.equipped.helmet=="it_helmet_5","Helmet and torso persist independently")
	var old_profile = state.default_profile()
	var base = JSON.parse_string(FileAccess.get_file_as_string("res://data/equipment.json"))
	for item in base:
		if item.id not in old_profile.owned: old_profile.owned.append(item.id)
	old_profile.equipped.armor = "armor_e2"
	old_profile.equipped.helmet = "helm_e3"
	var migrated = state.sanitize(old_profile)
	check(migrated.owned.size()==old_profile.owned.size(),"Old purchases are not removed")
	check(migrated.equipped.armor=="armor_e2" and migrated.equipped.helmet=="helm_e3","Old equipped IDs survive migration")

func simulation_checks() -> void:
	var stats = Catalogue.stats(items,{"armor":"de_armor_5","helmet":"fr_helmet_3","lance":"eng_lance_stout_5","horse":"horse_bay"})
	for mode in ["arena","war"]:
		var decorated = stats.duplicate(true)
		decorated.leg_decoration = 4
		var plain = stats.duplicate(true)
		plain.leg_decoration = 0
		var a = Model.new(mode,decorated,decorated,51234)
		var b = Model.new(mode,plain,plain,51234)
		var contacts = 0
		for frame in range(6000):
			for match_model in [a,b]:
				for side in range(2):
					var attacker = match_model.fighters[side]
					var target = match_model.fighters[1-side]
					var aim = asin(clampf((Model.body_position(target).y-Model.hand_position(attacker).y)/Model.lance_length(attacker),-1,1))
					match_model.set_controls(side,aim,0,true,1.0/60,.1)
				match_model.step(1.0/60)
			check(a.events==b.events,"Leg decorations do not alter contacts or results",{"mode":mode,"frame":frame})
			for event in a.events:
				if event.type=="hit": contacts += 1
			a.events.clear()
			b.events.clear()
			if a.phase=="ended": break
		check(a.phase=="ended" and b.phase=="ended" and contacts>0,"Cosmetic comparison contains actual hits and completed matches",{"mode":mode,"contacts":contacts,"phase":a.phase})
		rows.append({"cosmetic_simulation":mode,"contacts":contacts,"phase":a.phase})
		for side in range(2):
			for key in ["hp","poise","dead","ko","score","broken"]:
				check(a.fighters[side].get(key)==b.fighters[side].get(key),"Leg decoration gives no protection or outcome change",{"mode":mode,"key":key})

func capture(name: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(captures.path_join(name+".png"))==OK,"Screenshot saved",{"name":name})

func render_region(country: String) -> void:
	surface = Control.new()
	surface.theme = UI.theme()
	root.add_child(surface)
	var background = ColorRect.new()
	background.color = Color("26352f")
	background.size = Vector2(1440,810)
	surface.add_child(background)
	for tier in range(6):
		var origin = Vector2((tier%3)*480,(tier/3)*405)
		var helmet = Catalogue.find(items,"%s_helmet_%d" % [country,tier])
		var armor = Catalogue.find(items,"%s_armor_%d" % [country,tier])
		if helmet.is_empty() or armor.is_empty(): continue
		UI.label(surface,helmet.name,origin+Vector2(18,10),16,UI.GOLD,440)
		UI.label(surface,armor.name,origin+Vector2(18,36),15,UI.INK,440)
		UI.label(surface,"盔 "+helmet.historical_window+" / 甲 "+armor.historical_window,origin+Vector2(18,63),12,UI.MUTED,440)
		var equipment = {"helmet":helmet.id,"armor":armor.id,"lance":"lance_ash","horse":"horse_bay"}
		var stats = Catalogue.stats(items,equipment)
		var model = Model.new("arena",stats,stats,71)
		var view = Rider.new()
		view.fighter = model.fighters[tier%2]
		view.fighter.x = 0
		view.fighter.lane_y = 0
		view.fighter.aim = .12
		view.position = origin+Vector2(230,348)
		view.scale = Vector2.ONE*.78
		surface.add_child(view)
		for slot_index in range(2):
			var icon = TextureRect.new()
			icon.texture = Art.item_icon(helmet if slot_index==0 else armor)
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.position = origin+Vector2(369,94+slot_index*100)
			icon.size = Vector2(80,94)
			surface.add_child(icon)
	await capture(country+"_six_sets")
	surface.queue_free()
	await process_frame

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): report = arg.trim_prefix("--report=")
		if arg.begins_with("--captures="): captures = arg.trim_prefix("--captures=")
	var state = root.get_node("GameState")
	if not state.save_path.contains("qa_"):
		quit(2)
		return
	items = Catalogue.load_items()
	asset_checks()
	persistence_checks(state)
	simulation_checks()
	root.size = Vector2i(1440,810)
	DirAccess.make_dir_recursive_absolute(captures)
	for country in ["eng","fr","de","it"]:
		await render_region(country)
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	for slot in ["helmet","armor","lance"]:
		main.selected_slot = slot
		main.selected_era = -1
		main.selected_region = 2
		main.selected_item = Catalogue.find(items,"fr_"+slot+"_5" if slot!="lance" else "fr_lance_stout_5")
		main.show_armory()
		await capture("armory_"+slot)
		var scroll = main.info_panel.get_node("ProvenanceScroll")
		check(scroll.size.y>0 and scroll.size.y<200,"Long provenance stays in scroll area")
		for child in main.info_panel.get_children():
			if child is Button:
				check(child.position.y+child.size.y<=main.info_panel.size.y,"Shop action stays inside panel",{"slot":slot,"text":child.text})
	var result = {"passed":failures.is_empty(),"failures":failures,"rows":rows,"scope":"48 asset imports, real isolated purchases/auto/manual reload, legacy IDs, leg cosmetic simulation, engine-rendered regional sheets and shop; not OS input or human play"}
	DirAccess.make_dir_recursive_absolute(report.get_base_dir())
	var file = FileAccess.open(report,FileAccess.WRITE)
	file.store_string(JSON.stringify(result,"\t"))
	file.close()
	print("EQUIPMENT_V051 ",result.passed," failures=",failures.size())
	main.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
