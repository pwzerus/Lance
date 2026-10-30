class_name SoundBank
extends Node

var enabled = true
var music: AudioStreamPlayer
var streams: Dictionary = {}
static var shared_streams: Dictionary = {}
const MAX_VOICES = 12
const IMPACT_VARIANTS = 3
const IMPACT_FAMILIES = ["helmet","plate","mail","padded","shield_wood","brigandine"]
const CONTACT_RATE = 44100
const CONTACT_GROUP_BUDGET = .78
# Exact pre-bake PCM peaks from audio-01's original 16-bit WAVs. QA compares
# these to imported PCM. Godot 4.5.1's cubic resampler has coefficient L1
# bound 1 + mu - mu^2 <= 1.25; allow its 32767 PCM divisor and float margin.
# https://github.com/godotengine/godot/blob/4.5.1-stable/servers/audio/audio_stream.cpp#L178-L205
const CONTACT_RESAMPLE_BOUND = 1.251
# This table is a conservative group gain bound, not a per-sample limiter.
const CONTACT_PEAKS = {
	"contact_helmet_solid_0":0.449401855,
	"contact_helmet_solid_1":0.445098877,
	"contact_helmet_solid_2":0.442871094,
	"contact_helmet_glance_0":0.179412842,
	"contact_helmet_glance_1":0.188323975,
	"contact_helmet_glance_2":0.174102783,
	"contact_plate_solid_0":0.445434570,
	"contact_plate_solid_1":0.428344727,
	"contact_plate_solid_2":0.440490723,
	"contact_plate_glance_0":0.187408447,
	"contact_plate_glance_1":0.189178467,
	"contact_plate_glance_2":0.189605713,
	"contact_mail_solid_0":0.340972900,
	"contact_mail_solid_1":0.343902588,
	"contact_mail_solid_2":0.339447021,
	"contact_mail_glance_0":0.179229736,
	"contact_mail_glance_1":0.194702148,
	"contact_mail_glance_2":0.191192627,
	"contact_padded_solid_0":0.434051514,
	"contact_padded_solid_1":0.468811035,
	"contact_padded_solid_2":0.484130859,
	"contact_padded_glance_0":0.203308105,
	"contact_padded_glance_1":0.195739746,
	"contact_padded_glance_2":0.203948975,
	"contact_shield_wood_solid_0":0.410278320,
	"contact_shield_wood_solid_1":0.438842773,
	"contact_shield_wood_solid_2":0.440490723,
	"contact_shield_wood_glance_0":0.168457031,
	"contact_shield_wood_glance_1":0.181488037,
	"contact_shield_wood_glance_2":0.170745850,
	"contact_brigandine_solid_0":0.426055908,
	"contact_brigandine_solid_1":0.439270020,
	"contact_brigandine_solid_2":0.415313721,
	"contact_brigandine_glance_0":0.198272705,
	"contact_brigandine_glance_1":0.201171875,
	"contact_brigandine_glance_2":0.190490723,
	"lance_break_0":0.351745605,
	"lance_break_1":0.346435547,
	"lance_break_2":0.341796875
}
const IMPACT_ASSET_DIR = "res://assets/audio/impact_v050/"
static var contact_generation_count = 0
# Audible responses, not historical acoustic measurements. Metal has a short
# shell attack over a heavy body; no sustained high sine serves as the hit.
const CONTACT_PROFILES = {
	"helmet":{"modes":[Vector3(84,.31,9),Vector3(176,.13,15),Vector3(431,.09,32),Vector3(781,.04,44)],"low":.17,"attack":.12,"grain":0.0},
	"plate":{"modes":[Vector3(64,.34,8),Vector3(129,.12,12),Vector3(282,.08,28),Vector3(697,.03,38)],"low":.18,"attack":.10,"grain":0.0},
	"mail":{"modes":[Vector3(72,.28,11),Vector3(151,.09,17)],"low":.14,"attack":.08,"grain":.22},
	"padded":{"modes":[Vector3(56,.36,10),Vector3(103,.12,15)],"low":.28,"attack":.055,"grain":0.0},
	"shield_wood":{"modes":[Vector3(105,.30,12),Vector3(192,.16,19),Vector3(397,.07,30),Vector3(946,.025,47)],"low":.14,"attack":.15,"grain":0.0},
	"brigandine":{"modes":[Vector3(80,.30,10),Vector3(184,.10,19),Vector3(543,.06,36)],"low":.16,"attack":.10,"grain":.14}
}
var voices: Array[AudioStreamPlayer] = []
var next_voice = 0
var playback_paused = false
var _music_start_on_resume = false
var _impact_counters: Dictionary = {}

