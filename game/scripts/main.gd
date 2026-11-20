extends Node2D

const Trace099 = preload("res://scripts/core/frame_trace099.gd")
const UI = preload("res://scripts/ui/ui_factory.gd")
const Catalogue = preload("res://scripts/core/catalogue.gd")
const Rider = preload("res://scripts/visual/rider_view.gd")
const Model = preload("res://scripts/core/joust_match.gd")
const Battle = preload("res://scripts/battle.gd")
const Art = preload("res://scripts/visual/equipment_art.gd")
const Appearance = preload("res://scripts/core/character_appearance.gd")
const WindowActivity = preload("res://scripts/core/window_activity.gd")
const PracticeGuide = preload("res://scripts/core/practice_guide.gd")
const AudioMix = preload("res://scripts/core/audio_mix.gd")
const EquipmentComparison = preload("res://scripts/ui/equipment_comparison.gd")
const HorseSkin = preload("res://scripts/visual/horse_skin.gd")
const Status098 = preload("res://scripts/ui/combat_status098.gd")
const ResultPrewarm099 = preload("res://scripts/ui/result_prewarm099.gd")
var result_details: Label
var result_detail_scroll: ScrollContainer
var result_rewards: Label
var result_progress: Label
var result_timeline: Control
var result_debug = false
var result_detail_text = ""
const Campaign = preload("res://scripts/core/campaign.gd")
const BACKGROUND = preload("res://assets/art/pixel_v03/tournament_field.png")

class CharacterFaceCanvas extends Node2D:
	const Face = preload("res://scripts/visual/character_face.gd")
	var appearance: Dictionary = {}
	func _draw() -> void:
		Face.draw_portrait(self,appearance,Rect2(0,0,192,240))

class LanceIcon extends Control:
	const Lance = preload("res://scripts/visual/lance_art.gd")
	var equipment: Dictionary = {}
	func _draw() -> void:
		# HORSE-065 readability: a whole lance fitted to the card width was 2-3
		# px thick, so paint, vamplate and head could not be told apart. Keep
		# the true length across the width but thicken the drawing 2.6x.
		# Every lance shares one scale (longest catalogue reach 290) so a long
		# lance visibly outreaches a light one instead of all filling the card;
		# shaft thickness never drops below 1.6x on small armoury cards.
		var length = float(equipment.get("reach",247))
		var factor = size.x/(290.0+78.0)
		var thick = Vector2(factor,minf(maxf(factor*2.6,1.6),size.y/56.0))
		draw_set_transform(Vector2(67*factor,size.y*.30),0,thick)
		Lance.draw(self,equipment,Vector2.ZERO,0,length,false,0,"arena")
		draw_set_transform(Vector2(67*factor,size.y*.74),0,thick)
		Lance.draw(self,equipment,Vector2.ZERO,0,length,false,0,"war")

class ShieldIcon extends Control:
	const ShieldArt = preload("res://scripts/visual/shield_art.gd")
	var equipment: Dictionary = {}
	func _draw() -> void:
		var factor = minf(size.x/100.0,size.y/128.0)
		ShieldArt.draw(self,equipment,size*.5,false,Color.WHITE,0.0,factor)

class FamilyIcon extends Control:
	const Heraldry=preload("res://scripts/visual/heraldry.gd")
	var design="bend"
	func _draw() -> void:
		var scale_value=minf(size.x/104,size.y/112)
		var center=size*.5
		var outline=PackedVector2Array([Vector2(-33,-43),Vector2(33,-43),Vector2(33,40),Vector2(0,27),Vector2(-33,40)])
		for i in range(outline.size()): outline[i]*=scale_value
		var outer=outline.duplicate()
		for i in range(outer.size()): outer[i]+=center
		draw_colored_polygon(outer,Heraldry.field_color(design))
		for polygon in Heraldry.clipped_charges(design,outline,scale_value):
			for i in range(polygon.size()): polygon[i]+=center
			draw_colored_polygon(polygon,Heraldry.charge_color(design))
		for polygon in Heraldry.overlay_polygons(design):
			for i in range(polygon.size()): polygon[i]*=scale_value
			for piece in Geometry2D.intersect_polygons(outline,polygon):
				for i in range(piece.size()): piece[i]+=center
				draw_colored_polygon(piece,Heraldry.field_color(design))
		outer.append(outer[0])
		draw_polyline(outer,Color("b69b64"),2)
		draw_line(center+Vector2(-39,-47)*scale_value,center+Vector2(39,-47)*scale_value,Color("b69b64"),3)

class CaparisonIcon extends Control:
	## EQUIP-066: the player's own horse coat with the caparison texture on top,
	## in the player's arms: the same two textures the battle mesh uses.
	const HorseSkin = preload("res://scripts/visual/horse_skin.gd")
	var style = "none"
	var design = "bend"
	var coat = "bay"
	func _draw() -> void:
		var coat_texture = HorseSkin.coat_texture(coat)
		if coat_texture==null:
			return
		var aspect = 1024.0/683.0
		var width = minf(size.x,size.y*aspect)
		var area = Rect2((size-Vector2(width,width/aspect))*.5,Vector2(width,width/aspect))
		draw_texture_rect(coat_texture,area,false)
		var cloth = HorseSkin.caparison_texture(style,design)
		if cloth!=null:
			draw_texture_rect(cloth,area,false)

var ui_layer: CanvasLayer
var screen: Control
var preview: RiderView
var battle: BattleScene
var sounds: SoundBank
var page = "home"
var current_mode = "arena"
var session_id = ""
var pending_result: Dictionary = {}
var reward: Dictionary = {}
var selected_slot = "armor"
var selected_era = 0
var selected_region = 0 # 0 all, 1..4 regions, 5 shared
var selected_quality = 0 # 0 all, 1..6 qualities
var selected_item: Dictionary = {}
var info_panel: Control
var message_label: Label
var currency_label: Label
var result_visible = false
var screenshot_dir = ""
var smoke_mode = false
var shutting_down = false
var smoke_started = 0
var smoke_step = 0
var smoke_busy = false
var smoke_screens: Array = []
var smoke_original_profile: Dictionary = {}
var smoke_contacts: Array = []
var smoke_last_report = 0
var practice_match = false
## LEVEL-092: the campaign level being played (empty for free matches).
var current_level: Dictionary = {}
var level_chapter = -1
var level_selected = 0
var active_guide: PracticeGuide
var appearance_draft: Dictionary = {}
var character_options: Dictionary = {}
var character_face_preview: CharacterFaceCanvas
var brief_overlay: Control
var brief_return_focus: Control
var armory_scroll: ScrollContainer
var armory_scroll_offset = 0
var armory_filter_key = ""
var armory_cards: Dictionary = {}
var settings_notice: Label
var save_error_dialog: AcceptDialog
var slot_dialog: ConfirmationDialog
var audio_save_timer: Timer
var audio_save_pending = false
var audio_preview_notice: Label
var audio_preview_until = 0
var build_version = str(ProjectSettings.get_setting("application/config/version","unknown"))

func _ready() -> void:
	# Windows release must enter the OS Job before any gameplay starts.
	# This is a safety interlock, not a security boundary against manual bypass.
	if OS.get_name()=="Windows" and not OS.has_feature("editor") and OS.get_environment("GALUMU_MEMORY_BOUND")!="1024":
		OS.alert("请从发布包最外层的 LanceAndLaurel.exe 启动，以启用内存保护。开发目录也可使用 Play-Latest.cmd。", "骑枪与桂冠")
		get_tree().quit(2)
		return
	get_window().title = "骑枪与桂冠 · Lance & Laurel v"+build_version
	print("GALUMU_BUILD v",build_version)
	get_tree().auto_accept_quit = false
	add_child(WindowActivity.new())
	get_window().min_size = Vector2i(960,540)
	ui_layer = CanvasLayer.new()
	add_child(ui_layer)
	AudioMix.apply(GameState.profile.settings)
	audio_save_timer = Timer.new()
	audio_save_timer.one_shot = true
	audio_save_timer.ignore_time_scale = true
	audio_save_timer.process_mode = Node.PROCESS_MODE_ALWAYS
	audio_save_timer.timeout.connect(_flush_audio_settings)
	add_child(audio_save_timer)
	sounds = SoundBank.new()
	sounds.enabled = GameState.profile.settings.sound
	add_child(sounds)
	var arguments = OS.get_cmdline_user_args()
	for i in range(arguments.size()):
		if arguments[i] == "--smoke-test":
			smoke_mode = true
		if arguments[i] == "--screenshots" and i+1 < arguments.size():
			screenshot_dir = arguments[i+1]
	if smoke_mode:
		smoke_original_profile = GameState.profile.duplicate(true)
		smoke_started = Time.get_ticks_msec()
	show_home()
	if GameState.qa_input_probe:
		get_window().title = "Lance & Laurel v"+build_version+" QA - Desktop input"
		var audit = preload("res://scripts/core/desktop_input_audit.gd").new()
		audit.main = self
		add_child(audit)

func _clear_screen() -> void:
	_flush_audio_settings()
	if screen:
		# Deferred deletion keeps the old controls alive until frame end.
		# Hide them immediately so a second queued click cannot hit stale UI.
		screen.hide()
		screen.queue_free()
	if preview:
		preview.hide()
		preview.queue_free()
		preview = null
	screen = Control.new()
	screen.theme = UI.theme()
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.add_child(screen)
	message_label = null
	currency_label = null
	character_face_preview = null
	character_options.clear()
	brief_overlay = null
	brief_return_focus = null
	armory_cards.clear()

func _header(subtitle: String) -> void:
	UI.label(screen,"LANCE & LAUREL",Vector2(52,28),25,UI.GOLD)
	UI.label(screen,subtitle,Vector2(340,36),16,UI.MUTED)
	currency_label = UI.label(screen,"银币 %s   声望 %s" % [_short_number(int(GameState.profile.coins)),_short_number(int(GameState.profile.renown))],Vector2(1080,35),18,UI.GOLD)
	UI.separator(screen,Vector2(52,76),1336)

func _short_number(value: int) -> String:
	if value>=100000000:
		return "%.1f亿" % (float(value)/100000000)
	if value>=10000:
		return "%.1f万" % (float(value)/10000)
	return str(value)

func _add_preview(point: Vector2, preview_scale: float = 1.0, stats: Dictionary = {}) -> void:
	if preview:
		preview.queue_free()
	preview = Rider.new()
	preview.fighter = Model.new("arena",GameState.player_stats() if stats.is_empty() else stats).fighters[0]
	preview.fighter.x = 0.0
	preview.fighter.aim = -0.16
	preview.red = int(GameState.profile.region) == 1
	preview.position = point
	preview.scale = Vector2.ONE * preview_scale
	preview.preview = true
	add_child(preview)

