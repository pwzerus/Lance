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
const BACKGROUND = preload("res://assets/art/pixel_v03/tournament_field.png")
const WAR_BACKGROUND = preload("res://assets/art/pixel_v03/campaign_field.png")

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
var pointer_aim = -.08
var touch_roles: Dictionary = {}
var touch_origin: Dictionary = {}
var ai_timer = 0.0
var ai_error = 0.0
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
var contact_until = 0
var spur_left = 0.0
var mouse_held = false
var training_zones = false
var pass_connected = false
var camera_pass = 1
var approach_slow = false
var wind: AudioStreamPlayer
var zone_overlay: Node2D
var guard_high = false
var speed_meter: ProgressBar
var tactics_label: Label
var input_flash_until = 0
var ready_panel: Control
var contact_panel: Control
var practice = false
var learned = {"boost":false,"aim":false,"guard":false,"posture":false}

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
	var scenery = CanvasLayer.new()
	scenery.layer = -20
	add_child(scenery)
	var backdrop = TextureRect.new()
	backdrop.texture = WAR_BACKGROUND if mode=="war" else BACKGROUND
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.size = Vector2(1440,810)
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
	zone_overlay = preload("res://scripts/visual/hit_zone_overlay.gd").new()
	zone_overlay.match_model = match_model
	zone_overlay.z_index = 20
	zone_overlay.visible = false
	world.add_child(zone_overlay)
	sound = SoundBank.new()
	sound.enabled = GameState.profile.settings.sound
	add_child(sound)
	sound.music.stop()
	wind = AudioStreamPlayer.new()
	wind.stream = sound.streams.wind_loop
	wind.volume_db = -50
	add_child(wind)
	if sound.enabled:
		wind.play()
	for i in range(riders.size()):
		riders[i].stride_phase = i*1.1
		riders[i].hoof_contact.connect(_on_hoof_contact.bind(i))
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
	UI.label(top,"练习场 · 无奖励 / 盾位按轮次变化" if practice else ("竞技场 · 非致死比武" if mode=="arena" else "实战 · 致命对冲"),Vector2(280,23),18)
	pass_label = UI.label(top,"PASS  01 / 03",Vector2(1050,20),22,UI.GOLD)
	UI.button(top,"暂停  Esc",Rect2(1240,14,165,45),_toggle_pause)
	ready_panel = UI.panel(hud,Rect2(315,119,810,211),Color(.045,.08,.065,.90))
	callout = UI.label(hud,"整装待发",Vector2(420,123),40,UI.INK,600)
	callout.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subcallout = UI.label(hud,"",Vector2(370,183),18,UI.GOLD,700)
	subcallout.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	intermission = UI.label(hud,"",Vector2(330,245),19,UI.INK,780)
	intermission.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var bottom = UI.panel(hud,Rect2(0,758,1440,52),Color(.045,.08,.065,.96))
	hint = UI.label(bottom,"鼠标瞄准 · 左键催马 · 右键 / Q 换盾位 · W 前倾 / S 后仰 · H 判定",Vector2(25,14),16,UI.MUTED)
	speed_label = UI.label(bottom,"",Vector2(925,14),16,UI.GOLD,500)
	contact_panel = UI.panel(hud,Rect2(250,648,940,86),Color(.045,.08,.065,.93))
	contact_label = UI.label(contact_panel,"",Vector2(24,9),24,UI.GOLD,892)
	contact_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	speed_meter = ProgressBar.new()
	speed_meter.position = Vector2(950,735)
	speed_meter.size = Vector2(440,12)
	speed_meter.min_value = Model.TROT_SPEED
	speed_meter.max_value = Model.SURGE_SPEED
	speed_meter.show_percentage = false
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
	var tactic_panel = UI.panel(hud,Rect2(16,81,1000,35),Color(.045,.08,.065,.91))
	tactics_label = UI.label(tactic_panel,"",Vector2(13,3),18,UI.GOLD,970)

