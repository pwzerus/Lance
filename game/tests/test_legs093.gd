extends SceneTree
## FEEL-093 headless check of hoof swing timing, in the horse's own frame (what
## the eye follows on a moving horse). Same kinematics as RiderView: a world-
## planted hoof lifts off behind, the swing delivers it to the landing point
## ahead of the moving body. Compares the old delivery curve (HORSE-065 warped
## smootherstep) with Gait.delivery(). Measures, per gait speed:
##  back_dwell  fraction of the swing the hoof keeps drifting backwards after
##              lift-off (the visible "pause behind the horse")
##  peak_ratio  peak forward speed / mean forward speed during the swing
## Rule-free maths, not a render or a playtest.
const Gait = preload("res://scripts/visual/horse_gait.gd")
var report = ""

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): report = arg.trim_prefix("--report=")
	var result = {}
	var failures: Array = []
	for speed in [210.0,340.0,480.0]:
		var w = Gait.weights(speed)
		var duty = .41*w.y+.22*w.z+.22*w.w+.68*w.x
		var entry = {}
		for curve in ["legacy","current"]:
			entry[curve] = measure(curve,duty)
		result[str(int(speed))] = entry
		if float(entry.current.back_dwell)>.10:
			failures.append("speed %d still drifts back for %.0f%% of the swing" % [int(speed),100*float(entry.current.back_dwell)])
		if float(entry.current.back_dwell)>=float(entry.legacy.back_dwell):
			failures.append("speed %d: no improvement" % int(speed))
		if int(entry.current.reversals)!=1:
			failures.append("speed %d: hoof changes direction %d times" % [int(speed),int(entry.current.reversals)])
	for t in range(0,101):
		var x = t/100.0
		if t>0 and Gait.delivery(x)<Gait.delivery((t-1)/100.0)-.000001:
			failures.append("delivery is not monotonic")
			break
	if absf(Gait.delivery(0.0))>.0001 or absf(Gait.delivery(1.0)-1.0)>.0001:
		failures.append("delivery does not span 0..1")
	result["failures"] = failures
	result["passed"] = failures.is_empty()
	if not report.is_empty():
		var file = FileAccess.open(report,FileAccess.WRITE)
		file.store_string(JSON.stringify(result,"\t"))
		file.close()
	print("LEGS093 "+JSON.stringify(result))
	quit(0 if failures.is_empty() else 1)

static func legacy(t: float) -> float:
	var warped = t*(1.0+.24*(1.0-t))
	return warped*warped*warped*(warped*(6.0*warped-15.0)+10.0)

func measure(curve: String, duty: float) -> Dictionary:
	# Units: one stride length, one stride period. Body speed = 1.
	var swing = 1.0-duty
	var reach = duty*.5
	var start = -reach              # body frame at lift-off
	var landing = reach+swing       # world landing point (body moves on)
	var steps = 400
	var previous = start
	var previous_velocity = -1.0
	var back = 0
	var reversals = 0
	var peak = 0.0
	for i in range(1,steps+1):
		var t = float(i)/steps
		var d = legacy(t) if curve=="legacy" else Gait.delivery(t)
		var world = lerpf(start,landing,d)
		var body = world-swing*t
		var velocity = (body-previous)*steps/swing
		if velocity<0.0 and reversals==0:
			back += 1
		if previous_velocity<0.0 and velocity>=0.0:
			reversals += 1
		if previous_velocity>=0.0 and velocity<0.0 and i>steps*.9:
			pass # Returning with the ground just before touchdown is expected.
		peak = maxf(peak,velocity)
		previous = body
		previous_velocity = velocity
	var mean = (reach*2.0)/swing
	return {"back_dwell":snappedf(float(back)/steps,.001),"reversals":reversals,"peak_ratio":snappedf(peak/maxf(.0001,mean),.01)}
