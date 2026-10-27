extends SceneTree
const Model = preload("res://scripts/core/joust_match.gd")
const Catalogue = preload("res://scripts/core/catalogue.gd")

func _initialize() -> void:
	var failures: Array = []
	var combinations = 0
	var items = Catalogue.load_items()
	for lance in items:
		if lance.slot!="lance" or not lance.has("quality"):
			continue
		for horse in items:
			if horse.slot!="horse":
				continue
			for side in [0,1]:
				var stats = lance.stats.duplicate(true)
				stats.merge(horse.stats,true)
				var model = Model.new("war",stats,stats,821)
				model.phase = "charge"
				var attacker = model.fighters[side]
				var defender = model.fighters[1-side]
				defender.acted = true
				defender.shield = 0.0
				for f in model.fighters:
					f.speed = 480*horse.stats.speed
				var hits = 0
				for tick in range(360):
					var hand = Model.hand_position(attacker)
					var aim = asin(clampf((Model.body_position(defender).y-hand.y)/Model.lance_length(attacker),-1,1))
					model.set_controls(side,aim,0,true,1.0/30)
					model.set_controls(1-side,0,0,true,1.0/30)
					model.step(1.0/30)
					for event in model.drain_events():
						if event.type=="hit" and event.attacker==side:
							hits += 1
					if model.phase!="charge" or (defender.x-attacker.x)*int(attacker.direction)<-200:
						break
				combinations += 1
				if hits!=1:
					failures.append("%s / %s / side %d: %d hits" % [lance.id,horse.id,side,hits])
	print("EQUIPMENT_SWEEP_V042 "+JSON.stringify({"passed":failures.is_empty(),"failures":failures,"combinations":combinations,"scope":"72 regional lances x 10 horses x both lanes, 30Hz perfect body aim, unshielded target; collision coverage, not balance or human gameplay"}))
	quit(0 if failures.is_empty() else 1)