func _physics_process(delta: float) -> void:
	if paused or is_finished:
		return
	var fighter = match_model.fighters[0]
	if match_model.phase=="charge":
		spur_left = maxf(0,spur_left-delta)
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
	var boost = mouse_held or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or spur_left>0 or Input.is_physical_key_pressed(KEY_SPACE) or touch_roles.values().has("boost")
	if autoplay:
		var target = Model.head_position(match_model.fighters[1])
		aim = asin(clampf((target.y-hand.y)/Model.lance_length(fighter),-.629,.548))
		boost = true
		lean = 0.15
	match_model.set_controls(0,aim,lean,boost,delta,1.0 if guard_high else 0.0)
	_update_ai(delta)
	match_model.time_effect_active = Time.get_ticks_msec() < slow_until
	match_model.step(delta)
	for event in match_model.drain_events():
		_handle_event(event)
	_update_views()

func _on_hoof_contact(leg_index: int, rider_index: int) -> void:
	if paused or match_model.phase!="charge":
		return
	var fighter = match_model.fighters[rider_index]
	var pace = clampf((float(fighter.speed)-Model.TROT_SPEED)/(Model.GALLOP_SPEED-Model.TROT_SPEED),0,1)
	var pose = riders[rider_index].Gait.leg(leg_index,riders[rider_index].stride_phase,float(fighter.speed),true)
	effects.dust(Vector2(float(fighter.x)+pose.foot.x*int(fighter.direction),8),int(fighter.direction))
	sound.play("hoof",lerpf(-25,-17,pace)-(3 if rider_index==1 else 0),.92 if leg_index<2 else 1.12)

func _update_ai(delta: float) -> void:
	ai_timer -= delta
	var ai = match_model.fighters[ai_fighter_index]
	var player = match_model.fighters[1-ai_fighter_index]
	var difficulty = 0 if practice else int(GameState.profile.settings.difficulty)
	var distance = absf(float(player.x)-float(ai.x))
	# Once the last approach begins the opponent must commit visibly, giving
	# the player a feint window. Hard opponents commit later, not by reading
	# instantaneous controls. Keep applying the cached pose below this gate.
	var approaching = (float(ai.x)-float(player.x))*int(player.direction)>0
	var committed = match_model.phase=="charge" and approaching and distance<[0.0,800.0,500.0][difficulty]
	if ai_timer <= 0 and not committed:
		# Vary observation timing slightly so charge acceleration cannot align
		# every pass with the same final observation. This is delayed sensing,
		# not a random damage roll or a read of instantaneous player controls.
		ai_timer = [1.0,.65,.34][difficulty]*ai_rng.randf_range(.90,1.10)
		ai_error = ai_rng.randf_range(-1,1) * [34.0,19.0,8.0][difficulty]
		var choice = ai_rng.randf()
		ai_zone = "head" if choice<[.18,.30,.40][difficulty] else ("flank" if choice>.72 else "body")
		if distance<1450 and difficulty>=1 and choice<.78:
			ai_zone = "flank" if float(player.guard)>.65 else "head"
		ai_lean = .18
		if distance<1300 and difficulty>=1:
			var incoming_height = Model.hand_position(player).y+sin(float(player.aim))*Model.lance_length(player)
			ai_guard = 1.0 if incoming_height<Model.body_position(ai).y-28 else 0.0
			ai_lean = -.72 if incoming_height<Model.head_position(ai).y-6 and choice>.55 else .30
			if float(ai.shield)<=0:
				ai_lean = -.9 if incoming_height<Model.body_position(ai).y-25 else .55
		ai_target_y = (Model.head_position(player) if ai_zone=="head" else (Model.flank_position(player) if ai_zone=="flank" else Model.body_position(player))).y+ai_error
		if practice:
			ai_guard = 1.0 if match_model.pass_number%2==1 else 0.0
			ai_lean = 0
			ai_target_y = Model.body_position(player).y+22
	var target = Vector2(float(player.x),ai_target_y)
	var hand = Model.hand_position(ai)
	var aim = asin(clampf((target.y-hand.y)/Model.lance_length(ai),-.629,.548))
	# Defense uses the same delayed observations as aim; it does not read
	# and counter the player's current input on every physics tick.
	var lean = ai_lean
	var boost = distance > 700 and float(ai.stamina)>15
	if difficulty==2 and distance<700:
		boost = float(ai.stamina)>28
	match_model.set_controls(ai_fighter_index,aim,lean,boost,delta,ai_guard)

