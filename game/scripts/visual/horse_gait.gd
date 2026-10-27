extends RefCounted
## Stylized transverse gallop, not an equine biomechanics simulation.
## Ordered legs: far hind, near hind, far fore, near fore (leading).
## The four-beat/single-suspension sequence follows UMN Veterinary Anatomy.
const TROT_TOUCHDOWN = [0.5,0.0,0.0,0.5]
const GALLOP_TOUCHDOWN = [0.0,0.14,0.39,0.53]
const HIP_POINTS = [Vector2(-94,-123),Vector2(-100,-121),Vector2(64,-129),Vector2(70,-127)]
const GROUND = 12.0
const UPPER = 76.0
const LOWER = 68.0

static func frequency(speed: float) -> float:
	return lerpf(1.45,2.35,clampf((speed-210.0)/270.0,0,1))

static func body(phase: float, pace: float, moving: bool, stability: float = 1.0) -> Dictionary:
	if not moving:
		return {"offset":Vector2(0,sin(phase)*.45),"pitch":0.0,"neck":sin(phase)*.008,"tail":sin(phase*.7)*.045}
	var cycle = fposmod(phase/TAU,1)
	var suspension = sin((cycle-.79)/.21*PI) if cycle>.79 else 0.0
	# Deterministic stride: quality moderates transmitted motion, never removes
	# the gait or adds random aiming error. Suspension lifts the back visibly.
	var transmission = clampf(1.0/stability,.78,1.24)
	var bounce = lerpf(-absf(sin(phase*2))*3.6,sin(phase-.4)*5.0-suspension*6.0,pace)*transmission
	return {"offset":Vector2(0,bounce),"pitch":sin(phase+.25)*lerpf(.012,.047,pace),"neck":sin(phase-.45)*lerpf(.025,.075,pace),"tail":-.12*pace+sin(phase-.8)*lerpf(.06,.18,pace)}

static func leg(index: int, phase: float, speed: float, moving: bool, stability: float = 1.0, planted_x: float = INF) -> Dictionary:
	var pace = clampf((speed-210.0)/270.0,0,1)
	var pose = body(phase,pace,moving,stability)
	var hip: Vector2 = Vector2(-18,-168)+(HIP_POINTS[index]-Vector2(-18,-168)).rotated(pose.pitch)+pose.offset
	var front = index>=2
	var touchdown = lerpf(TROT_TOUCHDOWN[index],GALLOP_TOUCHDOWN[index],smoothstep(.15,.85,pace))
	var cycle = fposmod(phase/TAU-touchdown,1)
	var duty = lerpf(.43,.26 if index==3 else .22,pace)
	# During stance, local hoof velocity cancels horse translation. This
	# prevents moonwalking; faster movement changes reach as well as cadence.
	var reach = speed/frequency(speed)*duty*.5
	var foot = Vector2(HIP_POINTS[index].x+(5 if front else -5),GROUND)
	var contact = not moving or cycle<duty
	var swing = 0.0
	if moving:
		if contact:
			foot.x += lerpf(reach,-reach,cycle/duty)
		else:
			swing = (cycle-duty)/(1-duty)
			foot.x += lerpf(-reach,reach,smoothstep(0,1,swing))
			foot.y -= sin(PI*swing)*lerpf(29,58 if front else 48,pace)
	if contact and is_finite(planted_x):
		foot.x = planted_x
	var toe_angle = 0.0 if contact else sin(swing*TAU)*.6
	var ankle = foot-Vector2(6,11).rotated(toe_angle)
	var ray = ankle-hip
	var upper = UPPER
	var lower = LOWER
	var distance = clampf(ray.length(),absf(upper-lower)+.01,upper+lower-.01)
	var bend = acos(clampf((upper*upper+distance*distance-lower*lower)/(2*upper*distance),-1,1))
	var knee = hip+ray.normalized().rotated(bend*(-1 if front else 1))*upper
	return {"hip":hip,"knee":knee,"ankle":ankle,"foot":foot,"contact":contact,"cycle":cycle,"toe_angle":toe_angle,"front":front}

static func touchdown_indices(previous_phase: float, current_phase: float, speed: float) -> Array[int]:
	var result: Array[int] = []
	for i in range(4):
		var previous = leg(i,previous_phase,speed,true)
		var current = leg(i,current_phase,speed,true)
		if current.cycle<previous.cycle:
			result.append(i)
	return result
