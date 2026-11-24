class_name BattleScene
extends Node2D
const Trace099 = preload("res://scripts/core/frame_trace099.gd")

signal finished(result: Dictionary)
signal exit_requested
signal replay_requested
signal lesson_completed
signal lesson_exit_requested

const Model = preload("res://scripts/core/joust_match.gd")
const Rider = preload("res://scripts/visual/rider_view.gd")
const FX = preload("res://scripts/visual/impact_fx.gd")
const Cues = preload("res://scripts/visual/combat_cues.gd")
const Exchange = preload("res://scripts/visual/exchange_director.gd")
const UI = preload("res://scripts/ui/ui_factory.gd")
const Catalogue = preload("res://scripts/core/catalogue.gd")
const Guide = preload("res://scripts/core/practice_guide.gd")
const BACKGROUND = preload("res://assets/art/pixel_v03/tournament_field.png")
const WAR_BACKGROUND = preload("res://assets/art/pixel_v03/campaign_field.png")

# Main stages first rendering across frames; standalone rule fixtures retain
# synchronous construction. Gameplay never advances before the full view exists.
var staged_startup = false
var presentation_ready = false
var preparation_pause_requested = false
var preparation_stage = 0
var preparation_frame = 0
var preparation_layer: CanvasLayer
var match_model: JoustMatch
var mode = "arena"
var world: Node2D
var riders: Array = []
var rail: Node2D
var track: Node2D
var backdrop: TextureRect
var effects: ImpactFX
var hud: Control
var hud_brand113: Label
var hud_context113: Label
var hud_status_strip113: Control
var hud_guard_help113: Label
var hud_speed_caption113: Label
const Status098 = preload("res://scripts/ui/combat_status098.gd")
var status_gauges: Control
var debug_numbers: Label
var callout: Label
var subcallout: Label
var pass_label: Label
var hint: Label
var intermission: Label
var pause_panel: Control
var pause_save_notice: Label
var paused = false
var pause_started = 0
var is_finished = false
var terminal_at = 0
var fall_frame_size = Vector2.ZERO
var camera_subject_bounds = Rect2()
var departure_elapsed = 0.0
var last_visual_time = 0
var exchange_director = Exchange.new()
var exchange_state: Dictionary = exchange_director.sample()
var contact_first_frame_pending = false
var contact_audio: Array[Dictionary] = []
var shake = 0.0
var impact_kick = Vector2.ZERO
var camera_impact_age = 1.0
var camera_impact_strength = -1.0
var camera_impact_attacker = 2147483647
# FEEL-097: momentum direction, ring length and pitch of the current jolt.
var impact_drift = 0.0
var impact_life = .48
var impact_frequency = 6.5
var impact_grade: Control
var noise = FastNoiseLite.new()
var wheel_lean = 0.0
var touch_lean = 0.0
var touch_aim = Vector2.ZERO
var aim_pointer = Vector2(1150,400)
var pointer_aim = -.08
var touch_roles: Dictionary = {}
var touch_origin: Dictionary = {}
var ai_controller = preload("res://scripts/core/opponent_ai.gd").new()
var ai_zone = "body"
var ai_lean = .18
var ai_guard = 0.0
var ai_target_y = -212.0
var exchange_log: Array[Dictionary] = []
var ai_rng = RandomNumberGenerator.new()
var ai_fighter_index = 1 # Also permits symmetric QA with the AI on either side.
var last_phase = ""
var sound: SoundBank
var autoplay = false
var demo_seed = 0
var camera: Camera2D
var speed_label: Label
var contact_label: Label
var enemy_contact_label: Label
var contact_until = 0
var spur_left = 0.0
var mouse_held = false
var training_zones = false
var pass_connected = false
var camera_pass = 1
var approach_slow = false
var wind: AudioStreamPlayer
var zone_overlay: Node2D
var combat_cues: Node2D
var aim_label: Label
var guard_high = false
const COMBAT_SAFE_RECT = Rect2(16,154,1408,548)
const GUARD_VALUES = [1.0,.43,0.0]
const GUARD_NAMES = ["护头","护胸","护腹"]
const RUNUP_ZOOM = .68
const DUEL_ENTER_GAP = 1900.0
const DUEL_FULL_GAP = 1200.0
var guard_slot = 1
var guard_buttons: Array[Button] = []
var ui_pointer_held = false
var speed_meter: ProgressBar
var stamina_bar: ColorRect
var fatigue_label: Label
var tactics_label: Label
var input_flash_until = 0
var ready_panel: Control
var runup_panel: Control
var contact_panel: Control
var practice = false
var learned = {"boost":false,"aim":false,"guard":false,"posture":false}
var practice_guide: Guide
## LEVEL-092: a campaign level supplies the opponent's kit and AI profile.
var level: Dictionary = {}
var aim_revision = 0
var lesson_reported = false
var lesson_result_button: Button

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	last_visual_time = Time.get_ticks_msec()
	aim_pointer = get_global_mouse_position().clamp(Vector2.ZERO,Vector2(1440,810))
	noise.seed = 421
	noise.frequency = 7.0
	ai_rng.randomize()
	if demo_seed:
		ai_rng.seed = demo_seed+431
	var player_stats = GameState.player_stats()
	var enemy_stats = Catalogue.opponent_stats(GameState.items,Catalogue.era_for_renown(int(GameState.profile.renown)))
	if not level.is_empty():
		enemy_stats = Catalogue.stats(GameState.items,level.equipment)
		if level.has("appearance"):
			enemy_stats.appearance = preload("res://scripts/core/character_appearance.gd").sanitize(level.appearance)
		ai_controller.configure(level.ai)
	match_model = Model.new(mode, player_stats, enemy_stats, demo_seed if demo_seed else int(Time.get_ticks_usec()))
	if practice_guide: practice_guide.begin_attempt(match_model.fighters[0])
	match_model.fighters[0].guard = GUARD_VALUES[guard_slot]
	match_model.fighters[0].guard_target = GUARD_VALUES[guard_slot]
	match_model._cache_pose(match_model.fighters[0])
	get_window().focus_exited.connect(_on_focus_lost)
	_build_field()
	if staged_startup:
		_show_preparation()
		preparation_frame = Engine.get_process_frames()
		return
	for i in range(2): _build_rider(i)
	_build_battle_details()
	_build_hud()
	_update_hud()
	_finish_presentation()

func _build_rider(i: int) -> void:
	var rider = Rider.new()
	rider.fighter = match_model.fighters[i]
	rider.red = i == 1 or int(GameState.profile.region) == 1
	rider.mode = mode
	rider.blood_enabled = GameState.profile.settings.blood
	rider.z_index = 0 if i == 1 else 2
	match_model.fighters[i]["red"] = rider.red
	rider.position = Vector2(float(rider.fighter.x),float(rider.fighter.get("lane_y",0.0)))
	world.add_child(rider)
	# Godot enables overridden _process during READY; disable after attaching.
	rider.set_process(false)
	riders.append(rider)

func _build_battle_details() -> void:
	# A detached rider keeps its mount's effective Z. Draw its main body
	# after that mount so the near thigh does not vanish at the handover.
	# The separate far leg stays at its lower Z; the rail still splits lanes.
	world.move_child(effects,world.get_child_count()-1)
	rail = Node2D.new()
	rail.z_index = 1
	rail.draw.connect(_draw_rail)
	world.add_child(rail)
	zone_overlay = preload("res://scripts/visual/hit_zone_overlay.gd").new()
	zone_overlay.match_model = match_model
	zone_overlay.z_index = 20
	zone_overlay.visible = false
	world.add_child(zone_overlay)
	combat_cues = Cues.new()
	combat_cues.match_model = match_model
	combat_cues.z_index = 19
	world.add_child(combat_cues)
	# ART-090: helmet sight mask, above the field and below the HUD layer
	# (added before the HUD's CanvasLayer at the same layer index).
	var sight_layer = CanvasLayer.new()
	add_child(sight_layer)
	var sight = preload("res://scripts/visual/helmet_view.gd").new()
	sight.battle = self
	sight_layer.add_child(sight)
	# FEEL-097: bullet-time grade (edge vignette while the moment is held and
	# one soft flash on the freeze), above the field and below the HUD.
	impact_grade = Control.new()
	impact_grade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	impact_grade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	impact_grade.draw.connect(_draw_impact_grade)
	sight_layer.add_child(impact_grade)
	sound = SoundBank.new()
	sound.enabled = GameState.profile.settings.sound
	add_child(sound)
	sound.music.stop()
	effects.rider_landed.connect(func(impact_speed: float):
		var cue = sound.landing_cue(impact_speed)
		if not cue.is_empty():
			for limited in sound.limit_contact_group([cue]):
				sound.play(limited.cue,limited.db,limited.pitch))
	wind = AudioStreamPlayer.new()
	wind.bus = preload("res://scripts/core/audio_mix.gd").AMBIENCE
	wind.stream = sound.streams.wind_loop
	wind.volume_db = -50
	add_child(wind)
	if sound.enabled:
		wind.play()
	for i in range(riders.size()):
		riders[i].stride_phase = i*1.1
		riders[i].hoof_contact.connect(_on_hoof_contact.bind(i))
		riders[i].armor_motion.connect(_on_armor_motion.bind(i))

func _finish_presentation() -> void:
	_update_views()
	presentation_ready = true
	queue_redraw() # Restore shadows in the first fully revealed frame.
	last_visual_time = Time.get_ticks_msec()
	for rider in riders: rider.set_process(true)
	if is_instance_valid(preparation_layer):
		preparation_layer.hide()
		preparation_layer.queue_free()
		preparation_layer = null
	if preparation_pause_requested: _toggle_pause()

