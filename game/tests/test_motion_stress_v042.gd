extends SceneTree
const Model = preload("res://scripts/core/joust_match.gd")
const Rider = preload("res://scripts/visual/rider_view.gd")
const Catalogue = preload("res://scripts/core/catalogue.gd")
var failures: Array[String] = []
var worst_extension = 0.0
var worst_slip = 0.0
var worst_case = ""

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	for horse in Catalogue.load_items():
		if horse.slot!="horse":
			continue
		for hz in [30,60,120]:
			for facing in [-1,1]:
				var model = Model.new("arena",horse.stats)
				model.phase = "charge"
				var f = model.fighters[0]
				f.direction = facing
				f.x = -10000*facing
				for combatant in model.fighters:
					combatant.acted = true
				var rider = Rider.new()
				rider.fighter = f
				rider.moving = true
				var previous: Array = []
				for tick in range(hz*12):
					var delta = 1.0/hz
					model.set_controls(0,0,0,tick% (hz*4)<hz*2,delta)
					model.step(delta)
					rider.position = Vector2(f.x,f.lane_y)
					rider._process(delta)
					for i in range(4):
						var leg = rider.leg_poses[i]
						var extension = leg.knee.distance_to(leg.ankle)-Model.Gait.LOWER
						if extension>worst_extension:
							worst_extension = extension
							worst_case = "%s / %d Hz / %d / tick %d" % [horse.id,hz,facing,tick]
						var world_x = rider.position.x+leg.foot.x*facing
						if previous.size()==4 and leg.contact and previous[i].contact and leg.cycle>previous[i].cycle:
							worst_slip = maxf(worst_slip,absf(world_x-previous[i].x))
					previous.clear()
					for leg in rider.leg_poses:
						previous.append({"contact":leg.contact,"cycle":leg.cycle,"x":rider.position.x+leg.foot.x*facing})
				rider.free()
	if worst_extension>.1:
		failures.append("Acceleration extends a lower leg beyond its intended length")
	if worst_slip>.01:
		failures.append("Planted hoof slips during speed change")
	print("MOTION_STRESS_V042 "+JSON.stringify({"failures":failures,"passed":failures.is_empty(),"max_lower_extension":worst_extension,"max_hoof_slip":worst_slip,"worst_case":worst_case,"scope":"10 horses, both facings, 30/60/120 Hz, 12 simulated seconds with repeated acceleration/coast"}))
	quit(0 if failures.is_empty() else 1)
