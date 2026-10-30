extends RefCounted
## Authored walk/trot/canter/transverse-gallop curves. All timing is deterministic.
## Legs: far hind, near hind, far fore, near fore. Speeds are game units.
const WALK_TOUCHDOWN = [0.0,.5,.25,.75]
const TROT_TOUCHDOWN = [0.0,.5,.5,1.0]
const CANTER_TOUCHDOWN = [0.0,.28,.28,.58]
const GALLOP_TOUCHDOWN = [0.0,.14,.39,.53]
const HIP_POINTS = [Vector2(-93,-150),Vector2(-99,-148),Vector2(66,-136),Vector2(72,-134)]
const REST_FEET = [Vector2(-113,12),Vector2(-119,12),Vector2(59,12),Vector2(65,12)]
const GROUND = 12.0
# One measured whole-horse rest pose, in saddle/ground game coordinates.
# Legacy names map shoulder/elbow/carpus/fetlock to hip/proximal/knee/ankle
# in front, and hip/stifle/hock/fetlock behind. The carpus is NOT a stifle.
const FORE_PROXIMAL = Vector2(-19,37)
const HIND_PROXIMAL = Vector2(13,44)
const FORE_RADIUS = Vector2(1,45)
const FORE_CANNON = Vector2(-1,41)
const HIND_TIBIA = Vector2(-48,46)
const HIND_CANNON = Vector2(2,44)
const PASTERN = Vector2(12,23)
const HIND_PASTERN = Vector2(13,26)
# Retain legacy reach bounds for callers; exact bone-length checks must use
# segment_lengths(front), because a fore cannon is shorter than a hind one.
const UPPER = 66.48308055437865
const LOWER = 44.04543109109048
const NAMES = ["慢步","小跑","跑步","疾驰"]
# Cyclic back-height / pitch studies: compression, hind drive, fore support,
# collection and flight are separate poses instead of four pendulum legs.
const HEIGHTS = [
 [0.0,-1.0,-2.0,-1.0,0.0,1.0,0.0,-1.0,-2.0,-1.0,0.0,1.0],
 [1.0,-2.0,-4.5,-2.5,.5,2.0,1.0,-2.0,-4.5,-2.5,.5,2.0],
 [1.0,2.5,1.0,-1.5,-2.0,0.0,2.0,0.0,-4.0,-7.0,-8.0,-4.0],
 [1.0,3.0,1.0,-2.5,-1.0,1.5,3.0,0.0,-5.0,-10.0,-12.0,-7.0]]
# Trot is spring-like: back LOW at midstance, HIGH around suspension.
# Keep the authored vertical curve aligned with the diagonal footfalls.
const HEIGHT_PHASE = [0.0,.21,0.0,0.0]
const PITCHES = [
 [-.008,-.012,-.007,0.0,.008,.012,.008,.012,.007,0.0,-.008,-.012],
 [-.012,-.020,-.008,.015,.020,.008,-.012,-.020,-.008,.015,.020,.008],
 [-.018,-.028,-.008,.020,.037,.027,-.008,-.030,-.020,0.0,.012,0.0],
 [-.025,-.042,-.014,.032,.058,.042,-.010,-.045,-.028,0.0,.018,0.0]]

static func rest_foot(index: int) -> Vector2:
 return REST_FEET[index]

static func segment_lengths(front: bool) -> Dictionary:
 return {"proximal":FORE_PROXIMAL.length() if front else HIND_PROXIMAL.length(),
  "upper":FORE_RADIUS.length() if front else HIND_TIBIA.length(),
  "lower":FORE_CANNON.length() if front else HIND_CANNON.length(),
  "pastern":PASTERN.length() if front else HIND_PASTERN.length()}

static func rest_flex(front: bool) -> float:
 var upper = FORE_RADIUS if front else HIND_TIBIA
 var lower = FORE_CANNON if front else HIND_CANNON
 return absf(upper.angle_to(lower))

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
 return (.88*w.x+1.48*w.y+1.43*w.z+1.50*w.w)*clampf(speed/100.0,.10,1.12)

