extends Node
## Always runs, including when the battle has paused the SceneTree.
## A frame cap alone only slows the minimized-window allocation leak. Stop
## rebuilding canvas geometry while the OS cannot present the main window.
var was_suspended = false

static func suspended() -> bool:
	return DisplayServer.get_name() != "headless" and not DisplayServer.window_can_draw()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_priority = -100

func _unhandled_input(event: InputEvent) -> void:
	# Window controls remain available while the game and its Main node pause.
	# Keep one owner so an unpaused press cannot toggle twice.
	if get_parent().shutting_down:
		return
	if event is InputEventKey and event.pressed and not event.echo and KEY_F11 in [event.keycode,event.physical_keycode]:
		var fullscreen = DisplayServer.window_get_mode()==DisplayServer.WINDOW_MODE_FULLSCREEN
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if fullscreen else DisplayServer.WINDOW_MODE_FULLSCREEN)
		get_viewport().set_input_as_handled()

func _process(_delta: float) -> void:
	var hidden = suspended()
	Engine.max_fps = 10 if hidden else 60
	var main = get_parent()
	if was_suspended and not hidden:
		# Pending redraws may have been cleared during minimize. Paused riders do
		# not run _process, so explicitly restore every canvas once, even paused.
		_redraw_tree(main)
	was_suspended = hidden
	if hidden and is_instance_valid(main.battle) and not main.battle.paused and not main.battle.is_finished:
		# Preserve the game's existing explicit Resume flow and clear held input.
		# Never automatically unpause a player who was already paused.
		main.battle._toggle_pause()

func _redraw_tree(node: Node) -> void:
	if node is CanvasItem:
		node.queue_redraw()
	for child in node.get_children():
		_redraw_tree(child)
