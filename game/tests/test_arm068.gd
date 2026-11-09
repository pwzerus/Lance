extends SceneTree
## EQUIP-068 headless rule check: eased lance/shield motion (no overshoot, no
## instant full speed), arm fatigue from waving (slower when tired, recovers at
## rest), and the clear horse-tired step. Rule evidence only.
const Model = preload("res://scripts/core/joust_match.gd")
const Condition = preload("res://scripts/core/horse_condition.gd")
const DT = 1.0/120.0

func _initialize() -> void:
	var report = ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): report = arg.trim_prefix("--report=")
	var failures: Array = []
	var catalogue = load("res://scripts/core/catalogue.gd")
	var items = catalogue.load_items()
	var stats = catalogue.stats(items,{"horse":"horse_bay","armor":"eng_armor_3","helmet":"eng_helmet_3","shield":"eng_shield_3","lance":"eng_lance_long_3"})
	var model = Model.new("arena",stats,stats,77)
	model.phase = "charge"
	model.fighters[0].x = -900000.0
	model.fighters[1].x = 900000.0
	var f: Dictionary = model.fighters[0]
	# 1. Easing: first frame is not full speed, no overshoot, arrives.
	var first_step = 0.0
	var overshoot = false
	var max_velocity_jump = 0.0
	var previous_rate = 0.0
	var arrive_fresh = -1.0
	for tick in range(240):
		var before = float(f.aim)
		model.set_controls(0,.5,0.0,false,DT,.43)
		if tick==0:
			first_step = float(f.aim)-before
		overshoot = overshoot or float(f.aim)>.5001
		max_velocity_jump = maxf(max_velocity_jump,absf(float(f.aim_rate)-previous_rate))
		previous_rate = float(f.aim_rate)
		if arrive_fresh<0 and absf(float(f.aim)-.5)<.003:
			arrive_fresh = tick*DT
	var full_speed_step = 2.2*float(stats.get("lance_handling",1.0))*Condition.agility(stats)*DT
	if first_step>=full_speed_step*.5:
		failures.append("lance started at full speed (no ease-in)")
	if overshoot:
		failures.append("lance overshot its target")
	if arrive_fresh<0:
		failures.append("lance never arrived")
	# 2. Arm fatigue: wave for 4 s.
	var target = -.6
	for tick in range(int(4.0/DT)):
		if tick%int(.45/DT)==0:
			target = .5 if target<0 else -.6
		model.set_controls(0,target,0.0,false,DT,1.0 if target>0 else 0.0)
	var arm_after_waving = float(f.arm)
	if arm_after_waving>60.0:
		failures.append("waving 4 s left the arm at %.1f" % arm_after_waving)
	# Tired traverse time vs fresh.
	for tick in range(int(1.0/DT)):
		model.set_controls(0,-.6,0.0,false,DT,-1.0)
	var arm_before_tired_move = float(f.arm)
	var arrive_tired = -1.0
	for tick in range(480):
		model.set_controls(0,.5,0.0,false,DT,-1.0)
		if arrive_tired<0 and absf(float(f.aim)-.5)<.003:
			arrive_tired = tick*DT
	var fresh_model = Model.new("arena",stats,stats,78)
	fresh_model.phase = "charge"
	fresh_model.fighters[0].x = -900000.0
	fresh_model.fighters[1].x = 900000.0
	fresh_model.fighters[0].aim = -.6
	var arrive_fresh_full = -1.0
	for tick in range(480):
		fresh_model.set_controls(0,.5,0.0,false,DT,-1.0)
		if arrive_fresh_full<0 and absf(float(fresh_model.fighters[0].aim)-.5)<.003:
			arrive_fresh_full = tick*DT
	# Responsiveness guard: the old linear motion took 1.1/full_speed seconds.
	var linear = 1.1/(full_speed_step/DT)
	if arrive_fresh_full>linear*1.45:
		failures.append("eased sweep too sluggish: %.2f s vs linear %.2f s" % [arrive_fresh_full,linear])
	if not arrive_tired>arrive_fresh_full*1.15:
		failures.append("tired arm not slower: %.2f vs %.2f s" % [arrive_tired,arrive_fresh_full])
	# 3. Rest recovers.
	for tick in range(int(5.0/DT)):
		model.set_controls(0,.5,0.0,false,DT,-1.0)
	var arm_after_rest = float(f.arm)
	if arm_after_rest<85.0:
		failures.append("arm did not recover while still: %.1f" % arm_after_rest)
	# 4. Horse tired step.
	if not (Condition.gallop_ceiling(Condition.TIRED)==1.0 and Condition.gallop_ceiling(Condition.TIRED-.1)<=.901 and Condition.gallop_ceiling(0.0)<=.701):
		failures.append("horse ceiling is not a clear step")
	var summary = {"passed":failures.is_empty(),"failures":failures,"first_step":first_step,"full_speed_step":full_speed_step,
		"arrive_fresh_s":arrive_fresh,"arm_after_waving":arm_after_waving,"arm_before_tired_move":arm_before_tired_move,
		"traverse_fresh_s":arrive_fresh_full,"traverse_tired_s":arrive_tired,"arm_after_rest":arm_after_rest,
		"ceiling_34":Condition.gallop_ceiling(34.0),"ceiling_15":Condition.gallop_ceiling(15.0)}
	print("ARM068 "+JSON.stringify(summary))
	if not report.is_empty() and not FileAccess.file_exists(report):
		var file = FileAccess.open(report,FileAccess.WRITE)
		file.store_string(JSON.stringify(summary,"  "))
		file.close()
	quit(0 if failures.is_empty() else 1)
