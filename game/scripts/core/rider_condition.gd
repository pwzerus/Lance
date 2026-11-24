extends RefCounted
## Injury, awareness and saddle support are separate from match elimination.
## Values are deterministic game tuning, not clinical or historical injury rates.
const DEFAULTS = {"injury":0.0,"injury_zone":"","injury_pose":0.0,"injury_pose_rate":0.0,
	"consciousness":100.0,"unconscious":false,"unseated":false,"control_stun":0.0,
	"seat_offset":0.0,"seat_velocity":0.0,"seat_support":1.0,"seat_escape_time":0.0,"seat_strain":0.0,
	"seat_exit_pending":false,"seat_exit_reason":"seat","slump":0.0,"slump_velocity":0.0,"pose_clock113":0.0}

static func initialize(fighter: Dictionary) -> void:
	fighter.merge(DEFAULTS,false)

static func control_factor(fighter: Dictionary) -> float:
	var injury = clampf(float(fighter.get("injury",0.0)),0,1)
	return (1.0-injury*.30)*(.60 if float(fighter.get("control_stun",0.0))>0 else 1.0)

static func support_factor(fighter: Dictionary) -> float:
	return (1.0-clampf(float(fighter.get("injury",0.0)),0,1)*.22)*lerpf(.70,1.0,clampf(float(fighter.get("seat_support",1.0)),0,1))

static func strength_factor(fighter: Dictionary) -> float:
	return 1.0-clampf(float(fighter.get("injury",0.0)),0,1)*.16

static func apply_hit(fighter: Dictionary, contact: Dictionary, damage: float, impulse: float, threshold: float, mode: String) -> Dictionary:
	initialize(fighter)
	var zone = str(contact.zone)
	var severity = maxf(0.0,damage)
	var injury_before = float(fighter.injury)
	var tissue = .35 if zone=="shield" else (1.12 if zone=="flank" else 1.0)
	fighter.injury = clampf(injury_before+severity*.01*tissue,0,1)
	if zone!="shield" and severity>=10.0: fighter.injury_zone=zone
	var awareness_loss = severity*(1.30 if zone=="head" else (.28 if zone in ["body","flank"] else .10))
	fighter.consciousness = maxf(0.0,float(fighter.consciousness)-awareness_loss)
	if severity>=12.0:
		fighter.control_stun = maxf(float(fighter.control_stun),lerpf(.10,.32,clampf(severity/65.0,0,1)))
	var ratio = impulse/maxf(.001,threshold)
	# A blow shifts velocity, never the visible seat position on contact.
	fighter.seat_velocity = clampf(float(fighter.seat_velocity)-ratio*38.0,-100.0,100.0)
	var lost_support = float(fighter.balance)<=0.0 and impulse>threshold*.28
	fighter.unseated = bool(fighter.unseated) or impulse>threshold or lost_support
	fighter.dead = mode=="war" and float(fighter.hp)<=0.0
	fighter.unconscious = bool(fighter.unconscious) or float(fighter.consciousness)<=0.0 or float(fighter.hp)<=0.0
	if fighter.unconscious: fighter.consciousness=0.0
	fighter.ko = bool(fighter.unseated) or bool(fighter.unconscious) or bool(fighter.dead)
	if fighter.ko:
		fighter.boost=false
		fighter.acted=true
	var reason = ""
	if fighter.dead: reason="fatal"
	elif fighter.unseated: reason="impact" if impulse>threshold else "balance"
	elif fighter.unconscious: reason="health" if float(fighter.hp)<=0 else "unconscious"
	return {"unseated":fighter.unseated,"unconscious":fighter.unconscious,"consciousness":fighter.consciousness,
		"injury_before":injury_before,"injury":fighter.injury,"ko_reason":reason,"seat_support":fighter.seat_support}

static func advance_pose(fighter: Dictionary, delta: float) -> void:
	initialize(fighter)
	fighter.pose_clock113+=maxf(0.0,delta)
	fighter.control_stun=maxf(0.0,float(fighter.control_stun)-delta)
	var incapacitated = bool(fighter.get("ko",false)) and not bool(fighter.unseated)
	var remaining = clampf(delta,0.0,.25)
	while remaining>.000001:
		var dt = minf(remaining,1.0/120.0)
		var injury_target = float(fighter.injury)*(.28 if str(fighter.injury_zone)=="flank" else .18)
		fighter.injury_pose_rate += (40.0*(injury_target-float(fighter.injury_pose))-12.7*float(fighter.injury_pose_rate))*dt
		fighter.injury_pose += float(fighter.injury_pose_rate)*dt
		var slump_target = 1.0 if incapacitated else 0.0
		fighter.slump_velocity += (28.0*(slump_target-float(fighter.slump))-10.6*float(fighter.slump_velocity))*dt
		fighter.slump = clampf(float(fighter.slump)+float(fighter.slump_velocity)*dt,0,1)
		remaining-=dt
	if incapacitated:
		# A limp grip lowers through a finite rate. No input/AI can instantly
		# restore aim, guard or posture while the fighter is unconscious.
		fighter.aim=move_toward(float(fighter.aim),.54,delta*.65)
		fighter.guard=move_toward(float(fighter.guard),.15,delta*.50)
		fighter.aim_rate=0.0; fighter.guard_rate=0.0; fighter.lean_velocity=0.0

