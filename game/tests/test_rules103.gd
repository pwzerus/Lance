extends "test_beginner_rules100.gd"
## Campaign boundary, delayed decisions, finite motors and staged line changes.
func run()->void:
	var path="";var old_campaign="";var old_ai=""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--report="):path=a.trim_prefix("--report=")
		if a.begins_with("--old-campaign="):old_campaign=a.trim_prefix("--old-campaign=")
		if a.begins_with("--old-ai="):old_ai=a.trim_prefix("--old-ai=")
	if path.is_empty() or FileAccess.file_exists(path) or old_campaign.is_empty() or old_ai.is_empty() or not "qa_" in root.get_node("GameState").save_path or OS.get_environment("GALUMU_MEMORY_BOUND")=="":quit(2);return
	var OldCampaign=load(old_campaign);var OldBrain=load(old_ai)
	var items=Catalogue.load_items();var stats=Campaign.reference_kit(items,24,"light");var rows=[]
	for n in range(1,81):
		var level=Campaign.level(items,n);var old=OldCampaign.level(items,n)
		if n<18 or n>=40:check(level==old,"Unrelated level changed "+str(n))
		for key in ["reward_coins","reward_renown","mode"]:check(level[key]==old[key],"Progress changed "+str(n)+" "+key)
		if n!=24:
			for key in ["archetype","opponent"]:check(level[key]==old[key],"Unrelated identity changed "+str(n))
		else:check(level.archetype=="balanced","Recovery duel must not repeat heavy rider")
		for id in level.equipment.values():check(not Catalogue.find(items,id).is_empty(),"Invalid equipment "+str(n))
	for n in [0,1,5,12,17,40,80]:
		var a=Brain.new();var b=OldBrain.new()
		if n>0:a.configure(Campaign.level(items,n).ai);b.configure(OldCampaign.level(items,n).ai)
		var ma=Model.new("arena",stats,stats,103);var mb=Model.new("arena",stats,stats,103)
		var ra=RandomNumberGenerator.new();var rb=RandomNumberGenerator.new();ra.seed=103;rb.seed=103
		ma.phase="charge";mb.phase="charge"
		for tick in range(180):
			check(a.update(ma,1,1,1.0/60,ra)==b.update(mb,1,1,1.0/60,rb),"Unrelated AI changed "+str(n))
			ma.step(1.0/60);mb.step(1.0/60)
		check(ma.fighters==mb.fighters,"Unrelated motion changed "+str(n))
	for n in [20,21,23,24,25,27,28,29,30]:
		var level=Campaign.level(items,n)
		for side in range(2):
			for pass_n in [1,2,3]:
				var m=Model.new("arena",stats,stats,103);m.phase="charge";m.pass_number=pass_n
				var brain=Brain.new();brain.configure(level.ai)
				var rng=RandomNumberGenerator.new();rng.seed=103+pass_n
				var changes=[];var shown="";var locked="";var min_age=INF;var aim_step=0.0;var guard_step=0.0
				for tick in range(1200):
					var f=m.fighters[side];var before=Vector2(f.aim,f.guard)
					brain.update(m,side,1,1.0/60,rng)
					aim_step=maxf(aim_step,absf(f.aim-before.x));guard_step=maxf(guard_step,absf(f.guard-before.y))
					if brain.last_observation_time>=0:
						min_age=minf(min_age,brain.elapsed-brain.last_observation_time)
						if shown!=brain.zone:
							var remaining=maxf(0,(absf(m.fighters[0].x-m.fighters[1].x)-Model.lance_length(f)-40)/maxf(100,f.speed+float(brain.last_seen.get("speed",210))))
							changes.append({"zone":brain.zone,"remaining":remaining});shown=brain.zone
					if brain.committed:
						if locked.is_empty():locked=brain.zone
						check(brain.zone==locked,"Line moved after commitment")
					m.set_controls(1-side,-.68,0,true,1.0/60,1.0 if tick%160<80 else 0.0)
					m.fighters[1-side].acted=true;m.step(1.0/60);m.drain_events()
					if m.phase!="charge" or f.acted:break
				var may_change=n>=21 and pass_n in level.ai.get("lesson_change_passes",[1,2,3])
				check(changes.size()==(2 if may_change else 1),"Wrong lesson line count "+str(n)+"/"+str(pass_n))
				if changes.size()==2:check(changes[1].remaining>=1.79,"Late feint")
				check(min_age>=Brain.curve(Brain.REACTION,float(level.ai.awareness))-.001,"Reads current input")
				check(aim_step<.09 and guard_step<.08,"Weapon teleported")
				rows.append({"level":n,"side":side,"pass":pass_n,"changes":changes,"max_aim_step":aim_step,"max_guard_step":guard_step})
		print("RULES103 ",n)
	FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"failures":failures,"rows":rows,"scope":"54 approaches: staged high/low lessons, actual finite aim/guard, delayed observation, committed line; unchanged outside 18-39, rewards/modes/identities. Not human acceptance."},"\t"))
	print("RULES103 ",failures);quit(0 if failures.is_empty() else 1)
