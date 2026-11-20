extends SceneTree
## Paired, bounded campaign diagnostic. Kits come from audit107's legal
## first-clear budget ledger; this is neither a real playthrough nor a human
## win-rate estimate. Production physics runs at 120 Hz without shortcuts.
const Model=preload("res://scripts/core/joust_match.gd")
const Brain=preload("res://scripts/core/opponent_ai.gd")
const Campaign=preload("res://scripts/core/campaign.gd")
const Catalogue=preload("res://scripts/core/catalogue.gd")
var failures=[]
var dt=1.0/120.0
func _initialize()->void:call_deferred("run")
func simulate(level:Dictionary,stats:Dictionary,enemy_stats:Dictionary,seed_value:int,side:int,strategy:String,fixed_guard:bool)->Dictionary:
	var m=Model.new(level.mode,stats if side==0 else enemy_stats,enemy_stats if side==0 else stats,seed_value)
	var brain=Brain.new();brain.configure(level.ai)
	var rng=RandomNumberGenerator.new();rng.seed=seed_value+431
	var aim=-.08;var guard=.43;var hits=[];var lines=[];var observations=[]
	var shown="";var committed_line="";var pass_id=-1;var min_age=INF
	var aim_rate=0.0;var guard_rate=0.0;var input_clock=0.0
	for tick in range(120*90):
		var p=m.fighters[side];var enemy=m.fighters[1-side]
		if pass_id!=m.pass_number:
			pass_id=m.pass_number;shown="";committed_line="";observations.clear();input_clock=0.0
		observations.append({"time":m.time_elapsed,"head":Model.head_position(enemy).y,"body":Model.body_position(enemy).y,"flank":Model.flank_position(enemy).y,"guard":enemy.guard,"shield":Model.shield_position(enemy).y,"tip":Model.tip_position(enemy).y})
		while observations.size()>1 and float(observations[1].time)<=m.time_elapsed-.25:observations.pop_front()
		input_clock-=dt
		if input_clock<=0 and m.time_elapsed-float(observations[0].time)>=.25:
			input_clock=.6
			var seen:Dictionary=observations[0]
			var target=float(seen.head)
			if strategy in ["opening","brace","forward","continuous","reserve","coast","reserve_forward","coast_forward","continuous_forward"] and float(seen.guard)>.55:target=float(seen.flank)
			elif strategy=="body":target=float(seen.body)
			elif strategy=="shield_pressure":target=float(seen.shield)
			var error=-8.0 if seed_value%2==0 else 8.0
			aim=asin(clampf((target+error-Model.hand_position(p).y)/Model.lance_length(p),-.629,.548))
			var incoming=float(seen.tip)
			guard=1.0 if incoming<Model.body_position(p).y-30 else (0.0 if incoming>Model.body_position(p).y+22 else .43)
			if fixed_guard:guard=.43
		var gap=absf(p.x-enemy.x)
		var full_forward=strategy=="forward" or strategy.ends_with("_forward")
		var leaning=-1.0 if strategy=="backlean" else ((1.0 if full_forward else .55) if (strategy=="brace" or full_forward) and gap<1600 else 0.0)
		var urging=strategy.begins_with("continuous") or gap<3000
		if strategy.begins_with("reserve"):urging=gap<1500
		elif strategy.begins_with("coast"):urging=gap>1500
		m.set_controls(side,aim,leaning,urging,dt,guard)
		if m.phase=="charge":
			var before=Vector2(enemy.aim,enemy.guard)
			brain.update(m,1-side,1,dt,rng)
			aim_rate=maxf(aim_rate,absf(enemy.aim-before.x)/dt);guard_rate=maxf(guard_rate,absf(enemy.guard-before.y)/dt)
			if brain.last_observation_time>=0:
				min_age=minf(min_age,brain.elapsed-brain.last_observation_time)
				if shown!=brain.zone:
					var remaining=maxf(0,(absf(p.x-enemy.x)-Model.lance_length(enemy)-40)/maxf(100,enemy.speed+float(brain.last_seen.get("speed",210))))
					lines.append({"pass":pass_id,"zone":brain.zone,"time":m.time_elapsed,"estimated_lead":remaining,"committed":brain.committed});shown=brain.zone
			if brain.committed:
				if committed_line.is_empty():committed_line=brain.zone
				if brain.zone!=committed_line:failures.append("committed line changed: "+str([level.number,seed_value,side,pass_id]))
		m.step(dt)
		for event in m.drain_events():
			if event.type=="hit":
				var e=event.duplicate(true)
				hits.append({"player":e.attacker==side,"pass":pass_id,"time":m.time_elapsed,"zone":e.zone,"glanced":e.glanced,"impulse":e.impulse,"damage":e.damage,"ko":e.ko,"dead":e.dead,"reason":e.get("ko_reason",""),"player_speed":p.speed,"enemy_speed":enemy.speed,"player_stamina":p.stamina,"player_balance":p.balance,"player_arm":p.arm})
		if m.phase=="ended":
			return {"ended":true,"winner":-1 if m.result.winner==-1 else (0 if m.result.winner==side else 1),"result":m.result,"seconds":m.time_elapsed,"strategy":strategy,"seed":seed_value,"side":side,"hits":hits,"lines":lines,"minimum_observation_age":min_age,"max_aim_rate":aim_rate,"max_guard_rate":guard_rate}
	failures.append("timeout: "+str([level.number,seed_value,side,strategy]))
	return {"ended":false,"winner":-1,"strategy":strategy,"seed":seed_value,"side":side,"hits":hits,"lines":lines}