func _ready() -> void:
	music = AudioStreamPlayer.new()
	if shared_streams.is_empty():
		for sound_name in ["impact","shield","break","hoof","click","horn","win","lose","lute_loop","wind_loop"]:
			shared_streams[sound_name] = _synthesize(sound_name)
	if not shared_streams.has("contact_helmet_solid_0"):
		# Precompute before combat; contact selection never synthesizes or loads
		# files in the first displayed impact frame. Shared across all banks.
		for family in IMPACT_FAMILIES:
			for kind in ["solid","glance"]:
				for variant in range(IMPACT_VARIANTS):
					var cue = _contact_name(family,kind,variant)
					shared_streams[cue] = _load_impact_stream(cue,family,kind,variant)
		for variant in range(IMPACT_VARIANTS):
			var cue = "lance_break_%d" % variant
			shared_streams[cue] = _load_impact_stream(cue,"break","solid",variant)
	streams = shared_streams
	music.stream = streams.lute_loop
	music.volume_db = -16.0
	add_child(music)
	music.finished.connect(_loop_music)
	music.stream_paused = playback_paused
	if enabled:
		if playback_paused:
			_music_start_on_resume = true
		else:
			music.play()

func set_paused(value: bool) -> void:
	# Battle is PROCESS_MODE_ALWAYS. Tree pause alone therefore does not
	# freeze this bank's inherited players; pause their actual playheads.
	playback_paused = value
	if is_instance_valid(music):
		music.stream_paused = value
	for voice in voices:
		voice.stream_paused = value
	if not value and _music_start_on_resume:
		_music_start_on_resume = false
		if enabled and is_instance_valid(music) and music.stream and not music.has_stream_playback():
			music.play()

func set_enabled(value: bool) -> void:
	enabled = value
	if not enabled:
		_music_start_on_resume = false
		for voice in voices:
			voice.stop()
	if music:
		if enabled and not music.has_stream_playback():
			if playback_paused:
				_music_start_on_resume = true
			else:
				music.stream_paused = false
				music.play()
		elif not enabled:
			music.stop()

func play(sound: String, volume_db: float = -5.0, pitch: float = 1.0) -> void:
	if not enabled or playback_paused:
		return
	# A bounded pool avoids accumulating playing nodes during a burst of
	# impacts/hooves, and makes scene teardown stop every active voice.
	var player: AudioStreamPlayer
	for voice in voices:
		if not voice.playing:
			player = voice
			break
	if not player:
		if voices.size() < MAX_VOICES:
			player = AudioStreamPlayer.new()
			voices.append(player)
			add_child(player)
		else:
			player = voices[next_voice]
			next_voice = (next_voice + 1) % MAX_VOICES
	player.stop()
	player.stream_paused = false
	player.stream = streams.get(sound,streams.impact)
	player.volume_db = volume_db
	player.pitch_scale = pitch
	player.set_meta("sfx_cue",sound)
	player.play()

static func _contact_name(family: String, kind: String, variant: int) -> String:
	return "contact_%s_%s_%d" % [family,kind,variant]

static func is_contact_cue(cue: String) -> bool:
	return cue in ["impact","shield"] or cue.begins_with("contact_")

static func _finite_number(value: Variant, fallback: float) -> float:
	return float(value) if (value is int or value is float) and is_finite(float(value)) else fallback