func show_home() -> void:
	if GameState.recovery_required:
		show_save_recovery()
		return
	page = "home"
	_apply_display_settings()
	_clear_screen()
	_header("营地")
	var era = Catalogue.era_for_renown(int(GameState.profile.renown))
	var region = int(GameState.profile.region)
	var camp = preload("res://scripts/ui/home_camp.gd").new()
	camp.equipment = GameState.player_stats()
	camp.banner_color = Catalogue.REGION_COLORS[region]
	screen.add_child(camp)
	UI.label(screen,"LANCE  /  LAUREL",Vector2(80,117),17,UI.GOLD)
	UI.label(screen,"骑枪与桂冠",Vector2(74,155),57,UI.INK)
	UI.label(screen,"尘土扬起之前，决定这一枪。",Vector2(80,243),23,UI.MUTED)
	var cleared = GameState.profile.get("campaign_cleared",[]).size()
	var campaign = UI.button(screen,"关卡挑战  %d/%d" % [cleared,Campaign.COUNT],Rect2(78,314,266,76),func():show_levels(),true)
	campaign.add_theme_font_size_override("font_size",24)
	var start = UI.button(screen,"自由对战",Rect2(364,314,266,76),show_match_setup)
	start.add_theme_font_size_override("font_size",24)
	UI.label(screen,"挑战关卡赢取银币，也可以自由比武。",Vector2(80,407),17,UI.MUTED,560)
	UI.button(screen,"军械库",Rect2(78,458,266,72),show_armory)
	UI.button(screen,"练习场",Rect2(364,458,266,72),show_practice_setup)
	UI.label(screen,"换上你的纹章与装备",Vector2(94,543),16,UI.MUTED)
	UI.label(screen,"分步上手与自由对冲",Vector2(380,543),16,UI.MUTED)
	UI.button(screen,"存档 / 继续进度",Rect2(78,600,552,52),show_saves)
	UI.button(screen,"历史手记",Rect2(78,672,172,46),show_history)
	UI.button(screen,"设置",Rect2(268,672,172,46),show_settings)
	UI.button(screen,"保存并退出",Rect2(458,672,172,46),_save_and_exit)
	var save_caption = "进度待保存" if GameState.profile_save_pending else "自动保存已开启"
	UI.label(screen,save_caption+"　v"+build_version,Vector2(80,750),15,UI.MUTED).name="HomeSaveStatus"
	UI.button(screen,"玩法与制作说明",Rect2(384,742,246,36),show_help)
	UI.label(screen,"你的骑士",Vector2(813,122),16,UI.GOLD)
	UI.label(screen,Catalogue.REGIONS[region]+" · "+Catalogue.ERA_NAMES[era],Vector2(813,161),25,UI.INK)
	UI.label(screen,Catalogue.ERAS[era]+"   /   装备、坐骑与纹章随你出战",Vector2(813,205),15,UI.MUTED)
	UI.button(screen,"角色外观",Rect2(1150,116,220,42),show_character)
	_add_preview(Vector2(1072,660),1.30)
	var champion = UI.panel(screen,Rect2(766,690,606,94),Color(.045,.085,.065,.96))
	var next_era = era+1
	var journey = "即将开放："+Catalogue.ERA_NAMES[next_era] if next_era<Catalogue.ERAS.size() else "历代工坊已开放"
	UI.label(champion,journey,Vector2(22,12),18,UI.GOLD)
	var record_label = UI.label(champion,"%s 胜 / %s 场" % [_short_number(int(GameState.profile.wins)),_short_number(int(GameState.profile.matches))],Vector2(452,14),15,UI.MUTED)
	record_label.size=Vector2(132,24)
	record_label.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	var progress = ColorRect.new()
	progress.position=Vector2(22,49)
	progress.size=Vector2(562,6)
	progress.color=Color("27362b")
	progress.mouse_filter=Control.MOUSE_FILTER_IGNORE
	champion.add_child(progress)
	var progress_fill=ColorRect.new()
	var fraction=1.0 if next_era>=Catalogue.ERAS.size() else clampf(float(int(GameState.profile.renown)-Catalogue.ERA_REQUIREMENTS[era])/float(Catalogue.ERA_REQUIREMENTS[next_era]-Catalogue.ERA_REQUIREMENTS[era]),0,1)
	progress_fill.size=Vector2(562*fraction,6)
	progress_fill.color=UI.GOLD
	progress_fill.mouse_filter=Control.MOUSE_FILTER_IGNORE
	progress.add_child(progress_fill)
	UI.label(champion,"赢得声望，开启新的时代与工坊。" if next_era<Catalogue.ERAS.size() else "每一件收藏，都有它的来处。",Vector2(22,66),14,UI.MUTED)
	if GameState.profile_save_pending:
		UI.label(screen,"进度未保存，请到存档页重试。",Vector2(80,775),13,Color("efb566"),650)
	elif not GameState.load_notice.is_empty():
		UI.label(screen,"存档有异常，请查看存档页。",Vector2(80,775),13,Color("efb566"),650)
	_queue_opponent_assets()
	queue_redraw()

func show_save_recovery(notice: String = "") -> void:
	page = "recovery"
	_clear_screen()
	_header("存档恢复 · 原文件保持不动")
	currency_label.text = "等待选择恢复方式"
	UI.label(screen,"先保住你的旅程",Vector2(100,152),42,UI.GOLD)
	UI.label(screen,GameState.load_notice,Vector2(104,226),23,UI.INK,1210)
	UI.label(screen,"选择恢复或开始新旅程时，游戏会先保留损坏文件副本；保留失败就不会替换原文件。",Vector2(104,312),19,UI.MUTED,1210)
	for slot in range(1,4):
		var data = GameState.read_slot(slot)
		var card = UI.panel(screen,Rect2(104+(slot-1)*412,380,390,150))
		UI.label(card,"手动存档 %d" % slot,Vector2(18,12),23,UI.GOLD)
		UI.label(card,"没有可用的手动存档" if data.is_empty() else "%s · %s 场比赛" % [data.saved_at,_short_number(int(data.profile.matches))],Vector2(18,50),16,UI.MUTED,354)
		var button = UI.button(card,"恢复此存档",Rect2(18,91,354,42),func():_confirm_slot_operation(slot,true))
		button.disabled = data.is_empty()
	UI.button(screen,"保留损坏文件，开始新旅程",Rect2(104,590,780,65),func():
		if GameState.start_new_after_recovery():
			_apply_audio_settings()
			show_home()
		else: show_save_recovery(GameState.save_error),true)
	UI.button(screen,"退出，稍后处理",Rect2(910,590,408,65),_shutdown_and_quit)
	UI.label(screen,notice,Vector2(104,694),18,Color("efb566"),1210)
	UI.button(screen,"打开存档文件夹",Rect2(104,748,250,38),func():OS.shell_open(ProjectSettings.globalize_path(GameState.save_path).get_base_dir()))
	queue_redraw()

func show_character() -> void:
	page = "character"
	_clear_screen()
	appearance_draft = Appearance.sanitize(GameState.profile.get("appearance",Appearance.defaults()))
	_header("角色外观")
	UI.label(screen,"塑造你的骑士",Vector2(60,111),36,UI.INK)
	UI.label(screen,"即时预览；保存后用于营地与骑乘形象。",Vector2(64,170),18,UI.MUTED,850)
	UI.button(screen,"取消并返回",Rect2(1210,106,175,48),_cancel_character)
	var panel = UI.panel(screen,Rect2(60,215,590,435))
	var keys = ["face_shape","skin","brows","beard","eyes","hair"]
	var titles = ["脸型","肤色","眉毛","胡子","瞳色","发色"]
	for row in range(keys.size()):
		var field: String = keys[row]
		UI.label(panel,titles[row],Vector2(24,29+row*58),20,UI.GOLD)
		var option = OptionButton.new()
		option.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		option.position = Vector2(190,20+row*58)
		option.size = Vector2(374,46)
		for label in Appearance.OPTIONS[field]:
			option.add_item(str(label))
		option.selected = int(appearance_draft[field])
		option.item_selected.connect(func(index: int):_change_character_option(field,index))
		panel.add_child(option)
		character_options[field] = option
	UI.label(panel,"外观不改变装备属性或比赛判定。",Vector2(24,390),16,UI.MUTED,540)
	var face_panel = UI.panel(screen,Rect2(715,215,236,340),Color(.055,.10,.08,.95))
	UI.label(face_panel,"无盔头像",Vector2(24,14),18,UI.GOLD)
	character_face_preview = CharacterFaceCanvas.new()
	character_face_preview.position = Vector2(737,272)
	character_face_preview.appearance = appearance_draft.duplicate(true)
	screen.add_child(character_face_preview)
	UI.label(face_panel,"眼睛与眉须细节预览",Vector2(24,307),14,UI.MUTED,205)
	UI.label(screen,"上马预览",Vector2(1010,222),18,UI.GOLD)
	var stats = GameState.player_stats().duplicate(true)
	stats["appearance"] = appearance_draft.duplicate(true)
	_add_preview(Vector2(1170,620),.9,stats)
	UI.label(screen,"头盔按当前装备显示；闭盔会遮住部分面容。",Vector2(715,646),15,UI.MUTED,670)
	UI.button(screen,"保存并返回",Rect2(60,686,380,58),_save_character,true)
	UI.button(screen,"取消修改",Rect2(460,686,190,58),_cancel_character)
	message_label = UI.label(screen,"预览中，保存后生效。",Vector2(715,691),17,UI.MUTED,670)
	queue_redraw()

func _change_character_option(field: String, index: int) -> void:
	if page!="character" or not Appearance.OPTIONS.has(field):
		return
	appearance_draft[field] = index
	appearance_draft = Appearance.sanitize(appearance_draft)
	if is_instance_valid(preview):
		preview.fighter.stats["appearance"] = appearance_draft.duplicate(true)
		preview.queue_redraw()
	if is_instance_valid(character_face_preview):
		character_face_preview.appearance = appearance_draft.duplicate(true)
		character_face_preview.queue_redraw()
	if is_instance_valid(message_label):
		message_label.text = "预览中，保存后生效。"
		message_label.add_theme_color_override("font_color",UI.MUTED)

func _save_character() -> void:
	if page!="character":
		return
	if GameState.set_appearance(appearance_draft):
		show_home()
		return
	if is_instance_valid(message_label):
		message_label.text = "保存失败 · "+GameState.save_error+"\n修改仍在本页，可重试或取消。"
		message_label.add_theme_color_override("font_color",Color("efb566"))

func _cancel_character() -> void:
	appearance_draft.clear()
	show_home()