func run()->void:
	var path="";var audit_path="";var kit="light";var nums=[6,9,10,11,20,21,24,30,31,40,41,50,60,70,80]
	var cases=1;var seed_base=10701;var fixed_ai=0;var fixed_gear=0;var fixed_guard=false;var strategies=["opening","head"];var pace_override=-1.0;var horse_override=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):path=arg.trim_prefix("--report=")
		if arg.begins_with("--audit="):audit_path=arg.trim_prefix("--audit=")
		if arg.begins_with("--kit="):kit=arg.trim_prefix("--kit=")
		if arg.begins_with("--cases="):cases=clampi(int(arg.trim_prefix("--cases=")),1,8)
		if arg.begins_with("--seed-base="):seed_base=int(arg.trim_prefix("--seed-base="))
		if arg.begins_with("--fixed-ai="):fixed_ai=int(arg.trim_prefix("--fixed-ai="))
		if arg.begins_with("--fixed-gear="):fixed_gear=int(arg.trim_prefix("--fixed-gear="))
		if arg.begins_with("--pace-ease="):pace_override=clampf(float(arg.trim_prefix("--pace-ease=")),0,1)
		if arg.begins_with("--horse="):horse_override=arg.trim_prefix("--horse=")
		if arg=="--fixed-guard":fixed_guard=true
		if arg.begins_with("--strategies="):strategies=Array(arg.trim_prefix("--strategies=").split(","))
		if arg.begins_with("--levels="):
			nums=[]
			for n in arg.trim_prefix("--levels=").split(","):nums.append(int(n))
	var state=root.get_node("GameState")
	if path.is_empty() or FileAccess.file_exists(path) or not FileAccess.file_exists(audit_path) or not "qa_" in state.save_path or OS.get_environment("GALUMU_MEMORY_BOUND").is_empty():quit(2);return
	var audit=JSON.parse_string(FileAccess.get_file_as_string(audit_path))
	if not audit is Dictionary or not audit.get("passed",false) or kit not in ["light","heavy","early_light","early_heavy","starter"] or fixed_ai<0 or fixed_ai>80 or fixed_gear<0 or fixed_gear>80:quit(2);return
	for n in nums:
		if n<1 or n>80:quit(2);return
	for strategy in strategies:
		if strategy not in ["opening","head","body","shield_pressure","brace","forward","backlean","continuous","reserve","coast","reserve_forward","coast_forward","continuous_forward"]:quit(2);return
	if not horse_override.is_empty() and Catalogue.find(state.items,horse_override).get("slot","")!="horse":quit(2);return
	var report={"scope":"120Hz rule simulation; each seed played on BOTH sides; 250ms visible-pose delay plus 600ms command cadence, +/-8px aim error. Default no lean/spur inside 3000; brace=.55 or forward=1 inside 1600, backlean=-1 throughout, continuous=spur throughout. Legal-budget snapshots assume preceding first clears, not actual earned wins or real purchases. No human or visual acceptance.","kit":kit,"fixed_ai":fixed_ai,"fixed_gear":fixed_gear,"fixed_guard":fixed_guard,"pace_override":pace_override,"levels":{},"failures":failures}
	report.horse_override=horse_override
	report.scope+=" Reserve urges inside 1500; coast urges outside 1500 then releases. Suffix _forward combines that throttle with full forward lean inside 1600. Any horse/AI/pace overrides are explicit counterfactuals."
	for n in nums:
		var level=Campaign.level(state.items,n).duplicate(true)
		if fixed_ai>0:level.ai=Campaign.level(state.items,fixed_ai).ai.duplicate(true)
		if pace_override>=0:level.ai.pressure_ease=pace_override
		if fixed_gear>0:level.equipment=Campaign.level(state.items,fixed_gear).equipment.duplicate(true)
		var equipment=state.default_profile().equipped if kit=="starter" else audit.rows[n-1].budget_kits[kit].equipment
		equipment=equipment.duplicate()
		if not horse_override.is_empty():equipment.horse=horse_override
		var stats=Catalogue.stats(state.items,equipment);var enemy_stats=Catalogue.stats(state.items,level.equipment)
		var rows=[];var summary={"wins":0,"losses":0,"draws":0,"timeouts":0}
		for strategy in strategies:
			for c in range(cases):
				for side in range(2):
					var row=simulate(level,stats,enemy_stats,seed_base+c,side,strategy,fixed_guard);rows.append(row)
					if not row.ended:summary.timeouts+=1
					elif row.winner==0:summary.wins+=1
					elif row.winner==1:summary.losses+=1
					else:summary.draws+=1
					report.levels[str(n)]={"level":level,"equipment":equipment,"player_stats":stats,"enemy_stats":enemy_stats,"summary":summary,"rows":rows}
					FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
		print("CAMPAIGN_PROBE107 ",n," ",summary)
	report.complete=true;report.passed=failures.is_empty()
	FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	quit(0 if failures.is_empty() else 1)
