class_name ExchangeDirector
extends RefCounted
## Presentation timing only. The owner supplies WALL-CLOCK delta and applies
## sample.scale; this class never writes Engine, Model, controls or coordinates.
## Contact events remain owned by the rules/FX consumers; summaries are copies.

const APPROACH_MAX_DURATION = 1.15
const APPROACH_ENTER_DURATION = .18
const APPROACH_MIN_SCALE = .45
const HITSTOP_MIN_DURATION = .045
const HITSTOP_MAX_DURATION = .085
const HITSTOP_SCALE = .001
const READ_DURATION = .25
const READ_SCALE = .32
const RELEASE_DURATION = .25
const FAST_RELEASE_DURATION = .12
const MAX_IMPACT_DURATION = HITSTOP_MAX_DURATION+READ_DURATION+RELEASE_DURATION
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
	if bool(b.focus_valid) and (not bool(a.focus_valid) or float(b.focus_strength)>float(a.focus_strength) or (float(b.focus_strength)==float(a.focus_strength) and _focus_precedes(b,a))):
		for key in ["focus","focus_valid","focus_strength","attacker"]:
			result[key] = b[key]
	return result

static func contact_strength(event: Dictionary) -> float:
	var strength = clampf(maxf(0.0,float(event.get("impulse",0.0)))/85.0,0.0,1.0)
	# A blocked blow can be loud and forceful while transferring little injury
	# impulse to its rider. Use actual contact speed for that presentation.
	var speed: Variant = event.get("speed",0.0)
	if event.get("zone","")=="shield" and (speed is int or speed is float) and is_finite(float(speed)):
		strength = maxf(strength,clampf(float(speed)/900.0,0.0,1.0)*.75)
	return strength

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
		if bool(event.get("ko",false)) or bool(event.get("dead",false)):
			strength = 1.0
		var duration = lerpf(HITSTOP_MIN_DURATION,HITSTOP_MAX_DURATION,strength)
		if str(event.get("zone","body"))=="shield":
			duration = maxf(HITSTOP_MIN_DURATION,duration*.86)
		var point: Variant = event.get("position")
		var valid_point = point is Vector2 and Vector2(point).is_finite()
		var attacker: Variant = event.get("attacker")
		var summary = {"strength":strength,"duration":duration,
			"focus":point if valid_point else Vector2.ZERO,"focus_valid":valid_point,
			"focus_strength":strength if valid_point else -1.0,
			"attacker":int(attacker) if attacker is int else 2147483647}
		_pending = _merge_summary(_pending,summary)

func _consume_contacts() -> void:
	if _pending.is_empty():
		return
	var prior = {"strength":_strength,"duration":_contact_duration,
		"focus":_focus,"focus_valid":_focus_valid,"focus_strength":_focus_strength,
		"attacker":_focus_attacker}
	var summary = _merge_summary(prior,_pending)
	_strength = summary.strength
	_contact_duration = summary.duration
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
	_release_duration = FAST_RELEASE_DURATION if fast else RELEASE_DURATION
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
			_scale = HITSTOP_SCALE
			_approach = 0.0
			_audio_duck = lerpf(.55,.85,_strength)
			_focus_weight = lerpf(.4,1.0,_strength) if _focus_valid else 0.0
		"read":
			_scale = READ_SCALE
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
			"read": duration = READ_DURATION
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
		"release":_release,"strength":_strength,"hitstop":_state=="contact",
		"pass_connected":_pass_connected,"impact_active":_impact_episode and _state in ["contact","read","release"],
		"paused":_paused,"pass_id":_pass_id,"stage_elapsed":_stage_elapsed,
		"impact_elapsed":_impact_elapsed,"approach_elapsed":_approach_elapsed}