func _advance_preparation() -> void:
	if not staged_startup or preload("res://scripts/core/window_activity.gd").suspended(): return
	var frame = Engine.get_process_frames()
	if frame<=preparation_frame: return
	preparation_frame = frame
	# Explicit frame stages have no suspended coroutine stacks to retain
	# resources when the player closes/restarts part-way through preparation.
	match preparation_stage:
		0, 1: _build_rider(preparation_stage)
		2:
			_build_battle_details()
			_build_hud_top()
		3:
			_build_hud_bottom()
			_update_hud()
		4: _finish_presentation()
	preparation_stage += 1

func _build_field() -> void:
	world = Node2D.new()
	world.process_mode = Node.PROCESS_MODE_PAUSABLE
	world.position = Vector2(720,645)
	add_child(world)
	var scenery = CanvasLayer.new()
	scenery.layer = -20
	add_child(scenery)
	backdrop = TextureRect.new()
	backdrop.texture = WAR_BACKGROUND if mode=="war" else BACKGROUND
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.size = Vector2(1600,900)
	backdrop.position = Vector2(-80,-45)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scenery.add_child(backdrop)
	camera = Camera2D.new()
	camera.position = Vector2(720,480)
	camera.zoom = Vector2.ONE*.28
	add_child(camera)
	camera.make_current()
	effects = FX.new()
	effects.z_index = 10
	effects.blood_enabled = GameState.profile.settings.blood
	world.add_child(effects)
	var ground = StaticBody2D.new()
	ground.position = Vector2(0,22)
	ground.collision_layer = 8
	ground.collision_mask = 4
	var shape = CollisionShape2D.new()
	var rectangle = RectangleShape2D.new()
	rectangle.size = Vector2(12000,20)
	shape.shape = rectangle
	ground.add_child(shape)
	world.add_child(ground)
	track = Node2D.new()
	track.z_index = -3
	track.draw.connect(_draw_track)
	world.add_child(track)
	for lane_y in [-32.0,32.0]:
		var lane_ground = StaticBody2D.new()
		lane_ground.position = Vector2(0,lane_y+22)
		lane_ground.collision_layer = 16 if lane_y<0 else 32
		lane_ground.collision_mask = 4
		var lane_shape = CollisionShape2D.new()
		lane_shape.shape = rectangle.duplicate()
		lane_ground.add_child(lane_shape)
		world.add_child(lane_ground)

func _show_preparation() -> void:
	preparation_layer = CanvasLayer.new()
	preparation_layer.layer = 30
	add_child(preparation_layer)
	var image = TextureRect.new()
	image.texture = WAR_BACKGROUND if mode=="war" else BACKGROUND
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.size = backdrop.size
	image.position = backdrop.position
	image.mouse_filter = Control.MOUSE_FILTER_STOP
	preparation_layer.add_child(image)
	var panel = UI.panel(preparation_layer,Rect2(540,350,360,86),Color(.045,.08,.065,.96))
	UI.label(panel,"整装待发…",Vector2(35,25),22,UI.GOLD)

func _build_hud() -> void:
	_build_hud_top()
	_build_hud_bottom()

func _build_hud_top() -> void:
	var layer = CanvasLayer.new()
	add_child(layer)
	hud = Control.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.theme = UI.theme()
	layer.add_child(hud)
	# Every normal HUD element stays in one of the edge bands. The middle
	# rectangle belongs to the riders, including raised shields and hooves.
	var top = UI.panel(hud,Rect2(0,0,1440,58),Color(.045,.08,.065,.96))
	hud_brand113=UI.label(top,"LANCE & LAUREL",Vector2(20,12),22,UI.GOLD)
	var title = "跟教练练习" if practice_guide else ("练习场" if practice else (("竞技场" if mode=="arena" else "实战")+" · "+ai_controller.NAMES[int(GameState.profile.settings.difficulty)]))
	if not level.is_empty():
		title = str(level.opponent)+"  "+str(level.archetype_name)
	hud_context113=UI.label(top,title,Vector2(290,17),17,UI.INK,740)
	pass_label = UI.label(top,"PASS  01 / 03",Vector2(1065,16),20,UI.GOLD)
	if practice_guide:
		lesson_result_button = UI.button(top,"查看练习小结",Rect2(1045,8,210,42),func():lesson_exit_requested.emit())
		lesson_result_button.visible = false
		lesson_result_button.focus_mode = Control.FOCUS_NONE
	var pause_button = UI.button(top,"暂停 Esc",Rect2(1275,8,145,42),_toggle_pause)
	pause_button.focus_mode = Control.FOCUS_NONE
	var status = UI.panel(hud,Rect2(0,58,1440,40),Color(.045,.08,.065,.94))
	hud_status_strip113=status
	tactics_label = UI.label(status,"",Vector2(18,6),18,UI.INK,895)
	speed_label = UI.label(status,"",Vector2(930,8),16,UI.GOLD,490)
	ready_panel = UI.panel(hud,Rect2(0,98,1440,46),Color(.045,.08,.065,.90))
	runup_panel = UI.panel(hud,Rect2(0,98,1440,46),Color(.045,.08,.065,.90))
	runup_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	callout = UI.label(hud,"整装待发",Vector2(20,106),23,UI.INK,285)
	subcallout = UI.label(hud,"",Vector2(315,109),18,UI.GOLD,540)
	intermission = UI.label(hud,"",Vector2(870,110),16,UI.INK,550)
	intermission.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	contact_panel = UI.panel(hud,Rect2(0,98,1440,46),Color(.045,.08,.065,.94))
	contact_label = UI.label(contact_panel,"",Vector2(18,10),16,UI.GOLD,690)
	enemy_contact_label = UI.label(contact_panel,"",Vector2(735,10),16,UI.GOLD,685)
	# Both layouts explicitly assign their width; the original label helper
	# otherwise keeps its 690px minimum when switched to compact mode.
	contact_label.custom_minimum_size.x = 0
	enemy_contact_label.custom_minimum_size.x = 0
	callout.custom_minimum_size.x = 0
	for label in [contact_label,enemy_contact_label,tactics_label,speed_label,intermission]:
		label.autowrap_mode = TextServer.AUTOWRAP_OFF
		label.clip_text = true
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS

func _build_hud_bottom() -> void:
	var bottom = UI.panel(hud,Rect2(0,720,1440,90),Color(.045,.08,.065,.96))
	hud_guard_help113=UI.label(bottom,"右键或 Q 换盾位",Vector2(18,5),16,UI.MUTED)
	guard_buttons.clear()
	for i in range(3):
		var slot = i
		var button = UI.button(bottom,GUARD_NAMES[i],Rect2(18+i*118,752-720,110,44),func():_select_guard(slot))
		button.toggle_mode = true
		button.focus_mode = Control.FOCUS_NONE
		button.add_theme_stylebox_override("pressed",UI.box(Color("b69a60"),Color("f0d08c"),5))
		button.add_theme_color_override("font_pressed_color",Color("15221e"))
		guard_buttons.append(button)
	var aim_panel = UI.panel(bottom,Rect2(390,8,510,72),Color(.045,.08,.065,0))
	aim_label = UI.label(aim_panel,"",Vector2(12,6),18,UI.INK,486)
	speed_meter = ProgressBar.new()
	speed_meter.position = Vector2(992,777)
	speed_meter.size = Vector2(428,10)
	speed_meter.min_value = 0.0
	speed_meter.max_value = Model.SURGE_SPEED*float(match_model.fighters[0].stats.get("speed",1.0))
	speed_meter.show_percentage = false
	# ProgressBar reserves a font row even when percentages are hidden.
	speed_meter.add_theme_font_size_override("font_size",1)
	speed_meter.visible = true
	var meter_background = UI.box(Color("14251f"),Color("65745b"),2)
	var meter_fill = UI.box(Color("c6a258"),Color("ead09a"),2)
	for meter_style in [meter_background,meter_fill]:
		meter_style.content_margin_top = 0
		meter_style.content_margin_bottom = 0
		meter_style.content_margin_left = 0
		meter_style.content_margin_right = 0
	speed_meter.add_theme_stylebox_override("background",meter_background)
	speed_meter.add_theme_stylebox_override("fill",meter_fill)
	hud.add_child(speed_meter)
	speed_meter.size = Vector2(428,10)
	# EQUIP-067: the horse's condition gets its own gauge and numbers. The old
	# status line held stamina at the end of a trimmed label, so players never
	# saw the horse tire. (Diagnostic readout; may be simplified later.)
	# Plain rects: a second themed ProgressBar grew to its minimum height and
	# covered the readout (equip067-hud01).
	var stamina_back = ColorRect.new()
	stamina_back.position = Vector2(950,750)
	stamina_back.size = Vector2(470,12)
	stamina_back.color = Color("14251f")
	stamina_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(stamina_back)
	stamina_bar = ColorRect.new()
	stamina_bar.position = Vector2(1,1)
	stamina_bar.size = Vector2(468,10)
	stamina_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stamina_back.add_child(stamina_bar)
	fatigue_label = UI.label(bottom,"",Vector2(950,0),18,UI.INK,470)
	# Pace belongs to the horse area. Drawing it as a child of the older
	# top strip at a bottom-screen offset put it behind this opaque panel.
	speed_label.reparent(bottom)
	fatigue_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	hint = UI.label(aim_panel,"按住左键催马，松手收速",Vector2(12,48),13,UI.MUTED,486)
	hint.autowrap_mode = TextServer.AUTOWRAP_OFF
	hint.clip_text = true
	hint.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	hud_speed_caption113=UI.label(bottom,"速度",Vector2(950,48),13,UI.MUTED,42)
	status_gauges = Status098.new()
	status_gauges.arena = mode=="arena"
	status_gauges.name = "CombatStatus"
	status_gauges.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status_gauges.size = Vector2(1440,810)
	hud.add_child(status_gauges)
	debug_numbers = UI.label(hud,"",Vector2(18,60),14,UI.INK,1404)
	debug_numbers.visible = false

func combat_safe_rect() -> Rect2:
	return COMBAT_SAFE_RECT

