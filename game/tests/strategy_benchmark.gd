extends SceneTree

const Model = preload("res://scripts/core/joust_match.gd")
var battle_script: Script

func _initialize() -> void:
	call_deferred("run")

func simulate(strategy: String, difficulty: int, seed_value: int, player_index: int = 0) -> Dictionary:
	var controller = battle_script.new()
	controller.ai_fighter_index = 1-player_index
	controller.ai_rng.seed = seed_value
	controller.match_model = Model.new("arena",{}, {},seed_value)
	var model = controller.match_model
	var observation = 0.0
	var aim = -.08
	var guard = 0.0
	var hits = {"head":0,"body":0,"flank":0,"shield":0}
	for tick in range(120*50):
		var player = model.fighters[player_index]
		var enemy = model.fighters[1-player_index]
		observation -= 1.0/120
		if observation<=0:
			observation = .50
			var target_head = strategy=="head" or strategy=="backlean" or (strategy=="adaptive" and float(enemy.guard)<.5)
			var height = Model.head_position(enemy).y if target_head else Model.flank_position(enemy).y
			aim = asin(clampf((height-Model.hand_position(player).y)/Model.lance_length(player),-.629,.548))
			var incoming = Model.tip_position(enemy).y
			guard = 1.0 if incoming<Model.body_position(player).y-28 else 0.0
		model.set_controls(player_index,aim,-1.0 if strategy=="backlean" else 0.0,true,1.0/120,guard)
		controller._update_ai(1.0/120)
		model.step(1.0/120)
		for event in model.drain_events():
			if event.type=="hit" and int(event.attacker)==player_index:
				hits[event.zone] += 1
		if model.phase=="ended":
			var relative_winner = -1 if model.result.winner==-1 else (0 if model.result.winner==player_index else 1)
			var row = {"strategy":strategy,"difficulty":difficulty,"player_index":player_index,"seed":seed_value,"winner":relative_winner,"passes":model.pass_number,"hp":player.hp,"enemy_hp":enemy.hp,"hits":hits}
			controller.free()
			return row
	controller.free()
	return {"strategy":strategy,"difficulty":difficulty,"seed":seed_value,"error":"simulation timeout"}

func run() -> void:
	var state = root.get_node("GameState")
	if not state.save_path.contains("qa_"):
		quit(1)
		return
	battle_script = load("res://scripts/battle.gd")
	var rows: Array = []
	var summary: Array = []
	for difficulty in range(3):
		state.profile.settings.difficulty = difficulty
		for strategy in ["head","flank","adaptive","backlean"]:
			var counts = {"strategy":strategy,"difficulty":difficulty,"wins":0,"losses":0,"draws":0,"timeouts":0}
			for case_index in range(24):
				var row = simulate(strategy,difficulty,701+case_index%12,case_index/12)
				rows.append(row)
				if row.has("error"):
					counts.timeouts += 1
				elif row.winner==0:
					counts.wins += 1
				elif row.winner==1:
					counts.losses += 1
				else:
					counts.draws += 1
			summary.append(counts)
	var report = {"scope":"288 deterministic rule simulations using production delayed AI, equal default equipment, 12 seeds on both player sides, scripted player observes every 0.50 game seconds; not human play or win-rate estimates","summary":summary,"rows":rows}
	var file = FileAccess.open("res://tests/strategy_benchmark_v041.json",FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(report,"\t"))
	print("STRATEGY_BENCHMARK "+JSON.stringify(summary))
	quit()
