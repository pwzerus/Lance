extends SceneTree
## FEEL-094 follow-up: why did the scripted player's win rate on levels 1/10
## drop from 4/4 to 2/4? Replays the LEVEL-092 level bench (same scripted
## player, same kits, seeds 901+) with more seeds under four rule sets:
##   v092_off  pre-FEEL-093 tuning, FEEL-094 seat model off
##   v092_on   pre-FEEL-093 tuning, seat model on
##   cur_off   current tuning, seat model off
##   cur_on    current tuning, seat model on (the shipped rules)
## Cases 0/1 per strategy are exactly the original bench games.
## --levels=1,5,10  --cases=10  --report=path   (QA profile, memory bound)
## Writes only to --report. Rule simulation, not human play.
const Model = preload("res://scripts/core/joust_match.gd")
const Brain = preload("res://scripts/core/opponent_ai.gd")
const CONFIGS = ["v092_off","v092_on","cur_off","cur_on"]
var report_path = ""
var level_filter: Array = [1,5,10,15,20]
var cases = 10
var configs: Array = CONFIGS
var shield_line = "mixed"

func _initialize() -> void:
	call_deferred("run")

func simulate(brain, strategy: String, seed_value: int, player_index: int, player_stats: Dictionary, enemy_stats: Dictionary, mode: String) -> Dictionary:
	var stats_a = player_stats if player_index==0 else enemy_stats
	var stats_b = enemy_stats if player_index==0 else player_stats
	var model = Model.new(mode,stats_a,stats_b,seed_value)
	var rng = RandomNumberGenerator.new()
	rng.seed = seed_value+431
	var observation = 0.0
	var aim = -.08
	var guard = 0.0
	var dt = 1.0/120
	var taken: Array = []
	var landed: Array = []
	var peak = {"player":0.0,"enemy":0.0}
	var unsteady_sum = {"player":0.0,"enemy":0.0}
	var charge_ticks = 0
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
			brain.update(model,1-player_index,1,dt,rng)
			charge_ticks += 1
			for key in ["player","enemy"]:
				var fighter = player if key=="player" else enemy
				peak[key] = maxf(peak[key],float(fighter.unsteady))
				unsteady_sum[key] += float(fighter.unsteady)
		model.step(dt)
		for event in model.drain_events():
			if not event.has("zone"):
				continue
			var row = {"zone":str(event.zone),"impulse":snappedf(float(event.get("impulse",0.0)),.1),"unsteady":snappedf(float(event.get("unsteady",0.0)),.01),
				"ko":bool(event.get("ko",false)),"ko_reason":str(event.get("ko_reason","")),"glanced":bool(event.get("glanced",false)),"points":int(event.get("points",0)),"pass":model.pass_number}
			if int(event.defender)==player_index: taken.append(row)
			else: landed.append(row)
		if model.phase=="ended":
			var winner = -1 if model.result.winner==-1 else (0 if model.result.winner==player_index else 1)
			var scores = [int(model.result.player_score),int(model.result.enemy_score)]
			return {"winner":winner,"reason":str(model.result.reason),"passes":int(model.result.passes),
				"player_score":scores[player_index],"enemy_score":scores[1-player_index],
				"taken":taken,"landed":landed,
				"player_unsteady_peak":snappedf(peak.player,.01),"enemy_unsteady_peak":snappedf(peak.enemy,.01),
				"player_unsteady_mean":snappedf(unsteady_sum.player/maxf(1,charge_ticks),.001),"enemy_unsteady_mean":snappedf(unsteady_sum.enemy/maxf(1,charge_ticks),.001)}
	return {"error":"timeout"}