func _pointer_over_hud(point: Vector2) -> bool:
	# Keep-aspect windows can deliver negative / oversized logical X for side bars.
	return point.x<0.0 or point.x>=1440.0 or point.y<COMBAT_SAFE_RECT.position.y or point.y>=720.0 or (paused and is_instance_valid(pause_panel) and pause_panel.get_global_rect().has_point(point))

func _physics_process(delta: float) -> void:
	var trace_started = Trace099.begin()
	_physics_measured106(delta)
	Trace099.measure("battle_physics",trace_started)

func _physics_measured106(delta: float) -> void:
	if not presentation_ready: return
	if preload("res://scripts/core/window_activity.gd").suspended():
		return
	if paused or is_finished:
		return
	if match_model.phase=="ended":
		# A terminal state can be queued outside step() (e.g. a scripted end).
		# Stop controls, but still deliver the pending result exactly once.
		match_model.advance_terminal_pose113(delta)
		_consume_events(match_model.drain_events())
		_update_views()
		return
	var fighter = match_model.fighters[0]
	var hand = Model.hand_position(fighter)
	# Keep a committed angle while the pointer is still. A cinematic zoom
	# must not redirect the lance when the player has not moved the mouse.
	var aim = pointer_aim
	var lean = 0.0
	if GameState.profile.settings.mouse_only:
		lean = wheel_lean
	else:
		lean = float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)) - float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN))
	if touch_roles.values().has("lean"):
		lean = touch_lean
	if absf(lean)>.3:
		learned.posture = true
	var boost = (not ui_pointer_held and (mouse_held or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT))) or Input.is_physical_key_pressed(KEY_SPACE) or touch_roles.values().has("boost")
	if boost: learned.boost = true
	if autoplay:
		var target = Model.head_position(match_model.fighters[1])
		aim = asin(clampf((target.y-hand.y)/Model.lance_length(fighter),-.629,.548))
		boost = true
		lean = 0.15
	match_model.set_controls(0,aim,lean,boost,delta,GUARD_VALUES[guard_slot])
	_update_ai(delta)
	match_model.time_effect_active = bool(exchange_state.impact_active)
	match_model.step(delta)
	var events = match_model.drain_events()
	if practice_guide:
		practice_guide.observe(fighter,match_model.phase,delta,{"boost":boost,"aim":aim,"aim_revision":aim_revision,"guard":guard_slot,"lean":lean},events)
		if practice_guide.complete() and not lesson_reported:
			lesson_reported = true
			lesson_completed.emit()
	_consume_events(events)
	_update_views()

func _exchange_context() -> Dictionary:
	var a: Dictionary = match_model.fighters[0]
	var b: Dictionary = match_model.fighters[1]
	return {"phase":match_model.phase,"pass_id":match_model.pass_number,
		"gap":float(b.x)-float(a.x),"closing_speed":float(a.speed)+float(b.speed),
		"reach":maxf(Model.lance_length(a),Model.lance_length(b))+35.0,
		"slow_motion":bool(GameState.profile.settings.get("slow_motion",true))}

func _advance_exchange(real_delta: float) -> void:
	exchange_state = exchange_director.advance(real_delta,_exchange_context())
	approach_slow = exchange_state.state=="approach"
	pass_connected = bool(exchange_state.pass_connected)
	Engine.time_scale = 1.0 if is_finished else float(exchange_state.scale)

func _consume_events(events: Array) -> void:
	if events.is_empty():
		return
	# Aggregate a physics step before consuming it: simultaneous shield/body
	# contacts cannot shorten each other's hold or restart the same exchange.
	var prior_state = str(exchange_state.state)
	exchange_director.notify_contacts(events)
	_advance_exchange(0.0)
	if prior_state!="contact" and exchange_state.state=="contact":
		contact_first_frame_pending = true
		camera_impact_age = 0.0
		camera_impact_strength = -1.0
		camera_impact_attacker = 2147483647
		shake = 0.0
		impact_kick = Vector2.ZERO
	for event in events:
		_handle_event(event)
	_load_camera_impulse(events)

func _load_camera_impulse(events: Array) -> void:
	# A batch has one dominant visual impulse. Opposite simultaneous contacts
	# must not cancel on screen; ties are stable, independent of event order.
	for event in events:
		if event.get("type","")!="hit": continue
		var strength = clampf(Exchange.contact_strength(event),.15,1.0)
		# FEEL-097: an unhorsing blow is always the full jolt.
		if bool(event.get("unseated",event.get("ko",false))):
			strength = 1.0
		var attacker = int(event.attacker)
		if strength<camera_impact_strength or (strength==camera_impact_strength and attacker>=camera_impact_attacker): continue
		camera_impact_strength = strength
		camera_impact_attacker = attacker
		var direction = int(match_model.fighters[attacker].direction)
		# FEEL-097: the jolt follows both riders' momentum. A symmetric head-on
		# meeting stops both masses dead: mostly a vertical crunch. When one
		# rider is much faster, the pair's momentum carries through the blow
		# and the frame is thrown sideways in the faster rider's direction.
		var drift = Exchange.momentum(event,direction)
		var carry = clampf(absf(drift)*1.8,0.0,1.0)
		var lateral = signf(drift) if absf(drift)>.05 else float(direction)
		# Logical screen pixels, converted at the current zoom during rendering.
		shake = lerpf(5.0,20.0,strength)
		impact_kick = Vector2(lateral*lerpf(10.0,34.0,strength)*lerpf(.45,1.0,carry),-lerpf(2.0,12.0,strength)*(1.0-.6*carry))
		impact_drift = drift
		impact_life = lerpf(.48,.80,strength)
		impact_frequency = lerpf(7.0,4.5,strength)
		_rumble(strength,carry)

func _rumble(strength: float, carry: float) -> void:
	# FEEL-097: controller rumble alongside the camera jolt, same switch.
	if not GameState.profile.settings.shake:
		return
	for device in Input.get_connected_joypads():
		Input.start_joy_vibration(device,lerpf(.15,.55,strength),lerpf(.25,1.0,strength)*lerpf(1.0,.8,carry),lerpf(.14,.34,strength))

func _contact_camera_offset() -> Vector2:
	if not GameState.profile.settings.shake or camera_impact_age>=impact_life:
		return Vector2.ZERO
	var age = camera_impact_age
	var strength = clampf(camera_impact_strength,.15,1.0)
	# Heavier strikes ring longer and lower; a tap is a short, fine buzz.
	var envelope = exp(-lerpf(8.0,5.0,strength)*age)*(1.0-smoothstep(impact_life*.72,impact_life,age))
	var rate = lerpf(85.0,55.0,strength)
	var vibration = Vector2(noise.get_noise_1d(age*rate),noise.get_noise_1d(age*rate+100.0))*shake*.35
	var screen_offset = (impact_kick*cos(age*TAU*impact_frequency)+vibration)*envelope
	# The pair's net momentum then carries the frame a little after the jolt.
	screen_offset.x += impact_drift*lerpf(6.0,22.0,strength)*smoothstep(0.0,.18,age)*(1.0-smoothstep(impact_life*.6,impact_life,age))
	return screen_offset/maxf(.01,camera.zoom.x)

func _on_hoof_contact(leg_index: int, rider_index: int) -> void:
	if paused or match_model.phase!="charge":
		return
	var fighter = match_model.fighters[rider_index]
	var pace = clampf((float(fighter.speed)-Model.TROT_SPEED)/(Model.GALLOP_SPEED-Model.TROT_SPEED),0,1)
	var pose: Dictionary
	if riders[rider_index].leg_poses.size()==4:
		pose = riders[rider_index].leg_poses[leg_index]
	else:
		pose = riders[rider_index].Gait.leg(leg_index,riders[rider_index].stride_phase,float(fighter.speed),true)
	# ANIM-091: a driving launch throws more dirt back off the hinds; a check
	# makes the sitting hind hooves skid, spraying dirt forward.
	var drive = float(fighter.get("motion_drive",0.0))
	var hoof_point = Vector2(float(fighter.x)+pose.foot.x*int(fighter.direction),float(fighter.lane_y)+pose.foot.y)
	var push = clampf(drive,0,1)*(1.0 if leg_index<2 else .4)
	effects.dust(hoof_point,int(fighter.direction),clampf(pace+.65*push,0,1))
	if drive<-.35 and leg_index<2:
		effects.dust(hoof_point,-int(fighter.direction),clampf(-drive,0,1)*.7)
	sound.play("hoof",lerpf(-27,-12,pace)-(5 if rider_index==1 else 0),(.88 if leg_index<2 else 1.06)*lerpf(1.04,.94,pace))

func _on_armor_motion(strength: float, rider_index: int) -> void:
	if paused or match_model.phase!="charge" or not sound: return
	var fighter = match_model.fighters[rider_index]
	if fighter.get("ko",false) or fighter.get("dead",false): return
	var cue = sound.movement_cue(fighter.stats,strength,rider_index!=0)
	if not cue.is_empty(): sound.play(cue.cue,cue.db,cue.pitch)

func _update_ai(delta: float) -> void:
	if practice_guide and practice_guide.step<6:
		# An explicit non-attacking coach in guided practice only. The real
		# lance rises with its ordinary motor; competitive stats stay unchanged.
		match_model.set_controls(ai_fighter_index,-.68,0.0,practice_guide.step==5,delta,.43)
		match_model.fighters[ai_fighter_index].acted = true
		ai_guard = .43
		return
	var difficulty = 0 if practice else int(GameState.profile.settings.difficulty)
	var decision = ai_controller.update(match_model,ai_fighter_index,difficulty,delta,ai_rng,practice)
	ai_zone = decision.zone
	ai_guard = decision.guard
	ai_lean = decision.lean
	ai_target_y = decision.target_y