func _handle_event(event: Dictionary) -> void:
	match str(event.type):
		"hit":
			exchange_log.append(event.duplicate(true))
			pass_connected = true
			var index = int(event.defender)
			riders[index].impact_recoil = 1.0
			if event.zone=="shield":
				riders[index].shield_recoil = 1.0
			riders[int(event.attacker)].lance_recoil = clampf(float(event.impulse)/75,.25,1)
			effects.hit(event.position,int(match_model.fighters[int(event.attacker)].direction),event.damage,event.zone=="shield",event.broke)
			if event.broke:
				effects.break_lance(event,mode)
			shake = maxf(shake,clampf(float(event.impulse)*.09,2,8))
			var now = Time.get_ticks_msec()
			hitstop_until = now + (65 if event.zone!="shield" else 40)
			slow_until = now+510 if GameState.profile.settings.get("slow_motion",true) else 0
			Engine.time_scale = .001
			sound.play("impact" if event.zone!="shield" else "shield",-4,.85 if event.zone!="shield" else 1.05)
			if event.broke:
				sound.play("break",-7)
			var zones = {"head":"头盔 / 头部","body":"胸甲","flank":"腰腹","shield":"盾牌格挡"}
			var hit_text = ("你命中 · " if int(event.attacker)==0 else "对手命中 · ")+zones.get(event.zone,event.zone)
			if event.ko:
				hit_text += " · 击落！"
			elif event.zone!="shield":
				hit_text += " · 冲击 %d" % roundi(event.impulse)
				if float(event.get("support",1.0))<.70:
					hit_text += " · 失稳"
			if event.get("shield_broke",false):
				hit_text += " · 盾已破损"
			contact_label.text = contact_label.text+"\n"+hit_text if now<contact_until and contact_until-now>1600 else hit_text
			contact_until = now+1700
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
		_update_camera(real_delta,now)
		Engine.time_scale = .001 if now < hitstop_until else (.20 if now < slow_until else (.72 if approach_slow else 1.0))
		if terminal_at>0 and now>=hitstop_until:
			departure_elapsed = minf(1.4,departure_elapsed+delta)
		if terminal_at > 0 and now - terminal_at > 2600 and not is_finished:
			is_finished = true
			Engine.time_scale = 1.0
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		shake = move_toward(shake,0,4.8*real_delta)
		if wind and match_model:
			var pace = clampf((float(match_model.fighters[0].speed)-Model.TROT_SPEED)/(Model.GALLOP_SPEED-Model.TROT_SPEED),0,1)
			wind.volume_db = lerpf(wind.volume_db,lerpf(-34,-19,pace) if match_model.phase=="charge" else -50,1-exp(-real_delta*4))
	if camera:
		var shake_amount = shake if GameState.profile.settings.shake and not paused else 0.0
		camera.offset = Vector2(noise.get_noise_1d(now*.035),noise.get_noise_1d(now*.035+100))*shake_amount
	if match_model and match_model.phase == "ended" and world:
		_update_views()
	_update_hud()
	queue_redraw()

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
	approach_slow = GameState.profile.settings.get("slow_motion",true) and match_model.phase=="charge" and before_crossing and separation<650 and not pass_connected
	# Sublinear zoom preserves visible approach motion. Inverse-distance
	# framing nearly pinned both riders in place and concealed acceleration.
	var desired_zoom = clampf(.28*pow((Model.START_X*2.0)/maxf(separation,250),.65),.28,1.65)
	if terminal_at>0:
		desired_zoom = 1.6 if now-terminal_at<850 else 1.05
	var blend = 1.0-exp(-real_delta*(5.0 if approach_slow else 3.3))
	camera.zoom = camera.zoom.lerp(Vector2.ONE*desired_zoom,blend)
	camera.position = camera.position.lerp(Vector2(720+(a+b)*.5,480),blend)
	camera.force_update_scroll()

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
	zone_overlay.visible = training_zones