static func advance_support(fighter: Dictionary, delta: float, riding: bool) -> void:
	initialize(fighter)
	if fighter.ko:
		advance_limp_support(fighter,delta)
		return
	var pace = smoothstep(210.0,480.0,float(fighter.get("speed",0.0))) if riding else 0.0
	var unsettled = float(fighter.get("unsteady",0.0))*pace
	var injury = float(fighter.injury)
	# Thigh support fatigues under sustained violent movement, not one
	# correction. Releasing the movement rebuilds support before a slip.
	var strain_rate = maxf(0.0,(unsettled-.55)/.45)*.32-.45*(1.0-smoothstep(.25,.55,unsettled))
	fighter.seat_strain=clampf(float(fighter.seat_strain)+strain_rate*delta,0,1)
	var stiffness = lerpf(90.0,9.0,unsettled)*(1.0-injury*.30)
	var damping = lerpf(16.0,3.5,unsettled)
	var remaining = clampf(delta,0.0,.25)
	while remaining>.000001:
		var dt = minf(remaining,1.0/120.0)
		var offset = float(fighter.seat_offset)
		var rate = float(fighter.seat_velocity)
		var drive = -float(fighter.get("acceleration",0.0))*.12-float(fighter.get("lean_velocity",0.0))*13.0
		# Existing visible sway supplies the signed load. No new random phase
		# or aim noise: stopping abrupt movements lets the seat recentre.
		drive += float(fighter.get("sway",0.0))*unsettled*95.0
		# With repeated large leans the trunk's centre of mass passes beyond
		# the weakened thigh support. A single deliberate lean retains strong
		# support; frantic small aim corrections alone do not eject the rider.
		var lean = float(fighter.get("lean",0.0))
		drive += signf(lean)*smoothstep(.35,.80,absf(lean))*unsettled*380.0*smoothstep(.45,.90,float(fighter.seat_strain))
		rate += (-stiffness*offset-damping*rate+drive*pace)*dt
		fighter.seat_velocity=clampf(rate,-120,120)
		fighter.seat_offset=offset+float(fighter.seat_velocity)*dt
		var span = lerpf(24.0,18.0,injury)
		fighter.seat_support=clampf(1.0-absf(float(fighter.seat_offset))/span,0,1)
		if riding and absf(float(fighter.seat_offset))>span:
			fighter.seat_escape_time+=dt
		else:
			fighter.seat_escape_time=maxf(0.0,float(fighter.seat_escape_time)-dt*2.0)
		if float(fighter.seat_escape_time)>=.10:
			fighter.unseated=true; fighter.ko=true; fighter.acted=true; fighter.boost=false
			fighter.seat_exit_reason="seat"
			fighter.seat_exit_pending=true
			break
		remaining-=dt

static func advance_limp_support(fighter: Dictionary, delta: float) -> void:
	if not fighter.ko or fighter.unseated: return
	var remaining=clampf(delta,0.0,.25)
	var span=lerpf(24.0,18.0,float(fighter.injury))
	while remaining>.000001:
		var dt=minf(remaining,1.0/120.0)
		var offset=float(fighter.seat_offset)
		var rate=float(fighter.seat_velocity)
		# The saddle still supports a centred unconscious body. Close to an
		# edge, active thigh bracing is gone and existing outward momentum can
		# carry the pelvis past the support; no automatic health-based launch.
		var edge=smoothstep(.65,1.05,absf(offset)/span)
		var stiffness=lerpf(30.0,0.0,edge)
		var drive=signf(offset)*230.0*edge-float(fighter.get("acceleration",0.0))*.08
		rate+=(stiffness*(float(fighter.slump)*4.0-offset)-7.0*rate+drive)*dt
		fighter.seat_velocity=clampf(rate,-90,90)
		fighter.seat_offset=offset+float(fighter.seat_velocity)*dt
		fighter.seat_support=clampf(1.0-absf(float(fighter.seat_offset))/span,0,1)
		fighter.seat_escape_time=float(fighter.seat_escape_time)+dt if absf(float(fighter.seat_offset))>span else 0.0
		if float(fighter.seat_escape_time)>=.10:
			fighter.unseated=true;fighter.seat_exit_pending=true;fighter.seat_exit_reason="slip"
			break
		remaining-=dt
