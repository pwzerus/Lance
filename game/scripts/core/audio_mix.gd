extends RefCounted
## Four bounded, named buses. Preserve the engine Master and its output/mute
## state; all game gains are attenuation only, so contact headroom is unchanged.
const GAME = &"GALUMU"
const MUSIC = &"GALUMU Music"
const EFFECTS = &"GALUMU Effects"
const AMBIENCE = &"GALUMU Ambience"
const VOLUMES = {"master_volume":GAME,"music_volume":MUSIC,"effects_volume":EFFECTS,"ambience_volume":AMBIENCE}

static func ensure_buses() -> void:
	for name_value in [GAME,MUSIC,EFFECTS,AMBIENCE]:
		var index = AudioServer.get_bus_index(name_value)
		if index < 0:
			AudioServer.add_bus()
			index = AudioServer.bus_count-1
			AudioServer.set_bus_name(index,name_value)
			AudioServer.set_bus_send(index,&"Master" if name_value==GAME else GAME)

static func volume(settings: Dictionary, key: String) -> float:
	var raw: Variant = settings.get(key,1.0)
	return clampf(float(raw),0.0,1.0) if (raw is float or raw is int) and is_finite(float(raw)) else 1.0

static func apply(settings: Dictionary) -> void:
	ensure_buses()
	for key in VOLUMES:
		var index = AudioServer.get_bus_index(VOLUMES[key])
		var gain = volume(settings,key)
		var muted = gain<=0.0 or (key=="master_volume" and not bool(settings.get("sound",true)))
		AudioServer.set_bus_mute(index,muted)
		AudioServer.set_bus_volume_db(index,linear_to_db(maxf(.0001,gain)))

static func effects_audible(settings: Dictionary) -> bool:
	return bool(settings.get("sound",true)) and volume(settings,"master_volume")>0 and volume(settings,"effects_volume")>0
