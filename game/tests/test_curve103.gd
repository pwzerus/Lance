extends SceneTree
## Same delayed player and fixed purchased kit before/after. Records outcomes,
## not human win rates. Every action goes through the finite control motors.
const Model=preload("res://scripts/core/joust_match.gd")
const Campaign=preload("res://scripts/core/campaign.gd")
const Catalogue=preload("res://scripts/core/catalogue.gd")
const Brain=preload("res://scripts/core/opponent_ai.gd")
func _initialize()->void:call_deferred("run")
func run()->void:
	var path="";var nums=[18,20,21,22,23,24,25,26,27,28];var cases=2;var old_campaign="";var strategies=["head","opening"];var fixed_guard=false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--report="):path=a.trim_prefix("--report=")
		if a.begins_with("--cases="):cases=int(a.trim_prefix("--cases="))
		if a.begins_with("--old-campaign="):old_campaign=a.trim_prefix("--old-campaign=")
		if a.begins_with("--strategies="):strategies=Array(a.trim_prefix("--strategies=").split(","))
		if a=="--fixed-guard":fixed_guard=true
		if a.begins_with("--levels="):
			nums=[]
			for value in a.trim_prefix("--levels=").split(","):nums.append(int(value))
	if path.is_empty() or FileAccess.file_exists(path) or not "qa_" in root.get_node("GameState").save_path or OS.get_environment("GALUMU_MEMORY_BOUND")=="":quit(2);return
	var items=Catalogue.load_items();var stats=Campaign.reference_kit(items,24,"light")
	var source=Campaign if old_campaign.is_empty() else load(old_campaign)
	var report={"scope":"Fixed quality-1 English long lance/light shield/grey horse, 600ms aim and visible-tip guard updates, +/-8px, no lean, spur at 3000. Actual level mode and opponents. Both sides, finite controls, no human win-rate claim.","strategies":strategies,"old_campaign":old_campaign,"player_stats":stats,"levels":{},"failures":[]}
	report.fixed_chest_guard=fixed_guard
	if fixed_guard:report.scope+=" Counterfactual: guard remains at chest instead of reading the incoming line."
	for n in nums:
		var level=source.level(items,n);var enemy_stats=Catalogue.stats(items,level.equipment)
		var rows=[];var wins=0;var losses=0;var draws=0
		for strategy in strategies:
			for c in range(cases):
				var side=c%2;var seed_value=10301+c
				var m=Model.new(level.mode,stats if side==0 else enemy_stats,enemy_stats if side==0 else stats,seed_value)
				var brain=Brain.new();brain.configure(level.ai)
				var rng=RandomNumberGenerator.new();rng.seed=seed_value+431
				var aim=-.08;var guard=.43;var hits=[];var lines=[];var shown="";var steps=0
				for tick in range(6000):
					var p=m.fighters[side];var enemy=m.fighters[1-side]
					if tick%36==0:
						var target=Model.head_position(enemy)
						if strategy=="opening" and float(enemy.guard)>.55:target=Model.flank_position(enemy)
						elif strategy=="shield_pressure":target=Model.shield_position(enemy)
						elif strategy=="body":target=Model.body_position(enemy)
						aim=asin(clampf((target.y+(-8 if c%2==0 else 8)-Model.hand_position(p).y)/Model.lance_length(p),-.629,.548))
						var incoming=Model.tip_position(enemy).y
						guard=1.0 if incoming<Model.body_position(p).y-30 else (0.0 if incoming>Model.body_position(p).y+22 else .43)
						if fixed_guard:guard=.43
					m.set_controls(side,aim,0.0,absf(p.x-enemy.x)<3000,1.0/60,guard)
					if m.phase=="charge":
						brain.update(m,1-side,1,1.0/60,rng)
						var line=str(m.pass_number)+":"+brain.zone
						if shown!=line:lines.append({"line":line,"time":m.time_elapsed});shown=line
					m.step(1.0/60);steps+=1
					for e in m.drain_events():
						if e.type=="hit":hits.append({"player":e.attacker==side,"pass":m.pass_number,"zone":e.zone,"glanced":e.glanced,"impulse":e.impulse,"damage":e.damage,"speed":e.get("speed",0),"ko":e.ko,"reason":e.get("ko_reason",""),"dead":e.dead})
					if m.phase=="ended":break
				var ended=m.phase=="ended";var winner=-1 if m.result.get("winner",-1)==-1 else (0 if m.result.winner==side else 1)
				if not ended:report.failures.append("timeout "+str(n)+" "+str(c))
				if winner==0:wins+=1
				elif winner==1:losses+=1
				else:draws+=1
				rows.append({"strategy":strategy,"side":side,"seed":seed_value,"ended":ended,"winner":winner,"seconds":steps/60.0,"hits":hits,"lines":lines})
				report.levels[str(n)]={"level":level,"enemy_stats":enemy_stats,"rows":rows,"wins":wins,"losses":losses,"draws":draws}
				FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
		print("CURVE103 ",n," ",wins,"/",rows.size()," wins; ",draws," draws")
	report.passed=report.failures.is_empty()
	FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	quit(0 if report.passed else 1)