func _handle_event(event: Dictionary) -> void:
	match str(event.type):
		"hit":
			var recorded = event.duplicate(true)
			recorded["pass"] = match_model.pass_number
			exchange_log.append(recorded)
			pass_connected = true
			var index = int(event.defender)
			var strength = clampf(Exchange.contact_strength(event),.15,1.0)
			riders[index].receive_impact(strength,event.zone=="shield")
			riders[index].receive_contact(event)
			riders[int(event.attacker)].receive_lance_contact(strength)
			effects.hit(event.position,int(match_model.fighters[int(event.attacker)].direction),event.damage,event.zone=="shield",event.broke,event.zone,strength,event)
			if bool(event.get("shield_broke",false)):
				effects.break_shield(match_model.fighters[index],event)
			# FEEL-097: a horse knocked back onto its haunches skids its hinds,
			# spraying dirt forward; the slower horse of the pair skids hardest.
			for jolted in [int(event.attacker),index]:
				var mount: Dictionary = match_model.fighters[jolted]
				var skid = clampf(float(mount.get("reaction_horse_velocity",0.0))/10.0,0.0,1.0)
				if skid>.25:
					var facing = int(mount.direction)
					var hinds = Vector2(float(mount.x)-facing*50.0,float(mount.get("lane_y",0.0))+12.0)
					effects.dust(hinds,-facing,skid)
					effects.dust(hinds,facing,skid*.6)
			if event.broke:
				effects.break_lance(event,mode,match_model.fighters[int(event.attacker)].stats)
			var now = Time.get_ticks_msec()
			contact_audio.append(sound.impact_cue(event,match_model.fighters[index].stats))
			if event.broke:
				contact_audio.append(sound.break_cue(event))
			var hit_text = ("你命中 · " if int(event.attacker)==0 else "对手命中 · ")+Cues.contact_name(event)
			if bool(event.get("glanced",false)):
				hit_text += " · 擦偏"
			if bool(event.get("unseated",event.ko)):
				hit_text += " · 落马"
			elif event.ko:
				hit_text += " · 阵亡" if event.dead else " · 失去战斗能力"
			elif event.zone!="shield" and (not event.has("head_outcome") or training_zones):
				hit_text += (" · 重击" if float(event.impulse)>=70.0 else " · 命中") if not training_zones else " · 冲击 %d" % roundi(event.impulse)
				if float(event.get("support",1.0))<.70:
					hit_text += " · 失稳"
			if event.get("shield_broke",false):
				hit_text += " · 盾已破损"
			if now>=contact_until:
				for label in [contact_label,enemy_contact_label]:
					label.text = ""
					for key in ["debug_hit","compact_hit","display_debug"]:
						if label.has_meta(key): label.remove_meta(key)
			# A hit belongs beside the RECEIVING rider's life bar and body map.
			var actual_label = contact_label if int(event.defender)==0 else enemy_contact_label
			if actual_label.has_meta("diagnostic_notice113"):actual_label.remove_meta("diagnostic_notice113")
			var debug_hit = hit_text+"  冲击 %.1f  损伤 %.1f" % [float(event.impulse),float(event.damage)]
			actual_label.set_meta("debug_hit",debug_hit)
			actual_label.set_meta("compact_hit",Status098.contact_text(event))
			actual_label.set_meta("display_debug",_show_detailed_combat113())
			actual_label.text = debug_hit if _show_detailed_combat113() else Status098.contact_text(event)
			actual_label.add_theme_color_override("font_color",Cues.contact_color(event))
			contact_until = now+2100
			if bool(event.get("unseated",event.ko)):
				effects.fall(match_model.fighters[index],int(match_model.fighters[int(event.attacker)].direction),event,riders[index])
		"unseat":
			var index = int(event.defender)
			var recorded = event.duplicate(true)
			recorded["pass"]=match_model.pass_number
			exchange_log.append(recorded)
			var label = contact_label if index==0 else enemy_contact_label
			if label.has_meta("diagnostic_notice113"):label.remove_meta("diagnostic_notice113")
			var brief = Status098.contact_text(event)
			label.set_meta("compact_hit",brief)
			label.set_meta("debug_hit",brief+" · 鞍座支撑已失去")
			label.set_meta("display_debug",_show_detailed_combat113())
			label.text=brief
			label.add_theme_color_override("font_color",Color("e0ae59"))
			contact_until=Time.get_ticks_msec()+2100
			effects.fall(match_model.fighters[index],int(event.direction),event,riders[index])
		"charge":
			sound.play("horn",-10)
		"end":
			terminal_at = Time.get_ticks_msec()
			finished.emit(event.result)
		"rerack":
			camera_impact_age = 1.0
			camera_impact_strength = -1.0
			shake = 0.0
			impact_kick = Vector2.ZERO
			for rider in riders:
				rider.visible = true

func _process(delta: float) -> void:
	var trace_started=Trace099.begin()
	_process_measured099(delta)
	Trace099.measure("battle_process",trace_started)

func _process_measured099(delta: float) -> void:
	if not presentation_ready:
		_advance_preparation()
		return
	var now = Time.get_ticks_msec()
	if preload("res://scripts/core/window_activity.gd").suspended():
		last_visual_time = now
		return
	var elapsed = maxf(0.0,float(now-last_visual_time)/1000.0)
	var real_delta = minf(elapsed,.1)
	last_visual_time = now
	if not paused:
		var fresh_contact = not contact_audio.is_empty()
		# Start the contact's wall-clock budget at its first displayed frame.
		# A long pre-hit frame or synchronous result save must not consume
		# the whole hold before the player has seen that actual collision.
		_advance_exchange(0.0 if contact_first_frame_pending else elapsed)
		contact_first_frame_pending = false
		sound.set_movement_duck(float(exchange_state.audio_duck))
		# Start the short attack beside its visible frame, after any synchronous
		# result persistence. Keep hit rules and rewards in the physics step.
		for cue in sound.limit_contact_group(contact_audio):
			sound.play(cue.cue,cue.db,cue.pitch)
		contact_audio.clear()
		_update_camera(real_delta,now)
		if terminal_at>0 and not bool(exchange_state.hitstop) and not is_finished:
			# Keep riding out until the results cover the arena. Cutting off
			# at 1.4s snapped a galloping horse into its standing pose.
			departure_elapsed += delta
			for fighter in match_model.fighters:
				fighter.gait_moving = float(fighter.speed)>.5
				if fighter.gait_moving:
					fighter.gait_phase += delta*TAU*Model.Gait.frequency(float(fighter.speed))
		# FIX-104: retain impact/flight, then reach the result promptly. No pose
		# snapping or body removal when the wall-clock presentation budget ends.
		if terminal_at > 0 and now-terminal_at>1800 and not bool(exchange_state.impact_active) and (effects.falls_settled() or now-terminal_at>3600) and not is_finished:
			is_finished = true
			Engine.time_scale = 1.0
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		# Accumulate only unpaused time. Absolute wall-clock noise jumped phase
		# after pause; the former decay also ended before the loaded pose was read.
		if not fresh_contact:
			camera_impact_age += elapsed
		if wind and match_model:
			var pace = clampf((float(match_model.fighters[0].speed)-Model.TROT_SPEED)/(Model.GALLOP_SPEED-Model.TROT_SPEED),0,1)
			var duck = float(exchange_state.audio_duck)
			var wind_target = lerpf(-36,-12,pace)-duck*21.0 if match_model.phase=="charge" else -50.0
			wind.volume_db = lerpf(wind.volume_db,wind_target,1-exp(-real_delta*(24.0 if duck>.3 else 7.0)))
			var pitch_target = lerpf(.80,1.22,pace)*lerpf(1.0,.62,duck)
			wind.pitch_scale = lerpf(wind.pitch_scale,pitch_target,1-exp(-real_delta*12.0))
	if camera:
		if not GameState.profile.settings.shake:
			camera.offset = Vector2.ZERO
		elif not paused:
			var offset = _contact_camera_offset()
			camera.offset = _safe_camera_offset(offset)
	if match_model and match_model.phase == "ended" and world:
		_update_views()
	_update_hud()
	if is_instance_valid(impact_grade):
		impact_grade.queue_redraw()
	queue_redraw()

func _draw_impact_grade() -> void:
	# FEEL-097: frames the held moment. Edge bands darken the arena while the
	# exchange is in bullet time (deeper for heavier strikes and an unhorsing),
	# and the freeze opens with one soft flash. No strobe, HUD left untouched.
	if not bool(exchange_state.get("impact_active",false)):
		return
	var state = str(exchange_state.get("state","runup"))
	var strength = clampf(float(exchange_state.get("strength",0.0)),0.0,1.0)
	var weight = 1.0-float(exchange_state.get("release",0.0)) if state=="release" else 1.0
	var amount = weight*lerpf(.35,1.0,strength)*(1.15 if bool(exchange_state.get("ko",false)) else 1.0)
	var safe = COMBAT_SAFE_RECT
	for band in range(7):
		var r = safe.grow(-band*14.0)
		var color = Color(.03,.02,.02,.24*amount*(1.0-band/7.0))
		impact_grade.draw_rect(Rect2(r.position,Vector2(r.size.x,14)),color)
		impact_grade.draw_rect(Rect2(Vector2(r.position.x,r.end.y-14),Vector2(r.size.x,14)),color)
		impact_grade.draw_rect(Rect2(r.position+Vector2(0,14),Vector2(14,r.size.y-28)),color)
		impact_grade.draw_rect(Rect2(Vector2(r.end.x-14,r.position.y+14),Vector2(14,r.size.y-28)),color)
	if state=="contact":
		var flash = (1.0-smoothstep(0.0,.09,float(exchange_state.get("stage_elapsed",0.0))))*lerpf(.08,.20,strength)
		if flash>.002:
			impact_grade.draw_rect(safe,Color(1.0,.97,.88,flash))

