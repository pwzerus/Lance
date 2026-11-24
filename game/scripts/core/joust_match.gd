class_name JoustMatch
extends RefCounted
const HorseSurface113 = preload("res://scripts/core/horse_surface.gd")

const MAX_PASSES = 3
# EQUIP-069: post-armour damage a body/helm strike needs to score in full.
# Estimated from balance068 hit data: helm hits on light kit average ~24-29,
# on top plate ~19; 17 turns roughly a third of hits on heavy plate into touches.
const ATTAINT_DAMAGE = 17.0
# RULE-076 gameplay thresholds, not measurements of real injury probability.
const WAR_HEAD_DAMAGE = 50.0
const WAR_HEAD_SPEED = 820.0
const WAR_HEAD_INCIDENCE = .82
const WAR_HEAD_STABILITY = .80
# Cumulative in-match trauma is a gameplay severity budget, not medical data.
# An intact helmet may save the first blow; it is not immunity to repeated
# clean, supported head strikes. Glances and shield hits do not fill it.
const WAR_HEAD_LOAD_LIMIT = 60.0
## FEEL-093 (user: "almost never an unhorsing, everything is blocked or the
## armour is too strong"). Combat constants in one table so the balance test
## can replay the old values on the same seeds. A square strike on the shield
## now carries real momentum into the rider (historically the shield was the
## target and the usual way to unhorse), armour removes a smaller share of a
## blow, base damage is higher and the seat gives way sooner.
const TUNING_V092 = {"damage":19.0,"armor_effect":1.0,"shield_impulse":.28,"shield_glance_impulse":.16,
	"shield_rider_damage":.09,"shield_glance_damage":.035,"balance_loss":.82,"head_balance_loss":.50,"ko_threshold":96.0}
const TUNING_V097 = {"damage":23.0,"armor_effect":.75,"shield_impulse":.70,"shield_glance_impulse":.22,
	"shield_rider_damage":.12,"shield_glance_damage":.04,"balance_loss":1.25,"head_balance_loss":.95,"ko_threshold":58.0}
# REQ-098: fixed-condition targets are game balance, not real injury rates.
const TUNING = {"damage":52.0,"armor_effect":.60,"impulse":70.0,"full_closing_speed":960.0,
	"speed_exponent":.95,"shield_damage":100.0,"shield_impulse":1.0,"shield_glance_impulse":.30,
	"shield_rider_damage":.10,"shield_glance_damage":.02,"balance_loss":1.20,"head_balance_loss":.95,
	"ko_threshold":64.0,"continuous_shield":true}
static var tuning: Dictionary = TUNING
## FEEL-094 (user: "flailing about should make the seat unsteady and a fall
## more likely, and show it in the motion"). Every abrupt change of the
## rider's own motion - lean, lance swing, shield swing, spurring/checking -
## builds "fidget" (velocity changes beyond a free allowance, so one deliberate
## move costs almost nothing but repeated jerks stack). It fades with a ~.8 s
## half-life. Unsteadiness (0..1) lowers the seat's unhorse threshold, raises
## the balance lost to a hit, and drives a visible loose-seat sway that the
## hit anchors share (the body you see wobbling is the body that gets hit).
const FIDGET_FREE = {"lean":3.0,"aim":6.0,"guard":10.0}
const FIDGET_WEIGHT = {"lean":1.6,"aim":1.5,"guard":.6,"drive":1.4}
const FIDGET_DECAY = .9
const UNSTEADY_RANGE = Vector2(4.0,13.0)
const UNSTEADY_THRESHOLD_LOSS = .40
const UNSTEADY_BALANCE_GAIN = .70
## QA A/B only (like `tuning`): 0 switches the whole FEEL-094 seat model off
## (no fidget, no sway kicks) so benches can replay the same seeds without it.
static var unsteady_scale: float = 1.0
# FEEL-097 presentation reactions (never read by hit anchors, damage or KO).
# Leg and horse kicks grow faster than linearly with loading, so a light touch
# barely stirs them while a full strike throws the feet and checks the horse.
const NECK_RANGE = Vector2(-.36,.18)
const HEAD_WHIP = 9.0
const LEG_KICK = {"head":11.0,"body":15.0,"flank":17.0,"shield":8.0}
const HORSE_KICK = 13.0
const START_X = 2200.0
const EXIT_X = 850.0
const TROT_SPEED = 210.0
const GALLOP_SPEED = 480.0
const SURGE_SPEED = 515.0
const SPUR_DURATION = 0.0 # Compatibility only; urging now follows the physical hold.
const ACCELERATION = 330.0
const COAST_DECELERATION = 220.0
const START_ACCELERATION = 180.0
const ACCELERATION_SLEW = 950.0
const GROUND_Y = 0.0
const HIP = Vector2(-18, -168)
const Gait = preload("res://scripts/visual/horse_gait.gd")
const Shield = preload("res://scripts/core/shield_geometry.gd")
const Feedback = preload("res://scripts/core/contact_feedback.gd")
const Condition = preload("res://scripts/core/horse_condition.gd")
const RiderCondition = preload("res://scripts/core/rider_condition.gd")
var mode = "arena"
var phase = "ready"
var phase_time = 2.6
var pass_number = 1
var fighters: Array = []
var events: Array = []
var result: Dictionary = {}
var rng = RandomNumberGenerator.new()
var time_elapsed = 0.0
# The presentation layer supplies this flag from its real-time hitstop clock.
var time_effect_active = false

func _init(match_mode: String = "arena", player_stats: Dictionary = {}, opponent_stats: Dictionary = {}, seed_value: int = 12345) -> void:
	mode = match_mode
	rng.seed = seed_value
	fighters = [_make_fighter(-START_X, 1, player_stats), _make_fighter(START_X, -1, opponent_stats)]
	_reset_positions()

func _make_fighter(x: float, direction: int, stats: Dictionary) -> Dictionary:
	var fighter = {"x": x, "prev_x": x, "direction": direction, "speed": TROT_SPEED, "stamina": 100.0,
		"hp": 100.0, "head_load": 0.0, "shield": float(stats.get("shield_capacity",78.0)), "lean": 0.0, "aim": -0.08, "boost": false,
		"broken": false, "durability": float(stats.get("durability", 100.0)), "acted": false,
		"ko": false, "dead": false, "stats": stats.duplicate(true), "prev_tip": Vector2.ZERO,
		"prev_head": Vector2.ZERO, "prev_body": Vector2.ZERO, "prev_shield": Vector2.ZERO,
		"prev_hand": Vector2.ZERO, "prev_aim": -0.08, "prev_length": 247.0,
		"surge": 0.0, "last_hit": "", "damage_total": 0.0, "wounds": [], "score": 0, "arm": 100.0, "aim_rate": 0.0, "guard_rate": 0.0,
		"balance":100.0,"lean_velocity":0.0,"prev_flank":Vector2.ZERO,
		"guard":0.0,"guard_target":0.0,"lance_stability":.85,"aim_velocity":0.0,
		"reaction_angle":0.0,"reaction_angular_velocity":0.0,"reaction_shift":0.0,"reaction_shift_velocity":0.0,
		"reaction_neck":0.0,"reaction_neck_velocity":0.0,"arm_rest_delay":0.0,
		"shield_compression":0.0,"shield_compression_velocity":0.0,"lance_compression":0.0,"lance_compression_velocity":0.0,
		"shield_twist":0.0,"shield_twist_velocity":0.0,"guard_stun":0.0,
		"gait_phase":0.0,"gait_moving":false,"acceleration":0.0,"accel_command":0.0,"motion_drive":0.0,"motion_drive_velocity":0.0,"seat_drive":0.0,"seat_drive_velocity":0.0,"mount_velocity_y":0.0,"lane_y":32.0 if direction==1 else -32.0,
		"fidget":0.0,"unsteady":0.0,"sway":0.0,"sway_velocity":0.0,
		"reaction_legs":0.0,"reaction_legs_velocity":0.0,"reaction_horse":0.0,"reaction_horse_velocity":0.0}
	RiderCondition.initialize(fighter)
	return fighter

