class_name BattleScene
extends Node2D

signal finished(result: Dictionary)
signal exit_requested
signal replay_requested

const Model = preload("res://scripts/core/joust_match.gd")
const Rider = preload("res://scripts/visual/rider_view.gd")
const FX = preload("res://scripts/visual/impact_fx.gd")
const UI = preload("res://scripts/ui/ui_factory.gd")
const Catalogue = preload("res://scripts/core/catalogue.gd")
const BACKGROUND = preload("res://assets/art/tournament_field.png")
const WAR_BACKGROUND = preload("res://assets/art/campaign_field.png")

var match_model: JoustMatch
var mode = "arena"
var world: Node2D
var riders: Array = []
var effects: ImpactFX
var hud: Control
var callout: Label
var subcallout: Label
var pass_label: Label
var hint: Label
var intermission: Label
var pause_panel: Control
var paused = false
var pause_started = 0
var is_finished = false
var terminal_at = 0
var departure_elapsed = 0.0
var last_visual_time = 0
var hitstop_until = 0
var slow_until = 0
var shake = 0.0
var noise = FastNoiseLite.new()
var wheel_lean = 0.0
var touch_lean = 0.0
var touch_aim = Vector2.ZERO
var aim_pointer = Vector2(1150,400)
var touch_roles: Dictionary = {}
var touch_origin: Dictionary = {}
var ai_timer = 0.0
var ai_error = 0.0
var ai_zone = "body"
var ai_rng = RandomNumberGenerator.new()
var dust_timer = 0.0
var hoof_timer = 0.0
var last_phase = ""
var sound: SoundBank
var autoplay = false
var demo_seed = 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	last_visual_time = Time.get_ticks_msec()
	aim_pointer = get_global_mouse_position().clamp(Vector2.ZERO,Vector2(1440,810))
	noise.seed = 421
	noise.frequency = 7.0
	ai_rng.randomize()
	var player_stats = GameState.player_stats()
	var enemy_stats = Catalogue.opponent_stats(GameState.items,Catalogue.era_for_renown(int(GameState.profile.renown)))
	match_model = Model.new(mode, player_stats, enemy_stats, demo_seed if demo_seed else int(Time.get_ticks_usec()))
	world = Node2D.new()
	world.process_mode = Node.PROCESS_MODE_PAUSABLE
	world.position = Vector2(720,645)
	add_child(world)
	effects = FX.new()
	effects.blood_enabled = GameState.profile.settings.blood
	world.add_child(effects)
	var ground = StaticBody2D.new()
	ground.position = Vector2(0,22)
	ground.collision_layer = 8
	ground.collision_mask = 4
	var shape = CollisionShape2D.new()
	var rectangle = RectangleShape2D.new()
	rectangle.size = Vector2(2600,20)
	shape.shape = rectangle
	ground.add_child(shape)
	world.add_child(ground)
	for i in range(2):
		var rider = Rider.new()
		rider.fighter = match_model.fighters[i]
		rider.red = i == 1 or int(GameState.profile.region) == 1
		rider.mode = mode
		rider.blood_enabled = GameState.profile.settings.blood
		rider.z_index = 0 if i == 1 else 2
		match_model.fighters[i]["red"] = rider.red
		world.add_child(rider)
		riders.append(rider)
	sound = SoundBank.new()
	sound.enabled = GameState.profile.settings.sound
	add_child(sound)
	_build_hud()
	get_window().focus_exited.connect(_on_focus_lost)
	_update_views()

func _build_hud() -> void:
	var layer = CanvasLayer.new()
	add_child(layer)
	hud = Control.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.theme = UI.theme()
	layer.add_child(hud)
	var top = UI.panel(hud, Rect2(0,0,1440,76), Color(.045,.08,.065,.96))
	UI.label(top, "LANCE & LAUREL", Vector2(28,13), 24, UI.GOLD)
	UI.label(top, "竞技场 · 非致死比武" if mode == "arena" else "实战 · 致命对冲", Vector2(280,23),18)
	pass_label = UI.label(top,"PASS  01 / 03",Vector2(1050,20),22,UI.GOLD)
	UI.button(top,"暂停  Esc",Rect2(1240,14,165,45),_toggle_pause)
	callout = UI.label(hud,"整装待发",Vector2(420,123),40,UI.INK,600)
	callout.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subcallout = UI.label(hud,"",Vector2(370,183),18,UI.GOLD,700)
	subcallout.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	intermission = UI.label(hud,"",Vector2(330,245),19,UI.INK,780)
	intermission.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var bottom = UI.panel(hud,Rect2(0,758,1440,52),Color(.045,.08,.065,.96))
	hint = UI.label(bottom,"鼠标瞄准  ·  左键加速  ·  W 前倾 / S 后倾  ·  Esc 暂停",Vector2(35,13),17,UI.MUTED)
	UI.label(bottom,"没有准星。看枪尖，读对手。",Vector2(1080,13),17,UI.GOLD)