func save_report(report: Dictionary) -> void:
	var file = FileAccess.open(report_path,FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	file.close()

func summarize(rows: Array) -> Dictionary:
	var out = {"games":rows.size(),"wins":0,"losses":0,"draws":0,"timeouts":0,"lost_unhorsed":0,"lost_score":0,"won_unhorsed":0,"won_score":0,
		"player_hit_unsteady_mean":0.0,"player_unsteady_mean":0.0,"enemy_unsteady_mean":0.0}
	var hit_unsteady: Array = []
	for row in rows:
		if row.has("error"):
			out.timeouts += 1
			continue
		out.player_unsteady_mean += float(row.player_unsteady_mean)/rows.size()
		out.enemy_unsteady_mean += float(row.enemy_unsteady_mean)/rows.size()
		for hit in row.taken: hit_unsteady.append(float(hit.unsteady))
		var by_fall = str(row.reason)=="terminal"
		if row.winner==0:
			out.wins += 1
			out["won_unhorsed" if by_fall else "won_score"] += 1
		elif row.winner==1:
			out.losses += 1
			out["lost_unhorsed" if by_fall else "lost_score"] += 1
		else:
			out.draws += 1
	out.win_rate = snappedf(float(out.wins)/maxf(1,rows.size()),.001)
	var total = 0.0
	for value in hit_unsteady: total += value
	out.player_hit_unsteady_mean = snappedf(total/maxf(1,hit_unsteady.size()),.001)
	out.player_unsteady_mean = snappedf(out.player_unsteady_mean,.001)
	out.enemy_unsteady_mean = snappedf(out.enemy_unsteady_mean,.001)
	return out

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): report_path = arg.trim_prefix("--report=")
		if arg.begins_with("--cases="): cases = maxi(1,int(arg.trim_prefix("--cases=")))
		if arg.begins_with("--shield-line="): shield_line=arg.trim_prefix("--shield-line=")
		if arg.begins_with("--configs="): configs = Array(arg.trim_prefix("--configs=").split(","))
		if arg.begins_with("--levels="):
			level_filter = []
			for part in arg.trim_prefix("--levels=").split(","): level_filter.append(int(part))
	var state = root.get_node("GameState")
	if report_path.is_empty() or FileAccess.file_exists(report_path) or not state.save_path.contains("qa_") or OS.get_environment("GALUMU_MEMORY_BOUND")=="":
		quit(2)
		return
	var Campaign = load("res://scripts/core/campaign.gd")
	var Catalogue = load("res://scripts/core/catalogue.gd")
	var items = Catalogue.load_items()
	var report = {"scope":"LEVEL-092 scripted player vs level AI, %d seeds x 2 strategies per level and rule set; rule simulation, not human play" % cases,"levels":{}}
	for level in Campaign.levels(items):
		var n = int(level.number)
		if not level_filter.has(n):
			continue
		var kit = Campaign.reference_kit(items,n,shield_line)
		var enemy_kit = Catalogue.stats(items,level.equipment)
		var entry = {"archetype":str(level.archetype),"skill":float(level.ai.skill),"awareness":float(level.ai.awareness),"mode":str(level.mode),"shield_line":shield_line,"configs":{}}
		for config in configs:
			Model.tuning = Model.TUNING_V092 if config.begins_with("v092") else Model.TUNING
			Model.unsteady_scale = 1.0 if config.contains("_on") else 0.0
			# LEVEL-096: "cur_on_legacyai" replays the shipped rules with the
			# pre-FEEL-095 AI (no steady tracking) for an A/B on the same seeds.
			Brain.steady_tracking = not config.ends_with("_legacyai")
			var rows: Array = []
			for strategy in ["flank","adaptive"]:
				for case_index in range(cases):
					var brain = Brain.new()
					brain.configure(level.ai)
					var row = simulate(brain,strategy,901+case_index,case_index%2,kit,enemy_kit,str(level.mode))
					row["strategy"] = strategy
					row["seed"] = 901+case_index
					rows.append(row)
			var summary = summarize(rows)
			var original: Array = []
			for row in rows:
				if int(row.seed)<=902: original.append(row.get("winner",-2))
			summary["original_four"] = original
			entry.configs[config] = {"summary":summary,"games":rows}
			print("DIAG094 level %d %s %s" % [n,config,JSON.stringify(summary)])
		report.levels[str(n)] = entry
		# Saved after every level so a protector timeout keeps finished levels.
		save_report(report)
	Model.tuning = Model.TUNING
	Model.unsteady_scale = 1.0
	Brain.steady_tracking = true
	report["complete"] = true
	save_report(report)
	print("DIAG094_DONE "+report_path)
	quit(0)
