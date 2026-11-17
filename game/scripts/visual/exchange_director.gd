class_name ExchangeDirector
extends RefCounted
## Presentation timing only. The owner supplies WALL-CLOCK delta and applies
## sample.scale; this class never writes Engine, Model, controls or coordinates.
## Contact events remain owned by the rules/FX consumers; summaries are copies.

const APPROACH_MAX_DURATION = 1.15
const APPROACH_ENTER_DURATION = .18
const APPROACH_MIN_SCALE = .35
const CONTACT_LOAD_DURATION = .045
const CONTACT_LOAD_SCALE = .80
# FEEL-097 (user: hold the moment of impact longer): the freeze and the
# bullet-time read both grow with the actual contact strength, and an unhorsing
# gets the longest, deepest read. A glancing tap stays close to the old beat.
const HITSTOP_MIN_DURATION = .120
const HITSTOP_HEAVY_DURATION = .200
const KO_HITSTOP_DURATION = .230
const HITSTOP_MAX_DURATION = KO_HITSTOP_DURATION
const HITSTOP_SCALE = .001
const READ_MIN_DURATION = .40
const READ_HEAVY_DURATION = .85
const KO_READ_DURATION = 1.05 # FIX-104: readable fall without a prolonged defeat hold
const READ_DURATION = KO_READ_DURATION
const READ_LIGHT_SCALE = .28
const READ_HEAVY_SCALE = .16
const KO_READ_SCALE = .10
const KO_FLIGHT_SCALE = .32
const READ_SCALE = READ_LIGHT_SCALE
const RELEASE_DURATION = .24 # approach release after a miss
const IMPACT_RELEASE_LIGHT = .26
const IMPACT_RELEASE_HEAVY = .34
const KO_RELEASE_DURATION = .38
const FAST_RELEASE_DURATION = .12
const MAX_IMPACT_DURATION = KO_HITSTOP_DURATION+KO_READ_DURATION+KO_RELEASE_DURATION
const EPSILON = .00000001

var _state = "runup"
var _pass_id = 1
var _paused = false
var _slow_motion = true
var _stage_elapsed = 0.0
var _impact_elapsed = 0.0
var _approach_elapsed = 0.0
var _approach_used = false
var _pass_connected = false
var _impact_episode = false
var _scale = 1.0
var _approach = 0.0
var _audio_duck = 0.0
var _focus_weight = 0.0
var _release = 0.0
var _strength = 0.0
var _contact_duration = HITSTOP_MIN_DURATION
var _focus = Vector2.ZERO
var _focus_valid = false
var _focus_strength = -1.0
var _focus_attacker = 2147483647
var _entry_gap = 650.0
var _contact_gap = 250.0
var _release_from_scale = 1.0
var _release_from_approach = 0.0
var _release_from_duck = 0.0
var _release_from_focus = 0.0
var _release_duration = RELEASE_DURATION
var _read_duration = READ_MIN_DURATION
var _read_scale = READ_LIGHT_SCALE
var _impact_release = IMPACT_RELEASE_LIGHT
var _ko = false
var _pending: Dictionary = {}

func reset(pass_id: int = 1) -> void:
	_state = "runup"
	_pass_id = pass_id
	_paused = false
	_slow_motion = true
	_stage_elapsed = 0.0
	_impact_elapsed = 0.0
	_approach_elapsed = 0.0
	_approach_used = false
	_pass_connected = false
	_impact_episode = false
	_scale = 1.0
	_approach = 0.0
	_audio_duck = 0.0
	_focus_weight = 0.0
	_release = 0.0
	_strength = 0.0
	_contact_duration = HITSTOP_MIN_DURATION
	_focus = Vector2.ZERO
	_focus_valid = false
	_focus_strength = -1.0
	_focus_attacker = 2147483647
	_entry_gap = 650.0
	_contact_gap = 250.0
	_release_from_scale = 1.0
	_release_from_approach = 0.0
	_release_from_duck = 0.0
	_release_from_focus = 0.0
	_release_duration = RELEASE_DURATION
	_read_duration = READ_MIN_DURATION
	_read_scale = READ_LIGHT_SCALE
	_impact_release = IMPACT_RELEASE_LIGHT
	_ko = false
	_pending.clear()

func set_paused(value: bool) -> void:
	_paused = value

static func _number(value: Variant, fallback: float) -> float:
	if (value is int or value is float) and is_finite(float(value)):
		return float(value)
	return fallback

