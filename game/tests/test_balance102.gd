extends "test_beginner_rules100.gd"
## Campaign lessons: delayed observations, readable commitments and unchanged
## opening/endgame profiles. Full approach rules, not a human difficulty score.
func run() -> void:
	var folder=""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--report="):folder=a.trim_prefix("--report=")
	var state=root.get_node("GameState")
	if folder.is_empty() or FileAccess.file_exists(folder) or not "qa_" in state.save_path or OS.get_environment("GALUMU_MEMORY_BOUND")=="":quit(2);return
	var items=Catalogue.load_items();var stats=state.player_stats();var rows=[]
	var old_c=load("E:/GALUMU/docs/development/logs/feel102-old-campaign.gd")
	var old_b=load("E:/GALUMU/docs/development/logs/feel102-old-opponent_ai.gd")
	for n in range(1,81):
		if n<=5 or n>40:check(Campaign.level(items,n)==old_c.level(items,n),"Unrelated level changed "+str(n))
	for n in [0,1,3,5,41,80]:
		var a=Brain.new();var b=old_b.new()
		if n>0:a.configure(Campaign.level(items,n).ai);b.configure(old_c.level(items,n).ai)
		var ma=Model.new("arena",stats,stats,102);var mb=Model.new("arena",stats,stats,102)
		var ra=RandomNumberGenerator.new();var rb=RandomNumberGenerator.new();ra.seed=102;rb.seed=102
		ma.phase="charge";mb.phase="charge"
		for tick in range(180):
			check(a.update(ma,1,1,1.0/60,ra)==b.update(mb,1,1,1.0/60,rb),"Unrelated AI changed "+str(n))
			ma.step(1.0/60);mb.step(1.0/60)
	for n in [6,10,11,20,21,30,40]:
		var level=Campaign.level(items,n)
		for side in range(2):
			for pass_n in [1,2,3]:
				var m=Model.new("arena",stats,stats,102)
				m.phase="charge";m.pass_number=pass_n
				var brain=Brain.new();brain.configure(level.ai)
				var rng=RandomNumberGenerator.new();rng.seed=102+pass_n
				var changes=[];var shown="";var locked="";var min_age=INF;var max_aim_step=0.0
				for tick in range(1200):
					var f=m.fighters[side];var before=float(f.aim)
					brain.update(m,side,1,1.0/60,rng)
					max_aim_step=maxf(max_aim_step,absf(float(f.aim)-before))
					if brain.last_observation_time>=0:
						min_age=minf(min_age,brain.elapsed-brain.last_observation_time)
						if shown!=brain.zone:
							changes.append({"zone":brain.zone,"gap":absf(m.fighters[0].x-m.fighters[1].x),"time":m.time_elapsed,"remaining":maxf(0,(absf(m.fighters[0].x-m.fighters[1].x)-Model.lance_length(f)-40)/maxf(100,f.speed+float(brain.last_seen.get("speed",210))))})
							shown=brain.zone
					if brain.committed:
						if locked.is_empty():locked=brain.zone
						check(brain.zone==locked,"Late line changed after commitment")
					# Visible opposing shield moves, but the lesson cannot read it
					# to choose an instant counter. Both weapons keep their motors.
					m.set_controls(1-side,-.68,0,true,1.0/60,1.0 if tick%160<80 else 0.0)
					m.fighters[1-side].acted=true
					m.step(1.0/60);m.drain_events()
					if m.phase!="charge" or f.acted:break
				check(not changes.is_empty(),"Lesson never shown")
				check(max_aim_step<.09,"Lance teleported")
				check(min_age>=Brain.curve(Brain.REACTION,float(level.ai.awareness))+.35*float(level.ai.get("training",0))-.001,"Observation delay bypassed")
				if n<=20:check(changes.size()==1,"Fixed lesson flickered")
				else:
					check(changes.size()<=2,"Feinted more than once")
					if changes.size()==2:check(changes[1].remaining>=1.79,"Feint too late to read")
				rows.append({"level":n,"side":side,"pass":pass_n,"changes":changes,"committed":brain.committed,"max_aim_step":max_aim_step})
		print("LESSON102 completed level ",n)
		FileAccess.open(folder+".partial",FileAccess.WRITE).store_string(JSON.stringify({"failures":failures,"rows":rows}))
	FileAccess.open(folder,FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"failures":failures,"rows":rows,"scope":"42 approach lesson samples, unchanged 1-5/41-80 profiles, delayed input and finite motors. No human difficulty verdict."},"\t"))
	print("BALANCE102 ",failures);quit(0 if failures.is_empty() else 1)