func _reset_positions() -> void:
	for i in range(2):
		var fighter = fighters[i]
		fighter.x = -START_X if i == 0 else START_X
		fighter.prev_x = fighter.x
		fighter.direction = 1 if i == 0 else -1
		fighter.speed = 0.0
		fighter.acceleration = 0.0
		fighter.accel_command = 0.0
		fighter.motion_drive = 0.0
		fighter.motion_drive_velocity = 0.0
		fighter.seat_drive = 0.0
		fighter.seat_drive_velocity = 0.0
		fighter.mount_velocity_y = 0.0
		fighter.balance = minf(100.0,float(fighter.balance)+8.0)
		fighter.acted = false
		fighter.surge = 0.0
		fighter.boost = false
		fighter.gait_phase = 0.0 if i==0 else 1.1
		fighter.gait_moving = false
		fighter.reaction_neck = 0.0
		fighter.reaction_neck_velocity = 0.0
		fighter.arm_rest_delay = 0.0
		fighter.guard_stun = 0.0
		for key in ["seat_offset","seat_velocity","seat_escape_time","seat_strain"]: fighter[key]=0.0
		fighter.seat_support=1.0
		for key in ["reaction_angle","reaction_angular_velocity","reaction_shift","reaction_shift_velocity","shield_compression","shield_compression_velocity","lance_compression","lance_compression_velocity","shield_twist","shield_twist_velocity","fidget","unsteady","sway","sway_velocity","reaction_legs","reaction_legs_velocity","reaction_horse","reaction_horse_velocity"]:
			fighter[key] = 0.0
		if mode == "arena":
			fighter.broken = false
			fighter.durability = float(fighter.stats.get("durability", 100.0))
		_cache_pose(fighter)

static func pose_angle(fighter: Dictionary) -> float:
	var active = float(fighter.lean)*(deg_to_rad(25.0) if float(fighter.lean)>=0 else deg_to_rad(45.0))+gait_pose(fighter).rider_pitch+float(fighter.get("reaction_angle",0.0))+float(fighter.get("sway",0.0))+float(fighter.get("injury_pose",0.0))
	var slump = float(fighter.get("slump",0.0))
	if slump<=0: return active
	var angle = lerpf(active,1.15+gait_pose(fighter).rider_pitch*.30,slump)
	return minf(angle,slump_contact_angle113(fighter))

static func slump_contact_angle113(fighter: Dictionary) -> float:
	# The jaw/helmet rests against the moving crest. Solve the same torso
	# angle used by the hands, head target and fallen-pose capture, not a
	# separate sprite correction. No art textures enter the rule model.
	var phase = float(fighter.get("gait_phase",0.0))
	var speed = float(fighter.get("speed",0.0))
	var moving = bool(fighter.get("gait_moving",false))
	var drive = float(fighter.get("motion_drive",0.0))
	var key = [phase,speed,moving,drive,seat_inertia(fighter),float(fighter.get("pose_clock113",0.0)),float(fighter.get("unsteady",0.0)),float(fighter.get("reaction_horse",0.0)),float(fighter.stats.get("stability",1.0)),float(fighter.get("stamina",100.0)),float(fighter.get("reaction_shift",0.0)),float(fighter.get("seat_offset",0.0)),seat_lift(fighter)]
	if fighter.get("_slump_contact_key113")==key: return float(fighter._slump_contact_value113)
	var body = Gait.visual(gait_pose(fighter),phase,speed,moving,drive,seat_inertia(fighter),float(fighter.get("pose_clock113",0.0)),float(fighter.get("unsteady",0.0)),float(fighter.get("reaction_horse",0.0)))
	var points = HorseSurface113.crest_points(body)
	var origin = HIP+saddle_offset(fighter)+Vector2(float(fighter.get("reaction_shift",0.0))+float(fighter.get("seat_offset",0.0)),-seat_lift(fighter))
	var low = .35
	var high = 1.20
	for iteration in range(12):
		var angle = (low+high)*.5
		var head = origin+Vector2(sin(angle)*111.0,-cos(angle)*111.0)
		# A compact head capsule excludes plumes and loose mail. Positive gap
		# means the head can continue falling; contact preserves the neck chain.
		var gap = HorseSurface113.crest_height(points,head.x)-head.y-19.0
		if gap>=0: low=angle
		else: high=angle
	fighter._slump_contact_key113=key
	fighter._slump_contact_value113=low
	return low

static func rider_origin(fighter: Dictionary) -> Vector2:
	return mount_origin(fighter)+(HIP+Vector2(float(fighter.get("reaction_shift",0.0))+float(fighter.get("seat_offset",0.0)),-seat_lift(fighter)))*Vector2(int(fighter.direction),1)

static func seat_lift(fighter: Dictionary) -> float:
	# FEEL-094: an unsteady rider no longer sits the stride; the seat bounces
	# out of the saddle once per stride. Zero for a steady rider.
	var unsteady = float(fighter.get("unsteady",0.0))
	var support_lift = smoothstep(.20,.90,1.0-float(fighter.get("seat_support",1.0)))*6.0
	if unsteady<=0.0 or not bool(fighter.get("gait_moving",false)):
		return support_lift
	# Enter and leave saddle contact at zero vertical speed. Clipping a
	# plain sine left a velocity jump at each half-stride boundary, making
	# loose-seat motion look like a repeated hard tug. Keep one lift, its
	# original 9px peak, and the same unsteadiness/balance consequences.
	var lift = maxf(0.0,sin(float(fighter.get("gait_phase",0.0))+.4))
	return unsteady*9.0*lift*lift*smoothstep(0.0,120.0,float(fighter.get("speed",0.0)))+support_lift

static func add_fidget(fighter: Dictionary, amount: float) -> void:
	# Heavier riders sit deeper (Condition.seat .90-1.12), so the same jerk
	# unsettles them a little less.
	fighter.fidget = float(fighter.get("fidget",0.0))+amount*unsteady_scale/Condition.seat(fighter.stats)

static func advance_unsteady(fighter: Dictionary, delta: float, riding: bool) -> void:
	var dt_total = clampf(delta,0.0,.25)
	fighter.fidget = float(fighter.get("fidget",0.0))*exp(-FIDGET_DECAY*dt_total)
	var unsteady = smoothstep(UNSTEADY_RANGE.x,UNSTEADY_RANGE.y,float(fighter.fidget))
	fighter.unsteady = unsteady
	# The legacy balance budget retains a floor. Physical saddle support is
	# separate below: sustained violent motion can now slide past its edge.
	if riding and unsteady>.55 and float(fighter.balance)>25.0:
		var pace = smoothstep(TROT_SPEED,GALLOP_SPEED,float(fighter.speed))
		fighter.balance = maxf(25.0,float(fighter.balance)-(unsteady-.55)*5.0*pace*dt_total)
	# Loose-seat sway: torso pitch driven out of step with the horse's stride
	# (the rider bounces against the gait instead of with it), plus the kicks
	# set_controls adds from abrupt lean/lance changes. Spring ~1.3 Hz.
	var moving = bool(fighter.get("gait_moving",false))
	var phase = float(fighter.get("gait_phase",0.0))
	var target = unsteady*(.13*sin(phase+.9) if moving else .03*sin(phase*.5))
	var remaining = dt_total
	while remaining>.000001:
		var dt = minf(remaining,1.0/120.0)
		var sway = float(fighter.get("sway",0.0))
		var velocity = float(fighter.get("sway_velocity",0.0))
		velocity += (70.0*(target-sway)-6.0*velocity)*dt
		var next = clampf(sway+velocity*dt,-.17,.17)
		if absf(next)>=.17: velocity = 0.0
		fighter.sway = next
		fighter.sway_velocity = velocity
		remaining -= dt
	RiderCondition.advance_support(fighter,delta,riding)

