extends SceneTree
## EQUIP-066 rule simulation (no rendering, no input): two AI riders joust
## each other with chosen loadouts. Sides alternate every match so lane/side
## bias cancels. This is rule-simulation evidence only: AI play is not player
## play, and win rates show tendencies, not feel.
##
## The protector caps CPU at 25%, so one match costs seconds: the test steps at
## 60 Hz (both baseline and tuned runs use the same step), stops by itself
## inside --budget seconds and rewrites the report after every match, so a
## run always leaves evidence.
##
## --report=<new .json path> --only=<matchup index> [--matches=N] [--budget=S]
const Model = preload("res://scripts/core/joust_match.gd")
const Brain = preload("res://scripts/core/opponent_ai.gd")
const Catalogue = preload("res://scripts/core/catalogue.gd")
const Condition = preload("res://scripts/core/horse_condition.gd")
const DT = 1.0/60.0

const BASE = {"horse":"horse_bay","lance":"eng_lance_long_3","shield":"eng_shield_3","crest":"crest_bend"}
const KITS = {
	"light":{"armor":"eng_armor_0","helmet":"eng_helmet_0"},
	"medium":{"armor":"eng_armor_3","helmet":"eng_helmet_3"},
	"heavy":{"armor":"eng_armor_5","helmet":"eng_helmet_5"}}
# [kit A, difficulty A, kit B, difficulty B]
const MATCHUPS = [
	["heavy",2,"heavy",2],
	["light",2,"heavy",2],
	["medium",2,"heavy",2],
	["light",2,"medium",2],
	["light",2,"heavy",1],
	["light",1,"heavy",2]]

var items: Array = []
var report = ""
var results = {}

func _initialize() -> void:
	var matches = 200
	var only = 1
	var budget = 540.0
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): report = arg.trim_prefix("--report=")
		if arg.begins_with("--matches="): matches = int(arg.trim_prefix("--matches="))
		if arg.begins_with("--only="): only = int(arg.trim_prefix("--only="))
		if arg.begins_with("--budget="): budget = float(arg.trim_prefix("--budget="))
	if report.is_empty() or FileAccess.file_exists(report) or only<0 or only>=MATCHUPS.size():
		printerr("BALANCE066 needs a new --report path and a valid --only index")
		quit(2)
		return
	items = Catalogue.load_items()
	results = {"step_hz":60,"kits":{},"matchup":{}}
	for kit in KITS:
		var stats = loadout(kit)
		results.kits[kit] = {"armor":stats.get("armor"),"helmet":stats.get("helmet"),
			"load_kg":snappedf(Condition.load_kg(stats),.1),"capacity_kg":snappedf(Condition.capacity_kg(stats),.1),
			"worn_kg":snappedf(Condition.worn_kg(stats),.1)}
	run_matchup(MATCHUPS[only],matches,budget)
	print("BALANCE066 "+JSON.stringify(results.matchup))
	quit(0)

func loadout(kit: String) -> Dictionary:
	var equipped = BASE.duplicate()
	equipped.merge(KITS[kit],true)
	return Catalogue.stats(items,equipped)

func save() -> void:
	var file = FileAccess.open(report,FileAccess.WRITE)
	file.store_string(JSON.stringify(results,"  "))
	file.close()

func run_matchup(matchup: Array, matches: int, budget: float) -> void:
	var started = Time.get_ticks_msec()
	var a = loadout(matchup[0])
	var b = loadout(matchup[2])
	var tally = {"played":0,"a_wins":0,"b_wins":0,"draws":0,"passes":0,"ko":{},"hits":{"a":{},"b":{}},
		"damage":{"a":0.0,"b":0.0},"stamina_end":{"a":0.0,"b":0.0},"hp_margin":0.0,"score":{"a":0.0,"b":0.0},"arm_end":{"a":0.0,"b":0.0},"reasons":{}}
	for m in range(matches):
		if (Time.get_ticks_msec()-started)/1000.0>budget:
			break
		var a_first = m%2==0
		var model = Model.new("arena",a if a_first else b,b if a_first else a,9100+m)
		var brains = [Brain.new(),Brain.new()]
		var rng = RandomNumberGenerator.new()
		rng.seed = 7700+m
		var difficulty = [int(matchup[1]) if a_first else int(matchup[3]),int(matchup[3]) if a_first else int(matchup[1])]
		var guard = 0
		while model.phase!="ended" and guard<60*120:
			brains[0].update(model,0,difficulty[0],DT,rng)
			brains[1].update(model,1,difficulty[1],DT,rng)
			model.step(DT)
			for event in model.drain_events():
				if str(event.get("type",""))=="hit":
					var side = "a" if (int(event.attacker)==0)==a_first else "b"
					tally.hits[side][str(event.zone)] = int(tally.hits[side].get(str(event.zone),0))+1
					tally.damage[side] += float(event.get("damage",0.0))
					if bool(event.get("ko",false)):
						var reason = side+":"+str(event.get("ko_reason",""))
						tally.ko[reason] = int(tally.ko.get(reason,0))+1
			guard += 1
		var winner = int(model.result.get("winner",-1))
		var ia = 0 if a_first else 1
		tally.played += 1
		tally.passes += int(model.result.get("passes",0))
		tally.stamina_end.a += float(model.fighters[ia].stamina)
		tally.stamina_end.b += float(model.fighters[1-ia].stamina)
		tally.hp_margin += absf(float(model.fighters[0].hp)-float(model.fighters[1].hp))
		tally.score.a += float(model.fighters[ia].get("score",0))
		tally.score.b += float(model.fighters[1-ia].get("score",0))
		tally.arm_end.a += float(model.fighters[ia].get("arm",100.0))
		tally.arm_end.b += float(model.fighters[1-ia].get("arm",100.0))
		var reason = str(model.result.get("reason",""))
		tally.reasons[reason] = int(tally.reasons.get(reason,0))+1
		if winner==-1:
			tally.draws += 1
		elif winner==ia:
			tally.a_wins += 1
		else:
			tally.b_wins += 1
		var played = float(tally.played)
		results.matchup = {"a":"%s/d%d"%[matchup[0],matchup[1]],"b":"%s/d%d"%[matchup[2],matchup[3]],
			"played":tally.played,"a_win":snappedf(tally.a_wins/played,.001),"b_win":snappedf(tally.b_wins/played,.001),
			"draw":snappedf(tally.draws/played,.001),"avg_passes":snappedf(tally.passes/played,.01),
			"avg_hp_margin":snappedf(tally.hp_margin/played,.1),"ko":tally.ko,"hits":tally.hits,
			"damage_per_match":{"a":snappedf(tally.damage.a/played,.1),"b":snappedf(tally.damage.b/played,.1)},
			"stamina_end":{"a":snappedf(tally.stamina_end.a/played,.1),"b":snappedf(tally.stamina_end.b/played,.1)},
			"score_per_match":{"a":snappedf(tally.score.a/played,.01),"b":snappedf(tally.score.b/played,.01)},
			"arm_end":{"a":snappedf(tally.arm_end.a/played,.1),"b":snappedf(tally.arm_end.b/played,.1)},
			"decided_by":tally.reasons,
			"seconds":snappedf((Time.get_ticks_msec()-started)/1000.0,.1)}
		save()
