extends "test_rules098.gd"
## Reproducible damage/seat baseline, fixed legal loadouts and contact geometry.
## Direct contacts isolate rules; battle sweep coverage is recorded separately.
func _initialize() -> void:
	var folder = ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--folder="): folder=arg.trim_prefix("--folder=")
	if folder.is_empty() or DirAccess.dir_exists_absolute(folder) or OS.get_environment("GALUMU_MEMORY_BOUND")=="":
		quit(2); return
	DirAccess.make_dir_recursive_absolute(folder)
	items = Catalogue.load_items()
	var records = []
	for mode in ["arena","war"]:
		for tier in [0,3,5]:
			for pace in [.5,.75,1.0]:
				for zone in ["head","body","flank","shield"]:
					for eccentricity in ([0.0,1.0] if zone=="shield" else [0.0]):
						var shield = "eng_shield_0" if tier==0 else "eng_shield_5"
						var model = prepare(tier,shield,pace); model.mode=mode
						var record = {"mode":mode,"tier":tier,"pace":pace,"zone":zone,"eccentricity":eccentricity,"stats":model.fighters[1].stats.duplicate(true),"hits":[]}
						for number in range(3):
							var event = contact(model,zone,pace,eccentricity,0,1)
							var f: Dictionary = model.fighters[1]
							record.hits.append({"number":number+1,"damage":event.damage,"impulse":event.impulse,"ratio":event.impulse_ratio,"glanced":event.glanced,"shield":f.shield,"hp":f.hp,"balance":f.balance,"ko":f.ko,"reason":event.ko_reason,"dead":f.dead,"unseated":f.get("unseated",null),"consciousness":f.get("consciousness",null),"injury":f.get("injury",null)})
							check(is_finite(float(f.hp)) and f.hp>=0,"Finite nonnegative health")
							check(mode!="arena" or not f.dead,"Arena remains nonfatal")
							if f.ko: break
							# The same attacker receives a fresh lance and support for
							# a repeat controlled blow; defender injury never resets.
							model.fighters[0].broken=false
							model.fighters[0].lance_stability=1.0
							f.balance=minf(100,float(f.balance)+8.0)
						records.append(record)
	FileAccess.open(folder+"/report.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"failures":failures,"cases":records,"scope":"90 normalized direct-contact configurations: two modes, three armour tiers, three speeds, body/head/flank and shield centre/edge. Stops at first incapacity. No AI, swept geometry or player-incident reproduction claim."},"\t"))
	print("INJURY113 baseline cases=",records.size()," failures=",failures)
	quit(0 if failures.is_empty() else 1)