static func gait_pose(fighter: Dictionary) -> Dictionary:
	# Fatigue only lowers neck/head carriage; it never moves the saddle, rider
	# pitch or any hit anchor.
	# CORE-106: head/body/weapon sweeps and drawing request this same pose
	# many times without changing its inputs. Retain ONE exact result per
	# fighter; no frame keys, quantization or growing global history. QA and
	# contacts can change state within a frame and still get a fresh pose.
	var key = [float(fighter.get("gait_phase",0.0)),float(fighter.get("speed",0.0)),bool(fighter.get("gait_moving",false)),float(fighter.stats.get("stability",1.0)),float(fighter.get("motion_drive",0.0)),Condition.fatigue(float(fighter.get("stamina",100.0))),seat_inertia(fighter)]
	if fighter.get("_gait_pose_key")==key:
		return fighter._gait_pose_value
	var pose = Gait.body(key[0],key[1],key[2],key[3],key[4],key[5],key[6])
	# All entries are value types. A caller needing artistic edits duplicates
	# the dictionary (Gait.visual already does), preserving shared anchors.
	pose.make_read_only()
	fighter._gait_pose_key = key
	fighter._gait_pose_value = pose
	return pose

static func seat_inertia(fighter: Dictionary) -> float:
	# ANIM-091: how far the horse's drive has run ahead of the rider's seat.
	return float(fighter.get("motion_drive",0.0))-float(fighter.get("seat_drive",fighter.get("motion_drive",0.0)))

static func advance_drive(fighter: Dictionary, target: float, delta: float) -> void:
	# CORE-106: actual acceleration still changes speed immediately. The
	# horse's weight transfer follows continuously instead of a move_toward
	# ramp whose velocity stops dead at cruising speed. Analytic critically
	# damped response (16 rad/s), no additional oscillation or random shake.
	if delta<=0.0: return
	var dt = minf(delta,.25)
	var wanted = clampf(target,-1.0,1.0)
	var offset = float(fighter.get("motion_drive",0.0))-wanted
	var velocity = float(fighter.get("motion_drive_velocity",0.0))
	var decay = exp(-16.0*dt)
	var follow = velocity+16.0*offset
	fighter.motion_drive = wanted+(offset+follow*dt)*decay
	fighter.motion_drive_velocity = (velocity-16.0*follow*dt)*decay

static func advance_seat(fighter: Dictionary, delta: float) -> void:
	# The seat follows the horse's drive through a damped spring (about 9 rad/s,
	# damping .55): a spurred launch throws the rider back for ~.2s, a sudden
	# check pitches him forward, then he settles. Fixed small steps.
	var remaining = clampf(delta,0.0,.25)
	while remaining>.000001:
		var dt = minf(remaining,1.0/120.0)
		var seat = float(fighter.get("seat_drive",0.0))
		var velocity = float(fighter.get("seat_drive_velocity",0.0))
		velocity += (81.0*(float(fighter.get("motion_drive",0.0))-seat)-9.9*velocity)*dt
		fighter.seat_drive = seat+velocity*dt
		fighter.seat_drive_velocity = velocity
		remaining -= dt

static func release_drive_pose(fighter: Dictionary, delta: float) -> void:
	# The completed pass rides out at its retained speed. It has no continued
	# acceleration, so release launch/braking posture smoothly instead of
	# freezing the last weight-transfer and rider spring for the whole exit.
	advance_drive(fighter,0.0,delta)
	advance_seat(fighter,delta)

static func saddle_offset(fighter: Dictionary) -> Vector2:
	var pose = gait_pose(fighter)
	return pose.offset+pose.rider_offset

static func mount_origin(fighter: Dictionary) -> Vector2:
	return Vector2(float(fighter.x),float(fighter.get("lane_y",0.0)))+saddle_offset(fighter)*Vector2(int(fighter.direction),1)

static func body_position(fighter: Dictionary) -> Vector2:
	var angle = pose_angle(fighter)
	return rider_origin(fighter)+Vector2(sin(angle)*44.0*int(fighter.direction),-cos(angle)*44.0)

static func head_position(fighter: Dictionary) -> Vector2:
	var angle = pose_angle(fighter)
	return rider_origin(fighter)+Vector2(sin(angle)*111.0*int(fighter.direction),-cos(angle)*111.0)

static func hand_position(fighter: Dictionary) -> Vector2:
	var angle = pose_angle(fighter)
	var ray = Vector2(cos(float(fighter.aim))*int(fighter.direction),sin(float(fighter.aim)))
	# ANIM-105: lifting a couched lance also lifts its grip/forearm. Follow the
	# actual eased aim, never the input target, so the arm cannot teleport.
	# A short arc preserves the couched shoulder and neutral grip while the
	# same anchor continues to drive the visible hand, lance and swept hits.
	var relative_aim = float(fighter.aim)-angle
	var neutral = -.08
	var grip = Vector2(48,-53)+18.0*Vector2(cos(relative_aim)-cos(neutral),sin(relative_aim)-sin(neutral))
	return rider_origin(fighter)+grip.rotated(angle)*Vector2(int(fighter.direction),1)-ray*float(fighter.get("lance_compression",0.0))

static func shield_position(fighter: Dictionary) -> Vector2:
	# Forward bracing raises the left-chest shield; leaning back withdraws
	# the head, but exposes the abdomen and compromises saddle stability.
	var guard = float(fighter.get("guard",0.0))
	var local = Vector2(lerpf(44,55,smoothstep(0,.43,guard))-float(fighter.get("shield_compression",0.0)),lerpf(-4.0,-109.0,guard))
	# The shield turns around its handle, not independently of the left hand.
	var grip = Vector2(-10,4)
	local += grip-grip.rotated(float(fighter.get("shield_twist",0.0)))
	return rider_origin(fighter)+local.rotated(pose_angle(fighter))*Vector2(int(fighter.direction),1)

static func shield_angle(fighter: Dictionary) -> float:
	return pose_angle(fighter)+float(fighter.get("shield_twist",0.0))

static func shield_transform(fighter: Dictionary) -> Transform2D:
	return Transform2D(Vector2(int(fighter.direction),0),Vector2.DOWN,shield_position(fighter))*Transform2D(shield_angle(fighter),Vector2.ZERO)

static func shield_grip(fighter: Dictionary) -> Vector2:
	return shield_transform(fighter)*Vector2(-10,4)

static func reaction_strength(event: Dictionary) -> float:
	# Presentation loading, separate from injury: a solid shield transfers
	# little damage but must visibly take the arriving lance's momentum.
	if event.get("zone","")=="shield":return Feedback.shield_loading(event)
	var transfer = .48 if bool(event.get("glanced",false)) else .75
	return clampf(maxf(float(event.get("impulse",0.0))/85.0,clampf(float(event.get("speed",0.0))/900.0,0,1)*transfer),0,1)

static func advance_reaction(fighter: Dictionary, delta: float) -> void:
	# Same constrained spring pose drives visible shoulders, grips AND targets.
	# Impacts add velocity only, never a new position or a free aim command.
	RiderCondition.advance_pose(fighter,delta)
	var remaining = maxf(0.0,minf(delta,.25))
	while remaining>.000001:
		var dt = minf(remaining,1.0/120.0)
		var trunk_hit = str(fighter.get("last_hit","")) in ["body","flank"]
		var shield_hit = str(fighter.get("last_hit",""))=="shield"
		# A committed hit carries the torso through a visible loss of posture;
		# shoulders/grips/targets still use this one continuously integrated pose.
		for config in [["reaction_angle","reaction_angular_velocity",52.0 if trunk_hit else (72.0 if shield_hit else 105.0),10.0 if trunk_hit else (14.0 if shield_hit else 12.0),-.68 if trunk_hit else -.48,.58 if trunk_hit else .34],
			["reaction_shift","reaction_shift_velocity",250.0,20.0,-13.0,3.0],
			["shield_compression","shield_compression_velocity",330.0,24.0,-3.0,24.0],
			["shield_twist","shield_twist_velocity",150.0,14.0,-.32,.32],
			["lance_compression","lance_compression_velocity",360.0,24.0,-2.0,12.0],
			# FEEL-097 presentation only (no hit anchor reads these): legs thrown
			# out of the stirrups, and the horse knocked back onto its haunches.
			["reaction_legs","reaction_legs_velocity",70.0,7.5,-.60,1.50],
			["reaction_horse","reaction_horse_velocity",55.0,8.5,-.50,1.40]]:
			var position_key = str(config[0])
			var velocity_key = str(config[1])
			var displacement = float(fighter.get(position_key,0.0))
			var velocity = float(fighter.get(velocity_key,0.0))
			velocity += (-float(config[2])*displacement-float(config[3])*velocity)*dt
			var next = clampf(displacement+velocity*dt,float(config[4]),float(config[5]))
			if next==float(config[4]) and velocity<0.0 or next==float(config[5]) and velocity>0.0:
				velocity = 0.0
			fighter[position_key] = next
			fighter[velocity_key] = velocity
		# Head orientation lags a torso blow, then returns through the neck.
		# Its centre stays on the shared head collision anchor.
		var neck_target = clampf(-float(fighter.reaction_angle)*.45,-.18,.18) if trunk_hit or shield_hit else 0.0
		fighter.reaction_neck_velocity = float(fighter.get("reaction_neck_velocity",0.0))+(45.0*(neck_target-float(fighter.get("reaction_neck",0.0)))-8.0*float(fighter.get("reaction_neck_velocity",0.0)))*dt
		# FEEL-097: a helm strike whips the head back further than a torso blow
		# carries it forward. It still turns about the head target's centre.
		var neck = clampf(float(fighter.get("reaction_neck",0.0))+float(fighter.reaction_neck_velocity)*dt,NECK_RANGE.x,NECK_RANGE.y)
		if neck==NECK_RANGE.x and float(fighter.reaction_neck_velocity)<0.0 or neck==NECK_RANGE.y and float(fighter.reaction_neck_velocity)>0.0:
			fighter.reaction_neck_velocity = 0.0
		fighter.reaction_neck = neck
		remaining -= dt

