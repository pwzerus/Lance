extends SceneTree

const Model = preload("res://scripts/core/joust_match.gd")
var failures: Array = []
var checks = 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)

func run() -> void:
	var state = root.get_node("GameState")
	if not state.save_path.contains("qa_"):
		quit(1)
		return
	state.profile.settings.difficulty = 1
	var controller = load("res://scripts/battle.gd").new()
	controller.match_model = Model.new()
	controller.match_model.phase = "charge"
	controller.match_model.fighters[0].x = -500
	controller.match_model.fighters[1].x = 500
	controller.ai_timer = .5
	controller.ai_target_y = -123
	controller.ai_guard = .3
	controller._update_ai(.01)
	check(controller.ai_target_y==-123 and controller.ai_guard==.3,"Pending reaction must not read a new target or shield pose")
	controller.ai_timer = 0
	controller._update_ai(.01)
	check(controller.ai_target_y!=-123,"Outside commitment distance the elapsed observation must update")
	controller.match_model.fighters[0].x = -350
	controller.match_model.fighters[1].x = 350
	controller.ai_timer = 0
	controller.ai_target_y = -123
	controller.ai_guard = .3
	controller._update_ai(.01)
	check(controller.ai_target_y==-123 and controller.ai_guard==.3,"Standard AI must commit within 800 units even when reaction becomes due")
	state.profile.settings.difficulty = 2
	controller._update_ai(.01)
	check(controller.ai_target_y!=-123,"Hard AI may observe at 700 units before its later commitment")
	controller.match_model.fighters[0].x = -200
	controller.match_model.fighters[1].x = 200
	controller.ai_timer = 0
	controller.ai_target_y = -123
	controller._update_ai(.01)
	check(controller.ai_target_y==-123,"Hard AI also commits inside 500 units")
	controller.free()
	print("AI_REACTION_TEST_REPORT "+JSON.stringify({"checks":checks,"failures":failures,"passed":failures.is_empty()}))
	quit(0 if failures.is_empty() else 1)
