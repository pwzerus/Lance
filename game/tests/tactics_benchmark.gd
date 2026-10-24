extends SceneTree

const Model = preload("res://scripts/core/joust_match.gd")

func _initialize() -> void:
	call_deferred("run")

func attack_case(zone: String, guard: float, direction: int) -> Dictionary:
	var model = Model.new("arena",{}, {},123)
	model.phase = "charge"
	var attacker_index = 0 if direction==1 else 1
	var defender_index = 1-attacker_index
	model.fighters[defender_index].acted = true
	for tick in range(120*15):
		var a = model.fighters[attacker_index]
		var d = model.fighters[defender_index]
		var selected = "head" if zone=="late_switch" and absf(float(a.x)-float(d.x))>450 else ("flank" if zone=="late_switch" else zone)
		var height = Model.head_position(d).y if selected=="head" else Model.flank_position(d).y
		var aim = asin(clampf((height-Model.hand_position(a).y)/Model.lance_length(a),-.629,.548))
		model.set_controls(attacker_index,aim,0,true,1.0/120,0)
		model.set_controls(defender_index,0,0,true,1.0/120,guard)
		model.step(1.0/120)
		for event in model.drain_events():
			if event.type=="hit" and int(event.attacker)==attacker_index:
				return {"attack":zone,"guard":"high" if guard>0 else "low","direction":direction,"hit":event.zone,"damage":event.damage,"support":event.support,"time":model.time_elapsed}
		if float(a.x)*direction>float(d.x)*direction+400:
			break
	return {"attack":zone,"guard":"high" if guard>0 else "low","direction":direction,"hit":"miss","damage":0}

func run() -> void:
	var rows: Array = []
	for facing in [1,-1]:
		for guard in [0.0,1.0]:
			for target in ["head","flank","late_switch"]:
				rows.append(attack_case(target,guard,facing))
	var file = FileAccess.open("res://tests/tactics_benchmark.json",FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify({"scope":"12 isolated charge scenarios; defender does not attack; not human win rates","rows":rows},"\t"))
	print("TACTICS_BENCHMARK "+JSON.stringify(rows))
	quit()