static func flank_position(fighter: Dictionary) -> Vector2:
	return body_position(fighter)+Vector2(-6.0*int(fighter.direction),34.0)

static func lance_length(fighter: Dictionary) -> float:
	return 66.0 if fighter.broken else float(fighter.stats.get("reach", 247.0))

static func tip_position(fighter: Dictionary) -> Vector2:
	return hand_position(fighter) + Vector2(cos(float(fighter.aim)) * int(fighter.direction), sin(float(fighter.aim))) * lance_length(fighter)

func _cache_pose(fighter: Dictionary) -> void:
	fighter.prev_x = fighter.x
	fighter.prev_hand = hand_position(fighter)
	# Same immutable sampling instant: reuse the hand/body already evaluated.
	# No cross-tick cache and no reduced physics rate or sweep resolution.
	fighter.prev_tip = fighter.prev_hand + Vector2(cos(float(fighter.aim))*int(fighter.direction),sin(float(fighter.aim)))*lance_length(fighter)
	fighter.prev_aim = fighter.aim
	fighter.prev_length = lance_length(fighter)
	fighter.prev_body = body_position(fighter)
	fighter.prev_head = head_position(fighter)
	fighter.prev_shield = shield_position(fighter)
	fighter.prev_shield_angle = shield_angle(fighter)
	fighter.prev_flank = fighter.prev_body+Vector2(-6.0*int(fighter.direction),34.0)

func set_controls(index: int, aim: float, lean: float, boost: bool, delta: float, guard: float = -1.0) -> void:
	# A paused/frozen update may sample input but cannot advance a pose. The
	# near-target convergence tolerances must not move a limb without time.
	if delta<=0.0: return
	var fighter = fighters[index]
	if bool(fighter.get("ko",false)) or bool(fighter.get("dead",false)): return
	var distance = absf(float(fighters[0].x)-float(fighters[1].x))
	# Remaining reaction time, not a fixed distance, determines the close pass.
	# Releasing the spur buys adjustment time at the cost of one's own drive.
	var closing_speed = maxf(1.0,float(fighters[0].speed)+float(fighters[1].speed))
	var contact_time = maxf(0.0,distance-lance_length(fighter)-40.0)/closing_speed
	var committed = phase=="charge" and contact_time<.85 and float(fighters[0].x)<float(fighters[1].x)
	var pace_load = smoothstep(TROT_SPEED,GALLOP_SPEED,float(fighter.speed))
	var previous_aim = float(fighter.aim)
	var previous_rates = Vector3(float(fighter.get("aim_rate",0.0)),float(fighter.get("guard_rate",0.0)),float(fighter.get("lean_velocity",0.0)))
	# EQUIP-066: armour weight slows lance redirection, guard moves and the
	# recovery of lance support (light kit = quicker hands, heavy = slower).
	var agility = Condition.agility(fighter.stats)*RiderCondition.control_factor(fighter)
	# EQUIP-068: tired arms (from waving lance and shield) move slower too.
	var arm_factor = Condition.arm_factor(float(fighter.get("arm",100.0)))
	# EQUIP-068 (user request): the lance and shield ease in and out like the
	# lean, instead of starting and stopping at full speed in one frame.
	var aim_max = (.95 if committed else 2.2)*lerpf(1.0,.75,pace_load)*float(fighter.stats.get("lance_handling",1.0))*agility*arm_factor
	var aim_motion = eased(previous_aim,clampf(aim,-.68,.58),float(fighter.get("aim_rate",0.0)),aim_max,delta)
	fighter.aim = aim_motion.x
	fighter.aim_rate = aim_motion.y
	fighter.aim_velocity = absf(float(fighter.aim)-previous_aim)/maxf(delta,.00001)
	var movement = float(fighter.aim_velocity)
	# Holding a relative angle OR compensating for the horse's vertical
	# travel is a stable carry. Only the remaining intentional redirection
	# pays the feint cost; otherwise the stronger gait punishes bracing.
	var signed_turn = (float(fighter.aim)-previous_aim)/maxf(delta,.00001)
	var mount_compensation = float(fighter.get("mount_velocity_y",0.0))/maxf(40,cos(float(fighter.aim))*lance_length(fighter))
	movement = minf(movement,absf(signed_turn+mount_compensation))
	# Small corrections are free. Large late redirects sacrifice the support
	# behind the lance; the player keeps control instead of hitting an input lock.
	if movement>.24:
		fighter.lance_stability = maxf(.12,float(fighter.lance_stability)-(movement-.24)*delta*1.9)
	else:
		fighter.lance_stability = minf(1.0,float(fighter.lance_stability)+delta*.72*agility)
	if guard>=0:
		fighter.guard_target = clampf(guard,0,1)
	var previous_guard = float(fighter.guard)
	fighter.guard_stun = maxf(0.0,float(fighter.get("guard_stun",0.0))-delta)
	var guard_motion = eased(previous_guard,float(fighter.guard_target),float(fighter.get("guard_rate",0.0)),2.8*lerpf(1.0,.85,pace_load)*float(fighter.stats.get("shield_handling",1.0))*agility*arm_factor*(.55 if float(fighter.get("guard_stun",0.0))>0 else 1.0),delta)
	fighter.guard = guard_motion.x
	fighter.guard_rate = guard_motion.y
	# EQUIP-068 arm fatigue: big lance redirects and shield swings tire the arms
	# (heavier lance/shield tire faster); holding still lets them recover.
	var guard_speed = absf(float(fighter.guard)-previous_guard)/maxf(delta,.00001)
	var arm_rate = Condition.arm_rate(fighter.stats,movement,guard_speed)
	if arm_rate<0:
		fighter.arm_rest_delay = .40
	else:
		fighter.arm_rest_delay = maxf(0.0,float(fighter.get("arm_rest_delay",0.0))-delta)
		if fighter.arm_rest_delay>0: arm_rate=0.0
	fighter.arm = clampf(float(fighter.get("arm",100.0))+arm_rate*delta,0.0,100.0)
	var difference = clampf(lean,-1,1)-float(fighter.lean)
	# EQUIP-067 (user approved): lean switches faster, 1.6->2.3/s top speed and
	# 6->9/s^2 build-up; still eased in and out, never an instant snap.
	var target_velocity = clampf(difference*5.5,-2.3,2.3)
	fighter.lean_velocity = move_toward(float(fighter.lean_velocity),target_velocity,delta*9.0)
	if absf(difference)<minf(.004,2.3*delta) and absf(float(fighter.lean_velocity))<.06:
		fighter.lean = clampf(lean,-1,1)
		fighter.lean_velocity = 0.0
	else:
		fighter.lean = clampf(float(fighter.lean)+float(fighter.lean_velocity)*delta,-1,1)
	fighter.boost = boost
	# FEEL-094: abrupt changes of lance, shield and lean build fidget; the
	# allowance (FIDGET_FREE, per s^2) leaves smooth deliberate moves nearly free.
	var step_time = maxf(delta,.00001)
	var aim_jerk = float(fighter.aim_rate)-previous_rates.x
	var lean_jerk = float(fighter.lean_velocity)-previous_rates.z
	var jolt = FIDGET_WEIGHT.aim*maxf(0.0,absf(aim_jerk)-FIDGET_FREE.aim*step_time)
	jolt += FIDGET_WEIGHT.guard*maxf(0.0,absf(float(fighter.guard_rate)-previous_rates.y)-FIDGET_FREE.guard*step_time)
	jolt += FIDGET_WEIGHT.lean*maxf(0.0,absf(lean_jerk)-FIDGET_FREE.lean*step_time)
	if jolt>0.0:
		add_fidget(fighter,jolt*lerpf(.7,1.25,pace_load))
	# Throwing the weight forward leaves the torso behind for a moment;
	# dropping the lance pulls it forward. Velocity kicks on the sway spring.
	fighter.sway_velocity = float(fighter.get("sway_velocity",0.0))+(-.16*lean_jerk+.05*aim_jerk*(1.0+float(fighter.get("unsteady",0.0))))*unsteady_scale
	fighter.seat_velocity = float(fighter.get("seat_velocity",0.0))+(-lean_jerk*9.0+aim_jerk*2.5)*pace_load