func show_levels(chapter: int = -1, notice: String = "") -> void:
	# LEVEL-092: eight chapters of ten levels. Level n opens when n-1 is cleared.
	page = "levels"
	current_level = {}
	_clear_screen()
	var levels = Campaign.levels(GameState.items)
	var frontier = GameState.campaign_frontier()
	if chapter<0:
		chapter = level_chapter if level_chapter>=0 else (frontier-1)/Campaign.PER_CHAPTER
	level_chapter = clampi(chapter,0,Campaign.CHAPTERS.size()-1)
	if level_selected<1 or (level_selected-1)/Campaign.PER_CHAPTER!=level_chapter:
		level_selected = clampi(frontier,level_chapter*Campaign.PER_CHAPTER+1,(level_chapter+1)*Campaign.PER_CHAPTER)
	var cleared: Array = GameState.profile.get("campaign_cleared",[])
	_header("关卡挑战　已通过 %d / %d" % [cleared.size(),Campaign.COUNT])
	UI.label(screen,"第 %d 章：%s" % [level_chapter+1,Campaign.CHAPTERS[level_chapter]],Vector2(60,100),34,UI.INK)
	UI.label(screen,Campaign.CHAPTER_NOTES[level_chapter],Vector2(64,148),17,UI.MUTED,1100)
	UI.button(screen,"返回营地",Rect2(1208,100,175,48),show_home)
	for c in range(Campaign.CHAPTERS.size()):
		var target = c
		var first = c*Campaign.PER_CHAPTER+1
		var tab = UI.button(screen,"%d　%s" % [c+1,Campaign.CHAPTERS[c]],Rect2(60+c*166,180,160,40),func():show_levels(target),c==level_chapter)
		tab.add_theme_font_size_override("font_size",14)
		tab.disabled = not GameState.campaign_unlocked(first)
		if tab.disabled:
			tab.modulate = Color(1,1,1,.45)
	for i in range(Campaign.PER_CHAPTER):
		var level: Dictionary = levels[level_chapter*Campaign.PER_CHAPTER+i]
		var number = int(level.number)
		var unlocked = GameState.campaign_unlocked(number)
		var done = number in cleared
		var card = UI.panel(screen,Rect2(60+(i%5)*266,234+(i/5)*176,254,164),Color(.10,.16,.12,.96) if number==level_selected else Color(.045,.085,.065,.94))
		UI.label(card,("第 %d 关" % number)+("（冠军）" if bool(level.boss) else ""),Vector2(14,8),18,UI.GOLD)
		UI.label(card,"已通过" if done else ("可挑战" if unlocked else "未解锁"),Vector2(170,10),14,Color("9bd28a") if done else (UI.INK if unlocked else UI.MUTED))
		UI.label(card,str(level.opponent) if unlocked else "？？？",Vector2(14,38),17,UI.INK if unlocked else UI.MUTED,226)
		UI.label(card,"%s · %s" % [level.archetype_name,"实战" if level.mode=="war" else "竞技场"],Vector2(14,66),15,UI.MUTED,226)
		var grade = ["新手装","初级装","中级装","中高级装","高级装","最高级装"][clampi(int(level.quality),0,5)]
		UI.label(card,"%s · %s" % [grade,Campaign.ai_label(level.ai)],Vector2(14,90),13,UI.MUTED,226)
		var purse = int(level.reward_coins) if not done else Campaign.replay_coins(number,bool(level.boss))
		UI.label(card,("重玩 %d 银币" if done else "奖励 %d 银币") % purse,Vector2(14,126),15,UI.GOLD,130)
		var pick = UI.button(card,"选择" if unlocked else "未解锁",Rect2(150,118,92,36),func():
			level_selected = number
			show_levels(level_chapter))
		pick.add_theme_font_size_override("font_size",14)
		pick.disabled = not unlocked
	var selected: Dictionary = levels[level_selected-1]
	var detail = UI.panel(screen,Rect2(60,594,1320,190),Color(.045,.085,.065,.98))
	UI.label(detail,"第 %d 关 · %s" % [int(selected.number),str(selected.opponent)],Vector2(22,12),24,UI.GOLD,800)
	UI.label(detail,"%s，来自%s" % [selected.archetype_name,selected.region],Vector2(22,50),17,UI.INK,860)
	var kit: Array = []
	for slot in ["armor","helmet","shield","lance","horse"]:
		var item = Catalogue.find(GameState.items,str(selected.equipment.get(slot,"")))
		if not item.is_empty():
			kit.append(str(item.name).split(" · ")[-1])
	UI.label(detail,"装备：" + " / ".join(kit),Vector2(22,80),15,UI.MUTED,860)
	var hint = str(selected.hint)
	if bool(GameState.profile.settings.mouse_only): hint=hint.replace("按住 W","滚轮向上")
	UI.label(detail,"对策：" + hint,Vector2(22,110),16,UI.INK,860)
	var first_clear = int(selected.number) not in cleared
	UI.label(detail,("首次通关 +%d 银币 +%d 声望" % [int(selected.reward_coins),int(selected.reward_renown)]) if first_clear else ("重复通关 +%d 银币" % Campaign.replay_coins(int(selected.number),bool(selected.boss))),Vector2(22,145),18,UI.GOLD,860)
	var go = UI.button(detail,"出战",Rect2(960,40,330,70),func():_start_level(int(selected.number)),true)
	go.add_theme_font_size_override("font_size",26)
	go.disabled = not GameState.campaign_unlocked(int(selected.number))
	UI.button(detail,"练习前倾与防盾" if int(selected.number)>=6 and int(selected.number)<=10 else "进入练习场",Rect2(960,124,330,43),show_practice_setup)
	message_label = UI.label(screen,notice,Vector2(64,790),14,Color("efb566"),1300)
	_queue_opponent_assets(Catalogue.stats(GameState.items,selected.equipment))
	queue_redraw()

func _start_level(number: int) -> void:
	if not GameState.campaign_unlocked(number):
		show_levels(-1,"这一关尚未解锁：先通过上一关。")
		return
	current_level = Campaign.level(GameState.items,number)
	level_selected = number
	level_chapter = (number-1)/Campaign.PER_CHAPTER
	_begin_match(str(current_level.mode))

func show_match_setup() -> void:
	page = "setup"
	current_level = {}
	_clear_screen()
	_header("选择对手与赛制")
	UI.label(screen,"选择你的交锋",Vector2(60,115),38,UI.INK)
	UI.button(screen,"返回营地",Rect2(1208,105,175,48),show_home)
	var descriptions = ["比武不致死，每轮换新枪。\n最多三次对冲，落马可提前决胜。","重击与连续头伤可致命，头盔可救命\n断枪跨轮保留，收藏不会丢失。","熟悉催马、枪线和三档盾位\n对手按轮次换盾，不计胜负奖励。"]
	for i in range(3):
		var card = UI.panel(screen,Rect2(60+i*449,200,430,260))
		UI.label(card,["竞技场","实战","练习场"][i],Vector2(24,22),30,UI.GOLD)
		UI.label(card,descriptions[i],Vector2(24,83),19,UI.INK,382)
		var selected = i
		UI.button(card,["进入竞技场","进入实战","开始练习"][i],Rect2(24,182,382,54),func():
			if selected==2: show_practice_setup()
			else: _begin_match("war" if selected==1 else "arena"),i==0)
	UI.label(screen,"对手难度",Vector2(64,494),22,UI.GOLD)
	var ai_names = preload("res://scripts/core/opponent_ai.gd").NAMES
	var ai_notes = ["反应较慢，压枪更早，留出观察时间。","会判断来枪与暴露部位，有反应延迟。","更晚收招，会变招与记住上一轮的来枪。"]
	for i in range(3):
		var difficulty = i
		var button = UI.button(screen,ai_names[i],Rect2(60+i*449,539,430,49),func():
			GameState.set_setting("difficulty",difficulty)
			show_match_setup())
		button.toggle_mode = true
		button.button_pressed = int(GameState.profile.settings.difficulty)==i
		button.add_theme_stylebox_override("pressed",UI.box(Color("b69a60"),Color("f0d08c"),5))
		button.add_theme_color_override("font_pressed_color",Color("15221e"))
		UI.label(screen,ai_notes[i],Vector2(64+i*449,604),16,UI.MUTED,421)
	UI.label(screen,"难度改变反应与决策，不增加对手生命或伤害。练习场使用固定教学节奏。",Vector2(64,659),17,UI.MUTED,1200)
	UI.label(screen,"地区线",Vector2(64,722),18,UI.GOLD)
	var region = OptionButton.new()
	region.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	region.position = Vector2(165,709)
	region.size = Vector2(250,47)
	for name_value in Catalogue.REGIONS:
		region.add_item(name_value)
	region.selected = int(GameState.profile.region)
	region.item_selected.connect(func(index):
		GameState.profile.region = index
		GameState.save_profile()
		if is_instance_valid(message_label):
			message_label.text = "地区设置已应用，但暂未保存；回营地可重试保存。" if not GameState.save_error.is_empty() else ""
			message_label.tooltip_text = GameState.save_error)
	screen.add_child(region)
	UI.label(screen,"地区选择只影响装饰偏好，已购装备仍可使用。",Vector2(450,722),17,UI.MUTED,820)
	message_label = UI.label(screen,"设置已应用，但暂未保存；回营地可重试保存。" if not GameState.save_error.is_empty() else "",Vector2(64,772),14,Color("efb566"),1300)
	_queue_opponent_assets()
	queue_redraw()

func show_practice_setup() -> void:
	page = "practice_setup"
	current_level = {}
	_clear_screen()
	_header("先练习催马、瞄准和防盾")
	UI.label(screen,"从容上马，再迎向对手",Vector2(60,116),38,UI.INK)
	UI.button(screen,"返回营地",Rect2(1208,105,175,48),show_home)
	var guided = UI.panel(screen,Rect2(60,220,648,326))
	UI.label(guided,"分步上马练习",Vector2(28,24),31,UI.GOLD)
	UI.label(guided,"催马、收速、稳枪、防盾与姿态，逐步完成。\n教练先收枪，最后一项瞄胸出枪，让你实际练习格挡。",Vector2(28,88),21,UI.INK,592)
	var continuing = active_guide!=null and active_guide.step>0 and not active_guide.complete()
	var guide_caption = "继续练习 · 已完成 %d / 7" % active_guide.step if continuing else ("重温分步练习" if GameState.profile.settings.get("guided_practice_v087",false) else "第一次上马 · 开始引导")
	UI.button(guided,guide_caption,Rect2(28,234,592,62),func():
		var lesson = active_guide if continuing else PracticeGuide.new()
		_start_match("arena",true,lesson),true)
	var free = UI.panel(screen,Rect2(730,220,648,326))
	UI.label(free,"自由对冲练习",Vector2(28,24),31,UI.GOLD)
	UI.label(free,"完整的三轮对冲，对手会出枪并按轮次换盾。\n适合比较不同装备，练习提前瞄准和最后防守。",Vector2(28,88),21,UI.INK,592)
	UI.button(free,"进入自由练习",Rect2(28,234,592,62),func():_begin_match("arena",true))
	UI.label(screen,"两种练习都不计胜负奖励，不消耗银币或装备。随时按 Esc 暂停并返回营地。",Vector2(64,594),21,UI.MUTED,1290)
	UI.label(screen,"枪盾仍需要时间移动；练习进度按真实速度、姿态和接触判断，不会自动命中。",Vector2(64,650),18,UI.MUTED,1290)
	_queue_opponent_assets()
	queue_redraw()

func _queue_opponent_assets(level_opponent: Dictionary = {}) -> void:
	# COMM-087: a cold opponent coat/cloth cost ~18ms in its first draw.
	# Prepare only the next opponent using the existing bounded queue slices.
	# No worker threads, extra persistent texture cache, quality loss or input
	# delay. Page deletion cancels jobs that have not started; hidden pages stop.
	var opponent = level_opponent if not level_opponent.is_empty() else Catalogue.opponent_stats(GameState.items,Catalogue.era_for_renown(int(GameState.profile.renown)))
	var preparation = preload("res://scripts/ui/build_queue.gd").new()
	preparation.name = "OpponentArtPreparation"
	screen.add_child(preparation)
	var design = str(opponent.get("heraldry","bend"))
	# ART-090: the battle uses the baked battle sprites (opponent faces left).
	preparation.enqueue(func(): Art.battle_torso_for(opponent,design,-1))
	preparation.enqueue(func(): Art.battle_helmet_for(opponent))
	preparation.enqueue(func(): HorseSkin.coat_texture(str(opponent.get("horse_coat","bay"))))
	var cloth_design = preload("res://scripts/visual/heraldry.gd").mirrored_key(design,-1)
	preparation.enqueue(func(): HorseSkin.caparison_texture(str(opponent.get("caparison_style","none")),cloth_design))