func _physics_process(delta: float) -> void:
	if paused or is_finished:
		return
	var fighter = match_model.fighters[0]
	var mouse = aim_pointer - world.position
	if not touch_roles.is_empty() and touch_aim != Vector2.ZERO:
		mouse = touch_aim - world.position
	var hand = Model.hand_position(fighter)
	var difference = mouse - hand
	var aim = atan2(difference.y, maxf(absf(difference.x),35.0))
	var lean = 0.0
	if GameState.profile.settings.mouse_only:
		lean = wheel_lean
	else:
		lean = float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)) - float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN))
	if touch_roles.values().has("lean"):
		lean = touch_lean
	var boost = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or Input.is_physical_key_pressed(KEY_SPACE) or touch_roles.values().has("boost")
	if autoplay:
		var target = Model.head_position(match_model.fighters[1])
		aim = atan2(target.y-hand.y, maxf(absf(target.x-hand.x),35))
		boost = true
		lean = 0.15
	match_model.set_controls(0,aim,lean,boost,delta)
	_update_ai(delta)
	match_model.time_effect_active = Time.get_ticks_msec() < slow_until
	match_model.step(delta)
	for event in match_model.drain_events():
		_handle_event(event)
	_update_views()
	dust_timer -= delta
	hoof_timer -= delta
	if match_model.phase == "charge":
		if dust_timer <= 0:
			dust_timer = .09
			for f in match_model.fighters:
				effects.dust(Vector2(float(f.x)-int(f.direction)*70,0),int(f.direction))
		if hoof_timer <= 0:
			hoof_timer = .28 - clampf(float(fighter.speed)/1000,.0,.12)
			sound.play("hoof",-18,1.0 + float(fighter.speed)/1500)

func _update_ai(delta: float) -> void:
	ai_timer -= delta
	var ai = match_model.fighters[1]
	var player = match_model.fighters[0]
	var difficulty = int(GameState.profile.settings.difficulty)
	if ai_timer <= 0:
		ai_timer = [1.0,.65,.34][difficulty]
		ai_error = ai_rng.randf_range(-1,1) * [34.0,19.0,8.0][difficulty]
		ai_zone = "head" if ai_rng.randf() < [.18,.38,.58][difficulty] else "body"
	var target = Model.head_position(player) if ai_zone == "head" else Model.body_position(player)
	target.y += ai_error
	var hand = Model.hand_position(ai)
	var aim = atan2(target.y-hand.y,maxf(absf(target.x-hand.x),45))
	var distance = absf(float(player.x)-float(ai.x))
	var lean = -0.65 if distance < 520 and difficulty >= 1 else .10
	if ai_zone == "head":
		lean = .32
	var boost = distance < (850 if difficulty >= 1 else 680) and float(ai.stamina) > 18
	match_model.set_controls(1,aim,lean,boost,delta)

func _handle_event(event: Dictionary) -> void:
	match str(event.type):
		"hit":
			var index = int(event.defender)
			riders[index].impact_recoil = 1.0
			riders[int(event.attacker)].lance_recoil = clampf(float(event.impulse)/75,.25,1)
			effects.hit(event.position,int(match_model.fighters[int(event.attacker)].direction),event.damage,event.zone=="shield",event.broke)
			shake = maxf(shake,clampf(float(event.impulse)*.09,2,8))
			var now = Time.get_ticks_msec()
			hitstop_until = now + 50
			slow_until = now + 470
			Engine.time_scale = .001
			sound.play("break" if event.broke else "impact",-5)
			if bool(event.ko) or bool(event.dead):
				effects.fall(match_model.fighters[index],int(match_model.fighters[int(event.attacker)].direction))
		"charge":
			sound.play("horn",-10)
		"end":
			terminal_at = Time.get_ticks_msec()
			finished.emit(event.result)
		"rerack":
			for rider in riders:
				rider.visible = true

func _process(delta: float) -> void:
	var now = Time.get_ticks_msec()
	var real_delta = clampf(float(now-last_visual_time)/1000.0,0,.1)
	last_visual_time = now
	if not paused:
		Engine.time_scale = .001 if now < hitstop_until else (.17 if now < slow_until else 1.0)
		if terminal_at>0 and now>=hitstop_until:
			departure_elapsed = minf(1.4,departure_elapsed+delta)
		if terminal_at > 0 and now - terminal_at > 2300 and not is_finished:
			is_finished = true
			Engine.time_scale = 1.0
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		shake = move_toward(shake,0,4.8*real_delta)
	if world:
		var shake_amount = shake if GameState.profile.settings.shake and not paused else 0.0
		world.position = Vector2(720,645) + Vector2(noise.get_noise_1d(now*.035),noise.get_noise_1d(now*.035+100)) * shake_amount
	if match_model and match_model.phase == "ended" and world:
		_update_views()
	_update_hud()
	queue_redraw()

func _update_views() -> void:
	for i in range(2):
		var fighter = match_model.fighters[i]
		var departing = 0.0
		if match_model.phase == "ended" and terminal_at > 0:
			departing = departure_elapsed*float(fighter.speed)*int(fighter.direction)
		riders[i].position = Vector2(float(fighter.x)+departing, 0)
		riders[i].moving = match_model.phase=="charge" or (match_model.phase=="ended" and departure_elapsed<1.4)
		riders[i].visible = true
		riders[i].blood_enabled = GameState.profile.settings.blood
	effects.blood_enabled = GameState.profile.settings.blood