func _safe_camera_offset(offset: Vector2) -> Vector2:
	# Camera offsets bypass position framing. Bound the final kick as well,
	# so a raised shield or hoof cannot briefly cross into a HUD band.
	var mounted_bounds = _mounted_vertical_bounds()
	var bounds = Vector2(camera_subject_bounds.position.y,camera_subject_bounds.end.y) if camera_subject_bounds.has_area() else mounted_bounds
	var safe = COMBAT_SAFE_RECT.grow(-2)
	var center_y = get_viewport_rect().size.y*.5
	var lower = bounds.y-(safe.end.y-center_y)/camera.zoom.y-camera.position.y
	var upper = bounds.x-(safe.position.y-center_y)/camera.zoom.y-camera.position.y
	if lower<=upper:
		offset.y = clampf(offset.y,lower,upper)
	if camera_subject_bounds.has_area():
		var center_x = get_viewport_rect().size.x*.5
		var left = camera_subject_bounds.end.x-(safe.end.x-center_x)/camera.zoom.x-camera.position.x
		var right = camera_subject_bounds.position.x-(safe.position.x-center_x)/camera.zoom.x-camera.position.x
		if left<=right: offset.x=clampf(offset.x,left,right)
	return offset

func _update_camera(real_delta: float, now: int) -> void:
	if not match_model or not camera:
		return
	if camera_pass!=match_model.pass_number:
		camera_pass = match_model.pass_number
		pass_connected = false
	var a = float(match_model.fighters[0].x)
	var b = float(match_model.fighters[1].x)
	var separation = absf(b-a)
	var before_crossing = a<b
	# Establish both riders before the start. During the long run-up follow
	# the player at a stable scale, so world-fixed posts/ground convey speed.
	# Return to a two-rider frame BEFORE the 1100-unit aiming commitment.
	var desired_zoom = .28
	var center_x = 720+(a+b)*.5
	if match_model.phase=="ready":
		# Settle into the run-up framing before the horse starts. Otherwise
		# camera travel on the first spur is mistaken for acceleration.
		var settle = 1.0-smoothstep(.25,1.35,float(match_model.phase_time))
		desired_zoom = lerpf(.28,RUNUP_ZOOM,settle)
		center_x = lerpf(center_x,720+a+450.0/desired_zoom,settle)
	elif match_model.phase=="charge" and before_crossing:
		var duel = 1.0-smoothstep(DUEL_FULL_GAP,DUEL_ENTER_GAP,separation)
		var duel_zoom = clampf(1120.0/(separation+300.0),.44,1.65)
		desired_zoom = lerpf(RUNUP_ZOOM,duel_zoom,duel)
		var follow_x = 720+a+450.0/desired_zoom
		center_x = lerpf(follow_x,720+(a+b)*.5,duel)
	elif match_model.phase in ["charge","turn","ended"]:
		desired_zoom = clampf(1120.0/(separation+300.0),.44,1.65)
	var fall_rect = _fall_camera_rect()
	var fall_weight = smoothstep(.06,.48,float(now-terminal_at)/1000.0) if fall_rect.has_area() else 0.0
	if terminal_at>0:
		desired_zoom = 1.6 if now-terminal_at<850 else 1.05
		if fall_rect.has_area():
			center_x = lerpf(center_x,fall_rect.get_center().x,fall_weight)
			desired_zoom = lerpf(desired_zoom,2.10 if bool(exchange_state.impact_active) else 1.70,fall_weight)
	# The contact lies on an actual swept hit. Bias horizontally toward it;
	# keep the full mounted vertical silhouette and both riders in frame.
	var focus_weight = float(exchange_state.focus_weight)
	if focus_weight>0.0 and fall_weight<1.0:
		var focus_x = world.position.x+Vector2(exchange_state.focus).x
		center_x = lerpf(center_x,clampf(focus_x,720+(a+b)*.5-75,720+(a+b)*.5+75),focus_weight*.65*(1.0-fall_weight))
	# A horizontal close-up must also fit the whole mounted silhouette.
	# This stable vertical envelope includes helmet decoration, raised shield,
	# the larger gait phases, both lanes and a small strip below all hooves.
	# Keeping the envelope independent of the current stride avoids chasing
	# the horse's bob with the camera and cancelling its visible movement.
	var vertical_bounds = _mounted_vertical_bounds()
	if fall_rect.has_area():
		vertical_bounds = vertical_bounds.lerp(Vector2(fall_rect.position.y,fall_rect.end.y),fall_weight)
	camera_subject_bounds = Rect2(Vector2(fall_rect.position.x,vertical_bounds.x),Vector2(fall_rect.size.x,vertical_bounds.y-vertical_bounds.x)) if fall_rect.has_area() else Rect2()
	# Reserve a real screen-space margin for the impact vibration as well as
	# helmet/hoof framing. The HUD remains outside the moving world canvas.
	var safe = COMBAT_SAFE_RECT.grow(-14)
	var zoom_limit = safe.size.y/maxf(1.0,vertical_bounds.y-vertical_bounds.x)
	if fall_rect.has_area(): zoom_limit=minf(zoom_limit,safe.size.x/maxf(1.0,fall_rect.size.x))
	# Reserve a quarter-scale push for an actual hit. A 7% reserve vanished
	# against the ordinary approach zoom, making contact look no larger.
	if match_model.phase=="charge" and before_crossing and not pass_connected:
		desired_zoom = minf(desired_zoom,zoom_limit*.78)
	elif focus_weight>0.0 and fall_weight<1.0:
		desired_zoom = lerpf(desired_zoom,zoom_limit,focus_weight)
	desired_zoom = minf(desired_zoom,zoom_limit)
	var response = 10.0 if match_model.phase=="ready" else (24.0 if focus_weight>0.0 else (5.0 if approach_slow else 4.0))
	var blend = 1.0-exp(-real_delta*response)
	camera.zoom = camera.zoom.lerp(Vector2.ONE*desired_zoom,blend)
	var viewport_center_y = get_viewport_rect().size.y*.5
	var framing_y = (vertical_bounds.x+vertical_bounds.y)*.5-(safe.get_center().y-viewport_center_y)/maxf(.01,camera.zoom.y)
	camera.position = camera.position.lerp(Vector2(center_x,framing_y),blend)
	# Keep the entire envelope between the HUD bands during zoom transitions.
	var lowest_center = vertical_bounds.y-(safe.end.y-viewport_center_y)/camera.zoom.y
	var highest_center = vertical_bounds.x-(safe.position.y-viewport_center_y)/camera.zoom.y
	if lowest_center<=highest_center:
		camera.position.y = clampf(camera.position.y,lowest_center,highest_center)
	if fall_rect.has_area():
		var viewport_center_x=get_viewport_rect().size.x*.5
		var left=fall_rect.end.x-(safe.end.x-viewport_center_x)/camera.zoom.x
		var right=fall_rect.position.x-(safe.position.x-viewport_center_x)/camera.zoom.x
		if left<=right:camera.position.x=clampf(camera.position.x,left,right)
	if match_model.phase=="ready":
		# Interpolate the rider's SCREEN position, not two incompatible
		# world centres while zoom changes. The old blend briefly cropped
		# both horses during the ready-to-follow transition.
		var settle = 1.0-smoothstep(.25,1.35,float(match_model.phase_time))
		var player_screen_x = lerpf(720.0-Model.START_X*.28,270.0,settle)
		camera.position.x = 720+a+(720-player_screen_x)/camera.zoom.x
	camera.force_update_scroll()
	# Distant scenery moves less than the near track; it is not tied to a
	# fabricated speed timer. Keep overscan so no image edge becomes visible.
	backdrop.position.x = -80-clampf((camera.position.x-720)*.025,-60,60)

func _mounted_vertical_bounds() -> Vector2:
	var top = INF
	var bottom = -INF
	for fighter in match_model.fighters:
		var lane = float(fighter.get("lane_y",0.0))
		top = minf(top,world.position.y+lane-350.0)
		bottom = maxf(bottom,world.position.y+lane+26.0)
	return Vector2(top,bottom)

func _fall_camera_rect() -> Rect2:
	# Track the real detached body (including helmet, shield and both boots).
	# A growing envelope avoids zoom pumping as knees fold. Include both people
	# on a simultaneous KO; never favour one just because its event came first.
	var rect=Rect2()
	for body in effects.bodies:
		if is_instance_valid(body):
			var bounds: Rect2=body.world_body_rect()
			rect=rect.merge(bounds) if rect.has_area() else bounds
	if not rect.has_area(): return rect
	fall_frame_size=fall_frame_size.max(rect.size+Vector2(64,64))
	return Rect2(rect.get_center()-fall_frame_size*.5,fall_frame_size)

func _update_views() -> void:
	# Terminal readability only: retain lane order and world-space ballistics,
	# but let the fallen silhouette show through foreground occluders.
	var far_fall = false
	for fallen in effects.bodies:
		if is_instance_valid(fallen) and float(fallen.fighter.get("lane_y",0))<0:
			far_fall = true
	var fade_blend = 1.0-exp(-8.0*get_process_delta_time())
	rail.modulate.a = lerpf(rail.modulate.a,.22 if far_fall else 1.0,fade_blend)
	for i in range(2):
		var fighter = match_model.fighters[i]
		var departing = 0.0
		if match_model.phase == "ended" and terminal_at > 0:
			departing = departure_elapsed*float(fighter.speed)*int(fighter.direction)
		riders[i].position = Vector2(float(fighter.x)+departing, float(fighter.get("lane_y",0.0)))
		# Results freeze the existing phase and departure position. Preserve
		# that pose on both the horse renderer and the model-driven saddle;
		# switching only the renderer to standing disconnected their geometry.
		riders[i].moving = match_model.phase=="charge" or (match_model.phase=="turn" and fighter.gait_moving) or (match_model.phase=="ended" and float(fighter.speed)>.5)
		riders[i].visible = true
		var obscures_fall = false
		for fallen in effects.bodies:
			if is_instance_valid(fallen) and float(fighter.get("lane_y",0))>float(fallen.fighter.get("lane_y",0)) and absf(riders[i].position.x-fallen.position.x)<360.0:
				obscures_fall = true
		# Only the horse occludes the distant fall. Never fade its mounted rider.
		riders[i].horse_opacity = lerpf(riders[i].horse_opacity,.20 if obscures_fall else 1.0,fade_blend)
		riders[i].blood_enabled = GameState.profile.settings.blood
	effects.blood_enabled = GameState.profile.settings.blood
	for fallen in effects.bodies:
		if is_instance_valid(fallen):
			for renderer in [fallen.visual,fallen.far_leg]:
				renderer.blood_enabled = GameState.profile.settings.blood
				renderer.queue_redraw()
	zone_overlay.visible = training_zones and _show_detailed_combat113()
	combat_cues.enabled = GameState.profile.settings.get("aim_cues",true)