## Critically damped-ish follower used for lance aim and shield guard:
## desired speed shrinks near the target (ease-out) and speed changes at a
## limited rate (ease-in). Returns Vector2(new value, new velocity).
static func eased(value: float, target: float, velocity: float, max_speed: float, delta: float) -> Vector2:
	if delta<=0.0: return Vector2(value,velocity)
	var difference = target-value
	# equip068-arm01: gain 9 made a full sweep ~80% slower than the old linear
	# motion; 16/14 keeps the ease while staying close to the old response.
	var desired = clampf(difference*16.0,-max_speed,max_speed)
	velocity = move_toward(velocity,desired,maxf(.5,max_speed*14.0)*delta)
	var next = value+velocity*delta
	if signf(target-next)!=signf(difference) or (absf(target-next)<.0015 and absf(velocity)<.04 and absf(difference)<=max_speed*delta):
		return Vector2(target,0.0)
	return Vector2(next,velocity)

func step(delta: float) -> void:
	for fighter in fighters:
		advance_reaction(fighter,delta)
		advance_unsteady(fighter,delta,phase=="charge")
	_consume_seat_exits113()
	if phase == "ended":
		return
	if bool(fighters[0].ko) or bool(fighters[1].ko):
		_finish("terminal")
		return
	time_elapsed += delta
	if phase == "ready" or phase == "turn":
		phase_time -= delta
		if phase_time <= 0.0:
			if phase == "turn":
				_reset_positions()
				phase = "ready"
				phase_time = 1.7
				events.append({"type": "rerack", "pass": pass_number})
			else:
				phase = "charge"
				events.append({"type": "charge"})
		for fighter in fighters:
			# HORSE-065: the horse gets its breath back between passes, partly.
			fighter.stamina = minf(100.0,float(fighter.stamina)+Condition.rest_rate(fighter.stats)*delta)
			fighter.arm = minf(100.0,float(fighter.get("arm",100.0))+Condition.ARM_REST*delta)
			# The inactive turn phase still shows the horses riding out.
			# No contacts are evaluated here; reracking resets all anchors.
			fighter.gait_moving = phase=="turn" and float(fighter.speed)>.5
			if fighter.gait_moving:
				release_drive_pose(fighter,delta)
				fighter.x += int(fighter.direction)*float(fighter.speed)*delta
				fighter.gait_phase += delta*TAU*Gait.frequency(float(fighter.speed))
			_cache_pose(fighter)
		return
	for fighter in fighters:
		var old_mount_hand = hand_position(fighter)
		# HORSE-065: load (rider, armour, helmet, shield, lance) against the
		# horse's capacity sets drain, recovery and a small speed factor. A tired
		# horse can still be urged, but its gallop ceiling sinks toward a canter
		# instead of the old hard stop at 1% stamina.
		var multiplier = float(fighter.stats.get("speed", 1.0))*Condition.load_speed_factor(fighter.stats)
		var accelerating = bool(fighter.boost)
		var stamina_rate = -Condition.drain_rate(fighter.stats) if accelerating else Condition.recovery_rate(fighter.stats,float(fighter.speed),GALLOP_SPEED*multiplier,TROT_SPEED*multiplier)
		fighter.stamina = clampf(float(fighter.stamina)+stamina_rate*delta,0.0,100.0)
		var ceiling = Condition.gallop_ceiling(float(fighter.stamina))
		var target_speed = (maxf(GALLOP_SPEED*ceiling,TROT_SPEED) if accelerating else TROT_SPEED) * multiplier
		if float(fighter.surge) > 0.0 and not time_effect_active:
			if accelerating:
				target_speed = SURGE_SPEED * multiplier * ceiling
			fighter.surge = maxf(0.0, float(fighter.surge) - delta)
		var difference = target_speed-float(fighter.speed)
		var accel_factor = Condition.acceleration_factor(fighter.stats,float(fighter.stamina))
		var desired_acceleration = (ACCELERATION*accel_factor if accelerating else START_ACCELERATION) if difference>0 else -COAST_DECELERATION
		if absf(difference)<.001:
			desired_acceleration = 0
		fighter.accel_command = move_toward(float(fighter.get("accel_command",0.0)),desired_acceleration,ACCELERATION_SLEW*delta)
		# Releasing the spur starts deceleration on this tick, even during a
		# rising acceleration envelope. The horse still coasts with inertia.
		if difference<0 and float(fighter.accel_command)>0:
			fighter.accel_command = -COAST_DECELERATION*.45
		elif difference>0 and float(fighter.accel_command)<0:
			fighter.accel_command = ACCELERATION*.28
		var old_speed = float(fighter.speed)
		fighter.speed = move_toward(old_speed,target_speed,absf(float(fighter.accel_command))*delta)
		fighter.acceleration = (float(fighter.speed)-old_speed)/maxf(.00001,delta)
		var old_drive = float(fighter.get("motion_drive",0.0))
		advance_drive(fighter,float(fighter.acceleration)/ACCELERATION,delta)
		# FEEL-094: pumping the spur on and off jerks the seat as well.
		add_fidget(fighter,FIDGET_WEIGHT.drive*absf(float(fighter.motion_drive)-old_drive))
		advance_seat(fighter,delta)
		fighter.x += int(fighter.direction) * float(fighter.speed) * delta
		fighter.gait_moving = true
		fighter.gait_phase += delta*TAU*Gait.frequency(float(fighter.speed))
		fighter.mount_velocity_y = (hand_position(fighter).y-old_mount_hand.y)/maxf(.00001,delta)
	# Gather both candidates BEFORE applying either result, preserving simultaneous hits.
	var contacts: Array = []
	for i in range(2):
		if not fighters[i].acted:
			var contact = _detect_contact(i, delta)
			if not contact.is_empty():
				contacts.append(contact)
	# Both strikes were already committed before this batch landed. Newly
	# received injury cannot retroactively weaken the second enumerated hit.
	# Existing injuries still affect strength; later physics steps recapture it.
	for contact in contacts:
		contact["attacker_strength113"] = RiderCondition.strength_factor(fighters[int(contact.attacker)])
	for contact in contacts:
		_apply_contact(contact)
	for fighter in fighters:
		_cache_pose(fighter)
	if fighters[0].ko or fighters[1].ko or fighters[0].dead or fighters[1].dead:
		_finish("terminal")
	elif float(fighters[0].x) > EXIT_X and float(fighters[1].x) < -EXIT_X:
		if pass_number >= MAX_PASSES:
			_finish("hp")
		else:
			pass_number += 1
			phase = "turn"
			phase_time = 1.6
			events.append({"type": "turn", "pass": pass_number})

static func swept_circle(old_tip: Vector2, new_tip: Vector2, old_center: Vector2, new_center: Vector2, radius: float) -> float:
	var start = old_tip - old_center
	var end = new_tip - new_center
	if start.length_squared() <= radius * radius:
		return 0.0
	return Geometry2D.segment_intersects_circle(start, end, Vector2.ZERO, radius)