static func _ease(value: float) -> float:
	var t = clampf(value,0.0,1.0)
	return t*t*(3.0-2.0*t)

static func _focus_precedes(a: Dictionary, b: Dictionary) -> bool:
	if int(a.attacker)!=int(b.attacker):
		return int(a.attacker)<int(b.attacker)
	if float(a.focus.x)!=float(b.focus.x):
		return float(a.focus.x)<float(b.focus.x)
	return float(a.focus.y)<float(b.focus.y)

static func _merge_summary(a: Dictionary, b: Dictionary) -> Dictionary:
	if a.is_empty():
		return b.duplicate(true)
	var result = a.duplicate(true)
	result.strength = maxf(float(a.strength),float(b.strength))
	result.duration = maxf(float(a.duration),float(b.duration))
	result.read_duration = maxf(float(a.get("read_duration",READ_MIN_DURATION)),float(b.get("read_duration",READ_MIN_DURATION)))
	result.read_scale = minf(float(a.get("read_scale",READ_LIGHT_SCALE)),float(b.get("read_scale",READ_LIGHT_SCALE)))
	result.release = maxf(float(a.get("release",IMPACT_RELEASE_LIGHT)),float(b.get("release",IMPACT_RELEASE_LIGHT)))
	result.ko = bool(a.get("ko",false)) or bool(b.get("ko",false))
	if bool(b.focus_valid) and (not bool(a.focus_valid) or float(b.focus_strength)>float(a.focus_strength) or (float(b.focus_strength)==float(a.focus_strength) and _focus_precedes(b,a))):
		for key in ["focus","focus_valid","focus_strength","attacker"]:
			result[key] = b[key]
	return result

static func contact_strength(event: Dictionary) -> float:
	if event.get("zone","")=="shield":return preload("res://scripts/core/contact_feedback.gd").shield_loading(event)
	var strength = clampf(maxf(0.0,float(event.get("impulse",0.0)))/85.0,0.0,1.0)
	# Armour or a shield can transmit little injury while receiving a heavy
	# lance strike. Use actual incoming contact speed for this presentation,
	# never to increase damage. Scraping contact keeps a weaker visual accent.
	var speed: Variant = event.get("speed",0.0)
	if (speed is int or speed is float) and is_finite(float(speed)):
		var transfer = .48 if bool(event.get("glanced",false)) else .75
		strength = maxf(strength,clampf(float(speed)/900.0,0.0,1.0)*transfer)
	return strength

static func momentum(event: Dictionary, attacker_direction: int = 1) -> float:
	# FEEL-097: signed share of the pair's ground momentum along screen x for
	# equal masses: 0 for a symmetric head-on meeting (both stopped dead, a
	# vertical crunch), toward +-1 as one fast rider carries the collision.
	# Presentation only; damage already used the relative speed.
	var a = maxf(0.0,_number(event.get("attacker_speed"),0.0))
	var d = maxf(0.0,_number(event.get("defender_speed"),0.0))
	var a_dir = int(event.get("attacker_direction",attacker_direction))
	var d_dir = int(event.get("defender_direction",-attacker_direction))
	if a+d<1.0:
		return 0.0
	return clampf((a*a_dir+d*d_dir)/(a+d),-1.0,1.0)

func notify_contacts(events: Array) -> void:
	if _paused:
		return
	for event in events:
		if not event is Dictionary or event.get("type","")!="hit":
			continue
		var raw_impulse: Variant = event.get("impulse")
		if not (raw_impulse is int or raw_impulse is float) or not is_finite(float(raw_impulse)):
			continue
		# These are presentation tuning units, not historical force values.
		var strength = contact_strength(event)
		if bool(event.get("broke",false)):
			strength = minf(1.0,strength+.08)
		var ko = bool(event.get("ko",false)) or bool(event.get("dead",false))
		if ko:
			strength = 1.0
		var duration = KO_HITSTOP_DURATION if ko else lerpf(HITSTOP_MIN_DURATION,HITSTOP_HEAVY_DURATION,strength)
		if str(event.get("zone","body"))=="shield":
			duration = maxf(HITSTOP_MIN_DURATION,duration*.86)
		var point: Variant = event.get("position")
		var valid_point = point is Vector2 and Vector2(point).is_finite()
		var attacker: Variant = event.get("attacker")
		var summary = {"strength":strength,"duration":duration,"ko":ko,
			"read_duration":KO_READ_DURATION if ko else lerpf(READ_MIN_DURATION,READ_HEAVY_DURATION,strength),
			"read_scale":KO_READ_SCALE if ko else lerpf(READ_LIGHT_SCALE,READ_HEAVY_SCALE,strength),
			"release":KO_RELEASE_DURATION if ko else lerpf(IMPACT_RELEASE_LIGHT,IMPACT_RELEASE_HEAVY,strength),
			"focus":point if valid_point else Vector2.ZERO,"focus_valid":valid_point,
			"focus_strength":strength if valid_point else -1.0,
			"attacker":int(attacker) if attacker is int else 2147483647}
		_pending = _merge_summary(_pending,summary)