func show_saves(notice: String = "") -> void:
	page = "saves"
	_clear_screen()
	_header("存档 · 收藏、装备与养成进度")
	UI.label(screen,"保留你的骑士旅程",Vector2(60,112),38,UI.INK)
	UI.button(screen,"返回营地",Rect2(1208,105,175,48),show_home)
	var auto_card = UI.panel(screen,Rect2(60,191,1320,137))
	UI.label(auto_card,"当前进度 · 尚未保存" if GameState.profile_save_pending else "当前进度 · 自动保存",Vector2(24,18),25,UI.GOLD)
	UI.label(auto_card,"银币 %s  ·  声望 %s  ·  %s 场比赛" % [_short_number(int(GameState.profile.coins)),_short_number(int(GameState.profile.renown)),_short_number(int(GameState.profile.matches))],Vector2(24,65),20,UI.INK)
	UI.button(auto_card,"立即保存",Rect2(896,43,180,50),func():show_saves("已保存当前进度" if GameState.save_profile() else GameState.save_error))
	UI.button(auto_card,"继续游戏",Rect2(1100,43,194,50),show_match_setup,true)
	for i in range(3):
		var slot = i+1
		var data = GameState.read_slot(slot)
		var card = UI.panel(screen,Rect2(60+i*449,360,430,300))
		UI.label(card,"手动存档 %d" % slot,Vector2(24,20),26,UI.GOLD)
		if data.is_empty():
			UI.label(card,"空槽 / 暂无可读取的存档",Vector2(24,76),18,UI.MUTED,382)
		else:
			UI.label(card,data.saved_at+(" · 备份恢复" if data.recovered else ""),Vector2(24,75),16,UI.MUTED,382)
			UI.label(card,"银币 %s  ·  声望 %s\n%s · %s 场比赛" % [_short_number(int(data.profile.coins)),_short_number(int(data.profile.renown)),Catalogue.REGIONS[int(data.profile.region)],_short_number(int(data.profile.matches))],Vector2(24,112),19,UI.INK,382)
		UI.button(card,"保存到此槽" if data.is_empty() else "覆盖此槽",Rect2(24,211,184,53),func():_confirm_slot_operation(slot,false))
		var load_button = UI.button(card,"读取进度",Rect2(223,211,183,53),func():_confirm_slot_operation(slot,true))
		load_button.disabled = data.is_empty()
	UI.label(screen,"存档保留收藏、装备与设置；对冲从新比赛开始，不保存战斗中的位置。",Vector2(64,692),18,UI.MUTED,1290)
	var status_notice = notice
	if status_notice.is_empty():
		status_notice = "当前进度尚未保存，请点击「立即保存」重试。" if GameState.profile_save_pending else GameState.load_notice
	UI.label(screen,status_notice,Vector2(64,739),18,UI.GOLD,1290)
	queue_redraw()

func _confirm_slot_operation(slot: int, loading: bool) -> void:
	if is_instance_valid(slot_dialog) and not slot_dialog.is_queued_for_deletion(): return
	if not loading and GameState.read_slot(slot).is_empty():
		_perform_slot_operation(slot,false)
		return
	slot_dialog = ConfirmationDialog.new()
	slot_dialog.theme = UI.theme()
	slot_dialog.title = "读取存档 %d" % slot if loading else "覆盖存档 %d" % slot
	slot_dialog.dialog_text = ("这会用所选手动存档替换当前进度。\n原自动存档会保留为备份；尚未保存的进度会先尝试保存。" if loading else "这会将当前收藏和进度写入此槽。\n该槽上一次可用记录会保留为备份。")
	if GameState.recovery_required:
		slot_dialog.dialog_text = "这会从手动存档恢复旅程。\n游戏会先保留损坏的自动存档与备份文件。"
	slot_dialog.ok_button_text = "确认读取" if loading else "确认覆盖"
	slot_dialog.cancel_button_text = "取消"
	var dialog = slot_dialog
	add_child(dialog)
	dialog.confirmed.connect(func():
		dialog.hide()
		dialog.queue_free()
		_perform_slot_operation(slot,loading))
	dialog.canceled.connect(dialog.queue_free)
	dialog.popup_centered(Vector2i(690,220))

func _perform_slot_operation(slot: int, loading: bool) -> void:
	var success = GameState.load_slot(slot) if loading else GameState.save_slot(slot)
	if GameState.recovery_required:
		show_save_recovery(GameState.save_error)
		return
	if loading and success:
		_apply_audio_settings()
		_apply_display_settings()
	show_saves(("已读取存档 %d；原自动存档保留为备份" if loading else "已保存到存档 %d") % slot if success else GameState.save_error)

func _save_and_exit() -> void:
	if shutting_down:
		return
	if is_instance_valid(save_error_dialog) and not save_error_dialog.is_queued_for_deletion():
		# Repeated close requests must not duplicate a modal or turn a discard
		# confirmation back into a retry dialog underneath the player's click.
		save_error_dialog.grab_focus()
		return
	if GameState.recovery_required:
		_shutdown_and_quit()
		return
	if GameState.save_profile():
		_shutdown_and_quit()
		return
	if is_instance_valid(battle) and not battle.paused and not battle.is_finished:
		battle._toggle_pause()
	var dialog = ConfirmationDialog.new()
	save_error_dialog = dialog
	dialog.process_mode = Node.PROCESS_MODE_ALWAYS
	dialog.theme = UI.theme()
	dialog.title = "保存未成功"
	dialog.dialog_text = GameState.save_error+"\n游戏尚未退出，磁盘上的旧进度仍保留。\n你可以重试保存，或先返回游戏。"
	dialog.ok_button_text = "重试保存并退出"
	dialog.cancel_button_text = "返回游戏"
	var discard_button = dialog.add_button("不保存退出…",true,"discard")
	add_child(dialog)
	dialog.confirmed.connect(func():
		save_error_dialog = null
		dialog.hide()
		dialog.queue_free()
		_save_and_exit.call_deferred())
	dialog.canceled.connect(dialog.queue_free)
	dialog.custom_action.connect(func(action):
		if action!="discard":return
		save_error_dialog = null
		dialog.hide()
		dialog.queue_free()
		_confirm_discard_and_exit.call_deferred())
	dialog.popup_centered(Vector2i(720,230))
	UI.focus_actions([dialog.get_cancel_button(),dialog.get_ok_button(),discard_button])

func _confirm_discard_and_exit() -> void:
	if shutting_down or (is_instance_valid(save_error_dialog) and not save_error_dialog.is_queued_for_deletion()):return
	var dialog = ConfirmationDialog.new()
	save_error_dialog = dialog
	dialog.process_mode = Node.PROCESS_MODE_ALWAYS
	dialog.theme = UI.theme()
	dialog.title = "放弃未保存的改动？"
	dialog.dialog_text = "上次成功保存之后的奖励、装备或设置改动会丢失。\n磁盘上的旧进度不会被替换。\n确定要不保存就退出吗？"
	dialog.ok_button_text = "放弃改动并退出"
	dialog.cancel_button_text = "返回游戏"
	add_child(dialog)
	dialog.confirmed.connect(_shutdown_and_quit)
	dialog.canceled.connect(dialog.queue_free)
	dialog.popup_centered(Vector2i(720,230))
	UI.focus_actions([dialog.get_cancel_button(),dialog.get_ok_button()])

func _shutdown_and_quit() -> void:
	if shutting_down:
		return
	shutting_down = true
	set_process(false)
	set_process_unhandled_input(false)
	get_viewport().gui_disable_input = true
	# stop() queues mixer cleanup. Keep the tree alive briefly so looped WAV
	# playbacks are released before AudioServer teardown (also after battle).
	if sounds:
		sounds.set_enabled(false)
		sounds.stop_all()
	_close_battle()
	# A timer created after a slow save/render can consume that entire frame's
	# delta immediately: the intended 120ms was only 16ms in exit QA. Audio
	# removal needs mixer work plus main-thread cleanup, so wait actual time
	# and at least two process boundaries without blocking either thread.
	var quit_after = Time.get_ticks_msec()+120
	var closing_frames = 0
	while Time.get_ticks_msec()<quit_after or closing_frames<2:
		await get_tree().process_frame
		closing_frames += 1
	get_tree().quit()

func _notification(what: int) -> void:
	if what==NOTIFICATION_WM_CLOSE_REQUEST and is_inside_tree():
		_save_and_exit()

func _begin_match(mode: String, practice: bool = false) -> void:
	if GameState.profile.settings.get("combat_brief_v044",false):
		_start_match(mode,practice)
		return
	if is_instance_valid(brief_overlay):
		return
	brief_return_focus = get_viewport().gui_get_focus_owner()
	var shade = ColorRect.new()
	shade.color = Color(0,0,0,.70)
	shade.size = Vector2(1440,810)
	brief_overlay = shade
	screen.add_child(shade)
	var panel = UI.panel(shade,Rect2(270,95,900,620),Color(.045,.085,.065,.99))
	UI.label(panel,"上场前记住这四个动作",Vector2(30,24),32,UI.GOLD)
	UI.label(panel,"你在左侧。马匹自动前进，枪和盾都需要时间移动。",Vector2(30,78),20,UI.INK,840)
	var controls = [
		["催马 · 左键 / 空格","按住加速，松手收速；留意马匹体力。"],
		["瞄准 · 上下移动鼠标","抬枪、压枪有过程；停手稳枪。"],
		["防盾 · 1 / 2 / 3","护头 / 护胸 / 护腹；右键或Q循环。"],
		["姿态 · W / S","前倾支撑；后仰避头，同时暴露腰腹。"]]
	if GameState.profile.settings.get("mouse_only",false):
		controls[2]=["防盾 · 点击三个盾位","护头 / 护胸 / 护腹；右键循环。"]
		controls[3]=["姿态 · 滚轮 / 中键","滚轮倾身，中键回正；后仰会暴露腰腹。"]
	for i in range(controls.size()):
		var card=UI.panel(panel,Rect2(30+(i%2)*430,124+(i/2)*96,410,82),Color(.10,.16,.12,.95))
		UI.label(card,controls[i][0],Vector2(15,10),20,UI.GOLD,380)
		UI.label(card,controls[i][1],Vector2(15,43),16,UI.INK,380)
	UI.separator(panel,Vector2(30,329),840)
	var rules = "竞技场 · 最多三轮，落马提前决胜，每轮换新枪；不会死亡。\n盾1 · 胸腹2 · 头盔3；轻触1分，擦偏0分，非擦偏断枪+1。"
	if mode=="war":
		rules = "实战 · 头部重击可致命；连续正面受创会累积，头盔不能无限抵挡。\n盾挡与擦过可存活；断枪跨轮保留，死亡不会丢失收藏。"
	elif practice:
		rules = "练习场 · 对手按轮次换盾，最多三次对冲。\n不计胜负与奖励，先熟悉加减速、瞄准和防盾。"
	UI.label(panel,rules,Vector2(30,347),19,UI.INK,840)
	UI.label(panel,"枪尖颜色与部位框提示当前枪线，并不保证最终命中。",Vector2(30,423),17,UI.GOLD,840)
	UI.label(panel,"Esc 暂停　R 重开　H 判定范围　F11 全屏",Vector2(30,465),16,UI.MUTED,840)
	var begin = UI.button(panel,"明白了，出战",Rect2(30,522,330,58),func():
		for key in ["brief_seen","combat_brief_v043","combat_brief_v044"]:
			GameState.profile.settings[key]=true
		GameState.save_profile()
		_start_match(mode,practice))
	var lesson = UI.button(panel,"先做分步练习",Rect2(380,522,260,58),func():
		_dismiss_brief()
		show_practice_setup(),true)
	var cancel = UI.button(panel,"返回选择",Rect2(660,522,210,58),_dismiss_brief)
	UI.focus_actions([lesson,begin,cancel])

func _dismiss_brief() -> void:
	if is_instance_valid(brief_overlay):
		brief_overlay.hide()
		brief_overlay.queue_free()
	brief_overlay=null
	if is_instance_valid(brief_return_focus) and brief_return_focus.is_visible_in_tree():
		brief_return_focus.grab_focus()
	brief_return_focus=null

func _start_match(mode: String, practice: bool = false, guide: PracticeGuide = null) -> void:
	var trace_started = Trace099.begin()
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
	battle = Battle.new()
	battle.staged_startup = true
	battle.mode = mode
	battle.practice = practice
	battle.practice_guide = active_guide
	if practice:
		current_level = {}
	battle.level = current_level
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
	if not ResultPrewarm099.complete:
		# This CanvasLayer is below Battle's fully opaque preparation layer.
		# Its label owns its short lifetime even in QA with Main processing off.
		screen.add_child(ResultPrewarm099.new())
	queue_redraw()
	Trace099.end("start_match",trace_started)

func _on_lesson_completed() -> void:
	if GameState.profile.settings.get("guided_practice_v087",false): return
	GameState.profile.settings.combat_brief_v044 = true
	GameState.set_setting("guided_practice_v087",true)

func _finish_lesson() -> void:
	if active_guide==null or not active_guide.complete(): return
	_close_battle()
	page = "lesson_result"
	_clear_screen()
	result_visible = true
	_show_lesson_result()
	queue_redraw()