static func swept_lance(old_hand: Vector2, new_hand: Vector2, old_angle: float, new_angle: float, old_length: float, new_length: float, direction: int, old_center: Vector2, new_center: Vector2, radius: float, delta: float) -> Dictionary:
	# Subdivide the rotational arc as well as sweeping relative translation.
	# At normal 120 Hz the angular step is <0.038 rad. Eight-pixel arc chords
	# also cover deliberately exaggerated test poses and longer shop lances.
	var angle_delta = new_angle - old_angle
	var segments = maxi(1, ceili(absf(angle_delta) * maxf(old_length,new_length) / 8.0))
	var previous = old_hand + Vector2(cos(old_angle)*direction,sin(old_angle))*old_length
	var arc_margin = maxf(old_length,new_length)*(1.0-cos(absf(angle_delta)/segments*.5))
	for segment in range(segments):
		var t0 = float(segment)/segments
		var t1 = float(segment+1)/segments
		var angle = lerpf(old_angle,new_angle,t1)
		var current = old_hand.lerp(new_hand,t1) + Vector2(cos(angle)*direction,sin(angle))*lerpf(old_length,new_length,t1)
		# Sagitta bounds the curved path outside each linear sweep chord.
		var fraction = swept_circle(previous,current,old_center.lerp(new_center,t0),old_center.lerp(new_center,t1),radius+maxf(.01,arc_margin))
		if fraction >= 0.0:
			return {"fraction":lerpf(t0,t1,fraction),"point":previous.lerp(current,fraction),
				"velocity":(current-previous)/maxf(delta/segments,0.000001)}
		previous = current
	return {}

func _detect_contact(index: int, delta: float) -> Dictionary:
	var attacker = fighters[index]
	var defender = fighters[1 - index]
	# Once well past a target, a lance pointing forward cannot hit backwards.
	if (float(defender.x) - float(attacker.x)) * int(attacker.direction) < -115.0:
		return {}
	var current_hand = hand_position(attacker)
	var current_shield_angle = shield_angle(defender)
	var targets = [
		{"zone": "head", "center": head_position(defender), "old": defender.prev_head, "radius": 24.0},
		{"zone": "body", "center": body_position(defender), "old": defender.prev_body, "radius": 30.0},
		{"zone":"flank","center":flank_position(defender),"old":defender.prev_flank,"radius":22.0}]
	if float(defender.shield) > 0.0:
		# The circle is only a cheap broad phase; the shared outline resolves contact.
		targets.append({"zone": "shield", "center": shield_position(defender), "old": defender.prev_shield, "radius": 60.0*float(defender.stats.get("shield_scale",1.0))})
	var earliest = 2.0
	var found: Dictionary = {}
	var sweep: Dictionary = {}
	for target in targets:
		var candidate = swept_lance(attacker.prev_hand,current_hand,attacker.prev_aim,attacker.aim,attacker.prev_length,lance_length(attacker),int(attacker.direction),target.old,target.center,target.radius,delta)
		if target.zone=="shield" and not candidate.is_empty():
			candidate = Shield.sweep(attacker.prev_hand,current_hand,attacker.prev_aim,attacker.aim,attacker.prev_length,lance_length(attacker),int(attacker.direction),target.old,target.center,float(defender.get("prev_shield_angle",current_shield_angle)),current_shield_angle,int(defender.direction),str(defender.stats.get("shield_shape","kite")),delta,float(defender.stats.get("shield_scale",1.0)))
		if not candidate.is_empty() and float(candidate.fraction) < earliest:
			earliest = candidate.fraction
			found = target
			sweep = candidate
	if found.is_empty():
		return {}
	var tip_velocity = Vector2(sweep.velocity)
	var target_velocity = (Vector2(found.center) - Vector2(found.old)) / maxf(delta, 0.0001)
	# lane_y is drawing depth, not a hill the near rider must climb. Remove
	# that projected lane offset from elevation for axial force only. Keep
	# the visible shaft/sweep/contact point untouched, so aiming stays exact.
	var reach = maxf(1.0,lerpf(float(attacker.prev_length),lance_length(attacker),float(sweep.fraction)))
	var visual_angle = lerpf(float(attacker.prev_aim),float(attacker.aim),float(sweep.fraction))
	var elevation = asin(clampf((sin(visual_angle)*reach-float(defender.get("lane_y",0.0))+float(attacker.get("lane_y",0.0)))/reach,-1.0,1.0))
	var shaft = Vector2(cos(elevation)*int(attacker.direction),sin(elevation))
	# Rotation contributes to the swept hit and incidence below. Its velocity
	# is perpendicular to the real shaft, so it cannot create axial thrust.
	var hand_velocity = (current_hand-Vector2(attacker.prev_hand))/maxf(delta,0.0001)
	var relative_speed = clampf((hand_velocity-target_velocity).dot(shaft),30.0,1050.0)
	var event = {"attacker": index, "defender": 1 - index, "zone": found.zone, "speed": relative_speed,
		"position": sweep.point, "type": "hit", "combat_elevation":elevation,"shaft_alignment":clampf(cos(elevation),.4,1.0),
		# Presentation-only pre-impact motion. Capture before either simultaneous
		# contact changes a rider; fracture pieces must not use a fixed toss.
		"break_hand_velocity":hand_velocity,
		"break_angular_velocity":angle_difference(float(attacker.prev_aim),float(attacker.aim))*int(attacker.direction)/maxf(delta,.0001)}
	if found.zone=="shield":
		event.contact_local = sweep.contact_local
		event.merge(Shield.contact_region(sweep.contact_local,sweep.local_incoming,str(defender.stats.get("shield_shape","kite")),float(defender.stats.get("shield_scale",1.0))))
	elif found.zone=="head":
		# Outward normal at the actual entry point, with target translation at
		# the same sweep fraction. Do not use screen position or merely aim height.
		var center_at_contact = Vector2(found.old).lerp(found.center,float(sweep.fraction))
		var normal = Vector2(sweep.point)-center_at_contact
		var incoming = tip_velocity-target_velocity
		event.head_incidence = clampf(-incoming.normalized().dot(normal.normalized()),0,1) if normal.length_squared()>.0001 and incoming.length_squared()>.0001 else 0.0
	return event

