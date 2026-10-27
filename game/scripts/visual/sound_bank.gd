class_name SoundBank
extends Node

var enabled = true
var music: AudioStreamPlayer
var streams: Dictionary = {}
static var shared_streams: Dictionary = {}
const MAX_VOICES = 12
var voices: Array[AudioStreamPlayer] = []
var next_voice = 0

func _ready() -> void:
	music = AudioStreamPlayer.new()
	if shared_streams.is_empty():
		for sound_name in ["impact","shield","break","hoof","click","horn","win","lose","lute_loop","wind_loop"]:
			shared_streams[sound_name] = _synthesize(sound_name)
	streams = shared_streams
	music.stream = streams.lute_loop
	music.volume_db = -16.0
	add_child(music)
	music.finished.connect(_loop_music)
	if enabled:
		music.play()

func set_enabled(value: bool) -> void:
	enabled = value
	if not enabled:
		for voice in voices:
			voice.stop()
	if music:
		if enabled and not music.playing:
			music.play()
		elif not enabled:
			music.stop()

func play(sound: String, volume_db: float = -5.0, pitch: float = 1.0) -> void:
	if not enabled:
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
	player.stream = streams.get(sound,streams.impact)
	player.volume_db = volume_db
	player.pitch_scale = pitch
	player.play()

func _loop_music() -> void:
	if enabled and is_inside_tree():
		music.play()

func stop_all() -> void:
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
	for i in range(count):
		var t = float(i)/rate
		var sample = 0.0
		match sound_name:
			"impact": sample = (random_source.randf_range(-1,1)*.7 + sin(TAU*(95-50*t)*t)*.5)*exp(-t*14)*.7
			"shield": sample = (random_source.randf_range(-1,1)*exp(-t*30)*.6+sin(TAU*172*t)*exp(-t*15)*.35+sin(TAU*417*t)*exp(-t*12)*.15)*.8
			"break": sample = random_source.randf_range(-1,1)*exp(-t*10)*(1+.3*sin(t*280))*.65
			"hoof": sample = (sin(t*TAU*115)*.65+random_source.randf_range(-1,1)*.3)*exp(-t*35)*.6
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