static func impact_material(zone: String, stats: Dictionary) -> String:
	# Explicit authored equipment metadata wins. Current catalogue has no
	# material field: its named mail/coat-of-plates/plate tiers are the fallback.
	var field = "helmet_material" if zone=="head" else ("shield_material" if zone=="shield" else "armor_material")
	var material = str(stats.get(field,"")).strip_edges().to_lower()
	if material in ["padded","padding","cloth","textile","gambeson","leather"]:
		return "padded"
	if material in ["mail","chainmail","chain_mail"]:
		return "mail"
	if material in ["brigandine","coat_of_plates","lamellar"]:
		return "brigandine"
	if material in ["plate","steel","iron","metal"]:
		return "helmet" if zone=="head" else "plate"
	if zone=="shield":
		# Shape/quality/paint do not turn a wood-core shield into solid metal.
		return "shield_wood"
	if zone=="head":
		return "helmet"
	var tier = int(clampf(_finite_number(stats.get("armor_tier"),0.0),0.0,20.0))
	return "mail" if tier==0 else ("brigandine" if tier==1 else "plate")

func impact_cue(event: Dictionary, defender_stats: Dictionary) -> Dictionary:
	# Selection only: the owner queues this beside the FIRST visible hit frame.
	# It neither plays a sound nor advances the match's random-number stream.
	if event.get("type","")!="hit" or str(event.get("zone","")) not in ["head","body","flank","shield"]:
		return {}
	var impulse = _finite_number(event.get("impulse"),-1.0)
	if impulse<0.0:
		return {}
	var zone = str(event.zone)
	var family = impact_material(zone,defender_stats)
	var kind = "glance" if bool(event.get("glanced",false)) else "solid"
	var key = family+"/"+kind
	var variant = int(_impact_counters.get(key,0))%IMPACT_VARIANTS
	_impact_counters[key] = (variant+1)%IMPACT_VARIANTS
	# A shield's rule impulse has already been reduced by block/deflection.
	# Its audible contact must retain the actual incoming speed's energy;
	# changing this presentation strength never increases shield damage.
	var speed_strength = clampf(_finite_number(event.get("speed"),0.0)/900.0,0.0,1.0)*.75
	var strength = maxf(clampf(impulse/85.0,0.0,1.0),speed_strength)
	var pitch: float = lerpf(1.02,.91,strength)+[0.0,-.012,.014][variant]
	if zone=="flank":
		pitch *= .95 # Same actual armour, more damped lower-torso resonance.
	if kind=="glance":
		pitch *= 1.035
	return {"cue":_contact_name(family,kind,variant),"db":lerpf(-12.0,-5.0,strength)-(1.5 if kind=="glance" else 0.0),
		"pitch":pitch,"material":family,"zone":zone,"kind":kind,"variant":variant,"strength":strength}

func break_cue(event: Dictionary) -> Dictionary:
	if event.get("type","")!="hit" or not bool(event.get("broke",false)):
		return {}
	var variant = int(_impact_counters.get("break",0))%IMPACT_VARIANTS
	_impact_counters["break"] = (variant+1)%IMPACT_VARIANTS
	var strength = clampf(_finite_number(event.get("impulse"),0.0)/90.0,0.0,1.0)
	return {"cue":"lance_break_%d" % variant,"db":lerpf(-11.0,-7.0,strength),"pitch":[1.0,.975,1.025][variant],"variant":variant}

func landing_cue(impact_speed: float) -> Dictionary:
	# An actual ground-contact signal may call this once. Reuse the soft
	# cloth/low-pressure body at a lower pitch; never borrow a hoof sound.
	var speed = _finite_number(impact_speed,-1.0)
	if speed<0.0:
		return {}
	var variant = int(_impact_counters.get("landing",0))%IMPACT_VARIANTS
	_impact_counters["landing"] = (variant+1)%IMPACT_VARIANTS
	var strength = clampf(speed/550.0,0.0,1.0)
	return {"cue":_contact_name("padded","solid",variant),"db":lerpf(-12.0,-7.5,strength),
		"pitch":lerpf(.83,.68,strength),"kind":"landing","material":"ground_padded","variant":variant}

