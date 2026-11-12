extends "res://scripts/main.gd"
const TimedBattle=preload("res://tests/profile_battle088.gd")
func _start_match(mode: String, practice: bool = false, guide: PracticeGuide = null) -> void:
	_close_battle()
	active_guide = guide if practice and mode=="arena" else null
	practice_match = practice
	current_mode = mode
	page = "battle"
	_clear_screen()
	if sounds:
		sounds.music.stop()
	session_id = str(Time.get_ticks_usec())
	pending_result = {}
	reward = {}
	result_visible = false
	battle = TimedBattle.new()
	battle.mode = mode
	battle.practice = practice
	battle.practice_guide = active_guide
	battle.autoplay = smoke_mode
	battle.demo_seed = 271828 if smoke_mode else 0
	battle.finished.connect(_on_match_finished)
	battle.lesson_completed.connect(_on_lesson_completed)
	battle.lesson_exit_requested.connect(_finish_lesson)
	battle.exit_requested.connect(func():
		_close_battle()
		show_home())
	battle.replay_requested.connect(func():_start_match(current_mode,practice_match,active_guide))
	add_child(battle)
	queue_redraw()