func _apply_contact(contact: Dictionary) -> void:
	var attacker = fighters[int(contact.attacker)]
	var defender = fighters[int(contact.defender)]
	attacker.acted = true
	var speed = float(contact.speed)
	var support = lerpf(.38,1.0,float(attacker.get("lance_stability",1.0)))
	var power = float(attacker.stats.get("power",1.0))*(.66 if attacker.broken else 1.0)*(1.0+maxf(float(attacker.lean),0)*.08-maxf(-float(attacker.lean),0)*.28)*support
	power *= Condition.drive(float(attacker.speed),GALLOP_SPEED)
	power *= float(contact.get("attacker_strength113",RiderCondition.strength_factor(attacker)))
	contact["drive"] = Condition.drive(float(attacker.speed),GALLOP_SPEED)
	var alignment = clampf(float(contact.get("shaft_alignment",cos(float(attacker.aim)))), 0.4, 1.0)
	var impulse = speed * 0.085 * power * alignment
	var damage = float(tuning.damage) * pow(speed / 620.0, 1.25) * power * alignment
	var energy = pow(speed/float(tuning.get("full_closing_speed",960.0)),float(tuning.get("speed_exponent",.95)))*power*alignment
	var continuous = bool(tuning.get("continuous_shield",false))
	if continuous:
		impulse = float(tuning.impulse)*energy
		damage = float(tuning.damage)*energy
	var armor_effect = float(tuning.armor_effect)
	var zone = str(contact.zone)
	if zone=="shield" and not contact.has("shield_region"):
		var inverse = shield_transform(defender).affine_inverse()
		contact.contact_local = inverse*Vector2(contact.position)
		var incoming = Vector2(cos(float(attacker.aim))*int(attacker.direction),sin(float(attacker.aim)))
		contact.merge(Shield.contact_region(contact.contact_local,inverse.basis_xform(incoming),str(defender.stats.get("shield_shape","kite")),float(defender.stats.get("shield_scale",1.0))))
	var glanced = false
	var head_outcome = ""
	var head_angle_factor = 1.0
	var unarmoured_head_damage = 0.0
	var shield_before = float(defender.shield)
	if zone == "head":
		unarmoured_head_damage = damage*1.38*1.32
		if continuous:
			var protection = clampf((float(defender.stats.get("helmet",.08))-.08)/.36,0,1)
			damage = lerpf(85.0,70.0,protection)*energy
			impulse *= .95
		else:
			damage *= 1.38 * (1.0 - float(defender.stats.get("helmet", 0.08))*armor_effect)
			impulse *= .86
		if mode=="war" or continuous:
			# Missing geometry can never award a new critical hit. Legacy synthetic
			# events keep their former damage, but actual sweeps always supply it.
			var incidence = clampf(float(contact.get("head_incidence",1.0)),0,1)
			head_angle_factor = lerpf(.22,1.0,smoothstep(.55,.90,incidence)) if continuous else lerpf(.20,1.0,incidence*incidence)
			glanced = incidence<.60
			damage *= head_angle_factor
			impulse *= lerpf(.25,1.0,smoothstep(.60,.90,incidence)) if continuous else lerpf(.25,1.0,incidence)
			head_outcome = "glance" if glanced else "solid"
	elif zone in ["body","flank"]:
		damage *= 1.0 - float(defender.stats.get("armor", 0.10))*armor_effect
		impulse *= 1.28 if zone=="flank" else 1.18
	else:
		if continuous:
			var transfer = shield_transfer(float(contact.get("eccentricity",0.0)),float(contact.get("combat_elevation",attacker.aim)),shield_angle(defender))
			var protection: Dictionary = defender.stats.get("shield_protection",{"leak":.10,"absorb":0.0})
			var factor = float(transfer.factor)
			glanced = factor<.55
			var raw_damage = float(tuning.shield_damage)*energy
			defender.shield = maxf(0.0,float(defender.shield)-raw_damage*lerpf(.30,1.0,factor))
			damage = raw_damage*float(protection.get("leak",.10))*pow(factor,1.5)
			impulse *= factor*(1.0-clampf(float(protection.get("absorb",0.0)),0,.15))
			contact.merge({"shield_transfer":factor,"position_factor":transfer.position,"angle_factor":transfer.angle,"shield_angle_difference":transfer.deviation})
			if glanced:
				defender.guard_stun = maxf(float(defender.get("guard_stun",0.0)),.20)
				attacker.lance_stability = maxf(.20,float(attacker.lance_stability)-.18*(1.0-factor))
				# Deflection injects velocity; the shaft never teleports to a new aim.
				attacker.aim_rate = clampf(float(attacker.get("aim_rate",0.0))+float(contact.get("lever",0.0))*.65,-.9,.9)
		else:
			var angle_difference = absf(float(contact.get("combat_elevation",attacker.aim)) - float(defender.lean) * 0.38)
			glanced = angle_difference > 0.16 or absf(float(defender.lean))>.35
			defender.shield = maxf(0.0, float(defender.shield) - damage * (0.7 if glanced else 1.15))
			damage *= float(tuning.shield_glance_damage) if glanced else float(tuning.shield_rider_damage)
			impulse *= float(tuning.shield_glance_impulse) if glanced else float(tuning.shield_impulse)
	if mode == "war" and zone != "shield":
		damage *= 1.32
	if mode=="war" and zone=="head":
		var committed = contact.has("head_incidence") and float(contact.head_incidence)>=WAR_HEAD_INCIDENCE and speed>=WAR_HEAD_SPEED and float(attacker.get("lance_stability",1.0))>=WAR_HEAD_STABILITY and not attacker.broken
		contact["head_severity"] = damage
		var load_before = float(defender.get("head_load",0.0))
		var load_quality = 0.0
		if contact.has("head_incidence") and not attacker.broken:
			# Continuous transfer avoids an all-or-nothing injury jump for a
			# one-pixel change near the edge or a tiny change in arm stability.
			load_quality = smoothstep(.60,.90,float(contact.head_incidence))*smoothstep(.45,.80,float(attacker.get("lance_stability",1.0)))
		var load_added = (damage+impulse*.40)*load_quality
		defender.head_load = load_before+load_added
		contact["head_load_before"] = load_before
		contact["head_load_added"] = load_added
		contact["head_load"] = defender.head_load
		contact["head_reason"] = "glance" if glanced else ("broken" if attacker.broken else ("unsteady" if float(attacker.get("lance_stability",1.0))<.65 else ("low_speed" if speed<600.0 else "solid")))
		if committed and damage>=WAR_HEAD_DAMAGE:
			head_outcome = "fatal"
			damage = maxf(damage,float(defender.hp))
		elif load_before>0.0 and load_added>=12.0 and float(defender.head_load)>=WAR_HEAD_LOAD_LIMIT:
			head_outcome = "cumulative_fatal"
			damage = maxf(damage,float(defender.hp))
		elif committed and unarmoured_head_damage*head_angle_factor>=WAR_HEAD_DAMAGE and damage<WAR_HEAD_DAMAGE:
			head_outcome = "helmet_block"
		contact["head_outcome"] = head_outcome
	defender.hp = maxf(0.0, float(defender.hp) - damage)
	attacker.damage_total += damage
	defender.last_hit = zone
	if zone != "shield" and damage > 11.0:
		defender.wounds.append({"zone":zone,"severity":damage})
	var brace = 1.0+maxf(float(defender.lean),0)*.14-maxf(-float(defender.lean),0)*.14
	# EQUIP-066: a heavier armoured rider sits more firmly (more inertia).
	var seat = Condition.seat(defender.stats)
	# FEEL-094: a rider caught mid-flail has a weaker seat and loses more balance.
	var unsteady = float(defender.get("unsteady",0.0))
	var threshold = float(tuning.ko_threshold) * float(defender.stats.get("stability", 1.0))*brace*seat*(1.0-UNSTEADY_THRESHOLD_LOSS*unsteady)
	threshold *= RiderCondition.support_factor(defender)
	if continuous:
		# A nearly stationary mount cannot carry the rider through the same
		# impulse. At full gallop the table's neutral-seat thresholds stay exact.
		threshold *= lerpf(.88,1.0,smoothstep(.30,1.0,float(defender.speed)/GALLOP_SPEED))
	defender.balance = maxf(0.0,float(defender.balance)-impulse*(float(tuning.head_balance_loss) if zone=="head" else float(tuning.balance_loss))/seat*(1.0+UNSTEADY_BALANCE_GAIN*unsteady))
	contact["unsteady"] = unsteady
	contact["ko_threshold"] = threshold
	contact["impulse_ratio"] = impulse/maxf(.001,threshold)
	var condition = RiderCondition.apply_hit(defender,contact,damage,impulse,threshold,mode)
	contact.merge(condition,true)
	var ko_reason = str(condition.ko_reason)
	var stress = speed * 0.062 * (1.15 if zone == "shield" else 0.8)
	attacker.durability = maxf(0.0, float(attacker.durability) - stress)
	var break_probability = break_chance(mode, impulse, float(attacker.stats.get("durability", 100.0)))
	var broke_now = not attacker.broken and (float(attacker.durability) <= 0.0 or rng.randf() < break_probability)
	var old_tip = tip_position(attacker)
	var old_hand = hand_position(attacker)
	var old_reach = lance_length(attacker)
	if broke_now:
		attacker.broken = true
	# EQUIP-067 tournament score (arena), after historical score cheques:
	# a clean shield strike 1, body/flank 2, helm 3, +1 for breaking the
	# lance on the strike; a glancing blow scores nothing. Unhorsing still ends
	# the match at once. Before, three passes with no fall were decided by a
	# few points of hidden health, which read as random.
	var points = 0
	var attaint = false
	if not glanced:
		points = {"shield":1,"body":2,"flank":2,"head":3}.get(zone,0)
		# EQUIP-069 (user approved): armour earns its keep in the score. A body
		# or helm strike counts in full only if enough force gets through the
		# armour (an "attaint"); a weaker one is a mere touch worth 1. Before,
		# scores ignored armour, so heavy kit kept only its costs in the arena
		# and light kit won 66% at equal skill (balance068-v0427-m1).
		if zone!="shield":
			attaint = damage>=ATTAINT_DAMAGE
			if not attaint:
				points = 1
		if broke_now:
			points += 1
	attacker.score = int(attacker.get("score",0))+points
	attacker.surge = 0.20
	defender.surge = 0.20
	contact.merge({"damage": damage, "impulse": impulse, "glanced": glanced, "broke": broke_now, "points": points, "attaint": attaint, "dead": defender.dead, "ko": defender.ko,"ko_reason":ko_reason,"support":support,"balance_left":defender.balance,"shield_broke":shield_before>0 and float(defender.shield)<=0,
		"break_tip":old_tip,"break_hand":old_hand,"break_reach":old_reach,"break_angle":attacker.aim,"break_direction":attacker.direction,
		# FEEL-097: ground speeds for the presentation of momentum (camera kick,
		# fall trajectory, horse jolt). Read only by visuals; no rule uses them.
		"attacker_speed":float(attacker.speed),"defender_speed":float(defender.speed),
		"defender_ground_y":float(defender.get("lane_y",0.0))+Gait.GROUND,
		"attacker_direction":int(attacker.direction),"defender_direction":int(defender.direction)})
	var loading = reaction_strength(contact)
	var angular_kick = -11.2 if zone=="head" else (9.0 if zone=="flank" else (-8.4 if zone=="shield" else -10.0))
	defender.reaction_angular_velocity = clampf(float(defender.get("reaction_angular_velocity",0.0))+angular_kick*loading,-12.0 if zone=="body" else -10.0,9.0 if zone=="flank" else 5.5)
	defender.reaction_shift_velocity = maxf(-170.0,float(defender.get("reaction_shift_velocity",0.0))-145.0*loading)
	if zone=="shield":
		var eccentricity = float(contact.get("eccentricity",0.0))
		var shield_motion = clampf(sqrt(3.0/maxf(1.0,float(defender.stats.get("shield_kg",3.0)))),.72,1.30)
		defender.shield_compression_velocity = minf(760.0,float(defender.get("shield_compression_velocity",0.0))+690.0*loading*lerpf(1.0,.62,eccentricity)*shield_motion)
		# Edge torque remains visible even when little force reaches the torso.
		# Only velocity changes here; the same handle-constrained spring moves it.
		var twist_loading=maxf(loading,clampf(float(contact.get("speed",0))/900.0,0,1)*.65*eccentricity)
		defender.shield_twist_velocity = clampf(float(defender.get("shield_twist_velocity",0.0))+10.5*twist_loading*float(contact.get("lever",0.0))*shield_motion,-10.0,10.0)
	attacker.lance_compression_velocity = minf(360.0,float(attacker.get("lance_compression_velocity",0.0))+320.0*loading)
	_kick_presentation(attacker,defender,zone,loading)
	events.append(contact)

