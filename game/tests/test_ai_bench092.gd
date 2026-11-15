extends SceneTree
## LEVEL-092 headless AI benchmark (QA profile, memory bound). Same scripted
## player as tests/strategy_benchmark.gd (observes every 0.50 s, aims at head
## or flank, guards the incoming line), against delayed AI controllers.
## --compare : old "normal" (tests/opponent_ai_legacy091.gd, pre-LEVEL-092)
##             vs new "normal", same seeds, default equal kits.
## --levels  : sampled campaign levels (every 5th plus champions) with the
##             level's own kit and AI profile vs a kit the rewards could buy.
## Writes only to --report. Rule simulation, not human play.
const Model = preload("res://scripts/core/joust_match.gd")
const Brain = preload("res://scripts/core/opponent_ai.gd")
const Legacy = preload("res://tests/opponent_ai_legacy091.gd")
const STRATEGIES = ["head","flank","adaptive","backlean"]
var report_path = ""
var compare = false
var with_levels = false

func _initialize() -> void:
	call_deferred("run")

func simulate(brain, strategy: String, difficulty: int, seed_value: int, player_index: int, player_stats: Dictionary = {}, enemy_stats: Dictionary = {}, mode: String = "arena") -> Dictionary:
	var stats_a = player_stats if player_index==0 else enemy_stats
	var stats_b = enemy_stats if player_index==0 else player_stats
	var model = Model.new(mode,stats_a,stats_b,seed_value)
	var rng = RandomNumberGenerator.new()
	rng.seed = seed_value+431
	var observation = 0.0
	var aim = -.08
	var guard = 0.0
	var dt = 1.0/120
	for tick in range(120*60):
		var player = model.fighters[player_index]
		var enemy = model.fighters[1-player_index]
		observation -= dt
		if observation<=0:
			observation = .50
			var target_head = strategy=="head" or strategy=="backlean" or (strategy=="adaptive" and float(enemy.guard)<.5)
			var height = Model.head_position(enemy).y if target_head else Model.flank_position(enemy).y
			aim = asin(clampf((height-Model.hand_position(player).y)/Model.lance_length(player),-.629,.548))
			var incoming = Model.tip_position(enemy).y
			guard = 1.0 if incoming<Model.body_position(player).y-28 else 0.0
		model.set_controls(player_index,aim,-1.0 if strategy=="backlean" else 0.0,true,dt,guard)
		if model.phase=="charge":
			brain.update(model,1-player_index,difficulty,dt,rng)
		model.step(dt)
		model.drain_events()
		if model.phase=="ended":
			return {"winner":-1 if model.result.winner==-1 else (0 if model.result.winner==player_index else 1)}
	return {"error":"timeout"}

func tally(rows: Array) -> Dictionary:
	var counts = {"wins":0,"losses":0,"draws":0,"timeouts":0}
	for row in rows:
		if row.has("error"): counts.timeouts += 1
		elif row.winner==0: counts.wins += 1
		elif row.winner==1: counts.losses += 1
		else: counts.draws += 1
	counts["games"] = rows.size()
	counts["win_rate"] = snappedf(float(counts.wins)/maxf(1,rows.size()),.001)
	return counts

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): report_path = arg.trim_prefix("--report=")
		if arg=="--compare": compare = true
		if arg=="--levels": with_levels = true
	var state = root.get_node("GameState")
	if report_path.is_empty() or FileAccess.file_exists(report_path) or not state.save_path.contains("qa_") or OS.get_environment("GALUMU_MEMORY_BOUND")=="":
		quit(2)
		return
	var report = {"scope":"scripted player (0.50 s observation, always spurring) vs delayed AI; rule simulation, not human play or a win-rate estimate for people"}
	if compare:
		report["normal"] = {}
		for label in ["legacy","current"]:
			var rows: Array = []
			for strategy in STRATEGIES:
				for case_index in range(12):
					var brain = Legacy.new() if label=="legacy" else Brain.new()
					rows.append(simulate(brain,strategy,1,701+case_index%6,case_index/6))
			var counts = tally(rows)
			report.normal[label] = counts
			print("BENCH092 normal %s %s" % [label,JSON.stringify(counts)])
	if with_levels:
		var Campaign = load("res://scripts/core/campaign.gd")
		var Catalogue = load("res://scripts/core/catalogue.gd")
		var items = Catalogue.load_items()
		report["levels"] = []
		for level in Campaign.levels(items):
			var n = int(level.number)
			if n!=1 and n%5!=0:
				continue
			var kit = Campaign.reference_kit(items,n)
			var rows: Array = []
			for strategy in ["flank","adaptive"]:
				for case_index in range(2):
					var brain = Brain.new()
					brain.configure(level.ai)
					rows.append(simulate(brain,strategy,1,901+case_index,case_index%2,kit,Catalogue.stats(items,level.equipment),str(level.mode)))
			var counts = tally(rows)
			counts["level"] = n
			counts["archetype"] = str(level.archetype)
			counts["skill"] = float(level.ai.skill)
			counts["awareness"] = float(level.ai.awareness)
			report.levels.append(counts)
			print("BENCH092 level %d %s %.2f" % [n,str(level.archetype),float(counts.win_rate)])
	var file = FileAccess.open(report_path,FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	file.close()
	print("BENCH092_DONE "+report_path)
	quit(0)