func _close_battle() -> void:
	var trace_started = Trace099.begin()
	if battle:
		remove_child(battle)
		battle.queue_free()
		battle = null
	get_tree().paused = false
	Engine.time_scale = 1.0
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if sounds and sounds.enabled and sounds.music and not sounds.music.playing:
		sounds.music.play()
	Trace099.end("close_battle",trace_started)

func _on_match_finished(result: Dictionary) -> void:
	var trace_started = Trace099.begin()
	pending_result = result
	var outcome = 0 if int(result.winner) == -1 else (1 if int(result.winner)==0 else -1)
	if practice_match:
		reward = {"coins":0,"renown":0}
	elif not current_level.is_empty():
		reward = GameState.award_level(session_id,int(current_level.number),outcome)
	else:
		reward = GameState.award_match(session_id,outcome,current_mode)
	Trace099.end("award_result",trace_started)

func _process(_delta: float) -> void:
	if battle and battle.is_finished and not result_visible:
		show_result()
	if smoke_mode:
		_run_smoke()

func show_result() -> void:
	var trace_started = Trace099.begin()
	result_visible = true
	if active_guide:
		_show_lesson_result()
		return
	var result = pending_result
	var contacts: Array = battle.exchange_log if battle else []
	var report = preload("res://scripts/ui/combat_report.gd")
	var won = int(result.get("winner",-1)) == 0
	var draw = int(result.get("winner",-1)) == -1
	sounds.play("win" if won else "lose",-9)
	var panel = UI.panel(screen,Rect2(332,116,776,578),Color(.045,.085,.065,.98))
	# At the default 1280/1440 stretch, nearest filtering drops thin CJK
	# strokes. Filter only this text/flat-UI panel, not the pixel-art world.
	panel.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var heading = "练习结束，不计奖励" if practice_match else (("竞技场" if current_mode=="arena" else "实战")+" · "+preload("res://scripts/core/opponent_ai.gd").NAMES[int(GameState.profile.settings.difficulty)])
	if not current_level.is_empty():
		heading = "第 %d 关 · %s · %s · %s" % [int(current_level.number),"竞技场" if current_mode=="arena" else "实战",str(current_level.opponent),str(current_level.archetype_name)]
	UI.label(panel,heading,Vector2(35,22),16,UI.GOLD,520)
	var campaign_complete = int(current_level.get("number",0))==Campaign.COUNT and won and Campaign.all_complete(GameState.profile)
	var title = "八章挑战完成" if campaign_complete else ("平局" if draw else ("你赢了" if won else "这场输了"))
	UI.label(panel,title,Vector2(35,62),42,UI.INK).name="ResultTitle"
	if current_mode=="arena":
		UI.label(panel,"比分 %d : %d" % [int(result.get("player_score",0)),int(result.get("enemy_score",0))],Vector2(485,76),25,UI.GOLD,255).name="ResultScore"
	var explanation = "三轮后双方伤势相当。" if draw else ("三轮后双方仍在马上，对手的伤势较重。" if won else "三轮后双方仍在马上，你的伤势较重。")
	if result.get("reason") == "terminal":
		explanation = "双方同时落马。" if draw else "落马出局。"
	elif result.get("reason") == "score":
		explanation = "三轮结束，得分较高者胜。"
	elif current_mode=="arena":
		explanation = "双方同分，伤势也相当。" if draw else ("双方同分，对手的伤势较重。" if won else "双方同分，你的伤势较重。")
	if result.get("player_dead",false) or result.get("enemy_dead",false):
		explanation = "致命一击结束对局，收藏保留。"
	if result.get("reason")=="terminal" and not contacts.is_empty():
		explanation=report.summarize(contacts,current_mode)
		if result.get("player_dead",false) or result.get("enemy_dead",false): explanation+="收藏保留。"
	UI.label(panel,explanation,Vector2(35,128),18,UI.MUTED,706)
	UI.separator(panel,Vector2(35,177),706)
	result_timeline = Status098.new()
	result_timeline.history = true
	result_timeline.arena = current_mode=="arena"
	result_timeline.position = Vector2(35,192)
	result_timeline.size = Vector2(706,151)
	result_timeline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	result_timeline.name = "ContactTimeline"
	panel.add_child(result_timeline)
	result_timeline.refresh([],contacts,int(result.get("passes",3)))
	result_detail_scroll = ScrollContainer.new()
	result_detail_scroll.position = Vector2(35,190)
	result_detail_scroll.size = Vector2(706,157)
	result_detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(result_detail_scroll)
	var numbers = ""
	if battle:
		if current_mode=="arena": numbers="比分 %d : %d    " % [int(result.get("player_score",0)),int(result.get("enemy_score",0))]
		numbers+="生命 %s : %s\n" % [roundi(float(battle.match_model.fighters[0].hp)),roundi(float(battle.match_model.fighters[1].hp))]
	# Keep the complete report, but defer its hidden text layout until H.
	# Opening the concise result must not shape an invisible scroll of text.
	result_detail_text = numbers+report.summarize(contacts,current_mode,true)
	result_details = UI.label(result_detail_scroll,"",Vector2.ZERO,14,UI.INK,680)
	result_details.name = "ContactSummary"
	result_debug = false
	result_detail_scroll.visible = false
	UI.label(panel,"H 查看数据",Vector2(620,24),14,UI.MUTED,125)
	var reward_text = "银币 +%d · 声望 +%d" % [int(reward.get("coins",0)),int(reward.get("renown",0))]
	if practice_match:
		reward_text = "练习不计奖励"
	elif not current_level.is_empty():
		reward_text = (("首次通关 · " if reward.get("first_clear",false) else "重玩 · ")+reward_text) if won else "本关未通过，不计奖励。"
	var reward_label = UI.label(panel,reward_text,Vector2(35,363),23 if won or current_level.is_empty() else 19,UI.GOLD,706)
	reward_label.name = "ResultRewards"
	result_rewards = reward_label
	reward_label.set_meta("debug_text",reward_text)
	reward_label.set_meta("normal_text",reward_text)
	var next_era = Catalogue.era_for_renown(int(GameState.profile.renown)) + 1
	var progress = "全部时期已开放；继续收集工坊与纹章。" if next_era >= Catalogue.ERAS.size() else "%s 将在声望达到 %d 时开放（目前 %d）。" % [Catalogue.ERAS[next_era],Catalogue.ERA_REQUIREMENTS[next_era],GameState.profile.renown]
	var advice = "八章已完成，可重玩挑战或继续收集装备。" if campaign_complete else report.next_action(contacts,bool(GameState.profile.settings.get("mouse_only",false)),result)
	result_progress = UI.label(panel,advice,Vector2(35,408),15,UI.MUTED,706)
	result_progress.name="ResultAdvice"
	result_progress.set_meta("normal_text",advice)
	result_progress.set_meta("debug_text",progress)
	if GameState.profile_save_pending:
		var save_status = UI.label(panel,"本局进度暂未保存。",Vector2(35,439),16,Color("efb566"),490)
		save_status.name = "PendingRewardSave"
		UI.button(panel,"重试保存",Rect2(550,432,190,32),func():
			save_status.text = "本局进度已保存。" if GameState.save_profile() else "仍未保存，请检查磁盘空间或写入权限。")
	if not current_level.is_empty():
		var number = int(current_level.number)
		if won and number<Campaign.COUNT:
			UI.button(panel,"下一关",Rect2(35,470,222,56),func():
				_close_battle()
				_start_level(number+1),true)
		else:
			UI.button(panel,"重新挑战  R",Rect2(35,470,222,56),func():_start_match(current_mode,practice_match,active_guide),true)
		if not won:
			# Keep all navigation available, with a direct recovery path to gear.
			for child in panel.get_children():
				if child is Button and child.position.y==470: child.size.x=166
			UI.button(panel,"调整装备",Rect2(215,470,166,56),func():
				_close_battle()
				show_armory())
		UI.button(panel,"关卡列表",Rect2(395 if not won else 277,470,166 if not won else 222,56),func():
			_close_battle()
			show_levels())
		UI.button(panel,"返回营地",Rect2(575 if not won else 519,470,166 if not won else 222,56),func():
			_close_battle()
			show_home())
		Trace099.end("show_result",trace_started)
		return
	UI.button(panel,"再次对冲  R",Rect2(35,470,344,56),func():_start_match(current_mode,practice_match,active_guide),true)
	UI.button(panel,"返回营地",Rect2(397,470,344,56),func():
		_close_battle()
		show_home())
	Trace099.end("show_result",trace_started)

func _show_lesson_result() -> void:
	var lesson = active_guide
	var panel = UI.panel(screen,Rect2(270,110,900,590),Color(.045,.085,.065,.99))
	UI.label(panel,"七项练习已完成" if lesson.complete() else "练习小结 · 一步一步来",Vector2(30,25),34,UI.GOLD)
	UI.label(panel,"已完成 %d / 7 · 这次对冲不计胜负与奖励" % mini(lesson.step,7),Vector2(30,81),20,UI.INK,840)
	for i in range(PracticeGuide.TITLES.size()):
		var done = i<lesson.step
		UI.label(panel,("完成 · " if done else "待练 · ")+PracticeGuide.TITLES[i],Vector2(30+(i%2)*430,135+(i/2)*52),21,UI.GOLD if done else UI.MUTED,410)
	var contact_text = "完成接触后，这里会显示实际碰到的部位。"
	var names = preload("res://scripts/visual/combat_cues.gd")
	if not lesson.last_contact.is_empty():
		contact_text = "你的一枪："+names.contact_name(lesson.last_contact)+(" · 擦过" if lesson.last_contact.get("glanced",false) else " · 已接触")
	if not lesson.last_block.is_empty(): contact_text += "\n你的格挡："+names.contact_name(lesson.last_block)+" · 盾牌实际承受了来枪"
	UI.label(panel,contact_text,Vector2(30,352),19,UI.INK,840)
	var reminder = "下一步可进入竞技场：真实对手会选择空当并反击。" if lesson.complete() else "继续练习会保留已完成步骤；枪盾动作与命中仍按正常规则。"
	UI.label(panel,reminder,Vector2(30,416),17,UI.MUTED,840)
	if GameState.profile_save_pending:
		UI.label(panel,"进度尚未保存，请返回营地后到存档页重试。",Vector2(30,447),16,Color("efb566"),840)
	UI.button(panel,"进入竞技场" if lesson.complete() else "继续本次练习",Rect2(30,486,540,60),func():
		if lesson.complete(): _begin_match("arena")
		else: _start_match("arena",true,lesson),true)
	UI.button(panel,"返回营地",Rect2(590,486,280,60),func():
		_close_battle()
		show_home())