func _update_hud() -> void:
	if not match_model or not callout:
		return
	var phase = match_model.phase
	pass_label.text = "PASS  %02d / 03" % match_model.pass_number
	intermission.visible = phase in ["ready","turn"]
	if phase == "ready":
		callout.text = "第 %s 次对冲" % ["一","二","三"][match_model.pass_number-1]
		callout.modulate.a = 1
		subcallout.text = "整装 · %d" % maxi(1,ceili(match_model.phase_time))
		intermission.text = "骑手状态  %d%%     对手  %d%%\n%s" % [roundi(match_model.fighters[0].hp),roundi(match_model.fighters[1].hp),"新比武枪已备妥" if mode=="arena" else ("断枪未更换 · 残柄作战" if match_model.fighters[0].broken else "实战枪已备妥 · 留意头部防护")]
	elif phase == "charge":
		callout.text = ""
		subcallout.text = ""
	elif phase == "turn":
		callout.text = "回身重整"
		subcallout.text = "下一次对冲即将开始"
		intermission.text = "你的骑手状态  %d%%     对手  %d%%" % [roundi(match_model.fighters[0].hp),roundi(match_model.fighters[1].hp)]
	elif phase == "ended":
		callout.text = "交锋已定"
		subcallout.text = ""
	if not paused:
		Input.mouse_mode = Input.MOUSE_MODE_HIDDEN if phase == "charge" and not is_finished else Input.MOUSE_MODE_VISIBLE

func _draw() -> void:
	draw_texture_rect(WAR_BACKGROUND if mode == "war" else BACKGROUND,Rect2(0,0,1440,810),false)
	# The two tracks stay isolated; the rail is scenery and never stops a horse.
	for x in range(-20,1500,130):
		draw_rect(Rect2(x,602,13,89),Color("58432c"))
		draw_rect(Rect2(x+2,602,3,89),Color("a0814e"))
	draw_rect(Rect2(0,598,1440,12),Color("9e7843"))
	draw_line(Vector2(0,598),Vector2(1440,598),Color("d3af69"),2)
	draw_rect(Rect2(0,640,1440,7),Color("705231"))
	for i in range(2):
		if match_model:
			var point = world.position+riders[i].position+Vector2(0,12+(-10 if i==1 else 10))
			draw_set_transform(point,0,Vector2(1,.22))
			draw_circle(Vector2.ZERO,125,Color(0,0,0,.19))
			draw_set_transform(Vector2.ZERO)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_ESCAPE:
			_toggle_pause()
			get_viewport().set_input_as_handled()
		elif event.physical_keycode == KEY_R:
			get_viewport().set_input_as_handled()
			replay_requested.emit()
			return
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
			var role = "lean" if event.position.x < 720 else ("boost" if touch_roles.values().has("aim") else "aim")
			touch_roles[event.index] = role
			touch_origin[event.index] = event.position
			if role == "aim":
				touch_aim = event.position
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

func _input(event: InputEvent) -> void:
	# Godot supplies viewport coordinates after stretch/DPI conversion. Keep
	# aiming on this event path rather than polling an OS cursor every tick;
	# it also supports deterministic replay and injected input verification.
	if event is InputEventMouseMotion or event is InputEventMouseButton:
		aim_pointer = event.position

func _toggle_pause() -> void:
	if is_finished:
		return
	paused = not paused
	get_tree().paused = paused
	if paused:
		pause_started = Time.get_ticks_msec()
		_clear_touch()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		pause_panel = UI.panel(hud,Rect2(465,185,510,430),Color(.055,.09,.07,.98))
		UI.label(pause_panel,"暂停 · 调整装备前先喘口气",Vector2(28,24),24,UI.GOLD)
		UI.check(pause_panel,"显示血腥表现",GameState.profile.settings.blood,Vector2(28,90),func(value):
			GameState.set_setting("blood",value)
			if not value:
				effects.clear_blood()
			_update_views())
		UI.check(pause_panel,"镜头震动",GameState.profile.settings.shake,Vector2(28,140),func(value):GameState.set_setting("shake",value))
		UI.button(pause_panel,"继续对冲",Rect2(28,215,454,52),_toggle_pause,true)
		UI.button(pause_panel,"重新比赛",Rect2(28,280,220,48),func():replay_requested.emit())
		UI.button(pause_panel,"返回营地",Rect2(262,280,220,48),func():exit_requested.emit())
		UI.label(pause_panel,"血腥设置只改变画面，不改变伤害或死亡结果。",Vector2(28,353),15,UI.MUTED,454)
	else:
		pause_panel.queue_free()
		if terminal_at > 0:
			terminal_at += Time.get_ticks_msec()-pause_started
		# Effects use wall time; no time scale can become stuck after pause.
		hitstop_until = 0
		slow_until = 0
		Engine.time_scale = 1.0

func _clear_touch() -> void:
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
	Engine.time_scale = 1.0
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
