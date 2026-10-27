extends RefCounted
## Authored walk/trot/canter/transverse-gallop curves. All timing is deterministic.
## Legs: far hind, near hind, far fore, near fore. Speeds are game units.
const WALK_TOUCHDOWN = [0.0,.5,.25,.75]
const TROT_TOUCHDOWN = [0.0,.5,.5,1.0]
const CANTER_TOUCHDOWN = [0.0,.28,.28,.58]
const GALLOP_TOUCHDOWN = [0.0,.14,.39,.53]
const HIP_POINTS = [Vector2(-94,-123),Vector2(-100,-121),Vector2(64,-129),Vector2(70,-127)]
const GROUND = 12.0
const UPPER = 78.0
const LOWER = 70.0
const NAMES = ["慢步","小跑","跑步","疾驰"]
# Cyclic back-height / pitch studies: compression, hind drive, fore support,
# collection and flight are separate poses instead of four pendulum legs.
const HEIGHTS = [
 [0.0,-1.0,-2.0,-1.0,0.0,1.0,0.0,-1.0,-2.0,-1.0,0.0,1.0],
 [2.0,-4.0,-9.0,-5.0,1.0,4.0,2.0,-4.0,-9.0,-5.0,1.0,4.0],
 [2.0,5.0,1.0,-4.0,-3.0,4.0,5.0,-1.0,-8.0,-15.0,-17.0,-8.0],
 [2.0,6.0,1.0,-6.0,-3.0,4.0,6.0,0.0,-10.0,-20.0,-24.0,-14.0]]
const PITCHES = [
 [-.008,-.012,-.007,0.0,.008,.012,.008,.012,.007,0.0,-.008,-.012],
 [-.012,-.020,-.008,.015,.020,.008,-.012,-.020,-.008,.015,.020,.008],
 [-.025,-.040,-.012,.028,.055,.040,-.012,-.045,-.030,0.0,.018,0.0],
 [-.035,-.060,-.020,.045,.085,.060,-.015,-.065,-.040,0.0,.025,0.0]]

static func weights(speed: float) -> Vector4:
 var a = smoothstep(135,205,speed)
 var b = smoothstep(250,330,speed)
 var c = smoothstep(370,440,speed)
 return Vector4(1-a,a*(1-b),a*b*(1-c),a*b*c)

static func gait_index(speed: float) -> int:
 var w = weights(speed)
 var best = 0
 for i in range(1,4):
  if w[i]>w[best]:
   best = i
 return best

static func frequency(speed: float) -> float:
 var w = weights(speed)
 return (.88*w.x+1.48*w.y+1.65*w.z+1.85*w.w)*clampf(speed/100.0,.10,1.12)

static func _cycle(values: Array, cycle: float) -> float:
 var p = fposmod(cycle,1.0)*values.size()
 var i = int(p)
 var t = p-i
 var a = float(values[posmod(i-1,values.size())])
 var b = float(values[i])
 var c = float(values[(i+1)%values.size()])
 var d = float(values[(i+2)%values.size()])
 return .5*((2*b)+(-a+c)*t+(2*a-5*b+4*c-d)*t*t+(-a+3*b-3*c+d)*t*t*t)

static func body(phase: float, speed: float, moving: bool, stability: float = 1.0) -> Dictionary:
 if not moving:
  return {"offset":Vector2(0,sin(phase)*.45),"pitch":0.0,"neck":sin(phase)*.008,"tail":sin(phase*.7)*.045,"rider_offset":Vector2.ZERO,"rider_pitch":0.0,"gait":0}
 var w = weights(speed)
 var cycle = fposmod(phase/TAU,1)
 var intensity = smoothstep(0,95,speed)
 var height = 0.0
 var pitch = 0.0
 for i in range(4):
  height += _cycle(HEIGHTS[i],cycle)*w[i]
  pitch += _cycle(PITCHES[i],cycle)*w[i]
 var run = w.z+w.w
 # The back remains relatively rigid; the entire trunk rocks. Better horses
 # moderate rider transmission without eliminating their visible stride.
 var transmission = clampf(1.0/stability,.82,1.18)
 var rider_lag = sin(phase-.65)*(1.0*w.y+2.5*w.z+4.5*w.w)*transmission
 return {"offset":Vector2(sin(phase-.4)*run*3.2,height*intensity),"pitch":pitch*intensity,
  "neck":(-pitch*.55+sin(phase-.5)*(.025*w.x+.018*w.y+.050*w.z+.075*w.w))*intensity,
  "tail":(-.18*run+sin(phase-.9)*(.04+.16*run))*intensity,
  "rider_offset":Vector2(-sin(phase)*run*1.7,rider_lag*intensity),
  "rider_pitch":pitch*.42+sin(phase-.9)*.018*run*transmission,"gait":gait_index(speed)}