func show_armory() -> void:
	# Family arms are common decoration, not country/period/quality tiers.
	# Keep the player's gear filters so returning to armour restores them.
	var family_arms = selected_slot=="crest"
	var filter_key = "%s/%d/%d/%d" % [selected_slot,selected_era,selected_region,selected_quality]
	if page=="armory" and is_instance_valid(armory_scroll):
		armory_scroll_offset=armory_scroll.scroll_vertical
	if filter_key!=armory_filter_key:
		armory_scroll_offset=0
	armory_filter_key=filter_key
	page = "armory"
	_clear_screen()
	_header("军械库")
	UI.label(screen,"挑选武备",Vector2(55,105),37,UI.INK)
	UI.button(screen,"返回营地",Rect2(1210,100,175,48),show_home)
	# EQUIP-066: the cause of horse fatigue is shown where it is decided.
	var load_text = _load_summary(GameState.player_stats())
	UI.label(screen,load_text.text,Vector2(300,108),15,load_text.color,890)
	var index = 0
	for slot in Catalogue.SLOT_NAMES:
		var slot_value = str(slot)
		# Seven slots (EQUIP-066 added 马衣) share the space the six used.
		var slot_button=UI.button(screen,Catalogue.SLOT_NAMES[slot],Rect2(56+index*95,169,88,43),func():
			selected_slot = slot_value
			selected_item = {}
			show_armory(),selected_slot == slot_value)
		if slot=="crest": slot_button.add_theme_font_size_override("font_size",16)
		index += 1
	if selected_slot in ["crest","shield"]:
		UI.label(screen,"家族纹章通用，不分年代与品质；用于衣饰，盾纹固定。" if family_arms else "家族纹章用于罩袍、马衣和枪旗；盾纹随盾牌固定。",Vector2(56,215),13,UI.MUTED,810)
	var era_select = OptionButton.new()
	era_select.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	era_select.theme = UI.theme()
	era_select.position = Vector2(724,169)
	era_select.size = Vector2(210,43)
	era_select.add_item("不分年代" if family_arms else "全部年代")
	for i in range(Catalogue.ERAS.size()):
		era_select.add_item(Catalogue.ERAS[i])
	era_select.selected = 0 if family_arms else selected_era+1
	era_select.disabled = family_arms
	era_select.item_selected.connect(func(value):
		selected_era = value-1
		selected_item = {}
		show_armory())
	screen.add_child(era_select)
	var region_select = OptionButton.new()
	region_select.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	region_select.theme = UI.theme()
	region_select.position = Vector2(946,169)
	region_select.size = Vector2(199,43)
	for region_name in ["全部地区"]+Catalogue.REGIONS+["欧洲共通"]:
		region_select.add_item(region_name)
	region_select.selected = 5 if family_arms else selected_region
	region_select.disabled = family_arms
	region_select.item_selected.connect(func(value):
		selected_region = value
		selected_item = {}
		show_armory())
	screen.add_child(region_select)
	var quality_select = OptionButton.new()
	quality_select.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	quality_select.theme = UI.theme()
	quality_select.position = Vector2(1157,169)
	quality_select.size = Vector2(228,43)
	for quality_name in ["不分品质" if family_arms else "全部品质","新手","初级","中级","中高级","高级","最高级"]:
		quality_select.add_item(quality_name)
	quality_select.selected = 0 if family_arms else selected_quality
	quality_select.disabled = family_arms
	quality_select.item_selected.connect(func(value):
		selected_quality = value
		selected_item = {}
		show_armory())
	screen.add_child(quality_select)
	var scroll = ScrollContainer.new()
	scroll.name="ArmoryList"
	scroll.follow_focus = true
	armory_scroll=scroll
	scroll.position = Vector2(55,236)
	scroll.size = Vector2(830,478)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	screen.add_child(scroll)
	var grid = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation",14)
	grid.add_theme_constant_override("v_separation",14)
	scroll.add_child(grid)
	var filtered: Array = []
	for item in GameState.items:
		if bool(item.get("legacy",false)) and item.id not in GameState.profile.owned:
			continue
		var region_match = family_arms or selected_region==0 or item.region==("欧洲共通" if selected_region==5 else Catalogue.REGIONS[maxi(0,selected_region-1)])
		var quality_match = family_arms or selected_quality==0 or int(item.get("quality",-1))==selected_quality-1
		if item.slot == selected_slot and (family_arms or selected_era<0 or int(item.era) == selected_era) and region_match and quality_match:
			filtered.append(item)
	var build_queue = preload("res://scripts/ui/build_queue.gd").new()
	screen.add_child(build_queue)
	if selected_item.is_empty() and not filtered.is_empty():
		selected_item = filtered[0]
	for item in filtered:
		var item_value = item
		var card = Button.new()
		card.custom_minimum_size = Vector2(397,126)
		card.text = ""
		card.alignment = HORIZONTAL_ALIGNMENT_LEFT
		card.clip_contents = true
		card.add_theme_font_size_override("font_size",14)
		card.tooltip_text = item.description
		card.toggle_mode = true
		# Keep selection readable while icons/details build over later frames,
		# including the rebuild immediately after buying or equipping an item.
		card.set_pressed_no_signal(item.id==selected_item.get("id",""))
		card.focus_entered.connect(func(): _fill_armory_card(card,item_value))
		card.add_theme_stylebox_override("pressed",UI.box(Color("34452f"),UI.GOLD,5))
		card.pressed.connect(func():
			selected_item = item_value
			_update_item_panel())
		grid.add_child(card)
		armory_cards[item.id]=card
		build_queue.enqueue(func(): _fill_armory_card(card,item_value),card)
	if filtered.is_empty():
		var empty=VBoxContainer.new()
		empty.custom_minimum_size=Vector2(790,160)
		empty.add_theme_constant_override("separation",18)
		grid.add_child(empty)
		UI.label(empty,"没有符合当前筛选的装备",Vector2.ZERO,24,UI.GOLD,750)
		var empty_hint = "马匹与马衣为欧洲共通。" if selected_slot in ["horse","caparison"] else "当前地区、年代或品质下没有匹配项。"
		UI.label(empty,empty_hint+"试试清除筛选。",Vector2.ZERO,18,UI.INK,750)
		UI.button(empty,"清除筛选",Rect2(0,0,260,48),func():
			selected_region=0
			selected_era=-1
			selected_quality=0
			selected_item={}
			show_armory())
	info_panel = UI.panel(screen,Rect2(925,229,460,507),Color(.055,.10,.08,.95))
	info_panel.clip_contents = true
	UI.label(info_panel,"正在整理装备…",Vector2(22,16),22,UI.GOLD,415)
	build_queue.enqueue(func():
		if not info_panel.get_meta("details_ready",false): _update_item_panel())
	scroll.set_deferred("scroll_vertical",armory_scroll_offset)
	message_label = UI.label(screen,"收藏解锁不等于史实复原。每件装备保留来源与改编说明。",Vector2(57,744),16,UI.MUTED,830)
	queue_redraw()

func _fill_armory_card(card: Button, item: Dictionary) -> void:
	if card.get_meta("content_ready",false): return
	card.set_meta("content_ready",true)
	var owned = item.id in GameState.profile.owned
	var equipped = GameState.profile.equipped.get(item.slot) == item.id
	# Wider icon well (was 72x88): equipment differences were too small to see.
	var title = UI.label(card,("◆ " if equipped else "")+str(item.name),Vector2(14,10),17,UI.INK,218)
	title.max_lines_visible = 2
	var period=UI.label(card,"%s · %s" % [item.get("historical_window",Catalogue.ERAS[int(item.era)]),item.get("quality_name","旧藏")],Vector2(14,65),14,UI.MUTED,218)
	period.autowrap_mode=TextServer.AUTOWRAP_OFF
	period.clip_text=true
	period.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	period.tooltip_text=period.text
	UI.label(card,"已装备" if equipped else ("已收藏" if owned else ("%d 银币 · 声望 %d" % [item.price,Catalogue.required_renown(item)])),Vector2(14,94),15,UI.GOLD,218)
	if item.slot=="shield":
		period.visible = false
		var tag = "轻盾" if str(item.stats.get("shield_class","light"))=="light" else "重盾"
		UI.label(card,tag,Vector2(14,48),13,UI.GOLD)
		for i in range(3):
			var values=[float(item.stats.get("shield_speed",1))/1.15,1.0-float(item.stats.get("shield_protection",{}).get("leak",.1))*6,float(item.stats.get("shield_capacity",150))/400]
			_small_meter(card,["速度","防护","耐久"][i],Vector2(65,49+i*13),values[i],130)
	_add_item_icon(card,item,Vector2(236,8),Vector2(152,100),true)

func _small_meter(parent: Control, caption: String, at: Vector2, value: float, width: float=170) -> void:
	UI.label(parent,caption,at,11,UI.MUTED,34)
	var back=ColorRect.new()
	back.position=at+Vector2(35,4)
	back.size=Vector2(width-35,6)
	back.color=Color("22392e")
	back.mouse_filter=Control.MOUSE_FILTER_IGNORE
	parent.add_child(back)
	var fill=ColorRect.new()
	fill.size=Vector2((width-35)*clampf(value,0,1),6)
	fill.color=Color("c2a568")
	fill.mouse_filter=Control.MOUSE_FILTER_IGNORE
	back.add_child(fill)

func _player_heraldry() -> String:
	return str(GameState.player_stats().get("heraldry","bend"))

func _load_summary(stats: Dictionary) -> Dictionary:
	var Condition = Model.Condition
	var carried = Condition.load_kg(stats)
	var capacity = Condition.capacity_kg(stats)
	var ratio = carried/maxf(1.0,capacity)
	var band = "轻快" if ratio<.90 else ("适中" if ratio<1.02 else "沉重")
	var color = Color("9fd08a") if ratio<.90 else (UI.GOLD if ratio<1.02 else Color("e08a6a"))
	return {"text":"连人带装备 %d kg，马匹承载 %d kg。当前负担%s。" % [roundi(carried),roundi(capacity),band],"color":color}

func _add_item_icon(parent: Control, item: Dictionary, point: Vector2, dimensions: Vector2, deferred_card: bool = false) -> Control:
	var icon: Control
	if item.slot=="lance":
		var lance_icon = LanceIcon.new()
		lance_icon.equipment = item.stats.duplicate()
		lance_icon.equipment["heraldry"]=_player_heraldry()
		icon = lance_icon
	elif item.slot=="shield" and item.stats.has("shield_shape"):
		# The same fixed item device is shown in the shop and on the rider.
		var shield_icon = ShieldIcon.new()
		shield_icon.equipment = item.stats.duplicate()
		icon = shield_icon
	elif item.slot=="crest":
		var crest_icon = FamilyIcon.new()
		crest_icon.design = str(item.stats.get("heraldry","bend"))
		icon = crest_icon
	elif item.slot=="caparison":
		var cloth_icon = CaparisonIcon.new()
		cloth_icon.style = str(item.stats.get("caparison_style","none"))
		cloth_icon.design = _player_heraldry()
		cloth_icon.coat = str(GameState.player_stats().get("horse_coat","bay"))
		icon = cloth_icon
	else:
		var texture: TextureRect
		if deferred_card and item.slot in ["armor","helmet"]:
			texture = preload("res://scripts/ui/equipment_icon.gd").new()
			texture.equipment = item
		else:
			texture = TextureRect.new()
			texture.texture = Art.item_icon(item)
		texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		texture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon = texture
	# Text controls filter smoothly, but item artwork keeps its pixel sampling.
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.position = point
	icon.size = dimensions
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(icon)
	icon.set_deferred("size",dimensions)
	if item.slot=="lance" and dimensions.x>=120:
		UI.label(icon,"比武冠头",Vector2(0,3),11,UI.MUTED)
		UI.label(icon,"实战尖头",Vector2(0,dimensions.y*.5),11,UI.MUTED)
	return icon