func _show_detailed_combat113() -> bool:
	return bool(GameState.profile.settings.get("detailed_combat",false))

func _update_hud() -> void:
	if not match_model or not callout:
		return
	var detailed = _show_detailed_combat113()
	hud.visible = not is_finished
	var phase = match_model.phase
	runup_panel.visible = phase=="charge" and float(match_model.fighters[1].x)-float(match_model.fighters[0].x)>2000 and not is_finished
	ready_panel.visible = phase in ["ready","turn"] or (phase=="ended" and not is_finished)
	callout.visible = not is_finished
	subcallout.visible = not is_finished
	var f = match_model.fighters[0]
	var projection = Cues.project(match_model)
	var notice = _combat_notice()
	var show_aim = bool(GameState.profile.settings.get("aim_cues",true))
	aim_label.text = notice if not notice.is_empty() else ("枪线指向 "+Cues.NAMES[projection.zone] if projection.active else _exchange_hint())
	aim_label.add_theme_color_override("font_color",UI.GOLD if not notice.is_empty() else Cues.COLORS[projection.zone])
	# Aim assistance is optional; weapon failure and an exhausted arm are
	# essential state feedback. They must not live only in hidden diagnostics.
	aim_label.get_parent().visible = show_aim or not notice.is_empty()
	hint.visible = (show_aim or practice_guide!=null) and not bool(f.get("ko",false)) and phase!="ended"
	speed_meter.value = float(f.speed)
	# HORSE-065: a tired horse can still be urged, but no longer holds the gallop.
	var tired = float(f.stamina)<Model.Condition.TIRED
	# Match the model's equipment/load-adjusted cruise target. A fast horse
	# cruising normally must not appear to brake forever in the HUD.
	var speed_multiplier = float(f.stats.get("speed",1.0))*Model.Condition.load_speed_factor(f.stats)
	var cruise_target = Model.TROT_SPEED*speed_multiplier
	var pace_text = ("马累了，冲不起来" if tired else "催马冲刺") if f.boost else ("减速调枪" if float(f.speed)>cruise_target+20 else "松缰缓行")
	if phase=="ready":
		pace_text = "按住，准备催马" if f.boost else "整装待发"
	elif phase=="turn":
		pace_text = "回身让马歇口气"
	elif phase=="ended":
		pace_text = "交锋结束"
	var gait_name = Rider.Gait.NAMES[Rider.Gait.gait_index(float(f.speed))]
	# Urging is an input, not proof of speed: a tired horse can still be slow.
	# Keep the actual gait visible through acceleration AND release/coasting.
	speed_label.text = "%s · %s" % [gait_name,pace_text] if phase=="charge" else pace_text
	if detailed:
		speed_label.text = "%s · %s %d" % [pace_text,gait_name,roundi(float(f.speed))]
	var pace_color = smoothstep(Model.TROT_SPEED,Model.GALLOP_SPEED,float(f.speed)) if phase=="charge" else 0.0
	speed_label.add_theme_color_override("font_color",Color("c2d8ce").lerp(Color("f1bd67"),pace_color))
	var C = Model.Condition
	var stamina = float(f.stamina)
	var rate = -C.drain_rate(f.stats) if bool(f.boost) and phase=="charge" else (C.rest_rate(f.stats) if phase in ["ready","turn"] else C.recovery_rate(f.stats,float(f.speed),Model.GALLOP_SPEED*speed_multiplier,cruise_target))
	if phase=="ended" or stamina<=0.0 and rate<0.0 or stamina>=100.0 and rate>0.0:
		rate = 0.0 # Display the clamped change, not impossible gain/loss at a limit.
	var load_ratio = C.load_kg(f.stats)/maxf(1.0,C.capacity_kg(f.stats))
	stamina_bar.size = Vector2(468.0*clampf(stamina/100.0,0,1),10)
	stamina_bar.color = Color("6fae5a") if stamina>=C.TIRED+15 else (Color("d1a64a") if stamina>=C.TIRED else Color("c9573f"))
	fatigue_label.text = "马力 %d · 全速上限 %d%% · %+.1f/秒 · 负重 %d/%dkg (%d%%)" % [roundi(stamina),roundi(C.gallop_ceiling(stamina)*100.0),rate,roundi(C.load_kg(f.stats)),roundi(C.capacity_kg(f.stats)),roundi(load_ratio*100.0)]
	if not detailed:
		fatigue_label.text = "马匹体力 · "+("力竭" if stamina<20 else ("疲惫" if tired else ("吃力" if stamina<80 else "充沛")))
	fatigue_label.add_theme_color_override("font_color",UI.INK if stamina>=C.TIRED else Color("f08a6a"))
	var guard_text = GUARD_NAMES[guard_slot]+" · "+["下身较易暴露","头腹较易暴露","头胸较易暴露"][guard_slot]
	if absf(float(f.guard)-GUARD_VALUES[guard_slot])>.08:
		guard_text = "正在换盾，留意空隙"
	if float(f.shield)<=0:
		guard_text = "盾碎了，侧身避枪"
	for i in range(guard_buttons.size()):
		guard_buttons[i].button_pressed = i==guard_slot
		guard_buttons[i].disabled = float(f.shield)<=0 or is_finished
	tactics_label.text = "%s　|　枪稳 %d%%　|　平衡 %d%%　|　重心 %d%%　|　盾 %d%%　|　臂力 %d%%" % [guard_text,roundi(float(f.lance_stability)*100),roundi(f.balance),roundi((1.0-float(f.get("unsteady",0.0)))*100),roundi(float(f.shield)/float(f.stats.get("shield_capacity",78.0))*100),roundi(float(f.get("arm",100.0)))]
	if not detailed:
		tactics_label.text = guard_text
		if mode=="war" and float(f.get("head_load",0.0))>=Model.WAR_HEAD_LOAD_LIMIT*.5:
			tactics_label.text += "　· 头部重创，谨防再中"
		elif float(f.hp)<35: tactics_label.text += "　· 重伤"
		elif float(f.hp)<70: tactics_label.text += "　· 受伤"
		# FEEL-094: flailing is the one balance problem the player can fix now.
		if float(f.get("unsteady",0.0))>.45: tactics_label.text += "　· 重心不稳，减少急摆"
		elif float(f.balance)<40: tactics_label.text += "　· 坐姿失衡"
		elif not f.broken and float(f.lance_stability)<.65: tactics_label.text += "　· 枪未稳住"
	if f.broken:
		tactics_label.text += "　· 枪已断"
		if mode=="arena" and match_model.pass_number<match_model.MAX_PASSES:
			tactics_label.text += "，下轮换新枪"
		elif mode=="war":
			tactics_label.text += "，仅余残柄"
	if float(f.get("arm",100.0))<40.0:
		tactics_label.text += "　· 手臂酸软"
	if approach_slow:
		tactics_label.text += "　· 接近放缓"
	if not detailed and bool(f.ko):
		# Once unhorsed, further defensive advice is no longer actionable.
		tactics_label.text = "骑手阵亡" if bool(f.dead) else ("落马出局" if bool(f.get("unseated",true)) else "伤重退赛")
	tactics_label.modulate = Color(1.3,1.2,.7) if Time.get_ticks_msec()<input_flash_until else Color.WHITE
	if practice:
		hint.text = "练习 · 催马%s　调枪%s　防盾%s　俯仰%s" % ["✓" if learned.boost else "·","✓" if learned.aim else "·","✓" if learned.guard else "·","✓" if learned.posture else "·"]
	if practice_guide:
		tactics_label.text = practice_guide.instruction(bool(GameState.profile.settings.mouse_only))
		hint.text = "教练收枪 · 先专心练动作" if practice_guide.step<6 else "教练开始出枪 · 留意实际格挡回报"
		if practice_guide.complete(): hint.text = "七项完成 · 可查看小结或继续对冲"
		lesson_result_button.visible = practice_guide.complete() and not is_finished
		pass_label.visible = not lesson_result_button.visible
	var hud_now = pause_started if paused else Time.get_ticks_msec()
	if not detailed and contact_label.has_meta("diagnostic_notice113"):
		contact_label.text=""
		contact_label.remove_meta("diagnostic_notice113")
		if enemy_contact_label.text.is_empty():contact_until=0
	contact_label.visible = hud_now<contact_until and phase in ["charge","ended"]
	enemy_contact_label.visible = contact_label.visible
	contact_label.position.y = 10
	enemy_contact_label.position.y = 10
	contact_panel.visible = contact_label.visible
	for label in [contact_label,enemy_contact_label]:
		if label.has_meta("compact_hit") and bool(label.get_meta("display_debug"))!=detailed:
			label.text = str(label.get_meta("debug_hit" if detailed else "compact_hit"))
			label.set_meta("display_debug",detailed)
	pass_label.text = "PASS  %02d / 03" % match_model.pass_number
	if match_model.mode=="arena":
		# EQUIP-067 tournament scoring: shown beside the pass count.
		pass_label.text = "%02d/03 · 比分 %d : %d" % [match_model.pass_number,int(match_model.fighters[0].get("score",0)),int(match_model.fighters[1].get("score",0))]
	intermission.visible = phase in ["ready","turn"]
	if phase == "ready":
		callout.text = "准备 · %d" % maxi(1,ceili(match_model.phase_time))
		callout.modulate.a = 1
		subcallout.text = "整装 · %d" % maxi(1,ceili(match_model.phase_time))
		intermission.text = "每轮换新枪" if mode=="arena" else ("骑枪已断 · 残柄作战" if match_model.fighters[0].broken else "实战 · 留意防护")
	elif phase == "charge":
		callout.text = ""
		var gap = float(match_model.fighters[1].x)-float(f.x)
		subcallout.text = "对手在前方 · 按住催马，松手减速" if gap>2000 else ""
		if practice_guide and not practice_guide.complete():
			subcallout.text = "教练收枪 · 先按上方提示练动作" if practice_guide.step<6 else "教练瞄准胸口 · 提前把盾移到护胸"
	elif phase == "turn":
		callout.text = "回身重整"
		subcallout.text = "下一次对冲即将开始"
		intermission.text = "调整枪盾 · 马匹恢复体力"
	elif phase == "ended":
		callout.text = "交锋已定"
		subcallout.text = ""
	callout.visible = not is_finished and phase in ["ready","turn","ended"] and not contact_panel.visible
	subcallout.visible = not is_finished and not contact_panel.visible and not subcallout.text.is_empty()
	# DEV-113: detailed values require an explicit setting; H only toggles geometry within that mode.
	status_gauges.visible = not detailed and not is_finished
	if status_gauges.visible:
		status_gauges.minimal113=true
		status_gauges.contact_active113=contact_label.visible
		status_gauges.refresh(match_model.fighters,exchange_log,match_model.pass_number)
	debug_numbers.visible = detailed and not is_finished
	if debug_numbers.visible:
		var enemy = match_model.fighters[1]
		debug_numbers.text = "你 HP %d 平衡 %d  |  对手 HP %d 平衡 %d  |  %s\n伤情 %d%% · 意识 %d · 鞍座支撑 %d%% · 滑移 %.1f · 臂力 %d · 枪稳 %d%% · 盾 %d%%  |  %s" % [roundi(f.hp),roundi(f.balance),roundi(enemy.hp),roundi(enemy.balance),fatigue_label.text,roundi(float(f.get("injury",0))*100),roundi(float(f.get("consciousness",100))),roundi(float(f.get("seat_support",1))*100),float(f.get("seat_offset",0)),roundi(float(f.get("arm",100))),roundi(float(f.lance_stability)*100),roundi(float(f.shield)/maxf(1,float(f.stats.get("shield_capacity",150)))*100),guard_text]
	tactics_label.visible = false
	speed_label.visible = detailed
	# Diagnostic pace shares the lower-right horse gauge.
	speed_label.position = Vector2(950,1)
	fatigue_label.visible = not detailed
	pass_label.visible = detailed
	subcallout.visible = false
	intermission.visible = false
	callout.position = Vector2(603,116)
	callout.size = Vector2(234,36)
	callout.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if not detailed:
		contact_label.position = Vector2(24,1)
		contact_label.size = Vector2(350,24)
		enemy_contact_label.position = Vector2(1066,1)
		enemy_contact_label.size = Vector2(350,24)
		for label in [contact_label,enemy_contact_label]:
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		fatigue_label.text = "马力"+(" · 力竭" if stamina<20 else (" · 疲惫" if tired else ""))
		if practice_guide:
			hint.text = practice_guide.instruction(bool(GameState.profile.settings.mouse_only))
			aim_label.get_parent().visible=true
		else:
			hint.visible=false
			aim_label.text=notice.get_slice(" · ",0) if not notice.is_empty() else (("枪线 · "+Cues.NAMES[projection.zone]) if show_aim and projection.active else "")
			if notice.begins_with("鞍座失稳"):aim_label.text="失稳 · 回正身体"
			aim_label.get_parent().visible=not aim_label.text.is_empty()
		# If the notice is absent, the weapon gauges remain readable without
		# filling the empty centre with repeated control instructions.
		hud_guard_help113.visible=practice_guide!=null or phase in ["ready","turn"]
		hud_speed_caption113.text="速度"
	else:
		contact_label.position = Vector2(18,0)
		contact_label.size = Vector2(690,30)
		enemy_contact_label.position = Vector2(735,0)
		enemy_contact_label.size = Vector2(685,30)
		for label in [contact_label,enemy_contact_label]: label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		hud_guard_help113.visible=true
		hud_speed_caption113.text="速度"
	hud_brand113.visible=detailed
	hud_context113.position.x=290 if detailed else 24
	# Two CJK text lines are taller than the original one-line 40px band.
	# Fit the existing 58..144px HUD area without covering the riders.
	hud_status_strip113.size.y=maxf(40.0,ceilf(debug_numbers.get_minimum_size().y)+4.0) if detailed else 40.0
	contact_panel.position.y=58.0+hud_status_strip113.size.y if detailed else 98.0
	contact_panel.size.y=144.0-contact_panel.position.y if detailed else 46.0
	hud_status_strip113.self_modulate.a=1.0 if detailed else 0.0
	contact_panel.self_modulate.a=1.0 if detailed else 0.0
	# Keep the short countdown legible over bright sky without restoring a
	# full-width explanatory band. Both HUD modes retain this essential cue.
	ready_panel.position=callout.position
	ready_panel.size=callout.size
	ready_panel.visible=callout.visible
	runup_panel.visible=false
	if not paused:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _combat_notice() -> String:
	var player: Dictionary = match_model.fighters[0]
	if bool(player.get("ko",false)):
		return "骑手阵亡" if bool(player.get("dead",false)) else ("落马出局" if bool(player.get("unseated",true)) else "伤重退赛")
	if match_model.phase=="ended": return ""
	if float(player.get("seat_support",1.0))<.35: return "鞍座失稳 · 回正身体"
	if float(player.get("shield",1.0))<=0.0: return "盾已破 · 用俯仰避开来枪"
	if mode=="war" and float(player.get("head_load",0.0))>=Model.WAR_HEAD_LOAD_LIMIT*.5:
		return "头部重创 · 提前护头"
	if bool(player.get("broken",false)):
		if mode=="war": return "枪已断 · 残柄射程与冲力下降"
		return "枪已断 · 下轮换新枪" if match_model.pass_number<match_model.MAX_PASSES else "枪已断 · 先护住身体"
	if float(player.get("unsteady",0.0))>.45: return "重心不稳 · 减少急摆"
	if float(player.get("balance",100.0))<35.0: return "坐姿失衡 · 稳住身体"
	if float(player.get("arm",100.0))<40.0: return "手臂酸软 · 放缓调枪"
	return ""