func _update_hud() -> void:
	if not match_model or not callout:
		return
	var phase = match_model.phase
	ready_panel.visible = phase in ["ready","turn"] or (phase=="ended" and not is_finished)
	callout.visible = not is_finished
	subcallout.visible = not is_finished
	var f = match_model.fighters[0]
	speed_meter.value = float(f.speed)
	var pace_text = "催马" if f.boost and float(f.stamina)>4 else ("减速中" if float(f.speed)>Model.TROT_SPEED+20 else "巡航")
	if phase=="ready" and f.boost:
		pace_text = "已催马 · 等待起跑"
	speed_label.text = "%s · 速度 %d · 耐力 %d%%" % [pace_text,roundi(float(f.speed)),roundi(f.stamina)]
	var guard_text = "高盾 · 胸腹暴露" if guard_high else "低盾 · 头部暴露"
	if absf(float(f.guard)-(1.0 if guard_high else 0.0))>.08:
		guard_text = "换盾中 · 留意空隙"
	if float(f.shield)<=0:
		guard_text = "盾已破损 · 用姿态避枪"
	tactics_label.text = "%s　|　枪稳 %d%%　|　平衡 %d%%　|　盾 %d%%" % [guard_text,roundi(float(f.lance_stability)*100),roundi(f.balance),roundi(float(f.shield)/78*100)]
	if approach_slow:
		tactics_label.text += "　· 接近放缓"
	tactics_label.modulate = Color(1.3,1.2,.7) if Time.get_ticks_msec()<input_flash_until else Color.WHITE
	if practice:
		hint.text = "练习 · 催马%s　调枪%s　换盾%s　俯仰%s　| 右键 / Q 换盾位" % ["完成" if learned.boost else "待尝试","完成" if learned.aim else "待尝试","完成" if learned.guard else "待尝试","完成" if learned.posture else "待尝试"]
	contact_label.visible = Time.get_ticks_msec()<contact_until
	contact_panel.visible = contact_label.visible
	pass_label.text = "PASS  %02d / 03" % match_model.pass_number
	intermission.visible = phase in ["ready","turn"]
	if phase == "ready":
		callout.text = "第 %s 次对冲" % ["一","二","三"][match_model.pass_number-1]
		callout.modulate.a = 1
		subcallout.text = "整装 · %d" % maxi(1,ceili(match_model.phase_time))
		intermission.text = "骑手状态  %d%%     对手  %d%%\n%s" % [roundi(match_model.fighters[0].hp),roundi(match_model.fighters[1].hp),"新比武枪已备妥" if mode=="arena" else ("断枪未更换 · 残柄作战" if match_model.fighters[0].broken else "实战枪已备妥 · 留意头部防护")]
		if practice:
			intermission.text += "\n练习：高盾露腰腹，低盾露头；停手让枪稳回升。"
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
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _draw() -> void:
	# The two tracks stay isolated; the rail is scenery and never stops a horse.
	for x in range(-5000,6500,130):
		draw_rect(Rect2(x,602,13,89),Color("58432c"))
		draw_rect(Rect2(x+2,602,3,89),Color("a0814e"))
	draw_rect(Rect2(-5000,598,11500,12),Color("9e7843"))
	draw_line(Vector2(-5000,598),Vector2(6500,598),Color("d3af69"),2)
	draw_rect(Rect2(-5000,640,11500,7),Color("705231"))
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
		elif event.physical_keycode == KEY_H:
			training_zones = not training_zones
			zone_overlay.visible = training_zones
			contact_label.text = "判定显示：金色盾牌 · 青色头 / 胸 / 腰腹" if training_zones else "判定显示已关闭"
			contact_until = Time.get_ticks_msec()+2300
		elif event.physical_keycode == KEY_Q and not paused:
			guard_high = not guard_high
			learned.guard = true
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
	# Godot supplies viewport coordinates after stretch/DPI conversion. Keep
	# aiming on this event path rather than polling an OS cursor every tick;
	# it also supports deterministic replay and injected input verification.
	if event is InputEventMouseMotion or event is InputEventMouseButton:
		aim_pointer = event.position
	if event is InputEventMouseMotion and not paused:
		_set_pointer_aim(event.position)
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
		mouse_held = event.pressed and not paused
		if mouse_held:
			spur_left = Model.SPUR_DURATION
			input_flash_until = Time.get_ticks_msec()+350
			learned.boost = true
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_RIGHT and event.pressed and not paused:
		guard_high = not guard_high
		learned.guard = true
		sound.play("click",-16,.7)

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

func _toggle_pause() -> void:
	if is_finished:
		return
	paused = not paused
	get_tree().paused = paused
	wind.stream_paused = paused
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
	spur_left = 0
	mouse_held = false
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