func _update_item_panel() -> void:
	info_panel.set_meta("details_ready",true)
	for id in armory_cards:
		armory_cards[id].set_pressed_no_signal(id==selected_item.get("id",""))
	for child in info_panel.get_children():
		child.queue_free()
	if selected_item.is_empty():
		info_panel.visible=false
		return
	info_panel.visible=true
	var item = selected_item
	UI.label(info_panel,item.name,Vector2(22,16),22,UI.GOLD,415)
	UI.label(info_panel,"%s · %s · %s" % [item.region,item.get("quality_name","旧藏"),item.get("historical_window",Catalogue.ERAS[int(item.era)])],Vector2(22,76),13,UI.MUTED,415)
	UI.label(info_panel,item.description,Vector2(22,112),15,UI.INK,200)
	_add_item_icon(info_panel,item,Vector2(232,100),Vector2(206,140))
	var detail = ""
	for key in item.stats:
		var value = item.stats[key]
		match str(key):
			"armor": detail += "躯干防护  %d%%   " % roundi(float(value)*100)
			"helmet": detail += "头部防护  %d%%   " % roundi(float(value)*100)
			"helmet_vision":
				# ART-090: closed helms protect more but see less.
				detail += "视野  %d%%%s   " % [roundi(float(value)*100),"（开面）" if float(value)>=.85 else ("（窄眼缝）" if float(value)<.56 else "（面甲眼缝）")]
			"power": detail += "冲击修正  ×%.2f   " % value
			"reach": detail += "枪长  %d   " % value
			"durability": detail += "耐久  %d   " % value
			"speed": detail += "速度  ×%.2f   " % value
			"stability": detail += "鞍上稳定  ×%.2f   " % value
			"lance_handling": detail += "调枪速度  ×%.2f   " % value
			"shield_capacity": detail += "盾耐久  %d   " % value
			"shield_handling": detail += "换盾速度  ×%.2f   " % float(item.stats.get("shield_speed",value))
			"shield_protection": detail += "漏伤 %d%%   吸震 %d%%   " % [roundi(float(value.leak)*100),roundi(float(value.absorb)*100)]
			"armor_kg","helmet_kg","shield_kg","lance_kg","caparison_kg":
				detail += "重量  %.1f kg   " % value
			"caparison_renown":
				detail += "自由对战获胜额外声望  +%d   " % value
	if item.slot=="caparison":
		detail += "不提供防护"
	elif item.slot=="armor" or item.slot=="helmet":
		detail += "重量影响马匹负担和操控；防护以本件属性为准"
	var comparison = EquipmentComparison.summarize(GameState.items,GameState.profile.equipped,item)
	var overview = ScrollContainer.new()
	overview.name = "ComparisonScroll"
	overview.position = Vector2(22,281)
	overview.size = Vector2(416,108)
	overview.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	info_panel.add_child(overview)
	var comparison_rows = VBoxContainer.new()
	comparison_rows.add_theme_constant_override("separation",5)
	overview.add_child(comparison_rows)
	var comparison_title = UI.label(comparison_rows,"当前已装备" if comparison.same else "对比："+comparison.current_name,Vector2.ZERO,14,UI.MUTED,394)
	comparison_title.tooltip_text = comparison_title.text
	var comparison_queue = preload("res://scripts/ui/build_queue.gd").new()
	comparison_rows.add_child(comparison_queue)
	for line in comparison.lines:
		var line_text = str(line)
		comparison_queue.enqueue(func(): UI.label(comparison_rows,line_text,Vector2.ZERO,16,UI.INK,394))
	var scroll = ScrollContainer.new()
	scroll.name = "ProvenanceScroll"
	scroll.position = Vector2(22,281)
	scroll.size = Vector2(416,108)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	info_panel.add_child(scroll)
	scroll.visible = false
	var compare_button = UI.button(info_panel,"换装取舍",Rect2(22,242,200,31),func():
		overview.visible=true
		scroll.visible=false)
	compare_button.name = "CompareTab"
	var details_button = UI.button(info_panel,"详细数值与史料",Rect2(234,242,200,31),func():
		overview.visible=false
		scroll.visible=true)
	details_button.name = "DetailsTab"
	compare_button.toggle_mode=true
	details_button.toggle_mode=true
	var detail_tabs = ButtonGroup.new()
	compare_button.button_group=detail_tabs
	details_button.button_group=detail_tabs
	compare_button.button_pressed=true
	var paragraphs = VBoxContainer.new()
	paragraphs.add_theme_constant_override("separation",8)
	scroll.add_child(paragraphs)
	var paragraph_queue = preload("res://scripts/ui/build_queue.gd").new()
	paragraphs.add_child(paragraph_queue)
	for text_value in [detail,"腿甲花纹只作装饰，不增加防护值。" if item.slot=="armor" else "","制造地："+str(item.manufacture) if item.has("manufacture") else "",str(item.get("use_context","")),"考据："+str(item.source),str(item.historical_note)]:
		if str(text_value).is_empty():
			continue
		var paragraph_text = str(text_value)
		var paragraph_color = UI.GOLD if text_value==detail else UI.MUTED
		paragraph_queue.enqueue(func(): UI.label(paragraphs,paragraph_text,Vector2.ZERO,14,paragraph_color,394))
	if item.has("source_url"):
		var source_url = str(item.source_url)
		UI.button(info_panel,"查看馆藏来源 ↗",Rect2(22,397,202,30),func(): OS.shell_open(source_url))
	UI.label(info_panel,"数值为游戏平衡设定",Vector2(242,404),12,UI.MUTED,190)
	var owned = item.id in GameState.profile.owned
	var era_unlocked = int(GameState.profile.renown)>=Catalogue.required_renown(item)
	var equipped = GameState.profile.equipped.get(item.slot) == item.id
	var can_afford = int(GameState.profile.coins)>=int(item.price)
	var action_text = "购买 · %d 银币" % item.price
	if equipped:
		action_text = "已装备"
	elif owned:
		action_text = "装备"
	elif not era_unlocked:
		action_text = "需要 %d 声望" % Catalogue.required_renown(item)
	elif not can_afford:
		action_text = "还差 %d 银币" % (int(item.price)-int(GameState.profile.coins))
	var action = UI.button(info_panel,action_text,Rect2(22,441,412,44),func():
		if owned:
			if GameState.equip(item.id):
				show_armory()
				message_label.text="已装备 · "+str(item.name)
			else:
				message_label.text="装备未更换 · "+GameState.save_error
		else:
			var notice = GameState.purchase(item.id)
			show_armory()
			message_label.text = notice
			sounds.play("click",-12),true)
	action.disabled = equipped or (not owned and (not era_unlocked or not can_afford))

func show_settings() -> void:
	page = "settings"
	_clear_screen()
	_header("设置 · 让每一次交锋更适合你。")
	var panel = UI.panel(screen,Rect2(70,123,680,656))
	UI.label(panel,"游戏设置",Vector2(28,24),34,UI.GOLD)
	UI.check(panel,"显示血腥表现",GameState.profile.settings.blood,Vector2(28,104),func(value):_change_setting("blood",value))
	UI.label(panel,"关闭只隐藏血迹与伤口；实战依然允许死亡。",Vector2(28,150),16,UI.MUTED)
	UI.check(panel,"镜头震动",GameState.profile.settings.shake,Vector2(28,195),func(value):_change_setting("shake",value))
	UI.check(panel,"声音总开关",GameState.profile.settings.sound,Vector2(28,250),func(value):_change_setting("sound",value))
	UI.check(panel,"纯鼠标姿态控制",GameState.profile.settings.mouse_only,Vector2(28,305),func(value):_change_setting("mouse_only",value))
	UI.label(panel,"滚轮前后调倾身，中键回正；鼠标瞄准，左键加速。",Vector2(28,353),16,UI.MUTED,620)
	UI.label(panel,"自由对战难度",Vector2(28,406),19,UI.INK)
	UI.label(panel,"不改变关卡对手",Vector2(478,411),14,UI.MUTED,160)
	var difficulty = OptionButton.new()
	difficulty.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	difficulty.position = Vector2(183,398)
	difficulty.size = Vector2(280,45)
	for value in preload("res://scripts/core/opponent_ai.gd").NAMES:
		difficulty.add_item(value)
	difficulty.selected = int(GameState.profile.settings.difficulty)
	difficulty.item_selected.connect(func(value):_change_setting("difficulty",value))
	panel.add_child(difficulty)
	UI.check(panel,"垂直同步 · 撕裂时开启",bool(GameState.profile.settings.get("vsync",false)),Vector2(28,452),func(value):_change_setting("vsync",value))
	UI.label(panel,"关闭可减少显示等待；游戏仍限制为最高 60 帧。",Vector2(28,499),15,UI.MUTED,620)
	settings_notice = UI.label(panel,"修改后自动保存",Vector2(28,538),15,UI.MUTED,620)
	UI.button(panel,"返回营地",Rect2(28,581,620,49),show_home,true)
	UI.panel(screen,Rect2(810,123,565,596),Color(.055,.10,.08,.95))
	UI.label(screen,"操作",Vector2(844,150),32,UI.GOLD)
	UI.button(screen,"音量与材质试听",Rect2(1105,150,235,45),show_sound_settings)
	var posture_controls = "滚轮上下　倾身；中键回正" if bool(GameState.profile.settings.mouse_only) else "W / S　　 前倾支撑 / 后仰避头"
	UI.label(screen,"移动鼠标　瞄准；大幅改向会失稳\n左键 / 空格　按住催马，松开减速\n1 / 2 / 3　护头 / 护胸 / 护腹（右键循环）\n"+posture_controls+"\nH　　　　 对局判定；结算详情\nEsc　　　 暂停；结算后返回营地\nR 重开　　F11 全屏",Vector2(844,219),22,UI.INK,510)
	UI.label(screen,"触控输入已预留：左侧滑动倾身，右侧瞄准，\n右侧额外触点加速；尚未在手机设备验收。",Vector2(844,468),17,UI.MUTED,510)
	# ART-090: closed helmets narrow the view during the charge.
	UI.check(screen,"闭面头盔遮挡视野（眼缝效果）",bool(GameState.profile.settings.get("helmet_view",true)),Vector2(844,544),func(value):_change_setting("helmet_view",value))
	UI.check(screen,"接近时放缓与命中慢动作",GameState.profile.settings.slow_motion,Vector2(844,600),func(value):_change_setting("slow_motion",value))
	UI.check(screen,"显示枪线颜色与部位提示",GameState.profile.settings.aim_cues,Vector2(844,656),func(value):_change_setting("aim_cues",value))
	queue_redraw()

func show_sound_settings() -> void:
	page = "sound_settings"
	_clear_screen()
	_header("声音 · 音乐、蹄声与撞击，各有位置。")
	var panel = UI.panel(screen,Rect2(70,123,680,656))
	UI.label(panel,"声音设置",Vector2(28,24),34,UI.GOLD)
	UI.check(panel,"声音总开关",GameState.profile.settings.sound,Vector2(28,91),func(value):
		_change_setting("sound",value)
		if is_instance_valid(audio_preview_notice):
			audio_preview_notice.text = "声音已开启，可点击下方按钮试听。" if value else "声音已关闭；下方试听不会发声。")
	var rows = [["master_volume","总音量"],["music_volume","营地音乐"],["effects_volume","撞击、马蹄与操作"],["ambience_volume","冲锋风声"]]
	for i in range(rows.size()):
		var key: String = rows[i][0]
		var y = 159.0+i*85.0
		UI.label(panel,rows[i][1],Vector2(28,y),21,UI.INK)
		var value_label = UI.label(panel,"%d%%" % roundi(AudioMix.volume(GameState.profile.settings,key)*100),Vector2(550,y),21,UI.GOLD,88)
		var slider = HSlider.new()
		slider.name = key
		slider.position = Vector2(32,y+33)
		slider.size = Vector2(593,30)
		slider.min_value = 0; slider.max_value = 100; slider.step = 5
		slider.value = AudioMix.volume(GameState.profile.settings,key)*100
		slider.tooltip_text = rows[i][1]+"：左右方向键每次调整 5%，0 为静音。"
		slider.value_changed.connect(func(value):
			value_label.text = "%d%%" % roundi(value)
			_preview_audio_volume(key,float(value)/100.0))
		panel.add_child(slider)
	settings_notice = UI.label(panel,"调整立即生效，停手后自动保存。",Vector2(28,522),17,UI.MUTED,620)
	UI.button(panel,"返回设置",Rect2(28,581,302,49),show_settings,true)
	UI.button(panel,"返回营地",Rect2(348,581,302,49),show_home)
	var samples = UI.panel(screen,Rect2(810,123,565,656),Color(.055,.10,.08,.95))
	UI.label(samples,"听清这一次接触",Vector2(28,24),30,UI.GOLD)
	UI.label(samples,"以下为相同冲速下的实击示例。\n实际交锋还会随擦碰、断枪与来势变化。",Vector2(28,86),21,UI.INK,510)
	audio_preview_notice = UI.label(samples,"点击材质试听；使用当前音量。" if AudioMix.effects_audible(GameState.profile.settings) else "音效已静音；先开启声音并调高总音量和音效。",Vector2(28,174),18,UI.MUTED,510)
	UI.button(samples,"试听 · 钢制头盔",Rect2(28,270,510,57),func():_preview_material("head","钢制头盔"))
	UI.button(samples,"试听 · 板甲胸甲",Rect2(28,343,510,57),func():_preview_material("body","板甲胸甲"))
	UI.button(samples,"试听 · 木芯盾牌",Rect2(28,416,510,57),func():_preview_material("shield","木芯盾牌"))
	UI.label(samples,"想突出蹄声与碰撞，可以降低音乐和风声。\n0% 会完全静音；设置会保留在当前存档中。",Vector2(28,520),20,UI.MUTED,510)
	queue_redraw()

