extends SceneTree
const Campaign=preload("res://scripts/core/campaign.gd")
const Catalogue=preload("res://scripts/core/catalogue.gd")
const Brain=preload("res://scripts/core/opponent_ai.gd")
const Model=preload("res://scripts/core/joust_match.gd")
var failures=[]
func check(ok: bool, message: String) -> void:
	if not ok:failures.append(message)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var path="";var old_campaign="";var old_ai=""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--report="):path=a.trim_prefix("--report=")
		if a.begins_with("--old-campaign="):old_campaign=a.trim_prefix("--old-campaign=")
		if a.begins_with("--old-ai="):old_ai=a.trim_prefix("--old-ai=")
	var state=root.get_node("GameState")
	if path.is_empty() or FileAccess.file_exists(path) or not "qa_" in state.save_path or OS.get_environment("GALUMU_MEMORY_BOUND")=="":quit(2);return
	var items=Catalogue.load_items();var start=Catalogue.stats(items,state.default_profile().equipped)
	var rows=[]
	var compared=false
	if not old_campaign.is_empty() and not old_ai.is_empty():
		var OldCampaign=load(old_campaign);var OldBrain=load(old_ai)
		for n in range(15,81):check(Campaign.level(items,n)==OldCampaign.level(items,n),"Later campaign changed: "+str(n))
		for difficulty in [0,1,2]:
			for n in [0,15,40,80]:
				var a=Brain.new();var b=OldBrain.new()
				if n>0:
					a.configure(Campaign.level(items,n).ai);b.configure(OldCampaign.level(items,n).ai)
				var ma=Model.new("arena",{}, {},100);var mb=Model.new("arena",{}, {},100)
				var ra=RandomNumberGenerator.new();var rb=RandomNumberGenerator.new();ra.seed=432;rb.seed=432
				ma.phase="charge";mb.phase="charge"
				for tick in range(180):
					check(a.update(ma,1,difficulty,1.0/60,ra)==b.update(mb,1,difficulty,1.0/60,rb),"Unrelated AI decisions changed")
					ma.step(1.0/60);mb.step(1.0/60)
				check(ma.fighters==mb.fighters,"Unrelated AI simulation changed")
		compared=true
	for n in range(1,81):
		var level=Campaign.level(items,n)
		for id in level.equipment.values():check(not Catalogue.find(items,str(id)).is_empty(),"Missing level equipment "+str(n))
		check(level.reward_coins==120+12*(n-1)+(300 if n%10==0 else 0),"Reward changed")
		if n<=5:check(float(Catalogue.stats(items,level.equipment).reach)<=float(start.reach),"Starter opponent has first-strike reach")
		if n>=15:check(not level.ai.has("training"),"Onboarding escaped into later campaign")
		if n>1:check(Campaign.training_strength(n)<=Campaign.training_strength(n-1),"Training ramp increased unexpectedly")
	for n in [1,3,5,10,14,15]:
		var level=Campaign.level(items,n);var enemy_stats=Catalogue.stats(items,level.equipment)
		var m=Model.new("arena",start,enemy_stats,100)
		var brain=Brain.new();brain.configure(level.ai)
		var rng=RandomNumberGenerator.new();rng.seed=900
		m.phase="charge";m.fighters[0].x=-3000;m.fighters[1].x=3000
		var earliest=INF;var boosted=false;var head_target=false
		for tick in range(240):
			brain.update(m,1,1,1.0/120,rng)
			if brain.last_observation_time>=0:earliest=minf(earliest,brain.elapsed-brain.last_observation_time)
			boosted=boosted or m.fighters[1].boost
			head_target=head_target or brain.zone=="head"
		check(brain.decision_count>0,"No observation")
		if n<=3:check(not boosted,"Opening opponent sprints")
		if n<=5:
			check(not head_target,"Opening opponent hunts head")
			check(earliest>=.95,"Opening reaction is too quick")
		var aim=brain.target_y;var guard=brain.guard
		m.fighters[0].x=-120;m.fighters[1].x=120
		for tick in range(180):
			m.fighters[0].lean=sin(tick*.3)
			brain.update(m,1,1,1.0/120,rng)
		check(brain.committed and brain.target_y==aim and brain.guard==guard,"Last-moment read/teleport")
		check(m.fighters[1].stats==enemy_stats and m.fighters[1].hp==100,"Training changes health or equipment stats")
		rows.append({"level":n,"earliest_observation":earliest,"boosted":boosted,"head_target":head_target})
	FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"failures":failures,"rows":rows,"legacy_compared":compared},"\t"))
	print("BEGINNER_RULES100 ",failures)
	quit(0 if failures.is_empty() else 1)