func _exchange_hint() -> String:
	if match_model.phase=="ended":
		return "对冲结束"
	if match_model.phase=="ready":
		return "准备好，提前举盾"
	if match_model.phase=="turn":
		return "准备下一轮"
	var player: Dictionary = match_model.fighters[0]
	var opponent: Dictionary = match_model.fighters[1]
	if float(player.x)>=float(opponent.x):
		return "准备回身"
	if bool(player.acted):
		return "稳住身体" if bool(opponent.acted) else "举盾防住来枪"
	return "提前举盾，盯住枪尖"

func _draw() -> void:
	if not presentation_ready: return
	if preload("res://scripts/core/window_activity.gd").suspended():
		return
	for i in range(2):
		if match_model:
			var point = world.position+riders[i].position+Vector2(0,12)
			var air = clampf(-float(Model.gait_pose(match_model.fighters[i]).offset.y)/30.0,0,1)
			draw_set_transform(point,0,Vector2(lerpf(1,.91,air),lerpf(.22,.17,air)))
			draw_circle(Vector2.ZERO,125,Color(0,0,0,lerpf(.19,.13,air)))
			draw_set_transform(Vector2.ZERO)
	# A fallen rider needs the same ground reference as a mount. This lives
	# behind the actors/rail, on his actual lane floor, and never alters the
	# support solver. A high airborne body casts a lighter, softer footprint;
	# contact gathers it under the supported silhouette rather than the hip.
	if effects:
		for fallen in effects.bodies:
			if not is_instance_valid(fallen):continue
			var bounds: Rect2 = fallen.world_body_rect()
			var floor_point = fallen.get_parent().to_global(Vector2(0,fallen.ground_y))
			var center = to_local(Vector2(bounds.get_center().x,floor_point.y))
			var height = maxf(0.0,float(fallen.ground_y)-fallen.position.y-fallen.lowest_body_point())
			var airborne = smoothstep(0.0,160.0,height)
			var radius = clampf(bounds.size.x*.44,24.0,126.0)
			draw_set_transform(center,0,Vector2(1.0,lerpf(7.0,12.0,airborne)/radius))
			draw_circle(Vector2.ZERO,radius,Color(.10,.08,.05,lerpf(.23,.055,airborne)))
			if height<20.0:
				draw_set_transform(center,0,Vector2(.80,3.0/radius))
				draw_circle(Vector2.ZERO,radius,Color(.08,.06,.04,.11*(1.0-smoothstep(0.0,20.0,height))))
			draw_set_transform(Vector2.ZERO)

func _draw_rail() -> void:
	# A separate canvas item sits between the far and near mounts, rather
	# than the parent's draw call (which is behind every child).
	for x in range(-5700,5800,130):
		rail.draw_rect(Rect2(x,-92,12,104),Color("58432c"))
		rail.draw_rect(Rect2(x+2,-92,3,104),Color("a0814e"))
	rail.draw_rect(Rect2(-5700,-94,11500,12),Color("9e7843"))
	rail.draw_line(Vector2(-5700,-94),Vector2(5800,-94),Color("d3af69"),2)
	rail.draw_rect(Rect2(-5700,-43,11500,7),Color("705231"))