static func cue_peak_bound(cue: String) -> float:
	return float(CONTACT_PEAKS.get(cue,1.0))*CONTACT_RESAMPLE_BOUND

static func _group_voice(cue: String) -> bool:
	return is_contact_cue(cue) or cue=="break" or cue.begins_with("lance_break_")

func limit_contact_group(cues: Array, budget: float = CONTACT_GROUP_BUDGET) -> Array[Dictionary]:
	# The owner passes one displayed contact batch (hits + wood cracks).
	# Attenuate the group proportionally, preserving material/force contrasts.
	# Previously playing contact tails are included, so a delayed second hit
	# cannot simply stack another .78 on top. Wind/hooves remain outside this
	# group and need the owner's existing ducking/reserved headroom.
	var result: Array[Dictionary] = []
	var incoming_peak = 0.0
	for raw in cues:
		if not raw is Dictionary or not raw.has("cue"):
			continue
		var cue: Dictionary = raw.duplicate(true)
		cue.db = clampf(_finite_number(cue.get("db"),-80.0),-80.0,6.0)
		cue.pitch = clampf(_finite_number(cue.get("pitch"),1.0),.1,4.0)
		incoming_peak += cue_peak_bound(str(cue.cue))*db_to_linear(float(cue.db))
		result.append(cue)
	if result.is_empty():
		return result
	var existing: Array[AudioStreamPlayer] = []
	var existing_peak = 0.0
	for voice in voices:
		var cue = str(voice.get_meta("sfx_cue",""))
		if voice.has_stream_playback() and _group_voice(cue):
			existing.append(voice)
			existing_peak += cue_peak_bound(cue)*db_to_linear(voice.volume_db)
	var target = clampf(_finite_number(budget,CONTACT_GROUP_BUDGET),.01,CONTACT_GROUP_BUDGET)
	var gain = minf(1.0,target/maxf(.000001,incoming_peak+existing_peak))
	var cut = linear_to_db(gain)
	for voice in existing:
		voice.volume_db += cut
	for cue in result:
		cue.db += cut
		cue["group_reduction_db"] = cut
	return result

static func _load_impact_stream(cue: String, family: String, kind: String, variant: int) -> AudioStreamWAV:
	var path = IMPACT_ASSET_DIR+cue+".wav"
	if ResourceLoader.exists(path):
		var baked = load(path)
		if baked is AudioStreamWAV:
			baked.set_meta("audio_origin","baked")
			return baked
	# Development fallback keeps a missing optional asset playable; it is
	# resolved only while the bank warms, never by impact_cue()/play().
	var generated = _synthesize_lance_break(variant) if family=="break" else _synthesize_contact(family,kind,variant)
	generated.set_meta("audio_origin","synth_fallback")
	return generated

func _loop_music() -> void:
	if enabled and is_inside_tree():
		if playback_paused:
			_music_start_on_resume = true
		else:
			music.play()

func stop_all() -> void:
	_music_start_on_resume = false
	if music:
		music.stop()
		music.stream = null
	for voice in voices:
		voice.stop()
		voice.stream = null

func _exit_tree() -> void:
	stop_all()