static func _cycle(values: Array, cycle: float) -> float:
 var p = fposmod(cycle,1.0)*values.size()
 var i = int(p)
 var t = p-i
 var a = float(values[posmod(i-1,values.size())])
 var b = float(values[i])
 var c = float(values[(i+1)%values.size()])
 var d = float(values[(i+2)%values.size()])
 return .5*((2*b)+(-a+c)*t+(2*a-5*b+4*c-d)*t*t+(-a+3*b-3*c+d)*t*t*t)

static func body(phase: float, speed: float, moving: bool, stability: float = 1.0, drive: float = 0.0) -> Dictionary:
 if not moving:
  return {"offset":Vector2(0,sin(phase)*.45),"pitch":0.0,"neck":sin(phase)*.008,"neck_offset":Vector2.ZERO,"tail":sin(phase*.7)*.045,"rider_offset":Vector2.ZERO,"rider_pitch":0.0,"gait":0}
 var w = weights(speed)
 var cycle = fposmod(phase/TAU,1)
 var intensity = smoothstep(0,95,speed)
 var height = 0.0
 var pitch = 0.0
 for i in range(4):
  height += _cycle(HEIGHTS[i],cycle+HEIGHT_PHASE[i])*w[i]
  pitch += _cycle(PITCHES[i],cycle)*w[i]
 var run = w.z+w.w
 # The back remains relatively rigid; the entire trunk rocks. Better horses
 # moderate rider transmission without eliminating their visible stride.
 var transmission = clampf(1.0/stability,.82,1.18)
 # Absorption follows the same back curve, including BOTH diagonal trot
 # beats. A separate single sine made alternate trot beats look detached.
 var delayed_height = 0.0
 var delayed_pitch = 0.0
 for i in range(4):
  delayed_height += _cycle(HEIGHTS[i],cycle-.055+HEIGHT_PHASE[i])*w[i]
  delayed_pitch += _cycle(PITCHES[i],cycle-.04)*w[i]
 var rider_lag = (delayed_height-height)*.32*transmission
 return {"offset":Vector2(sin(phase-.4)*run*1.2,height*intensity+absf(drive)*1.0),"pitch":pitch*intensity-drive*.018,
  "neck":(.11*run-pitch*.55+sin(phase-.5)*(.025*w.x+.018*w.y+.050*w.z+.075*w.w))*intensity,
  "neck_offset":Vector2(run*(3+3*sin(phase-.3)),run*(2+2*cos(phase)))*intensity,
  "tail":(.30*run+sin(phase-1.1)*(.04+.10*run))*intensity,
  "rider_offset":Vector2(-sin(phase)*run*1.7,rider_lag*intensity),
  "rider_pitch":delayed_pitch*.48+drive*.035,"gait":gait_index(speed)}

static func _swing_point(front: bool, t: float, reach: float, lift: float, run: float) -> Vector2:
 var times = [0.0,.18,.42,.75,1.0] if front else [0.0,.22,.55,.84,1.0]
 var points = [Vector2(-reach,0),Vector2(-reach,-lift*.55),Vector2(0,-lift),Vector2(reach,-lift*.45),Vector2(reach,0)] if front else [Vector2(-reach,0),Vector2(-reach+12,-lift*.65),Vector2(reach*.15,-lift),Vector2(reach+6*run,-lift*.3),Vector2(reach,0)]
 for i in range(times.size()-1):
  if t<=times[i+1]:
   var local = inverse_lerp(times[i],times[i+1],t)
   var a: Vector2 = points[maxi(0,i-1)]
   var b: Vector2 = points[i]
   var c: Vector2 = points[i+1]
   var d: Vector2 = points[mini(points.size()-1,i+2)]
   var result = b.cubic_interpolate(c,a,d,local)
   if front:
    # RiderView uses this x as interpolation towards a predicted WORLD
    # landing. Overshooting reach extrapolated beyond that landing, pulled
    # the shorter fore chain fully straight, then snapped its elbow during
    # late-swing recovery. Keep the authored lift but make forward delivery
    # monotone with zero endpoint velocity/acceleration.
    var progress = clampf(t,0,1)
    var delivered = progress*progress*progress*(progress*(6.0*progress-15.0)+10.0)
    result.x = lerpf(-reach,reach,delivered)
   result.y = minf(0,result.y)
   return result
 return Vector2(reach,0)