static func _swing_point(front: bool, t: float, reach: float, lift: float, run: float) -> Vector2:
 var times = [0.0,.18,.42,.75,1.0] if front else [0.0,.22,.55,.84,1.0]
 var points = [Vector2(-reach,0),Vector2(-reach-3,-lift*.55),Vector2(-9,-lift),Vector2(reach+12*run,-lift*.45),Vector2(reach,0)] if front else [Vector2(-reach,0),Vector2(-reach+12,-lift*.65),Vector2(reach*.15,-lift),Vector2(reach+6*run,-lift*.3),Vector2(reach,0)]
 for i in range(times.size()-1):
  if t<=times[i+1]:
   var local = inverse_lerp(times[i],times[i+1],t)
   var a: Vector2 = points[maxi(0,i-1)]
   var b: Vector2 = points[i]
   var c: Vector2 = points[i+1]
   var d: Vector2 = points[mini(points.size()-1,i+2)]
   var result = b.cubic_interpolate(c,a,d,local)
   result.y = minf(0,result.y)
   return result
 return Vector2(reach,0)

static func leg(index: int, phase: float, speed: float, moving: bool, stability: float = 1.0, planted_x: float = INF, override_foot: Vector2 = Vector2.INF) -> Dictionary:
 var pose = body(phase,speed,moving,stability)
 var hip: Vector2 = Vector2(-18,-168)+(HIP_POINTS[index]-Vector2(-18,-168)).rotated(pose.pitch)+pose.offset
 var front = index>=2
 var w = weights(speed)
 var touchdown = WALK_TOUCHDOWN[index]*w.x+TROT_TOUCHDOWN[index]*w.y+CANTER_TOUCHDOWN[index]*w.z+GALLOP_TOUCHDOWN[index]*w.w
 var cycle = fposmod(phase/TAU-touchdown,1)
 var canter_duty = [.30,.28,.28,.32][index]
 var gallop_duty = [.20,.22,.22,.26][index]
 var duty = .68*w.x+.41*w.y+canter_duty*w.z+gallop_duty*w.w
 var reach = maxf(0,speed)/maxf(.1,frequency(speed))*duty*.5
 var lift = (22*w.x+39*w.y+(57 if front else 51)*w.z+(76 if front else 65)*w.w)*smoothstep(0,85,speed)
 var foot = Vector2(HIP_POINTS[index].x+(8 if front else -8),GROUND)
 var nominal_contact = not moving or cycle<duty
 var contact = nominal_contact
 var swing = 0.0
 if moving:
  if contact:
   foot.x += lerpf(reach,-reach,cycle/duty)
  else:
   swing = (cycle-duty)/(1-duty)
   foot += _swing_point(front,swing,reach,lift,w.z+w.w)
 if contact and is_finite(planted_x):
  foot.x = planted_x
 if override_foot.is_finite():
  foot = override_foot
 var toe_angle = 0.0 if contact else sin(swing*TAU-.35)*.55
 var ankle = foot-Vector2(0,12).rotated(toe_angle)
 var ray = ankle-hip
 # Out-of-reach support releases; never stretch a bone or drive a hoof underground.
 if ray.length()>UPPER+LOWER-.01:
  ankle = hip+ray.normalized()*(UPPER+LOWER-.01)
  foot = ankle+Vector2(0,12).rotated(toe_angle)
  contact = false
  ray = ankle-hip
 var distance = clampf(ray.length(),absf(UPPER-LOWER)+.01,UPPER+LOWER-.01)
 var bend = acos(clampf((UPPER*UPPER+distance*distance-LOWER*LOWER)/(2*UPPER*distance),-1,1))
 var knee = hip+ray.normalized().rotated(bend*(-1 if front else 1))*UPPER
 return {"hip":hip,"knee":knee,"ankle":ankle,"foot":foot,"contact":contact,"nominal_contact":nominal_contact,"cycle":cycle,"toe_angle":toe_angle,"front":front,"swing":swing,"reach":reach,"duty":duty,"lift":lift}

static func touchdown_indices(previous_phase: float, current_phase: float, speed: float) -> Array[int]:
 var result: Array[int] = []
 for i in range(4):
  var previous = leg(i,previous_phase,speed,true)
  var current = leg(i,current_phase,speed,true)
  if current.cycle<previous.cycle:
   result.append(i)
 return result
