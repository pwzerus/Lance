extends "test_horse_battle060.gd"
## Keep actual playback/mixer activity but mute ONLY this process's Master bus.
## Maps the exact object IDs in --verbose exit warnings to authored cues.
func _initialize() -> void:
	AudioServer.set_bus_mute(0,true)
	super._initialize()

func sample(label: String) -> void:
	super.sample(label)
	if label=="restored":
		var objects = {}
		for key in main.sounds.streams:
			objects[key] = main.sounds.streams[key].get_instance_id()
		print("QA_AUDIO_OBJECTS "+JSON.stringify(objects))
		print("QA_MUSIC_PLAYBACK "+str(main.sounds.music.get_stream_playback().get_instance_id()) if main.sounds.music.has_stream_playback() else "QA_MUSIC_NO_PLAYBACK")
