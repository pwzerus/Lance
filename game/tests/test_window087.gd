extends "test_ui082.gd"
## Real isolated Windows render-window transitions, not OS keyboard/mouse input.
var windows=[]

func wall_wait(seconds:float)->void:
	var end=Time.get_ticks_msec()+int(seconds*1000)
	while Time.get_ticks_msec()<end:await process_frame

func key(code:Key)->void:
	var event=InputEventKey.new();event.keycode=code;event.physical_keycode=code;event.pressed=true
	Input.parse_input_event(event)
	event=event.duplicate();event.pressed=false;Input.parse_input_event(event)

func observe(tag:String,expected_mode:int)->void:
	await wall_wait(1.25)
	check(DisplayServer.window_get_mode()==expected_mode,"Window mode did not apply: "+tag)
	check(DisplayServer.window_can_draw(),"Window cannot render: "+tag)
	var before=Engine.get_frames_drawn()
	await wall_wait(.3)
	check(Engine.get_frames_drawn()>before,"Visible window stopped presenting: "+tag)
	await RenderingServer.frame_post_draw
	var texture_reported_size=root.get_texture().get_size()
	var picture=root.get_texture().get_image()
	var colors={}
	for y in range(3,30):
		for x in range(3,30):colors[picture.get_pixel(picture.get_width()*x/32,picture.get_height()*y/32).to_rgba32()]=true
	check(colors.size()>35,"Output appears blank: "+tag)
	check(picture.save_png(folder+"/"+tag+".png")==OK,"Cannot save render evidence: "+tag)
	windows.append({"tag":tag,"mode":DisplayServer.window_get_mode(),"window_size":str(DisplayServer.window_get_size()),"root_size":str(root.size),"content_scale_size":str(root.content_scale_size),"content_scale_factor":root.content_scale_factor,"viewport_rect":str(root.get_visible_rect()),"texture_reported_size":str(texture_reported_size),"image_size":str(picture.get_size()),"sampled_colors":colors.size(),"page":main.page,"paused":main.battle.paused if is_instance_valid(main.battle) else false})

func run()->void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--folder="):folder=arg.trim_prefix("--folder=")
	state=root.get_node("GameState")
	if folder.is_empty() or DirAccess.dir_exists_absolute(folder) or not state.save_path.contains("qa_") or OS.get_environment("GALUMU_MEMORY_BOUND")!="1024" or DisplayServer.get_name()=="headless":quit(2);return
	DirAccess.make_dir_recursive_absolute(folder)
	state.save_path=folder+"/qa_profile.json";state.backup_path=folder+"/qa_backup.json";state.load_profile()
	AudioServer.set_bus_mute(0,true)
	root.size=Vector2i(960,540)
	main=load("res://scenes/main.tscn").instantiate();root.add_child(main);current_scene=main
	await observe("01_minimum",DisplayServer.WINDOW_MODE_WINDOWED)
	key(KEY_F11);await observe("02_fullscreen",DisplayServer.WINDOW_MODE_FULLSCREEN)
	key(KEY_F11);await observe("03_returned",DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED)
	await observe("04_maximized",DisplayServer.WINDOW_MODE_MAXIMIZED)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED);root.size=Vector2i(1024,768)
	main.show_settings();await observe("05_square_settings",DisplayServer.WINDOW_MODE_WINDOWED)
	main._start_match("arena",true)
	main.battle.autoplay=true
	await wall_wait(3)
	key(KEY_ESCAPE);await wall_wait(.2)
	check(main.battle.paused,"Pause key did not pause actual battle")
	var position=float(main.battle.match_model.fighters[0].x)
	key(KEY_F11);await observe("06_paused_fullscreen",DisplayServer.WINDOW_MODE_FULLSCREEN)
	check(main.battle.paused and is_equal_approx(position,float(main.battle.match_model.fighters[0].x)),"Fullscreen changed a paused simulation")
	key(KEY_F11);await observe("07_paused_return",DisplayServer.WINDOW_MODE_WINDOWED)
	key(KEY_ESCAPE);await wall_wait(.3)
	check(not main.battle.paused,"Resume key stopped working after changing mode")
	await wall_wait(4)
	check(float(main.battle.match_model.fighters[0].x)>position,"Battle did not advance after explicit resume")
	await observe("08_playing",DisplayServer.WINDOW_MODE_WINDOWED)
	main._close_battle();main.show_home();await wall_wait(.3)
	check(not paused and AudioServer.bus_count==5,"Window transitions leaked pause or sound buses")
	check(state.profile.matches==0,"Practice window test changed player results")
	FileAccess.open(folder+"/report.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"failures":failures,"windows":windows,"version":ProjectSettings.get_setting("application/config/version"),"scope":"Actual protected package, eight isolated render-window states, F11/Escape through Input.parse_input_event, engine maximize/resize, actual paused/resumed practice. No OS input, desktop switch, multi-monitor or multi-DPI certification."},"\t"))
	print("WINDOW087 ",failures)
	main.notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