func _preview_audio_volume(key: String, value: float) -> void:
	if key not in AudioMix.VOLUMES: return
	GameState.profile.settings[key] = clampf(value,0.0,1.0)
	AudioMix.apply(GameState.profile.settings)
	audio_save_pending = true
	audio_save_timer.start(.3)
	if is_instance_valid(settings_notice): settings_notice.text = "正在调整；停手后自动保存。"

func _flush_audio_settings() -> void:
	if not audio_save_pending: return
	audio_save_pending = false
	if is_instance_valid(audio_save_timer): audio_save_timer.stop()
	GameState.save_profile()
	GameState.profile_changed.emit()
	_settings_save_notice()

func _apply_audio_settings() -> void:
	AudioMix.apply(GameState.profile.settings)
	if is_instance_valid(sounds): sounds.set_enabled(GameState.profile.settings.sound)

func _preview_material(zone: String, title: String) -> void:
	if not AudioMix.effects_audible(GameState.profile.settings):
		audio_preview_notice.text = "音效已静音；先开启声音并调高总音量和音效。"
		return
	if Time.get_ticks_msec()<audio_preview_until: return
	audio_preview_until = Time.get_ticks_msec()+650
	var cue = sounds.impact_cue({"type":"hit","zone":zone,"impulse":60.0,"speed":800.0,"glanced":false},{"helmet_material":"steel","armor_material":"plate","shield_material":"wood"})
	for limited in sounds.limit_contact_group([cue]): sounds.play(limited.cue,limited.db,limited.pitch)
	audio_preview_notice.text = "试听示例："+title+" · 实击。"

func _change_setting(key: String, value: Variant) -> void:
	GameState.set_setting(key,value)
	if key=="vsync": _apply_display_settings()
	if key=="sound": _apply_audio_settings()
	_settings_save_notice()

func _settings_save_notice() -> void:
	if page in ["settings","sound_settings"] and is_instance_valid(settings_notice):
		var saved = GameState.save_error.is_empty()
		settings_notice.text = "已保存设置" if saved else "设置已应用，但暂未保存；可回营地重试保存。"
		settings_notice.add_theme_color_override("font_color",UI.MUTED if saved else Color("efb566"))
		settings_notice.tooltip_text = GameState.save_error

func _apply_display_settings() -> void:
	# Keep the independent 60 FPS cap in WindowActivity. On this Windows/GL
	# setup swap synchronization stalled isolated rendering far below budget.
	# Players can restore sync if tearing is visible; no quality or RAM change.
	if DisplayServer.get_name()=="headless": return
	var requested = DisplayServer.VSYNC_ENABLED if bool(GameState.profile.settings.get("vsync",false)) else DisplayServer.VSYNC_DISABLED
	if DisplayServer.window_get_vsync_mode()!=requested:
		DisplayServer.window_set_vsync_mode(requested)

func show_history() -> void:
	page = "history"
	_clear_screen()
	_header("历史手记 · 器物有来处，改编有说明。")
	UI.label(screen,"枪尖之外的历史",Vector2(56,107),37,UI.INK)
	UI.button(screen,"返回营地",Rect2(1210,101,175,48),show_home)
	var entries = [
		["四地区，早期共通", "12 世纪至 13 世纪早期，英、法、德、意骑手装备并不截然不同。本作先保留结构共性，再扩充地区与个人装饰。", "Met · Fashion 1000–1300", "https://www.metmuseum.org/essays/fashion-in-european-armor-1000-1300"],
		["比武也可能用尖头枪", "冠状多齿头与尖头枪头有各自赛事语境。名字中含“war”的比武并不自动等于真实战场杀敌。", "Met · Four Lance Heads", "https://www.metmuseum.org/art/collection/search/35791"],
		["钢铁并不等于僵硬", "合身战场甲与专用比武甲需要分别理解。后者可能集中保护来枪方向，前者还要兼顾多方向威胁与活动。", "Wallace · Armour A23", "https://wallacelive.wallacecollection.org/eMP/eMuseumPlus?module=collection&objectId=60514&service=ExternalInterface"],
		["马匹不只比巨大", "英格兰考古研究提醒：中世纪马匹的体格、性情、训练与用途要结合看待，不能把现代巨型挽马作为唯一模板。", "University of Exeter", "https://news-archive.exeter.ac.uk/2022/january/articles/medievalwarhorsesweresurp.html"],
		["装饰有结构和年代", "盾徽、头饰、绘画、蚀刻和镀金丰富了骑士形象。收藏可以跨时代，拼装却不应被宣传成同代原装复原。", "Met · Decoration of Armor", "https://www.metmuseum.org/essays/the-decoration-of-european-armor"],
		["我们的规则与历史边界", "竞技场非致死、先计分；实战允许致命伤。固定分道、最多三轮与平分决胜方式都是游戏改编，史实不存在统一的全欧洲计分或断枪率。", "项目考据档案 · 规则与器物分别说明", ""]]
	for i in range(entries.size()):
		var entry = entries[i]
		var card = UI.panel(screen,Rect2(56+(i%3)*449,180+(i/3)*271,430,250))
		UI.label(card,entry[0],Vector2(20,17),23,UI.GOLD)
		UI.label(card,entry[1],Vector2(20,66),17,UI.INK,389)
		UI.label(card,entry[2],Vector2(20,190),13,UI.MUTED,389)
		if not str(entry[3]).is_empty():
			var url = str(entry[3])
			UI.button(card,"查阅来源 ↗",Rect2(255,207,150,31),func():OS.shell_open(url))
	UI.label(screen,"这里是历史启发的游戏，装备数值与奖励属于设计；史料与改编说明见军械库详情。",Vector2(56,750),16,UI.MUTED)
	queue_redraw()

func show_help(credits: bool = false) -> void:
	page = "help"
	_clear_screen()
	_header("玩法与制作说明 · 清楚规则，也保留器物的来处。")
	var license_path = ""
	if not OS.has_feature("editor"):
		license_path = OS.get_executable_path().get_base_dir().get_base_dir().path_join("licenses")
	preload("res://scripts/ui/help_pages.gd").build(screen,credits,func():show_help(false),func():show_help(true),show_home,license_path)
	queue_redraw()

func _draw() -> void:
	if page == "battle":
		return
	draw_texture_rect(BACKGROUND,Rect2(0,0,1440,810),false,Color(.57,.62,.55))
	for i in range(18):
		var alpha = .62 * (1.0-float(i)/18)
		draw_rect(Rect2(i*80,0,80,810),Color(.025,.055,.041,alpha))
	draw_rect(Rect2(0,0,1440,86),Color(.035,.07,.05,.92))
	draw_rect(Rect2(0,786,1440,24),Color(.03,.055,.04,.7))

func _unhandled_input(event: InputEvent) -> void:
	if result_visible and is_instance_valid(result_details) and event is InputEventKey and event.pressed and not event.echo and KEY_H in [event.keycode,event.physical_keycode]:
		result_debug = not result_debug
		if result_debug and result_details.text.is_empty(): result_details.text=result_detail_text
		result_detail_scroll.visible = result_debug
		result_rewards.text = result_rewards.get_meta("debug_text" if result_debug else "normal_text")
		result_progress.text = result_progress.get_meta("debug_text" if result_debug else "normal_text")
		result_timeline.visible = not result_debug
		if not result_debug: result_timeline.queue_redraw()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var keys = [event.keycode,event.physical_keycode]
		if KEY_ESCAPE in keys and page != "battle":
			if is_instance_valid(brief_overlay):
				_dismiss_brief()
			else:
				show_home()
		elif KEY_R in keys and page == "battle" and result_visible:
			_start_match(current_mode,practice_match,active_guide)

func _run_smoke() -> void:
	if Time.get_ticks_msec()-smoke_last_report>5000:
		smoke_last_report = Time.get_ticks_msec()
		print("SMOKE_PROGRESS elapsed=",Time.get_ticks_msec()-smoke_started," step=",smoke_step," busy=",smoke_busy," phase=",battle.match_model.phase if battle else page," pass=",battle.match_model.pass_number if battle else 0," scale=",Engine.time_scale," fps=",Engine.get_frames_per_second())
	if smoke_busy:
		return
	smoke_busy = true
	var elapsed = Time.get_ticks_msec() - smoke_started
	if battle and not battle.effects.bursts.is_empty() and current_mode not in smoke_contacts:
		smoke_contacts.append(current_mode)
		await _capture("08_arena_impact" if current_mode=="arena" else "09_war_impact")
	if smoke_step == 0 and elapsed > 1000:
		await _capture("01_home")
		smoke_step = 1
	elif smoke_step == 1 and elapsed > 2100:
		show_armory()
		smoke_step = 2
	elif smoke_step == 2 and elapsed > 3100:
		await _capture("02_armory")
		show_history()
		smoke_step = 3
	elif smoke_step == 3 and elapsed > 4200:
		await _capture("03_history")
		_start_match("arena")
		smoke_step = 4
	elif smoke_step == 4 and battle and battle.match_model.phase == "charge" and battle.match_model.fighters[0].x > -330:
		await _capture("04_arena")
		smoke_step = 5
	elif smoke_step == 5 and result_visible:
		await _capture("05_result")
		smoke_step = 6
		get_tree().create_timer(1.0).timeout.connect(func():_start_match("war"))
	elif smoke_step == 6 and current_mode == "war" and battle and battle.match_model.phase == "charge" and absf(float(battle.match_model.fighters[0].x)-float(battle.match_model.fighters[1].x))<750:
		await _capture("06_war")
		smoke_step = 7
	elif smoke_step == 7 and current_mode == "war" and result_visible:
		await _capture("07_war_result")
		smoke_step = 8
		GameState.profile = smoke_original_profile
		GameState.save_profile()
		print("SMOKE_TEST_COMPLETE: " + str(smoke_screens))
		get_tree().create_timer(1.0).timeout.connect(_shutdown_and_quit)
	if elapsed > 180000:
		GameState.profile = smoke_original_profile
		GameState.save_profile()
		push_error("Smoke test timed out at step " + str(smoke_step))
		get_tree().quit(1)
	smoke_busy = false

func _capture(name_value: String) -> void:
	if screenshot_dir.is_empty():
		return
	var directory_error = DirAccess.make_dir_recursive_absolute(screenshot_dir)
	if directory_error != OK:
		push_error("Cannot create smoke capture directory: " + screenshot_dir)
		get_tree().quit(2)
		return
	await RenderingServer.frame_post_draw
	var image = get_viewport().get_texture().get_image()
	var path = screenshot_dir.path_join(name_value + ".png")
	var error = image.save_png(path)
	print("SCREENSHOT: " + path + " " + str(error))
	if error != OK:
		push_error("Smoke capture failed: " + path)
		get_tree().quit(2)
		return
	smoke_screens.append(name_value)
