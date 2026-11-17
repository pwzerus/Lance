extends SceneTree
## Frozen-pose sweep diagnosis, NOT a match-win or human-feel test.
const Model=preload("res://scripts/core/joust_match.gd")
const Catalogue=preload("res://scripts/core/catalogue.gd")

func _initialize() -> void:call_deferred("run")

func strike(kit: Dictionary, side: int, guard: float, lean: float, zone: String, offset: float) -> Dictionary:
	var m=Model.new("arena",kit,kit,101)
	var a: Dictionary=m.fighters[side]
	var d: Dictionary=m.fighters[1-side]
	d.x=0.0;d.guard=guard;d.guard_target=guard;d.lean=lean
	for f in m.fighters:f.speed=350.0
	var target: Vector2=Model.head_position(d) if zone=="head" else (Model.body_position(d) if zone=="body" else Model.flank_position(d))
	target.y+=offset
	a.aim=asin(clampf((target.y-Model.hand_position(a).y)/Model.lance_length(a),-.629,.548))
	a.x+=target.x+int(a.direction)*8.0-Model.tip_position(a).x
	for f in m.fighters:m._cache_pose(f)
	# Travel along the charge axis with the actual lance angle and staggered
	# lanes. All target regions compete for earliest time of contact.
	a.prev_hand-=Vector2(int(a.direction)*170.0,0)
	var e=m._detect_contact(side,170.0/700.0)
	if not e.is_empty():m._apply_contact(e)
	return {"side":side,"guard":guard,"lean":lean,"target":zone,"offset":offset,"event":e}

func approach(kit: Dictionary, side: int, guard: float, zone: String) -> Dictionary:
	var m=Model.new("arena",kit,kit,101)
	m.phase="charge"
	for f in m.fighters:
		f.x=-500.0 if int(f.direction)==1 else 500.0
		f.speed=350.0
		f.guard=guard;f.guard_target=guard
		m._cache_pose(f)
	# One attacking lance isolates defensive coverage, not duel outcome.
	m.fighters[1-side].acted=true
	var aim=-.08
	for tick in range(480):
		var a: Dictionary=m.fighters[side];var d: Dictionary=m.fighters[1-side]
		if tick%24==0:
			var target=Model.head_position(d) if zone=="head" else (Model.body_position(d) if zone=="body" else Model.flank_position(d))
			aim=asin(clampf((target.y-Model.hand_position(a).y)/Model.lance_length(a),-.629,.548))
		m.set_controls(side,aim,0.0,true,1.0/120,guard)
		m.set_controls(1-side,-.08,0.0,true,1.0/120,guard)
		m.step(1.0/120)
		for e in m.drain_events():
			if e.get("type")=="hit" and int(e.attacker)==side:
				return {"side":side,"guard":guard,"target":zone,"event":e,"ticks":tick+1}
		if m.phase!="charge":break
	return {"side":side,"guard":guard,"target":zone,"event":{},"miss":true}

func run() -> void:
	var path=""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--report="):path=a.trim_prefix("--report=")
	if path.is_empty() or FileAccess.file_exists(path) or OS.get_environment("GALUMU_MEMORY_BOUND")=="" or not "qa_" in root.get_node("GameState").save_path:quit(2);return
	var items=Catalogue.load_items();var rows=[]
	for q in range(6):
		var kit=Catalogue.stats(items,{"armor":"eng_armor_3","helmet":"eng_helmet_3","shield":"eng_shield_"+str(q),"horse":"horse_bay","lance":"lance_ash"})
		for side in range(2):
			for guard in [0.0,.43,1.0]:
				for lean in [-1.0,0.0,1.0]:
					for zone in ["head","body","flank"]:
						for offset in [-10.0,0.0,10.0]:
							var row=strike(kit,side,guard,lean,zone,offset)
							row.shield="eng_shield_"+str(q);rows.append(row)
	var approaches=[]
	for q in [0,5]:
		var kit=Catalogue.stats(items,{"armor":"eng_armor_3","helmet":"eng_helmet_3","shield":"eng_shield_"+str(q),"horse":"horse_bay","lance":"lance_ash"})
		for side in range(2):
			for guard in [0.0,.43,1.0]:
				for zone in ["head","body","flank"]:
					var row=approach(kit,side,guard,zone)
					row.shield="eng_shield_"+str(q);approaches.append(row)
	FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify({"scope":"972 frozen-pose real sweeps, actual lane depth; aimed center +/-10px, six English shields, both approaches, three guards and three leans. Also 36 isolated finite-control approaches, aim updates every 200ms, neutral lean, defender lance disabled. No AI or human win-rate claim.","rows":rows,"approaches":approaches},"\t"))
	print("GUARD101 rows=",rows.size()," approaches=",approaches.size());quit(0)
