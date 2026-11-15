extends SceneTree
## FEEL-095 rule simulation (no rendering, no input): production AIs joust on
## the same seeds twice, with OpponentAI.steady_tracking off (FEEL-094
## behaviour) and on. Splits the seat "fidget" each rider builds into its
## sources (lance aim, shield, lean, spur drive) with the same allowance and
## weights as JoustMatch.set_controls, and reports unsteadiness at the moment
## of each hit, unhorse rate, how often the shield/lean targets change and
## whether the riders still hit (zones, glances, points per pass).
## 60 Hz like test_unhorse093. AI play, not player play.
## --report=path  --matches=N  --budget=s  --blocks=veteran_heavy,level70,normal
const Model = preload("res://scripts/core/joust_match.gd")
const Brain = preload("res://scripts/core/opponent_ai.gd")
const Catalogue = preload("res://scripts/core/catalogue.gd")
const Condition = preload("res://scripts/core/horse_condition.gd")
const DT = 1.0/60.0
const BASE = {"horse":"horse_bay","lance":"eng_lance_long_3","shield":"eng_shield_3","crest":"crest_bend"}
const KITS = {"medium":{"armor":"eng_armor_3","helmet":"eng_helmet_3"},"heavy":{"armor":"eng_armor_5","helmet":"eng_helmet_5"}}
## block: kit, difficulty, optional campaign level for the AI profile, share of matches
const BLOCKS = {"veteran_heavy":["heavy",2,0,1.0],"level70":["medium",2,70,.6],"normal":["medium",1,0,.3]}
var items: Array = []
var report = ""
var results = {}

func _initialize() -> void:
	var matches = 20
	var budget = 540.0
	var chosen: Array = ["veteran_heavy","level70","normal"]
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): report = arg.trim_prefix("--report=")
		if arg.begins_with("--matches="): matches = int(arg.trim_prefix("--matches="))
		if arg.begins_with("--budget="): budget = float(arg.trim_prefix("--budget="))
		if arg.begins_with("--blocks="): chosen = Array(arg.trim_prefix("--blocks=").split(","))
	if report.is_empty() or FileAccess.file_exists(report) or OS.get_environment("GALUMU_MEMORY_BOUND")=="":
		quit(2)
		return
	items = Catalogue.load_items()
	var Campaign = load("res://scripts/core/campaign.gd")
	var started = Time.get_ticks_msec()
	var share_total = 0.0
	for key in chosen: share_total += float(BLOCKS[key][3])
	for key in chosen:
		var block: Array = BLOCKS[key]
		var profile = {}
		if int(block[2])>0:
			profile = Campaign.level(items,int(block[2])).ai
		var count = maxi(2,int(round(matches*float(block[3]))))
		var per = budget*float(block[3])/share_total/2.0
		results[key] = {"profile":profile,"kit":block[0],"difficulty":block[1]}
		for steady in [false,true]:
			Brain.steady_tracking = steady
			var label = "steady" if steady else "legacy"
			results[key][label] = run_block(str(block[0]),int(block[1]),profile,count,per)
			print("STEADY095 %s %s %s" % [key,label,JSON.stringify(results[key][label])])
			save()
	Brain.steady_tracking = true
	results["seconds"] = snappedf((Time.get_ticks_msec()-started)/1000.0,.1)
	save()
	print("STEADY095_DONE "+report)
	quit(0)

func save() -> void:
	var file = FileAccess.open(report,FileAccess.WRITE)
	file.store_string(JSON.stringify(results,"  "))
	file.close()

func loadout(kit: String) -> Dictionary:
	var equipped = BASE.duplicate()
	equipped.merge(KITS[kit],true)
	return Catalogue.stats(items,equipped)

