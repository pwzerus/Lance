extends SceneTree
## Verify that exported rule metadata describes the state actually changed.
## Synthetic contacts isolate metadata; this is not a sweep/aiming test.
const Model = preload("res://scripts/core/joust_match.gd")
var failures: Array = []
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var report = ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): report=arg.trim_prefix("--report=")
	if report.is_empty() or FileAccess.file_exists(report) or OS.get_environment("GALUMU_MEMORY_BOUND")!="1024" or not root.get_node("GameState").save_path.contains("qa_"):
		quit(2); return
	var rows: Array = []
	for mode in ["arena","war"]:
		for zone in ["head","body","shield"]:
			for seed_value in range(8):
				var m=Model.new(mode,{"stability":8.0},{"stability":8.0},8200+seed_value)
				m._apply_contact({"type":"hit","attacker":0,"defender":1,"zone":zone,"shield_region":"rim","speed":700.0,"position":Vector2.ZERO})
				var events=m.drain_events()
				var hit: Dictionary=events[0]
				var expected = 0
				if not hit.glanced:
					expected=1 if zone=="shield" or hit.damage<17.0 else (3 if zone=="head" else 2)
					if m.fighters[0].broken: expected+=1
				if bool(hit.get("broke",false))!=bool(m.fighters[0].broken): failures.append("break metadata differs "+mode+zone+str(seed_value))
				if int(hit.points)!=expected or int(m.fighters[0].score)!=expected: failures.append("score differs "+mode+zone+str(seed_value))
				if bool(hit.get("attaint",false))!=(zone!="shield" and not hit.glanced and hit.damage>=17.0): failures.append("attaint metadata differs "+mode+zone+str(seed_value))
				rows.append({"mode":mode,"zone":zone,"seed":seed_value,"hit":hit,"broken":m.fighters[0].broken,"score":m.fighters[0].score,"expected":expected})
	var probe=Model.new()
	var data={"passed":failures.is_empty(),"failures":failures,"constants":probe.get_script().get_script_constant_map().keys(),"rows":rows,"scope":"Synthetic contact metadata/state consistency, not swept input or balance."}
	FileAccess.open(report,FileAccess.WRITE).store_string(JSON.stringify(data,"\t"))
	print("PACKAGE082 ",failures)
	quit(0 if failures.is_empty() else 1)