func _consume_contacts() -> void:
	if _pending.is_empty():
		return
	var prior = {"strength":_strength,"duration":_contact_duration,
		"focus":_focus,"focus_valid":_focus_valid,"focus_strength":_focus_strength,
		"attacker":_focus_attacker,"read_duration":_read_duration,"read_scale":_read_scale,
		"release":_impact_release,"ko":_ko}
	if not _pass_connected:
		# A fresh exchange starts from the incoming contact, not from the
		# previous pass's (reset) light defaults merged as a floor.
		prior = {}
	var summary = _merge_summary(prior,_pending)
	_strength = summary.strength
	_contact_duration = summary.duration
	_read_duration = float(summary.get("read_duration",READ_MIN_DURATION))
	_read_scale = float(summary.get("read_scale",READ_LIGHT_SCALE))
	_impact_release = float(summary.get("release",IMPACT_RELEASE_LIGHT))
	_ko = bool(summary.get("ko",false))
	_focus = summary.focus
	_focus_valid = summary.focus_valid
	_focus_strength = summary.focus_strength
	_focus_attacker = summary.attacker
	_pending.clear()
	if not _pass_connected:
		_pass_connected = true
		_approach_used = true
		_impact_episode = true
		_impact_elapsed = 0.0
		_state = "contact"
		_stage_elapsed = 0.0
	# Later hits can strengthen this exchange but cannot restart read/release
	# or stack additional cinematic time. Model still reports and applies them.

func _begin_release(impact: bool, fast: bool = false) -> void:
	_release_from_scale = _scale
	_release_from_approach = _approach
	_release_from_duck = _audio_duck
	_release_from_focus = _focus_weight
	_release_duration = FAST_RELEASE_DURATION if fast else (_impact_release if impact else RELEASE_DURATION)
	_impact_episode = impact
	_state = "release"
	_stage_elapsed = 0.0
	_release = 0.0

func _refresh(context: Dictionary) -> void:
	_release = 0.0
	match _state:
		"approach":
			var gap = _number(context.get("gap"),_entry_gap)
			var proximity = clampf((_entry_gap-gap)/maxf(1.0,_entry_gap-_contact_gap),0.0,1.0)
			_approach = _ease(_stage_elapsed/APPROACH_ENTER_DURATION)*_ease(proximity)
			_scale = lerpf(1.0,APPROACH_MIN_SCALE,_approach)
			_audio_duck = .15*_approach
			_focus_weight = 0.0 # Before contact the owner keeps its own duel framing.
		"contact":
			# Let the actual hit load the body/guard for a few frames before
			# holding it. Freezing the untouched pose made heavy hits look like taps.
			_scale = CONTACT_LOAD_SCALE if _stage_elapsed<CONTACT_LOAD_DURATION else HITSTOP_SCALE
			_approach = 0.0
			_audio_duck = lerpf(.55,.85,_strength)
			_focus_weight = lerpf(.4,1.0,_strength) if _focus_valid else 0.0
		"read":
			_scale = _read_scale
			# Hold the loaded blow deeply, then let the rider actually leave the
			# saddle and turn. A flat near-freeze hid the flight until time snapped
			# back. This curve is wall-clock driven; ballistics still use game time.
			if _ko:
				_scale = lerpf(_read_scale,KO_FLIGHT_SCALE,smoothstep(.35,1.0,_stage_elapsed/_read_duration))
			_approach = 0.0
			_audio_duck = lerpf(.4,.65,_strength)
			_focus_weight = lerpf(.4,1.0,_strength) if _focus_valid else 0.0
		"release":
			_release = clampf(_stage_elapsed/_release_duration,0.0,1.0)
			var blend = _ease(_release)
			_scale = lerpf(_release_from_scale,1.0,blend)
			_approach = _release_from_approach*(1.0-blend)
			_audio_duck = _release_from_duck*(1.0-blend)
			_focus_weight = _release_from_focus*(1.0-blend)
		_:
			_scale = 1.0
			_approach = 0.0
			_audio_duck = 0.0
			_focus_weight = 0.0