func _synthesize(sound_name: String) -> AudioStreamWAV:
	var durations = {"impact":.45,"shield":.5,"break":.5,"hoof":.16,"click":.08,"horn":1.2,"win":1.6,"lose":1.3,"lute_loop":12.8,"wind_loop":2.0}
	var rate = 22050
	var count = int(float(durations[sound_name]) * rate)
	var bytes = PackedByteArray()
	bytes.resize(count * 2)
	var random_source = RandomNumberGenerator.new()
	random_source.seed = 781
	var notes = [146.83,220.0,293.66,349.23,293.66,220.0,164.81,196.0,261.63,329.63,261.63,196.0,130.81,196.0,261.63,293.66]
	var filtered_noise = 0.0
	var contact_noise = 0.0
	for i in range(count):
		var t = float(i)/rate
		var sample = 0.0
		match sound_name:
			"impact":
				var raw = random_source.randf_range(-1,1)
				contact_noise = lerpf(contact_noise,raw,.18)
				var attack = (raw-contact_noise)*.5*exp(-t*90)*.25
				var plate = (sin(TAU*1180*t)*.10+sin(TAU*2090*t)*.06)*exp(-t*55)
				var weight = sin(TAU*(82*t-38*t*t))*exp(-t*11)*.34
				var chest = sin(TAU*137*t)*exp(-t*18)*.10
				# Short surface attack plus a lower resonant body. Absolute
				# layer weights sum to <=.85; clipping is not the loudness tool.
				sample = (attack+plate+weight+chest)*minf(1.0,t/.0015)*minf(1.0,(float(durations[sound_name])-t)/.012)
			"shield":
				var raw = random_source.randf_range(-1,1)
				contact_noise = lerpf(contact_noise,raw,.22)
				var attack = (raw-contact_noise)*.5*exp(-t*80)*.21
				var wood = sin(TAU*144*t)*exp(-t*16)*.31+sin(TAU*237*t)*exp(-t*22)*.12
				var boss = sin(TAU*565*t)*exp(-t*15)*.10+sin(TAU*1007*t)*exp(-t*20)*.06
				# Distinct dull board/boss layers, not a brighter copy of a
				# body hit. Game synthesis, not a recorded material simulation.
				sample = (attack+wood+boss)*minf(1.0,t/.0012)*minf(1.0,(float(durations[sound_name])-t)/.012)
			"break": sample = random_source.randf_range(-1,1)*exp(-t*10)*(1+.3*sin(t*280))*.65
			"hoof":
				var strike = random_source.randf_range(-1,1)*exp(-t*110)*.45
				var weight = sin(TAU*(86*t-95*t*t))*exp(-t*29)*.68
				sample = (strike+weight)*.78
			"click": sample = sin(t*TAU*600)*exp(-t*65)*.35
			"horn": sample = (sin(t*TAU*196)+.3*sin(t*TAU*392))*minf(1,t*8)*maxf(0,1-t/1.2)*.3
			"win": sample = sin(t*TAU*[261.63,329.63,392.0,523.25][mini(3,int(t/.3))])*exp(-fmod(t,.3)*5)*maxf(0,1-t/1.6)*.4
			"lose": sample = sin(t*TAU*[293.66,261.63,196.0][mini(2,int(t/.4))])*exp(-fmod(t,.4)*4)*maxf(0,1-t/1.3)*.35
			"lute_loop":
				for harmonic in range(1,5):
					sample += sin(TAU*float(notes[int(t/.8)%notes.size()])*harmonic*t)*exp(-fmod(t,.8)*(4+harmonic*.5))/harmonic*.085
			"wind_loop":
				filtered_noise = lerpf(filtered_noise,random_source.randf_range(-1,1),.065)
				sample = filtered_noise*(.55+.12*sin(TAU*t*4))
		var value = int(clampf(sample,-1,1)*32767)
		bytes[i*2] = value & 255
		bytes[i*2+1] = (value >> 8) & 255
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.stereo = false
	stream.data = bytes
	if sound_name=="wind_loop":
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_end = count
	return stream

static func _pcm_stream(bytes: PackedByteArray, rate: int) -> AudioStreamWAV:
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.stereo = false
	stream.data = bytes
	return stream

