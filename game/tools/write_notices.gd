extends SceneTree

func _initialize() -> void:
	var destination = "E:/GALUMU/builds/LanceAndLaurel/THIRD_PARTY_NOTICES.txt"
	var args = OS.get_cmdline_user_args()
	if args.size()>0:
		destination = args[0]
	var file = FileAccess.open(destination,FileAccess.WRITE)
	if file == null:
		push_error("Cannot write notices: "+destination)
		quit(1)
		return
	file.store_string("Lance & Laurel — third-party notices\n\nGodot Engine 4.5.1\nhttps://godotengine.org/license/\n\n")
	file.store_string(Engine.get_license_text()+"\n\n")
	file.store_string("ENGINE COMPONENT COPYRIGHT INFORMATION\n\n")
	for component in Engine.get_copyright_info():
		file.store_string(str(component.name)+"\n")
		for part in component.parts:
			file.store_string("License: "+str(part.license)+"\n")
			for notice in part.copyright:
				file.store_string(str(notice)+"\n")
		file.store_string("\n")
	var licenses = Engine.get_license_info()
	var names = licenses.keys()
	names.sort()
	for name_value in names:
		file.store_string("\nLICENSE: "+str(name_value)+"\n\n"+str(licenses[name_value])+"\n")
	file.store_string("\nFONT: Noto Sans SC — SIL Open Font License 1.1\nThe full font license accompanies this build as FONT_OFL.txt.\nhttps://github.com/google/fonts/tree/main/ofl/notosanssc\n")
	file.close()
	print("NOTICES_WRITTEN "+destination)
	quit()
