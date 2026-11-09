extends SceneTree
## Deterministic swept shield contacts and production reaction integration.
## This is rule/geometry evidence, not human input or a feel endorsement.
const Model = preload("res://scripts/core/joust_match.gd")
const Rider = preload("res://scripts/visual/rider_view.gd")
const Cues = preload("res://scripts/visual/combat_cues.gd")
var failures: Array = []
var rows: Array = []

func check(ok: bool, message: String) -> void:
	if not ok and message not in failures: failures.append(message)

func _initialize() -> void:
	for shape in ["kite","heater","targe"]:
		for facing in [1,-1]:
			for height in [0.0,-27.0,40.0,-40.0]:
				var stats = {"shield_shape":shape,"durability":1000.0,"stability":2.0}
				var model = Model.new("arena",stats,stats,7200)
				var di = 0 if facing==1 else 1
				var ai = 1-di
				var defender: Dictionary = model.fighters[di]
				var attacker: Dictionary = model.fighters[ai]
				defender.x = 0.0
				defender.lane_y = 0.0
				defender.guard = .43
				attacker.aim = 0.0
				attacker.speed = 480.0
				var center = Model.shield_position(defender)
				var end_tip = center+Vector2(-facing*80,height)
				var start_tip = center+Vector2(facing*80,height)
				attacker.x += end_tip.x-Model.tip_position(attacker).x
				attacker.lane_y += end_tip.y-Model.tip_position(attacker).y
				for f in model.fighters: model._cache_pose(f)
				attacker.prev_hand = start_tip-Vector2(-facing,0)*Model.lance_length(attacker)
				attacker.prev_tip = start_tip
				var event: Dictionary = model._detect_contact(ai,.16)
				var name = "%s / %d / %.0f" % [shape,facing,height]
				check(not event.is_empty() and event.get("zone","")=="shield","Sweep failed: "+name)
				if event.is_empty() or event.zone!="shield": continue
				var expected = "center" if height==0 else ("face" if height==-27 else "rim")
				check(event.shield_region==expected,"Wrong region: "+name)
				check(not Cues.contact_name(event).is_empty(),"Missing contact name")
				var before = Model.shield_transform(defender)
				model._apply_contact(event)
				check(Model.shield_transform(defender).is_equal_approx(before),"Contact teleported shield")
				var hp = float(defender.hp)
				var max_twist = 0.0
				var compression = 0.0
				var prior_angle = Model.shield_angle(defender)
				for tick in range(240):
					Model.advance_reaction(defender,1.0/120.0)
					Model.advance_reaction(attacker,1.0/120.0)
					max_twist = maxf(max_twist,absf(defender.shield_twist))
					compression = maxf(compression,defender.shield_compression)
					var pose = Rider.arm_pose(defender)
					check(Vector2(pose.left.hand).distance_to(Model.shield_transform(defender)*Vector2(-10,4))<.001,"Grip separated")
					for side in ["left","right"]:
						var arm: Dictionary = pose[side]
						check(absf(Vector2(arm.shoulder).distance_to(arm.elbow)-Rider.ARM_UPPER)<.05,"Upper arm disconnected")
						check(absf(Vector2(arm.hand).distance_to(arm.elbow)-Rider.ARM_LOWER)<.05,"Forearm disconnected")
					check(absf(Model.shield_angle(defender)-prior_angle)<.13,"Shield turned discontinuously")
					prior_angle = Model.shield_angle(defender)
				check(defender.hp==hp,"Reaction dealt repeated damage")
				check(compression>5.0,"No visible shield load")
				check(max_twist<.001 if height==0 else max_twist>.06,"Missing region-specific torque: "+name)
				check(absf(defender.shield_twist)<.001,"Shield did not settle")
				rows.append({"case":name,"region":event.shield_region,"peak_twist_degrees":rad_to_deg(max_twist),"peak_compression":compression,"hp":hp,"score":attacker.score})
				model._reset_positions()
				check(defender.shield_twist==0.0 and defender.shield_twist_velocity==0.0,"Rerack retained torque")
	var result = {"passed":failures.is_empty(),"failures":failures,"cases":rows}
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):
			var file = FileAccess.open(arg.trim_prefix("--report="),FileAccess.WRITE)
			file.store_string(JSON.stringify(result,"\t"))
	print("CONTACT072 "+JSON.stringify(result))
	quit(0 if failures.is_empty() else 1)
