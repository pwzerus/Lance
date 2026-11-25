extends "test_rules098.gd"
## Fixed-contact material comparison; no claim about human difficulty.
func _initialize() -> void:
	var folder="";var baseline=false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--folder="):folder=arg.trim_prefix("--folder=")
		if arg=="--baseline":baseline=true
	if folder.is_empty() or DirAccess.dir_exists_absolute(folder) or OS.get_environment("GALUMU_MEMORY_BOUND")=="":quit(2);return
	DirAccess.make_dir_recursive_absolute(folder);items=Catalogue.load_items()
	var records=[]
	for region in ["eng","fr","de","it"]:
		for quality in range(6):
			var id=region+"_shield_"+str(quality)
			var stats=kit(3,id)
			for pace in [.5,.75,1.0]:
				for eccentricity in [0.0,1.0]:
					var m=prepare(3,id,pace)
					var sequence=[]
					for index in range(20):
						# Restore the mount/rider between material strikes, retaining only
						# the shield. This is NOT a playable multi-pass win-rate test.
						var remaining=float(m.fighters[1].shield)
						m=prepare(3,id,pace);m.fighters[1].shield=remaining
						var event=contact(m,"shield",pace,eccentricity,0,1)
						sequence.append({"remaining":m.fighters[1].shield,"damage":event.damage,"impulse":event.impulse,"broke":event.shield_broke,"unseated":m.fighters[1].unseated})
						if event.shield_broke:break
					var row={"id":id,"class":stats.shield_class,"capacity":stats.shield_capacity,"pace":pace,"eccentricity":eccentricity,"hits_to_break":sequence.size(),"sequence":sequence}
					records.append(row)
					if not baseline and stats.shield_class=="light" and pace==1.0 and eccentricity==0:
						check(sequence.size()<=(1 if quality==0 else 2),"Light shield cannot repeatedly absorb full square charges: "+id)
					if not baseline and stats.shield_class=="heavy" and pace==1.0 and eccentricity==0:
						check(sequence.size()>=3 and sequence.size()<=4,"Heavy construction resists more material strikes, but is finite: "+id)
			if quality%2==0:
				var heavy=kit(3,region+"_shield_"+str(quality+1))
				check(stats.shield_kg<heavy.shield_kg and stats.shield_speed>heavy.shield_speed,"Light shield keeps load and speed advantage: "+id)
	if not baseline:
		var legacy=kit(3,"shield_basic")
		check(legacy.shield_capacity==kit(3,"eng_shield_0").shield_capacity,"Saved starter shield follows the same light construction")
		var outcome=contact(prepare(3,"eng_shield_0"),"shield",1,0,0,1)
		var wording=load("res://scripts/ui/combat_report.gd").summarize([outcome])
		check(outcome.shield_broke and wording.contains("击破") and not wording.contains("挡住"),"Unhorsing summary does not claim a broken shield held intact")
		var report_script=load("res://scripts/ui/combat_report.gd")
		var other=outcome.duplicate(true);other.defender=0
		check(report_script.summarize([outcome,other]).contains("双方盾牌均被击破"),"Both broken shields remain visible before any physical release")
		other.ko=true;other.unseated=true;other.ko_reason="impact"
		check(report_script.summarize([outcome,other]).contains("落马"),"A resolved fall takes precedence over the nonterminal shield summary")
	FileAccess.open(folder+"/report.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"failures":failures,"records":records,"baseline":baseline,"scope":"144 fixed-contact material sequences. Rider restored between blows; not actual rounds, AI win rate or player acceptance."},"\t"))
	print("SHIELD113 ",failures);quit(0 if failures.is_empty() else 1)
