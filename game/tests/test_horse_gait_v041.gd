extends SceneTree
const Gait = preload("res://scripts/visual/horse_gait.gd")
var failures: Array[String] = []

func _initialize() -> void:
	var airborne_frames = 0
	var contacts: Array = []
	for sample in range(240):
		var phase = TAU*sample/240.0
		var airborne = true
		for i in range(4):
			var leg = Gait.leg(i,phase,480,true)
			if leg.contact:
				airborne = false
				if absf(leg.foot.y-Gait.GROUND)>.01:
					failures.append("Supporting hoof left the ground")
			if leg.foot.y>Gait.GROUND+.01:
				failures.append("Hoof penetrates ground")
			if leg.hip.distance_to(leg.knee)>74.1 or leg.knee.distance_to(leg.ankle)>66.1:
				failures.append("Unreachable foot stretched a bone")
		if airborne:
			airborne_frames += 1
		contacts.append_array(Gait.touchdown_indices(phase-.001,phase,480))
	if airborne_frames<30 or airborne_frames>80:
		failures.append("Gallop must have a short, visible suspension rather than constant floating")
	# Sample events by stepping through a whole cycle, not only exact beats.
	contacts.clear()
	for sample in range(241):
		contacts.append_array(Gait.touchdown_indices(TAU*(sample-1)/240.0,TAU*sample/240.0,480))
	if contacts.slice(0,4)!=[0,1,2,3]:
		failures.append("Expected hind-hind-fore-fore transverse gallop order")
	for speed in [210.0,350.0,480.0]:
		for i in range(4):
			for sample in range(240):
				var p = TAU*sample/240.0
				var dt = .001
				var a = Gait.leg(i,p,speed,true)
				var b = Gait.leg(i,p+dt*TAU*Gait.frequency(speed),speed,true)
				if a.contact and b.contact and b.cycle>a.cycle:
					if absf((b.foot.x-a.foot.x)/dt+speed)>1.0:
						failures.append("Planted hoof slides against travel speed")
	print("HORSE_GAIT_V041 "+JSON.stringify({"passed":failures.is_empty(),"failures":failures,"suspension_frames_of_240":airborne_frames,"footfalls":contacts,"scope":"kinematic contact and reach, not a visual quality or biomechanics certification"}))
	quit(0 if failures.is_empty() else 1)
