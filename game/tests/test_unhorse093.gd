extends SceneTree
## FEEL-093 rule simulation (no rendering, no input): two production AIs joust
## with chosen kits, first with the pre-FEEL-093 combat table (TUNING_V092),
## then with the current one, on the same seeds. Reports how matches end
## (unhorsing / score / health), unhorse reasons, blocked share, damage and
## the light-vs-heavy balance. Sides alternate every match. 60 Hz steps; the
## protector caps CPU at 25%, so the run stops by itself inside --budget.
## AI play is not player play: tendencies only, not feel.
const Model = preload("res://scripts/core/joust_match.gd")
const Brain = preload("res://scripts/core/opponent_ai.gd")
const Catalogue = preload("res://scripts/core/catalogue.gd")
const DT = 1.0/60.0
const BASE = {"horse":"horse_bay","lance":"eng_lance_long_3","shield":"eng_shield_3","crest":"crest_bend"}
const KITS = {
	"light":{"armor":"eng_armor_0","helmet":"eng_helmet_0"},
	"medium":{"armor":"eng_armor_3","helmet":"eng_helmet_3"},
	"heavy":{"armor":"eng_armor_5","helmet":"eng_helmet_5"}}
const MATCHUPS = [["medium",1,"medium",1,"arena"],["light",1,"heavy",1,"arena"],["heavy",2,"heavy",2,"arena"],["medium",1,"medium",1,"war"]]
var items: Array = []
var report = ""
var results = {}
var labels: Array = ["v092","current"]
var chosen: Array = []

func _initialize() -> void:
	var matches = 24
	var budget = 560.0
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): report = arg.trim_prefix("--report=")
		if arg.begins_with("--matches="): matches = int(arg.trim_prefix("--matches="))
		if arg.begins_with("--budget="): budget = float(arg.trim_prefix("--budget="))
		if arg=="--current-only": labels = ["current"]
		if arg.begins_with("--matchups="):
			chosen = []
			for index in arg.trim_prefix("--matchups=").split(","): chosen.append(int(index))
	if report.is_empty() or FileAccess.file_exists(report) or OS.get_environment("GALUMU_MEMORY_BOUND")=="":
		quit(2)
		return
	items = Catalogue.load_items()
	var started = Time.get_ticks_msec()
	if chosen.is_empty():
		chosen = range(MATCHUPS.size())
	var per = budget/(chosen.size()*labels.size())
	for index in chosen:
		var matchup: Array = MATCHUPS[index]
		var key = "%s/d%d vs %s/d%d %s" % matchup
		results[key] = {}
		for label in labels:
			Model.tuning = Model.TUNING_V092 if label=="v092" else Model.TUNING
			results[key][label] = run_matchup(matchup,matches,per)
			print("UNHORSE093 %s %s %s" % [key,label,JSON.stringify(results[key][label])])
			save()
	Model.tuning = Model.TUNING
	results["seconds"] = snappedf((Time.get_ticks_msec()-started)/1000.0,.1)
	save()
	print("UNHORSE093_DONE "+report)
	quit(0)

func loadout(kit: String) -> Dictionary:
	var equipped = BASE.duplicate()
	equipped.merge(KITS[kit],true)
	return Catalogue.stats(items,equipped)

func save() -> void:
	var file = FileAccess.open(report,FileAccess.WRITE)
	file.store_string(JSON.stringify(results,"  "))
	file.close()

func run_matchup(matchup: Array, matches: int, budget: float) -> Dictionary:
	var started = Time.get_ticks_msec()
	var a = loadout(matchup[0])
	var b = loadout(matchup[2])
	var t = {"played":0,"a_wins":0,"b_wins":0,"draws":0,"unhorsed":0,"passes":0,"ko":{},"zones":{},"glanced":0,"hits":0,"damage":0.0,"reasons":{},"impulses":[],"unsteady":[]}
	for m in range(matches):
		if (Time.get_ticks_msec()-started)/1000.0>budget:
			break
		var a_first = m%2==0
		var model = Model.new(str(matchup[4]),a if a_first else b,b if a_first else a,9300+m)
		var brains = [Brain.new(),Brain.new()]
		var rng = RandomNumberGenerator.new()
		rng.seed = 7900+m
		var difficulty = [int(matchup[1]) if a_first else int(matchup[3]),int(matchup[3]) if a_first else int(matchup[1])]
		var guard = 0
		while model.phase!="ended" and guard<60*120:
			brains[0].update(model,0,difficulty[0],DT,rng)
			brains[1].update(model,1,difficulty[1],DT,rng)
			model.step(DT)
			for event in model.drain_events():
				if str(event.get("type",""))=="hit":
					t.hits += 1
					t.zones[str(event.zone)] = int(t.zones.get(str(event.zone),0))+1
					if bool(event.get("glanced",false)): t.glanced += 1
					t.damage += float(event.get("damage",0.0))
					t.impulses.append(float(event.get("impulse",0.0)))
					# FEEL-094: defender's seat steadiness at the moment of the hit.
					t.unsteady.append(float(event.get("unsteady",0.0)))
					if bool(event.get("ko",false)):
						var reason = str(event.get("ko_reason",""))
						t.ko[reason] = int(t.ko.get(reason,0))+1
			guard += 1
		var ia = 0 if a_first else 1
		var winner = int(model.result.get("winner",-1))
		t.played += 1
		t.passes += int(model.result.get("passes",0))
		var reason = str(model.result.get("reason",""))
		t.reasons[reason] = int(t.reasons.get(reason,0))+1
		if bool(model.fighters[0].ko) or bool(model.fighters[1].ko):
			t.unhorsed += 1
		if winner==-1: t.draws += 1
		elif winner==ia: t.a_wins += 1
		else: t.b_wins += 1
	var played = maxf(1.0,float(t.played))
	var sorted: Array = t.impulses.duplicate()
	sorted.sort()
	var percentile = func(p: float) -> float: return snappedf(float(sorted[clampi(int(p*(sorted.size()-1)),0,sorted.size()-1)]),.1) if not sorted.is_empty() else 0.0
	var wobble: Array = t.unsteady.duplicate()
	wobble.sort()
	var wobble_mean = 0.0
	for value in wobble: wobble_mean += float(value)/maxf(1,wobble.size())
	var wobble_p90 = float(wobble[int(.9*(wobble.size()-1))]) if not wobble.is_empty() else 0.0
	return {"played":t.played,"unhorse_rate":snappedf(t.unhorsed/played,.001),"a_win":snappedf(t.a_wins/played,.001),"b_win":snappedf(t.b_wins/played,.001),
		"draw":snappedf(t.draws/played,.001),"avg_passes":snappedf(t.passes/played,.01),"ko_reasons":t.ko,"decided_by":t.reasons,
		"hit_zones":t.zones,"glance_share":snappedf(float(t.glanced)/maxf(1,t.hits),.001),"damage_per_hit":snappedf(t.damage/maxf(1,t.hits),.1),
		"impulse_p50":percentile.call(.5),"impulse_p90":percentile.call(.9),"impulse_max":percentile.call(1.0),
		"unsteady_at_hit_mean":snappedf(wobble_mean,.001),"unsteady_at_hit_p90":snappedf(wobble_p90,.001)}