static func _synthesize_contact(family: String, kind: String, variant: int) -> AudioStreamWAV:
	contact_generation_count += 1
	var profile: Dictionary = CONTACT_PROFILES[family]
	var glance = kind=="glance"
	var duration = .36 if glance else .56
	var count = int(duration*CONTACT_RATE)
	var bytes = PackedByteArray()
	bytes.resize(count*2)
	var rng = RandomNumberGenerator.new()
	rng.seed = 5003+IMPACT_FAMILIES.find(family)*419+variant*97+(1709 if glance else 0)
	var tuning = rng.randf_range(.984,1.016)
	var grain_delays: Array[float] = []
	for delay in [.005,.019,.037,.061,.089,.123]:
		grain_delays.append(float(delay)+rng.randf_range(-.0018,.0018))
	var low_noise = 0.0
	var mid_noise = 0.0
	var modes: Array = profile.modes
	var low_gain = float(profile.low)*(.45 if glance else 1.0)
	var attack_gain = float(profile.attack)
	var grain_gain = float(profile.grain)
	for i in range(count):
		var t = float(i)/CONTACT_RATE
		var raw = rng.randf_range(-1.0,1.0)
		low_noise = lerpf(low_noise,raw,.055 if family=="padded" else .10)
		mid_noise = lerpf(mid_noise,raw,.38)
		var bright = (raw-mid_noise)*.5
		var band = (mid_noise-low_noise)*.5
		var body = 0.0
		for mode in modes:
			# Fast high-mode damping avoids the former pitched bell-like tail.
			# Slight downward pressure chirp lives only in the low body modes.
			var frequency = float(mode.x)*tuning
			var phase = frequency*t-(frequency*.10*t*t if frequency<200 else 0.0)
			body += sin(TAU*phase)*float(mode.y)*exp(-t*float(mode.z))
		body *= .30 if glance else 1.0
		var attack = bright*attack_gain*exp(-t*(70.0 if glance else 92.0))
		var pressure = low_noise*low_gain*exp(-t*13.0)
		var grains = 0.0
		if grain_gain>0.0:
			var envelope = 0.0
			for start in grain_delays:
				var age = t-start
				if age>=0.0:
					envelope = maxf(envelope,minf(1.0,age/.0015)*exp(-age*85.0))
			grains = band*grain_gain*envelope
		var scrape = 0.0
		if glance:
			# Tangential grit is a short broad-band scrape, not another ding.
			scrape = band*.30*minf(1.0,t/.008)*exp(-maxf(0.0,t-.025)*22.0)
		var attack_ramp = minf(1.0,t/(.003 if family=="padded" else .0012))
		var tail = clampf((duration-t)/.018,0.0,1.0)
		# Profile gains have bounded sums (<.9); no peak normalization or
		# hard clipping is used to fake impact weight. 16-bit conversion only.
		var sample = (body+attack+pressure+grains+scrape)*attack_ramp*tail
		var value = int(sample*32767.0)
		bytes[i*2] = value&255
		bytes[i*2+1] = (value>>8)&255
	return _pcm_stream(bytes,CONTACT_RATE)

static func _synthesize_lance_break(variant: int) -> AudioStreamWAV:
	contact_generation_count += 1
	var duration = .44
	var count = int(duration*CONTACT_RATE)
	var bytes = PackedByteArray()
	bytes.resize(count*2)
	var rng = RandomNumberGenerator.new()
	rng.seed = 7811+variant*137
	var low = 0.0
	var cracks = [.0,.009+variant*.002,.026,.055+variant*.003,.101,.154]
	for i in range(count):
		var t = float(i)/CONTACT_RATE
		var raw = rng.randf_range(-1,1)
		low = lerpf(low,raw,.18)
		var envelope = 0.0
		for start in cracks:
			var age = t-float(start)
			if age>=0.0:
				envelope = maxf(envelope,minf(1.0,age/.0008)*exp(-age*105.0))
		var snap = (raw-low)*.5*.47*envelope
		var fibre = low*.18*exp(-t*17.0)
		var weight = (sin(TAU*108*t)*.14+sin(TAU*221*t)*.06)*exp(-t*24.0)
		var value = int((snap+fibre+weight)*minf(1.0,t/.0008)*clampf((duration-t)/.016,0.0,1.0)*32767.0)
		bytes[i*2] = value&255
		bytes[i*2+1] = (value>>8)&255
	return _pcm_stream(bytes,CONTACT_RATE)
