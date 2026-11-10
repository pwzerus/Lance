extends TextureRect
## Armoury cards load their original full-quality texture only when visible.
## Work is shared across cards: one bounded slice per frame, never a queue
## of background loads retained after leaving the screen.
const Art = preload("res://scripts/visual/equipment_art.gd")
const WindowActivity = preload("res://scripts/core/window_activity.gd")
static var _budget_frame = -1
static var _spent_usec = 0
const BUDGET_USEC = 2000
var equipment: Dictionary = {}
var first_frame = 0

func _ready() -> void:
	first_frame = Engine.get_process_frames()+1

func _process(_delta: float) -> void:
	if WindowActivity.suspended(): return
	var frame = Engine.get_process_frames()
	if frame<first_frame or not is_visible_in_tree(): return
	var clip: Node = get_parent()
	while clip!=null:
		if clip is ScrollContainer and not get_global_rect().intersects(clip.get_global_rect()): return
		clip=clip.get_parent()
	if _budget_frame!=frame:
		_budget_frame=frame
		_spent_usec=0
	if _spent_usec>=BUDGET_USEC: return
	var started = Time.get_ticks_usec()
	texture = Art.item_icon(equipment)
	_spent_usec += Time.get_ticks_usec()-started
	set_process(false)