func advance(real_delta: float, context: Dictionary) -> Dictionary:
	if _paused:
		return sample()
	var pass_value: Variant = context.get("pass_id",_pass_id)
	var next_pass = int(pass_value) if pass_value is int else _pass_id
	if next_pass!=_pass_id:
		reset(next_pass)
	_slow_motion = bool(context.get("slow_motion",true))
	var phase = str(context.get("phase","charge"))
	if phase in ["ready","turn"]:
		reset(_pass_id)
		_slow_motion = bool(context.get("slow_motion",true))
		return sample()
	_consume_contacts()
	var gap = _number(context.get("gap"),INF)
	if _state=="runup" and phase=="charge" and _slow_motion and not _approach_used and not _pass_connected and gap>0.0:
		var reach = maxf(1.0,_number(context.get("reach"),250.0))
		var closing = maxf(1.0,_number(context.get("closing_speed"),420.0))
		var entry = clampf(reach+closing*.45,reach+160.0,maxf(650.0,reach+380.0))
		if gap<entry:
			_entry_gap = entry
			_contact_gap = reach
			_approach_used = true
			_state = "approach"
			_stage_elapsed = 0.0
	_refresh(context)
	if _state=="approach" and (not _slow_motion or phase!="charge" or gap<=0.0):
		_begin_release(false,not _slow_motion)
	elif _state=="read" and not _slow_motion:
		_begin_release(true,true)
	elif _state=="release" and not _slow_motion and _release_duration>FAST_RELEASE_DURATION:
		# Restart interpolation from its CURRENT value, never from the old
		# read scale. A late toggle must not turn .02s remaining into .12s
		# and silently exceed the exchange's original wall-clock budget.
		var remaining_release = maxf(EPSILON,_release_duration-_stage_elapsed)
		_begin_release(_impact_episode,true)
		_release_duration = minf(_release_duration,remaining_release)
	var remaining = maxf(0.0,_number(real_delta,0.0))
	# At most five transitions are possible; a long frame consumes every
	# elapsed stage rather than extending wall-clock budgets by a .1s clamp.
	for iteration in range(6):
		if _state=="runup" or remaining<=EPSILON:
			break
		var duration = APPROACH_MAX_DURATION
		match _state:
			"contact": duration = _contact_duration
			"read": duration = _read_duration
			"release": duration = _release_duration
		var spent = minf(remaining,maxf(0.0,duration-_stage_elapsed))
		_stage_elapsed += spent
		remaining -= spent
		if _state=="approach":
			_approach_elapsed += spent
		if _impact_episode and _state in ["contact","read","release"]:
			_impact_elapsed += spent
		_refresh(context)
		if _stage_elapsed+EPSILON<duration:
			break
		match _state:
			"approach": _begin_release(false)
			"contact":
				if _slow_motion:
					_state = "read"
					_stage_elapsed = 0.0
				else:
					_begin_release(true,true)
			"read": _begin_release(true)
			"release":
				_state = "runup"
				_stage_elapsed = 0.0
				_impact_episode = false
		_refresh(context)
	_refresh(context)
	return sample()

func sample() -> Dictionary:
	return {"state":_state,"scale":_scale,"approach":_approach,
		"focus":_focus,"focus_weight":_focus_weight,"audio_duck":_audio_duck,
		"release":_release,"strength":_strength,"hitstop":_state=="contact" and _stage_elapsed>=CONTACT_LOAD_DURATION,
		"contact_loading":_state=="contact" and _stage_elapsed<CONTACT_LOAD_DURATION,
		"pass_connected":_pass_connected,"impact_active":_impact_episode and _state in ["contact","read","release"],
		"paused":_paused,"pass_id":_pass_id,"stage_elapsed":_stage_elapsed,
		"impact_elapsed":_impact_elapsed,"approach_elapsed":_approach_elapsed,
		"ko":_ko,"read_duration":_read_duration,"read_scale":_read_scale,"release_duration":_release_duration}
