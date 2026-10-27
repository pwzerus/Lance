extends SceneTree
const Model = preload("res://scripts/core/joust_match.gd")
const Cues = preload("res://scripts/visual/combat_cues.gd")
var failures: Array = []
var samples = 0
func _initialize() -> void:
	for facing in [1,-1]:
		for guard in [0.0,.43,1.0]:
			for lean in [-1.0,0.0,1.0]:
				for reach in [66.0,247.0,330.0]:
					for aim_index in range(17):
						var model = Model.new()
						model.phase = "charge"
						var a = model.fighters[0]
						var d = model.fighters[1]
						d.stats.shield_shape = ["kite","heater","targe"][aim_index%3]
						a.direction = facing
						a.x = -650*facing
						a.aim = lerpf(-.68,.58,float(aim_index)/16)
						a.stats.reach = reach
						d.direction = -facing
						d.x = 0
						d.lean = lean
						d.guard = guard
						model._cache_pose(a)
						model._cache_pose(d)
						var projected = Cues.project(model).zone
						var actual = "miss"
						for tick in range(160):
							a.x += facing*6
							var contact = model._detect_contact(0,1.0/120)
							if not contact.is_empty():
								actual = contact.zone
								break
							model._cache_pose(a)
						samples += 1
						if projected!=actual:
							failures.append({"facing":facing,"guard":guard,"lean":lean,"reach":reach,"shape":d.stats.shield_shape,"aim":a.aim,"projected":projected,"actual":actual})
	print("CUE_CONTACTS_V043 "+JSON.stringify({"passed":failures.is_empty(),"samples":samples,"failures":failures,"scope":"frozen-pose current-height projection versus actual swept contacts; excludes future pose changes"}))
	quit(0 if failures.is_empty() else 1)