static func shield_transfer(eccentricity: float, elevation: float, shield_pose: float) -> Dictionary:
	# Both angles are in each rider's facing-local coordinates. The incoming
	# shaft is mirrored at the opposing rider, hence the sum, not subtraction.
	var deviation = absf(wrapf(elevation+shield_pose,-PI,PI))
	var position = lerpf(1.0,.30,smoothstep(1.0/3.0,1.0,clampf(eccentricity,0,1)))
	var angle = lerpf(1.0,.30,smoothstep(deg_to_rad(15.0),deg_to_rad(40.0),deviation))
	return {"position":position,"angle":angle,"factor":position*angle,"deviation":deviation}

static func absorbs(own_speed: float) -> float:
	# A galloping horse carries momentum through the blow; one at a walk or
	# standing is shoved back onto its haunches by the same impulse.
	return lerpf(1.55,.70,smoothstep(0.0,GALLOP_SPEED,own_speed))

func _kick_presentation(attacker: Dictionary, defender: Dictionary, zone: String, loading: float) -> void:
	# FEEL-097: presentation springs only; geometry, damage and KO are already
	# settled above. Both riders take the same impulse (the attacker through
	# his lance rest), but the slower horse is the one visibly knocked back.
	if zone=="head":
		defender.reaction_neck_velocity = float(defender.get("reaction_neck_velocity",0.0))-HEAD_WHIP*loading
	var heavy = pow(loading,1.6)
	defender.reaction_legs_velocity = minf(16.0,float(defender.get("reaction_legs_velocity",0.0))+float(LEG_KICK.get(zone,8.0))*heavy)
	defender.reaction_horse_velocity = minf(14.0,float(defender.get("reaction_horse_velocity",0.0))+HORSE_KICK*pow(loading,1.3)*absorbs(float(defender.speed))*(.7 if zone=="shield" else 1.0))
	attacker.reaction_horse_velocity = minf(14.0,float(attacker.get("reaction_horse_velocity",0.0))+HORSE_KICK*.55*pow(loading,1.3)*absorbs(float(attacker.speed)))
	attacker.reaction_legs_velocity = minf(16.0,float(attacker.get("reaction_legs_velocity",0.0))+2.5*heavy)

static func break_chance(match_mode: String, impulse: float, durability: float = 100.0) -> float:
	var quality = clampf(100.0 / maxf(durability, 60.0), 0.55, 1.5)
	return clampf(((0.48 + impulse * 0.0030) if match_mode == "arena" else (0.055 + impulse * 0.0011)) * quality, 0.02, 0.94)

func advance_terminal_pose113(delta: float) -> void:
	for fighter in fighters:
		advance_reaction(fighter,delta)
		release_drive_pose(fighter,delta)
		advance_unsteady(fighter,delta,false)
	_consume_seat_exits113()

func _consume_seat_exits113() -> void:
	for index in range(fighters.size()):
		var f: Dictionary = fighters[index]
		if not bool(f.get("seat_exit_pending",false)): continue
		f.seat_exit_pending=false
		var reason = str(f.get("seat_exit_reason","seat"))
		var direction = int(signf(float(f.get("seat_velocity",-1.0))))*int(f.direction)
		if direction==0: direction=-int(f.direction)
		events.append({"type":"unseat","zone":"seat","attacker":-1,"defender":index,"position":rider_origin(f),"speed":f.speed,
			"damage":0.0,"impulse":0.0,"points":0,"broke":false,"attaint":false,"ko":true,"dead":f.dead,"unseated":true,
			"ko_reason":reason,"defender_speed":f.speed,"attacker_speed":0.0,"direction":direction,"balance_left":f.balance})
		if not result.is_empty(): result["player_unseated" if index==0 else "enemy_unseated"]=true

func _finish(reason: String) -> void:
	phase = "ended"
	var out_a = bool(fighters[0].ko) or bool(fighters[0].dead)
	var out_b = bool(fighters[1].ko) or bool(fighters[1].dead)
	var winner = -1
	if reason == "terminal":
		if out_a != out_b:
			winner = 1 if out_a else 0
	else:
		var score_a = int(fighters[0].get("score",0))
		var score_b = int(fighters[1].get("score",0))
		if mode=="arena" and score_a!=score_b:
			# Tournament: the score sheet decides; health only breaks a tie.
			winner = 0 if score_a>score_b else 1
			reason = "score"
		else:
			var difference = float(fighters[0].hp) - float(fighters[1].hp)
			if absf(difference) > 0.01:
				winner = 0 if difference > 0.0 else 1
	result = {"winner": winner, "reason": reason, "passes": pass_number, "mode": mode,
		"player_hp": fighters[0].hp, "enemy_hp": fighters[1].hp, "player_dead": fighters[0].dead, "enemy_dead": fighters[1].dead,
		"player_unseated":fighters[0].get("unseated",false),"enemy_unseated":fighters[1].get("unseated",false),
		"player_unconscious":fighters[0].get("unconscious",false),"enemy_unconscious":fighters[1].get("unconscious",false),
		"player_score": int(fighters[0].get("score",0)), "enemy_score": int(fighters[1].get("score",0))}
	events.append({"type": "end", "result": result.duplicate(true)})

func drain_events() -> Array:
	var pending = events
	events = []
	return pending
