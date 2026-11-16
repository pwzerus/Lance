extends "test_head076.gd"
const Catalogue=preload("res://scripts/core/catalogue.gd")

func strike(facing: int, shield: String, pose: float, offset: float, pace: float, zone: String, guarded_head: bool=false, shield_health: float=-1) -> Dictionary:
	var kit=Catalogue.stats(Catalogue.load_items(),{"armor":"eng_armor_3","helmet":"eng_helmet_3","shield":shield,"horse":"horse_bay","lance":"lance_ash"})
	var m=Model.new("arena",kit,kit,981)
	var di=0 if facing==1 else 1
	var ai=1-di
	var defender: Dictionary=m.fighters[di]
	var attacker: Dictionary=m.fighters[ai]
	# The normal lanes deliberately start on different hoof phases. A mirror
	# contract must mirror the full pose, not only X and equipment.
	for f in m.fighters:
		f.gait_phase=0.0
		f.lane_y=0.0
	defender.x=0.0
	defender.lane_y=0.0
	defender.guard=1.0 if zone=="shield" or guarded_head else -1.0
	if shield_health>=0: defender.shield=shield_health
	defender.shield_twist=pose
	defender.speed=480*pace
	attacker.aim=0.0
	attacker.speed=480*pace
	attacker.lance_stability=1.0
	var center=Model.shield_position(defender) if zone=="shield" else Model.head_position(defender)
	var start=center+Vector2(facing*130,offset)
	var end=center+Vector2(-facing*8,offset)
	attacker.x+=end.x-Model.tip_position(attacker).x
	attacker.lane_y+=end.y-Model.tip_position(attacker).y
	for f in m.fighters: m._cache_pose(f)
	attacker.prev_hand=start-Vector2(-facing,0)*Model.lance_length(attacker)
	var event=m._detect_contact(ai,138.0/(960*pace))
	if not event.is_empty(): m._apply_contact(event)
	return event

func run() -> void:
	var report=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): report=arg.trim_prefix("--report=")
	if report.is_empty() or FileAccess.file_exists(report) or OS.get_environment("GALUMU_MEMORY_BOUND")=="" or not root.get_node("GameState").save_path.contains("qa_"):
		quit(2)
		return
	for shield in ["eng_shield_0","eng_shield_5"]:
		for pose in [-.55,0.0,.55]:
			for offset in [-30,0,30]:
				for pace in [.5,1.0]:
					for zone in ["head","shield"]:
						var left=strike(1,shield,pose,offset,pace,zone)
						var right=strike(-1,shield,pose,offset,pace,zone)
						check(left.is_empty()==right.is_empty(),"mirror hit/miss mismatch")
						if left.is_empty() or right.is_empty(): continue
						for key in ["zone","glanced","ko","points"]:
							check(left[key]==right[key],"mirror "+key+" mismatch")
						for key in ["damage","impulse","balance_left","shield_transfer","head_incidence"]:
							check(absf(float(left.get(key,0))-float(right.get(key,0)))<.01,"mirror "+key+" mismatch")
						rows.append({"shield":shield,"pose":pose,"offset":offset,"pace":pace,"target":zone,"left":left,"right":right})
	for direction in [-1,1]:
		var guarded=strike(direction,"eng_shield_5",0,0,1,"head",true)
		var broken=strike(direction,"eng_shield_5",0,0,1,"head",true,0)
		check(guarded.get("zone","")=="shield","raised heavy shield misses frontal head line")
		check(broken.get("zone","")=="head","broken shield still blocks the head line")
	FileAccess.open(report,FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"failures":failures,"sweep_pairs":rows.size(),"rows":rows},"  "))
	print("CONTACT098 "+JSON.stringify({"failures":failures,"pairs":rows.size()}))
	quit(0 if failures.is_empty() else 1)
