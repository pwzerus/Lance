extends SceneTree
## Paired seeds/equipment/directions. Scripted choices probe tradeoffs, never
## represent a human win rate. No artificial stamina refill or target damage.
const Model=preload("res://scripts/core/joust_match.gd")
const Campaign=preload("res://scripts/core/campaign.gd")
const Catalogue=preload("res://scripts/core/catalogue.gd")
const Brain=preload("res://scripts/core/opponent_ai.gd")
const DT=1.0/120.0
var failures=[]
func _initialize()->void:call_deferred("run")
func trial(stats:Dictionary,ai:Dictionary,mode:String,pace:String,side:int,seed_value:int)->Dictionary:
	var m=Model.new(mode,stats,stats,seed_value)
	var brain=Brain.new();brain.configure(ai)
	var rng=RandomNumberGenerator.new();rng.seed=seed_value+210
	var aim=-.08;var guard=.43;var recovering=false;var hits=[];var minimum_stamina=100.0
	var max_speed=0.0;var boost_seconds=0.0;var max_unsteady=0.0;var steps=0
	for tick in range(120*90):
		var p=m.fighters[side];var enemy=m.fighters[1-side]
		if tick%36==0:
			var target=Model.head_position(enemy)
			aim=asin(clampf((target.y+(-8 if side==0 else 8)-Model.hand_position(p).y)/Model.lance_length(p),-.629,.548))
			var incoming=Model.tip_position(enemy).y
			guard=1.0 if incoming<Model.body_position(p).y-30 else (0.0 if incoming>Model.body_position(p).y+22 else .43)
		var gap=absf(p.x-enemy.x)
		var boost=true
		match pace:
			"late":boost=gap<1900.0
			"recover":
				if p.stamina<35:recovering=true
				elif p.stamina>70:recovering=false
				boost=not recovering
			"coast":boost=false
		m.set_controls(side,aim,.15,boost,DT,guard)
		if m.phase=="charge":
			brain.update(m,1-side,1,DT,rng)
			if boost:boost_seconds+=DT
		m.step(DT);steps=tick+1
		minimum_stamina=minf(minimum_stamina,p.stamina);max_speed=maxf(max_speed,p.speed);max_unsteady=maxf(max_unsteady,p.unsteady)
		for e in m.drain_events():
			if e.type=="hit":
				hits.append({"pass":m.pass_number,"player":e.attacker==side,"zone":e.zone,"glanced":e.glanced,"damage":e.get("damage",0),"impulse":e.impulse,"ko":e.ko,"dead":e.get("dead",false),"speed":p.speed,"stamina":p.stamina,"arm":p.arm,"time":m.time_elapsed})
		if m.phase=="ended":break
	var player=m.fighters[side]
	return {"mode":mode,"pace":pace,"side":side,"seed":seed_value,"ended":m.phase=="ended","seconds":steps*DT,"winner":-1 if m.result.get("winner",-1)==-1 else (0 if m.result.winner==side else 1),"hits":hits,"minimum_stamina":minimum_stamina,"final_stamina":player.stamina,"max_speed":max_speed,"boost_seconds":boost_seconds,"max_unsteady":max_unsteady,"player_score":player.score,"enemy_score":m.fighters[1-side].score}
func run()->void:
	var folder="";var levels=[5,24,40];var seeds=[10611,10619,10631]
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--folder="):folder=arg.trim_prefix("--folder=")
		if arg=="--quick":levels=[24];seeds=[10611]
	if folder.is_empty() or DirAccess.dir_exists_absolute(folder) or not "--test-profile" in OS.get_cmdline_user_args() or OS.get_environment("GALUMU_MEMORY_BOUND")!="1024":quit(2);return
	DirAccess.make_dir_recursive_absolute(folder)
	var items=Catalogue.load_items();var rows=[]
	for level_number in levels:
		var level=Campaign.level(items,level_number);var stats=Catalogue.stats(items,level.equipment)
		for mode in ["arena","war"]:
			for seed_value in seeds:
				for side in [0,1]:
					for pace in ["sustained","late","recover","coast"]:
						var row=trial(stats,level.ai,mode,pace,side,seed_value);row.level=level_number;row.equipment=level.equipment
						rows.append(row)
						if not row.ended:failures.append("Match did not finish: "+str([level_number,mode,side,seed_value,pace]))
				FileAccess.open(folder+"/partial.json",FileAccess.WRITE).store_string(JSON.stringify({"rows":rows,"failures":failures}))
				print("PACING106 ",level_number," ",mode," seed=",seed_value," rows=",rows.size())
				await process_frame
	FileAccess.open(folder+"/report.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"failures":failures,"rows":rows,"scope":"Matched actual catalogue equipment/AI, 120Hz rules, 300ms head/visible-tip observation with fixed +/-8px aim error; no stamina resets. Diagnostic strategy comparison, not human win rates or full rendered Battle."},"\t"))
	quit(0 if failures.is_empty() else 1)
