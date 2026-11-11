extends SceneTree
## Format conversion of the existing project SVG, no alteration to its design.
func _initialize() -> void:
	var target=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):target=arg.trim_prefix("--output=")
	if target.is_empty() or FileAccess.file_exists(target):quit(2);return
	var sizes=[16,24,32,48,64,128,256]
	var data=PackedByteArray();data.resize(6+16*sizes.size())
	data.encode_u16(0,0);data.encode_u16(2,1);data.encode_u16(4,sizes.size())
	var svg=FileAccess.get_file_as_string("res://assets/icon.svg")
	for i in range(sizes.size()):
		var size=int(sizes[i]);var image=Image.new()
		if image.load_svg_from_string(svg,float(size)/128.0)!=OK:quit(1);return
		var png=image.save_png_to_buffer()
		var offset=6+16*i
		data[offset]=size if size<256 else 0;data[offset+1]=data[offset]
		data.encode_u16(offset+4,1);data.encode_u16(offset+6,32)
		data.encode_u32(offset+8,png.size());data.encode_u32(offset+12,data.size())
		data.append_array(png)
	DirAccess.make_dir_recursive_absolute(target.get_base_dir())
	var file=FileAccess.open(target,FileAccess.WRITE)
	if not file:quit(1);return
	file.store_buffer(data);file.close()
	print("ICON087 ",target," sizes=",sizes," bytes=",data.size())
	quit()