static func leg(index: int, phase: float, speed: float, moving: bool, stability: float = 1.0, planted_x: float = INF, override_foot: Vector2 = Vector2.INF, drive: float = 0.0, actual_swing: float = -1.0, cycle_override: float = -1.0) -> Dictionary:
 var pose = body(phase,speed,moving,stability,drive)
 var hip: Vector2 = Vector2(-18,-168)+(HIP_POINTS[index]-Vector2(-18,-168)).rotated(pose.pitch)+pose.offset
 var front = index>=2
 var w = weights(speed)
 var touchdown = WALK_TOUCHDOWN[index]*w.x+TROT_TOUCHDOWN[index]*w.y+CANTER_TOUCHDOWN[index]*w.z+GALLOP_TOUCHDOWN[index]*w.w
 var cycle = fposmod(phase/TAU-touchdown,1)
 if cycle_override>=0:
  cycle = fposmod(cycle_override,1.0)
 var canter_duty = [.30,.28,.28,.32][index]
 var gallop_duty = [.20,.22,.22,.26][index]
 var duty = .68*w.x+.41*w.y+canter_duty*w.z+gallop_duty*w.w
 var reach = maxf(0,speed)/maxf(.1,frequency(speed))*duty*.5
 var lift = (15*w.x+25*w.y+(37 if front else 33)*w.z+(46 if front else 41)*w.w)*smoothstep(0,85,speed)
 var foot = rest_foot(index)
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
 if actual_swing>=0.0:
  contact = false
  swing = clampf(actual_swing,0,1)
 # The shoulder joint glides with the scapular sling. At the ends of a
 # planted stride this small local motion avoids either forcing a wrist
 # bend or stretching the measured limb. It is not additional whole-body
 # bounce and does not affect the rule saddle or rider's aiming rhythm.
 var root_offset = Vector2.ZERO
 if front and moving:
  var stride_x = foot.x-rest_foot(index).x
  var ground_weight = 1.0-smoothstep(0.0,14.0,maxf(0.0,GROUND-foot.y))
  var scapula_activity = smoothstep(0,85,speed)
  # Loading the shoulder cannot vanish as the planted foot passes below
  # the chest. An extension-only dip made the almost straight fore chain
  # run out of reach at midstance and leave the walk on one hind hoof.
  root_offset = Vector2(clampf(stride_x*.22,-8.5,8.5),6.5*ground_weight)*scapula_activity
  hip += root_offset.rotated(float(pose.pitch))
 # Uncurl before touchdown: the last part of swing places a flat hoof,
 # rather than snapping a still-curled toe to the floor on the beat.
 var curl = (.28*w.x+.50*w.y+.72*w.z+.85*w.w)*smoothstep(0,85,speed)
 var toe_angle = 0.0 if contact else -sin(PI*smoothstep(0,.83,swing))*curl
 var pastern = PASTERN if front else HIND_PASTERN
 var lengths = segment_lengths(front)
 var proximal_length = float(lengths.proximal)
 var upper_length = float(lengths.upper)
 var lower_length = float(lengths.lower)
 var ankle = foot-pastern.rotated(toe_angle)
 var hip_ray = ankle-hip
 var requested_reach = hip_ray.length()
 var requested_foot = foot
 var reach_limited = false
 # Reach belongs to the entire shoulder/elbow/wrist or hip/stifle/hock
 # chain, not to two equal sticks below a fixed elbow/stifle.
 var maximum_reach = proximal_length+upper_length+lower_length-.03
 if hip_ray.length()>maximum_reach:
  ankle = hip+hip_ray.normalized()*maximum_reach
  foot = ankle+pastern.rotated(toe_angle)
  contact = false
  reach_limited = true
  hip_ray = ankle-hip
 if hip_ray.length()<.05:
  ankle = hip+Vector2(0,.05)
  foot = ankle+pastern.rotated(toe_angle)
  contact = false
  reach_limited = true
  hip_ray = ankle-hip
 # Angles below are authored departures from a straight distal chain,
 # not clinical goniometer angles. The weight-bearing fore wrist stays
 # almost straight; during swing it folds the cannon BACK under the arm.
 # The hind stifle and hock shorten together through the same three-link
 # solve, respecting their reciprocal action instead of separate hinges.
 var flex = rest_flex(front)
 if moving:
  var fold_activity = smoothstep(0,85,speed)
  if contact:
   var compression = sin(PI*clampf(cycle/maxf(.01,duty),0,1))
   flex += compression*(.025*w.x+.04*w.y+.055*w.z+.07*w.w if front else .045*w.x+.07*w.y+.09*w.z+.11*w.w)*fold_activity
  else:
   var fold = sin(PI*smoothstep(0.0,.88 if front else .90,swing))
   flex += fold*(.60*w.x+1.10*w.y+1.35*w.z+1.50*w.w if front else .28*w.x+.52*w.y+.70*w.z+.82*w.w)*fold_activity
 var distal_distance = sqrt(maxf(.0001,upper_length*upper_length+lower_length*lower_length+2.0*upper_length*lower_length*cos(flex)))
 var hip_distance = hip_ray.length()
 var minimum_distal = maxf(absf(upper_length-lower_length)+.01,absf(hip_distance-proximal_length)+.001)
 var maximum_distal = minf(upper_length+lower_length-.01,hip_distance+proximal_length-.001)
 if front and moving:
  # During protraction the hoof moves away from the chest while the wrist
  # is still tucked. A purely time-authored wrist curl can demand a distal
  # chain shorter than that geometry permits: acos then hits gamma=0 and
  # whips the elbow forward. Unfold the wrist with reach BEFORE that pole
  # singularity. Fade the preference to zero at the sole so support and
  # touchdown retain their full reach and the world's locked hoof target.
  var airborne = smoothstep(0.0,18.0,maxf(0.0,GROUND-requested_foot.y))*smoothstep(0,85,speed)
  var pole_angle = deg_to_rad(20.0)*airborne
  var pole_distance = sqrt(maxf(.0001,proximal_length*proximal_length+hip_distance*hip_distance-2.0*proximal_length*hip_distance*cos(pole_angle)))
  minimum_distal = maxf(minimum_distal,minf(pole_distance,maximum_distal))
 distal_distance = clampf(distal_distance,minimum_distal,maximum_distal)
 var proximal_bend = acos(clampf((proximal_length*proximal_length+hip_distance*hip_distance-distal_distance*distal_distance)/(2.0*proximal_length*hip_distance),-1,1))
 var proximal_angle = hip_ray.angle()+proximal_bend*(1 if front else -1)
 var proximal_limited = false
 if not front:
  # The femur is mostly buried in the muscular hindquarter. Unbounded
  # pole-angle solutions fanned it nearly horizontal during protraction,
  # pulling that entire skin patch into a triangular wing. Keep a compact
  # thigh envelope; the tibia/hock takes the remaining distal articulation.
  var local_angle = angle_difference(float(pose.pitch),proximal_angle)
  var limited_angle = clampf(local_angle,deg_to_rad(50),deg_to_rad(105))
  proximal_limited = absf(limited_angle-local_angle)>.0001
  proximal_angle = limited_angle+float(pose.pitch)
 var proximal = hip+Vector2.from_angle(proximal_angle)*proximal_length
 var ray = ankle-proximal
 if ray.length()>upper_length+lower_length-.01:
  ankle = proximal+ray.normalized()*(upper_length+lower_length-.01)
  foot = ankle+pastern.rotated(toe_angle)
  contact = false
  reach_limited = true
  ray = ankle-proximal
 var distance = maxf(.001,ray.length())
 var bend = acos(clampf((upper_length*upper_length+distance*distance-lower_length*lower_length)/(2.0*upper_length*distance),-1,1))
 var knee = proximal+ray.normalized().rotated(bend*(-1 if front else 1))*upper_length
 return {"hip":hip,"proximal":proximal,"knee":knee,"ankle":ankle,"foot":foot,"contact":contact,"nominal_contact":nominal_contact,"cycle":cycle,"toe_angle":toe_angle,"front":front,"swing":swing,"reach":reach,"duty":duty,"lift":lift,"root_offset":root_offset,"reach_limited":reach_limited,"requested_flex":flex,"requested_reach":requested_reach,"maximum_reach":maximum_reach,"requested_foot":requested_foot,"proximal_limited":proximal_limited}

static func touchdown_indices(previous_phase: float, current_phase: float, speed: float) -> Array[int]:
 var result: Array[int] = []
 for i in range(4):
  var previous = leg(i,previous_phase,speed,true)
  var current = leg(i,current_phase,speed,true)
  if current.cycle<previous.cycle:
   result.append(i)
 return result