func _draw_track() -> void:
	# World-space hoof tracks and tufts supply a stable parallax reference.
	# Both lanes stay distinct and every mark remains fixed to the ground.
	for lane in [-32.0,32.0]:
		track.draw_rect(Rect2(-5700,lane+7,11500,28),Color(.36,.31,.22,.30))
		for i in range(-74,75):
			var x = i*78.0
			var y = lane+16+posmod(i*17,15)
			track.draw_line(Vector2(x,y),Vector2(x+19+posmod(i*7,21),y),Color(.30,.26,.18,.46),3)
			track.draw_line(Vector2(x+35,y+7),Vector2(x+43,y+7),Color(.65,.56,.36,.40),2)
	for i in range(-50,51):
		var x = i*113.0
		track.draw_polyline(PackedVector2Array([Vector2(x,83),Vector2(x-4,76),Vector2(x+1,80),Vector2(x+4,73)]),Color("777445"),2)

func _unhandled_input(event: InputEvent) -> void:
	if not presentation_ready:
		if event is InputEventKey and event.pressed and not event.echo and KEY_ESCAPE in [event.keycode,event.physical_keycode]:
			preparation_pause_requested = true
			get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var keys = [event.keycode,event.physical_keycode]
		if is_finished:
			# The result belongs to Main. Escape leaves it, R restarts once,
			# and H reaches Main's report instead of toggling hidden hit zones.
			if KEY_ESCAPE in keys:
				get_viewport().set_input_as_handled()
				exit_requested.emit()
			elif KEY_R in keys:
				get_viewport().set_input_as_handled()
				replay_requested.emit()
			return
		if KEY_ESCAPE in keys:
			_toggle_pause()
			get_viewport().set_input_as_handled()
		elif KEY_R in keys:
			get_viewport().set_input_as_handled()
			replay_requested.emit()
			return
		elif KEY_H in keys and _show_detailed_combat113():
			training_zones = not training_zones
			zone_overlay.visible = training_zones
			enemy_contact_label.text = ""
			for label in [contact_label,enemy_contact_label]:
				for meta in ["compact_hit","debug_hit","display_debug"]:
					if label.has_meta(meta):label.remove_meta(meta)
			contact_label.set_meta("diagnostic_notice113",true)
			contact_label.add_theme_color_override("font_color",UI.GOLD)
			contact_label.text = "判定显示：金色盾牌 · 青色头 / 胸 / 腰腹" if training_zones else "判定显示已关闭"
			contact_until = Time.get_ticks_msec()+2300
		elif KEY_Q in keys and not paused:
			_select_guard((guard_slot+1)%3)
		elif KEY_1 in keys and not paused:
			_select_guard(0)
		elif KEY_2 in keys and not paused:
			_select_guard(1)
		elif KEY_3 in keys and not paused:
			_select_guard(2)
	if paused:
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			wheel_lean = clampf(wheel_lean + .33,-1,1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			wheel_lean = clampf(wheel_lean - .33,-1,1)
		elif event.button_index == MOUSE_BUTTON_MIDDLE:
			wheel_lean = 0
	if event is InputEventScreenTouch:
		if event.pressed and not event.canceled:
			if _pointer_over_hud(event.position):
				return
			var role = "lean" if event.position.x < 720 else ("boost" if touch_roles.values().has("aim") else "aim")
			touch_roles[event.index] = role
			touch_origin[event.index] = event.position
			if role == "aim":
				touch_aim = event.position
				_set_pointer_aim(event.position)
		else:
			if touch_roles.get(event.index) == "lean":
				touch_lean = 0
			if touch_roles.get(event.index) == "aim":
				touch_aim = Vector2.ZERO
			touch_roles.erase(event.index)
			touch_origin.erase(event.index)
	elif event is InputEventScreenDrag:
		if touch_roles.get(event.index) == "lean":
			touch_lean = clampf((Vector2(touch_origin[event.index]).y-event.position.y)/100,-1,1)
		elif touch_roles.get(event.index) == "aim":
			touch_aim = event.position
			_set_pointer_aim(event.position)

func _input(event: InputEvent) -> void:
	if not presentation_ready or is_finished: return
	# Godot supplies viewport coordinates after stretch/DPI conversion. Keep
	# aiming on this event path rather than polling an OS cursor every tick;
	# it also supports deterministic replay and injected input verification.
	if event is InputEventMouseMotion or event is InputEventMouseButton:
		aim_pointer = event.position
	if event is InputEventScreenTouch and event.pressed and not event.canceled:
		var slot = _guard_at(event.position)
		if slot>=0:
			_select_guard(slot)
			get_viewport().set_input_as_handled()
			return
	if event is InputEventMouseMotion and not paused and not _pointer_over_hud(event.position):
		_set_pointer_aim(event.position)
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
		ui_pointer_held = event.pressed and _pointer_over_hud(event.position)
		mouse_held = event.pressed and not paused and not ui_pointer_held
		if mouse_held:
			input_flash_until = Time.get_ticks_msec()+350
			learned.boost = true
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_RIGHT and event.pressed and not paused:
		_select_guard((guard_slot+1)%3)

func _select_guard(slot: int) -> void:
	if paused or is_finished or (match_model and float(match_model.fighters[0].shield)<=0):
		return
	guard_slot = clampi(slot,0,2)
	guard_high = guard_slot==0
	learned.guard = true
	input_flash_until = Time.get_ticks_msec()+220
	if sound:
		sound.play("click",-16,.7)

func _guard_at(point: Vector2) -> int:
	for i in range(guard_buttons.size()):
		if is_instance_valid(guard_buttons[i]) and guard_buttons[i].get_global_rect().has_point(point):
			return i
	return -1

func _set_pointer_aim(point: Vector2) -> void:
	if not match_model or not world:
		return
	var mouse = get_canvas_transform().affine_inverse()*point-world.position
	var difference = mouse-Model.hand_position(match_model.fighters[0])
	var previous = pointer_aim
	# In a fixed lane duel the readable choice is tip HEIGHT, not how far
	# horizontally the cursor happens to be from the approaching rider.
	pointer_aim = asin(clampf(difference.y/Model.lance_length(match_model.fighters[0]),-.629,.548))
	if absf(pointer_aim-previous)>.025:
		learned.aim = true
		aim_revision += 1

func _toggle_pause() -> void:
	if not presentation_ready:
		# Minimize/focus loss can arrive between construction slices. Remember
		# explicit Resume without touching HUD/audio nodes that do not exist yet.
		preparation_pause_requested = true
		if wind: wind.stream_paused = true
		if sound: sound.set_paused(true)
		return
	if is_finished:
		return
	paused = not paused
	get_tree().paused = paused
	wind.stream_paused = paused
	sound.set_paused(paused)
	exchange_director.set_paused(paused)
	if paused:
		pause_started = Time.get_ticks_msec()
		_clear_touch()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		pause_panel = UI.panel(hud,Rect2(465,160,510,480),Color(.055,.09,.07,.98))
		UI.label(pause_panel,"暂停",Vector2(28,24),24,UI.GOLD)
		var blood_switch = UI.check(pause_panel,"显示血腥表现",GameState.profile.settings.blood,Vector2(28,90),func(value):
			_pause_setting("blood",value)
			if not value:
				effects.clear_blood()
			_update_views())
		var shake_switch = UI.check(pause_panel,"镜头震动",GameState.profile.settings.shake,Vector2(28,140),func(value):_pause_setting("shake",value))
		var detail_switch = UI.check(pause_panel,"详细战斗信息",_show_detailed_combat113(),Vector2(28,190),func(value):
			_pause_setting("detailed_combat",value)
			if not value:training_zones=false
			_update_hud();_update_views())
		detail_switch.name="DetailedCombatPause"
		pause_save_notice = UI.label(pause_panel,"",Vector2(28,238),14,Color("efb566"),454)
		var resume_button = UI.button(pause_panel,"继续对冲",Rect2(28,270,454,52),_toggle_pause,true)
		var restart_button = UI.button(pause_panel,"重新比赛",Rect2(28,335,220,48),func():replay_requested.emit())
		var exit_button = UI.button(pause_panel,"返回营地",Rect2(262,335,220,48),func():exit_requested.emit())
		UI.label(pause_panel,"关闭详细信息可恢复简洁界面。\n血腥设置只改变画面，不改变伤害或死亡结果。",Vector2(28,412),15,UI.MUTED,454)
		UI.focus_actions([blood_switch,shake_switch,detail_switch,resume_button,restart_button,exit_button],3)
	else:
		pause_panel.hide()
		pause_panel.queue_free()
		# Space belongs to urging the horse again, not activating a previously
		# focused Pause button when the player releases it after resuming.
		var focused = get_viewport().gui_get_focus_owner()
		if is_instance_valid(focused): focused.release_focus()
		var pause_duration = Time.get_ticks_msec()-pause_started
		if terminal_at > 0:
			terminal_at += pause_duration
		if contact_until>pause_started:
			contact_until += pause_duration
		# A paused impact resumes its remaining budget; paused wall time is
		# excluded from presentation just as it is from physics and audio.
		last_visual_time = Time.get_ticks_msec()
		Engine.time_scale = float(exchange_state.scale)

func _pause_setting(key: String, value: Variant) -> void:
	GameState.set_setting(key,value)
	if is_instance_valid(pause_save_notice):
		pause_save_notice.text = "" if GameState.save_error.is_empty() else "设置已应用，暂未保存；回营地可重试保存。"
		pause_save_notice.tooltip_text = GameState.save_error

func _clear_touch() -> void:
	spur_left = 0
	mouse_held = false
	ui_pointer_held = false
	touch_roles.clear()
	touch_origin.clear()
	touch_lean = 0.0
	touch_aim = Vector2.ZERO

func _on_focus_lost() -> void:
	if not is_inside_tree():
		return
	_clear_touch()
	if not autoplay and not paused and not is_finished:
		_toggle_pause()

func _exit_tree() -> void:
	if wind:
		wind.stop()
		wind.stream = null
	if sound:
		sound.stop_all()
	Engine.time_scale = 1.0
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