func run_block(kit: String, difficulty: int, profile: Dictionary, matches: int, budget: float) -> Dictionary:
	var started = Time.get_ticks_msec()
	var stats = loadout(kit)
	var t = {"played":0,"unhorsed":0,"passes":0,"hits":0,"glanced":0,"points":0,"zones":{},"ko":{},"unsteady":[],
		"fidget":{"aim":0.0,"guard":0.0,"lean":0.0,"drive":0.0},"guard_changes":0,"lean_changes":0,"rider_passes":0,"peak_unsteady":[]}
	for m in range(matches):
		if (Time.get_ticks_msec()-started)/1000.0>budget:
			break
		var model = Model.new("arena",stats,stats,9500+m)
		var brains = [Brain.new(),Brain.new()]
		for brain in brains:
			if not profile.is_empty(): brain.configure(profile)
		var rng = RandomNumberGenerator.new()
		rng.seed = 7950+m
		var pass_peak = [0.0,0.0]
		var last_pass = 1
		var ticks = 0
		while model.phase!="ended" and ticks<60*120:
			var charging = model.phase=="charge"
			for i in range(2):
				var fighter = model.fighters[i]
				var previous = Vector3(float(fighter.aim_rate),float(fighter.guard_rate),float(fighter.lean_velocity))
				var pace = lerpf(.7,1.25,smoothstep(Model.TROT_SPEED,Model.GALLOP_SPEED,float(fighter.speed)))
				var guard_target = float(fighter.guard_target)
				var lean_before = float(brains[i].lean)
				brains[i].update(model,i,difficulty,DT,rng)
				if not charging:
					continue
				var seat = Condition.seat(fighter.stats)
				t.fidget.aim += Model.FIDGET_WEIGHT.aim*maxf(0.0,absf(float(fighter.aim_rate)-previous.x)-Model.FIDGET_FREE.aim*DT)*pace/seat
				t.fidget.guard += Model.FIDGET_WEIGHT.guard*maxf(0.0,absf(float(fighter.guard_rate)-previous.y)-Model.FIDGET_FREE.guard*DT)*pace/seat
				t.fidget.lean += Model.FIDGET_WEIGHT.lean*maxf(0.0,absf(float(fighter.lean_velocity)-previous.z)-Model.FIDGET_FREE.lean*DT)*pace/seat
				if absf(float(fighter.guard_target)-guard_target)>.01: t.guard_changes += 1
				if absf(float(brains[i].lean)-lean_before)>.01: t.lean_changes += 1
				pass_peak[i] = maxf(pass_peak[i],float(fighter.unsteady))
			var drives = [float(model.fighters[0].motion_drive),float(model.fighters[1].motion_drive)]
			model.step(DT)
			if charging:
				for i in range(2):
					t.fidget.drive += Model.FIDGET_WEIGHT.drive*absf(float(model.fighters[i].motion_drive)-drives[i])/Condition.seat(model.fighters[i].stats)
			if model.pass_number!=last_pass or model.phase=="ended":
				for i in range(2): t.peak_unsteady.append(pass_peak[i])
				t.rider_passes += 2
				pass_peak = [0.0,0.0]
				last_pass = model.pass_number
			for event in model.drain_events():
				if str(event.get("type",""))=="hit":
					t.hits += 1
					t.zones[str(event.zone)] = int(t.zones.get(str(event.zone),0))+1
					if bool(event.get("glanced",false)): t.glanced += 1
					t.points += int(event.get("points",0))
					t.unsteady.append(float(event.get("unsteady",0.0)))
					if bool(event.get("ko",false)):
						var reason = str(event.get("ko_reason",""))
						t.ko[reason] = int(t.ko.get(reason,0))+1
			ticks += 1
		t.played += 1
		t.passes += int(model.result.get("passes",0))
		if bool(model.fighters[0].ko) or bool(model.fighters[1].ko):
			t.unhorsed += 1
	var played = maxf(1.0,float(t.played))
	var rider_passes = maxf(1.0,float(t.rider_passes))
	var stat = func(values: Array) -> Array:
		if values.is_empty(): return [0.0,0.0]
		var sorted = values.duplicate()
		sorted.sort()
		var total = 0.0
		for value in sorted: total += float(value)
		return [snappedf(total/sorted.size(),.001),snappedf(float(sorted[int(.9*(sorted.size()-1))]),.001)]
	var at_hit = stat.call(t.unsteady)
	var peak = stat.call(t.peak_unsteady)
	var fidget_total = 0.0
	for key in t.fidget: fidget_total += float(t.fidget[key])
	var fidget_per_pass = {}
	for key in t.fidget: fidget_per_pass[key] = snappedf(float(t.fidget[key])/rider_passes,.01)
	return {"played":t.played,"unhorse_rate":snappedf(t.unhorsed/played,.001),"avg_passes":snappedf(t.passes/played,.01),"ko_reasons":t.ko,
		"unsteady_at_hit_mean":at_hit[0],"unsteady_at_hit_p90":at_hit[1],"pass_peak_unsteady_mean":peak[0],"pass_peak_unsteady_p90":peak[1],
		"fidget_per_rider_pass":fidget_per_pass,"fidget_per_rider_pass_total":snappedf(fidget_total/rider_passes,.01),
		"guard_changes_per_rider_pass":snappedf(t.guard_changes/rider_passes,.01),"lean_changes_per_rider_pass":snappedf(t.lean_changes/rider_passes,.01),
		"hits_per_rider_pass":snappedf(t.hits/rider_passes,.001),"glance_share":snappedf(float(t.glanced)/maxf(1,t.hits),.001),
		"points_per_rider_pass":snappedf(t.points/rider_passes,.001),"hit_zones":t.zones}
