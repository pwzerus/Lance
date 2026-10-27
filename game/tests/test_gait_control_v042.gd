extends SceneTree
const Model = preload("res://scripts/core/joust_match.gd")
const Catalogue = preload("res://scripts/core/catalogue.gd")

func _initialize() -> void:
	var failures: Array = []
	var report: Array = []
	for horse in Catalogue.load_items():
		if horse.slot!="horse":
			continue
		var model = Model.new("arena",horse.stats)
		model.phase = "charge"
		var f = model.fighters[0]
		f.x = -250
		model.fighters[1].x = 250
		f.aim = 0.0
		f.speed = 480.0*horse.stats.speed
		f.gait_moving = true
		var uncorrected = 0.0
		var corrected = 0.0
		var minimum = INF
		var maximum = -INF
		var target_y = f.lane_y+Model.HIP.y-54
		for tick in range(600):
			f.gait_phase = tick/120.0*TAU*Model.Gait.frequency(f.speed)
			var offset = Model.saddle_offset(f).y
			minimum = minf(minimum,offset)
			maximum = maxf(maximum,offset)
			uncorrected += offset*offset
			var desired = asin(clampf((target_y-Model.hand_position(f).y)/Model.lance_length(f),-1,1))
			model.set_controls(0,desired,0,true,1.0/120.0)
			var error = Model.tip_position(f).y-target_y
			corrected += error*error
		var raw_rms = sqrt(uncorrected/600)
		var corrected_rms = sqrt(corrected/600)
		if maximum-minimum>22 or maximum-minimum<3:
			failures.append(horse.id+": gait amplitude outside moderate range")
		if corrected_rms>1.0 or corrected_rms>=raw_rms*.3:
			failures.append(horse.id+": legal controls cannot compensate predictable motion")
		report.append({"horse":horse.id,"span":maximum-minimum,"raw_rms":raw_rms,"corrected_rms":corrected_rms,"end_lance_stability":f.lance_stability})
	print("GAIT_CONTROL_V042 "+JSON.stringify({"failures":failures,"passed":failures.is_empty(),"scope":"rule simulation with ideal corrective input; not human skill evidence","horses":report}))
	quit(0 if failures.is_empty() else 1)
