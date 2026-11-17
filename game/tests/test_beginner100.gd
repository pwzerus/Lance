extends SceneTree
## Real starter kit, delayed coarse input. Simulation is not a human win rate.
const Model=preload("res://scripts/core/joust_match.gd")
const Brain=preload("res://scripts/core/opponent_ai.gd")
const Campaign=preload("res://scripts/core/campaign.gd")
const Catalogue=preload("res://scripts/core/catalogue.gd")
var failures=[]
func _initialize() -> void: call_deferred("run")
func simulate(level: Dictionary, player_stats: Dictionary, enemy_stats: Dictionary, seed_value: int, side: int, strategy: String) -> Dictionary:
	var model=Model.new(str(level.mode),player_stats if side==0 else enemy_stats,enemy_stats if side==0 else player_stats,seed_value)
	var brain=Brain.new();brain.configure(level.ai)
	var rng=RandomNumberGenerator.new();rng.seed=seed_value+431
	var aim=-.08;var wait=0.0;var hits=[];var steps=0
	for tick in range(120*100):
		var p=model.fighters[side];var enemy=model.fighters[1-side]
		wait-=1.0/120
		if wait<=0:
			wait=.85
			var target=Model.body_position(enemy).y
			if strategy=="watch_shield" and float(enemy.guard)>.55: target=Model.flank_position(enemy).y
			# A repeatable 10px vertical error, no instantaneous tracking.
			target+=10.0 if seed_value%2==0 else -10.0
			aim=asin(clampf((target-Model.hand_position(p).y)/Model.lance_length(p),-.629,.548))
		model.set_controls(side,aim,0.0,true,1.0/120,.43)
		if model.phase=="charge":brain.update(model,1-side,1,1.0/120,rng)
		model.step(1.0/120);steps+=1
		for event in model.drain_events():
			if event.get("type")=="hit":hits.append({"by_player":int(event.attacker)==side,"zone":event.zone,"ko":event.ko,"damage":event.damage,"pass":model.pass_number,"speed":event.get("speed",0)})
		if model.phase=="ended":
			return {"winner":-1 if model.result.winner==-1 else (0 if model.result.winner==side else 1),"passes":model.pass_number,"hits":hits,"seconds":steps/120.0,"reason":model.result.reason,"side":side,"strategy":strategy,"seed":seed_value}
	return {"error":"timeout"}
func run() -> void:
	var path="";var nums=[1,2,3,5,10,14,15];var cases=4
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--report="):path=a.trim_prefix("--report=")
		if a.begins_with("--cases="):cases=int(a.trim_prefix("--cases="))
		if a.begins_with("--levels="):
			nums=[]
			for n in a.trim_prefix("--levels=").split(","):nums.append(int(n))
	var state=root.get_node("GameState")
	if path.is_empty() or FileAccess.file_exists(path) or not "qa_" in state.save_path or OS.get_environment("GALUMU_MEMORY_BOUND")=="":quit(2);return
	var items=Catalogue.load_items();var starter=state.default_profile().equipped
	var stats=Catalogue.stats(items,starter)
	var report={"scope":"Starter inventory; 850ms aim updates, +/-10px repeatable error, fixed chest guard, no lean, continuous spur. Rule simulation, not human win rates.","starter":starter,"player_stats":stats,"levels":{}}
	for n in nums:
		var level=Campaign.level(items,n);var enemy=Catalogue.stats(items,level.equipment)
		var rows=[];var wins=0;var losses=0;var draws=0;var falls=0
		for strategy in ["body","watch_shield"]:
			for c in range(cases):
				var row=simulate(level,stats,enemy,10001+c,c%2,strategy);rows.append(row)
				if row.has("error"):failures.append("timeout level "+str(n));continue
				if row.winner==0:wins+=1
				elif row.winner==1:
					losses+=1
					if row.reason=="terminal":falls+=1
				else:draws+=1
		var summary={"wins":wins,"losses":losses,"draws":draws,"lost_unhorsed":falls,"games":rows.size()}
		report.levels[str(n)]={"level":level,"enemy_stats":enemy,"summary":summary,"rows":rows}
		FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
		print("BEGINNER100 ",n," ",summary)
	report.passed=failures.is_empty();report.failures=failures
	FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	quit(0 if failures.is_empty() else 1)
