extends SceneTree
## ART-090 battle sprite baker. Runs headless through Start-MemoryBound.
##
## Diagnosis: the 48 historical armour/helmet plates are ~1250 px sources, but
## in a match the torso covers only ~45-150 screen px and the project samples
## canvas textures NEAREST. Each frame therefore picked scattered source pixels:
## mail, belts, etching and surcoat colours read as speckle. This tool bakes a
## proper battle-size pixel sprite once: box-filtered downscale, a little
## clarity and saturation, a reduced palette and an inner edge line.
##
## Armours that show cloth (surcoats, jupons, cloth-covered plates) also get a
## cloth mask; every arms design is baked onto that cloth (field over the whole
## garment, charge across it, folds kept from the original luminance), so the
## rider's surcoat bears the same arms as shield and caparison. Plate armours
## keep their own decoration, now readable.
##
## --out=<new absolute dir> [--install]
const Heraldry = preload("res://scripts/visual/heraldry.gd")
const MANIFEST = "res://data/equipment_art_v051.json"
const FIT = "res://data/equipment_fit_v052.json"
const INSTALL_DIR = "res://assets/art/battle090"
const TEXELS_PER_UNIT = 1.25
const TORSO_UNITS = Vector2(94,104)
const PALETTE = 28
# Armours whose plates show cloth. "white": a white/undyed cloth panel also
# counts (low saturation, high value). "skip_top": ignore the top fraction
# (mail coif/collar) when classifying.
# "gold": yellow/gilt embroidery or yellow cloth is part of the garment (the
# English jupon's old royal charges; the French yellow velvet brigandine).
# art090-bake01 review: fr_armor_2 is leather, not cloth, so it keeps its look.
const CLOTH = {
	# Cream wool sits in the gold hue band; bake02 left cream patches.
	"eng_armor_1":{"white":true,"white_v":.50,"gold":true},
	"eng_armor_2":{"gold":true},
	"eng_armor_3":{},
	"fr_armor_1":{"white":true},
	"fr_armor_3":{"gold":true},
	"de_armor_1":{"white":true},
	"it_armor_1":{"white":true},
	"it_armor_2":{}}

var out_dir = ""
var install = false
## FEEL-093: dress only some arms (comma list); default all.
var only_designs: PackedStringArray = []

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="): out_dir = arg.trim_prefix("--out=")
		if arg=="--install": install = true
		if arg.begins_with("--designs="): only_designs = arg.trim_prefix("--designs=").split(",")
	if out_dir.is_empty() or OS.get_environment("GALUMU_MEMORY_BOUND")!="1024" or DirAccess.dir_exists_absolute(out_dir):
		printerr("BATTLE090 usage: --out=<new dir> [--install], via Start-MemoryBound")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(out_dir)
	var manifest = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	var fit = JSON.parse_string(FileAccess.get_file_as_string(FIT))
	if not manifest is Dictionary or not fit is Dictionary:
		quit(1)
		return
	var armor_rows: Array[Image] = []
	var helmet_cells: Array[Image] = []
	var ids = manifest.keys()
	ids.sort()
	for id in ids:
		var entry: Dictionary = manifest[id]
		var source = _source(entry)
		if source==null:
			printerr("BATTLE090 cannot load ",id)
			continue
		if str(id).contains("_armor_"):
			var size = Vector2i(roundi(TORSO_UNITS.x*TEXELS_PER_UNIT),roundi(TORSO_UNITS.y*TEXELS_PER_UNIT))
			var sprite = bake(source,size)
			_save(sprite,"armor/%s.png" % id)
			var row: Array[Image] = [_zoom(_flat(source,size),3),_zoom(sprite,3)]
			if CLOTH.has(id):
				var mask = cloth_mask(sprite,CLOTH[id])
				row.append(_zoom(_mask_view(sprite,mask),3))
				for design in Heraldry.ARMS:
					if not only_designs.is_empty() and design not in only_designs:
						continue
					var dressed = dress(sprite,mask,design,1)
					_save(dressed,"armor/%s__%s.png" % [id,design])
					# FEEL-093: every asymmetric design gets a mirrored variant.
					if design in Heraldry.ASYMMETRIC:
						_save(dress(sprite,mask,design,-1),"armor/%s__%s_l.png" % [id,design])
					row.append(_zoom(dressed,3))
			armor_rows.append(_row(row))
		elif str(id).contains("_helmet_"):
			var box: Array = fit.get(id,{}).get("size",[62,72])
			var size = Vector2i(roundi(float(box[0])*TEXELS_PER_UNIT),roundi(float(box[1])*TEXELS_PER_UNIT))
			var sprite = bake(source,size)
			_save(sprite,"helmet/%s.png" % id)
			helmet_cells.append(_row([_zoom(_flat(source,size),3),_zoom(sprite,3)]))
		print("BATTLE090 baked ",id)
	_stack(armor_rows).save_png(out_dir.path_join("armor_sheet.png"))
	_stack(helmet_cells).save_png(out_dir.path_join("helmet_sheet.png"))
	print("BATTLE090 done")
	quit(0)

func _source(entry: Dictionary) -> Image:
	var path = str(entry.get("image_path",""))
	var image = Image.load_from_file(ProjectSettings.globalize_path(path))
	if image==null or image.is_empty():
		return null
	image.convert(Image.FORMAT_RGBA8)
	var original: Array = entry.get("source_size",[image.get_width(),image.get_height()])
	var region: Array = entry.get("source_region",[0,0,image.get_width(),image.get_height()])
	var ratio = Vector2(image.get_width()/float(original[0]),image.get_height()/float(original[1]))
	return image.get_region(Rect2i(roundi(float(region[0])*ratio.x),roundi(float(region[1])*ratio.y),roundi(float(region[2])*ratio.x),roundi(float(region[3])*ratio.y)))

# ------------------------------------------------------------------ baking

static func _flat(source: Image, size: Vector2i) -> Image:
	# What the game drew before: nearest sampling straight from the source.
	var image = source.duplicate()
	image.resize(size.x,size.y,Image.INTERPOLATE_NEAREST)
	return image

static func downscale(source: Image, size: Vector2i) -> Image:
	# Halve with a box filter until within 2x, then Lanczos to the target.
	# Colour is premultiplied first so transparent black does not bleed in.
	var image = source.duplicate()
	var data = image.get_data()
	for i in range(0,data.size(),4):
		var a = data[i+3]/255.0
		data[i] = int(data[i]*a)
		data[i+1] = int(data[i+1]*a)
		data[i+2] = int(data[i+2]*a)
	image.set_data(image.get_width(),image.get_height(),false,Image.FORMAT_RGBA8,data)
	while image.get_width()>size.x*2 and image.get_height()>size.y*2:
		image.resize(image.get_width()/2,image.get_height()/2,Image.INTERPOLATE_BILINEAR)
	image.resize(size.x,size.y,Image.INTERPOLATE_LANCZOS)
	data = image.get_data()
	for i in range(0,data.size(),4):
		var a = data[i+3]/255.0
		if a>.01:
			data[i] = clampi(int(data[i]/a),0,255)
			data[i+1] = clampi(int(data[i+1]/a),0,255)
			data[i+2] = clampi(int(data[i+2]/a),0,255)
		data[i+3] = 255 if a>=.5 else 0
	image.set_data(size.x,size.y,false,Image.FORMAT_RGBA8,data)
	return image

static func bake(source: Image, size: Vector2i) -> Image:
	var image = downscale(source,size)
	# Clarity: unsharp mask against a one-texel blur, then gentle saturation.
	var blur = image.duplicate()
	blur.resize(maxi(2,size.x/2),maxi(2,size.y/2),Image.INTERPOLATE_BILINEAR)
	blur.resize(size.x,size.y,Image.INTERPOLATE_BILINEAR)
	var w = size.x
	var h = size.y
	var colors: Array[Color] = []
	var opaque: Array[int] = []
	for y in range(h):
		for x in range(w):
			var c = image.get_pixel(x,y)
			if c.a<.5:
				continue
			var b = blur.get_pixel(x,y)
			var sharp = Color(c.r+.55*(c.r-b.r),c.g+.55*(c.g-b.g),c.b+.55*(c.b-b.b),1).clamp()
			sharp = Color.from_hsv(sharp.h,clampf(sharp.s*1.12,0,1),clampf((sharp.v-.5)*1.08+.5,0,1))
			image.set_pixel(x,y,sharp)
			colors.append(sharp)
			opaque.append(y*w+x)
	# Palette reduction (k-means in RGB) gives clean pixel-art colour areas.
	var palette = kmeans(colors,PALETTE)
	for k in range(opaque.size()):
		var i = opaque[k]
		image.set_pixel(i%w,i/w,nearest(palette,colors[k]))
	# Inner edge line: opaque texels touching transparency are darkened, so the
	# piece separates from the horse and the other layers at any zoom.
	var edge = image.duplicate()
	for y in range(h):
		for x in range(w):
			var c = edge.get_pixel(x,y)
			if c.a<.5:
				continue
			var touches = false
			for d in [Vector2i(1,0),Vector2i(-1,0),Vector2i(0,1),Vector2i(0,-1)]:
				var p = Vector2i(x,y)+d
				if p.x<0 or p.y<0 or p.x>=w or p.y>=h or edge.get_pixel(p.x,p.y).a<.5:
					touches = true
			if touches:
				image.set_pixel(x,y,c.darkened(.55))
	return image

static func kmeans(colors: Array[Color], k: int) -> Array[Color]:
	var centers: Array[Color] = []
	if colors.is_empty():
		return centers
	# Deterministic seeds spread over the luminance-sorted colours.
	var sorted = colors.duplicate()
	sorted.sort_custom(func(a,b): return a.get_luminance()<b.get_luminance())
	for i in range(k):
		centers.append(sorted[int((i+.5)*sorted.size()/k)])
	# Fit on every 3rd colour (enough for the palette, ~3x faster under the
	# protector's CPU quota); every texel is still mapped afterwards.
	for _iteration in range(6):
		var sums: Array[Vector3] = []
		var counts: Array[int] = []
		sums.resize(k)
		counts.resize(k)
		for i in range(k):
			sums[i] = Vector3.ZERO
			counts[i] = 0
		for n in range(0,colors.size(),3):
			var c = colors[n]
			var j = nearest_index(centers,c)
			sums[j] += Vector3(c.r,c.g,c.b)
			counts[j] += 1
		for i in range(k):
			if counts[i]>0:
				var m = sums[i]/counts[i]
				centers[i] = Color(m.x,m.y,m.z)
	return centers

static func nearest_index(palette: Array[Color], c: Color) -> int:
	var best = 0
	var best_d = INF
	for i in range(palette.size()):
		var p = palette[i]
		var d = (p.r-c.r)*(p.r-c.r)*.30+(p.g-c.g)*(p.g-c.g)*.59+(p.b-c.b)*(p.b-c.b)*.11
		if d<best_d:
			best_d = d
			best = i
	return best

static func nearest(palette: Array[Color], c: Color) -> Color:
	return palette[nearest_index(palette,c)]

# ------------------------------------------------------------------ cloth

static func cloth_mask(sprite: Image, config: Dictionary) -> PackedByteArray:
	var w = sprite.get_width()
	var h = sprite.get_height()
	var mask = PackedByteArray()
	mask.resize(w*h)
	for y in range(h):
		for x in range(w):
			var c = sprite.get_pixel(x,y)
			if c.a<.5:
				continue
			var hue = c.h*360.0
			var gold = hue>=34.0 and hue<=62.0 and c.s>.35 and c.v>.50
			var leather = hue>=12.0 and hue<=42.0 and c.v<.66 and c.s>.25
			if bool(config.get("gold",false)):
				gold = false
			var dyed = c.s>=.34 and c.v>=.16 and not gold and not leather
			var white = bool(config.get("white",false)) and c.s<.26 and c.v>float(config.get("white_v",.70))
			if dyed or white:
				mask[y*w+x] = 1
	# 3x3 majority keeps garment areas and drops isolated rivets/highlights.
	var clean = mask.duplicate()
	for y in range(1,h-1):
		for x in range(1,w-1):
			var n = 0
			for dy in range(-1,2):
				for dx in range(-1,2):
					n += mask[(y+dy)*w+x+dx]
			clean[y*w+x] = 1 if n>=5 else 0
	return clean

static func dress(sprite: Image, mask: PackedByteArray, design: String, facing: int) -> Image:
	var w = sprite.get_width()
	var h = sprite.get_height()
	var bounds = Rect2i(w,h,0,0)
	var lum_sum = 0.0
	var count = 0
	var min_p = Vector2i(w,h)
	var max_p = Vector2i(-1,-1)
	for y in range(h):
		for x in range(w):
			if mask[y*w+x]==1:
				min_p = Vector2i(mini(min_p.x,x),mini(min_p.y,y))
				max_p = Vector2i(maxi(max_p.x,x),maxi(max_p.y,y))
				lum_sum += sprite.get_pixel(x,y).get_luminance()
				count += 1
	var image = sprite.duplicate()
	if count<12:
		return image
	var mean = lum_sum/count
	var box = Rect2(Vector2(min_p),Vector2(max_p-min_p+Vector2i.ONE))
	var field = Heraldry.field_color(design)
	var charge = Heraldry.charge_color(design)
	var inside = PackedByteArray()
	inside.resize(w*h)
	for y in range(h):
		for x in range(w):
			if mask[y*w+x]==1 and _in_charge(design,Vector2(x+.5,y+.5),box,facing):
				inside[y*w+x] = 1
	for y in range(h):
		for x in range(w):
			var i = y*w+x
			if mask[i]==0:
				continue
			var c = sprite.get_pixel(x,y)
			var shade = clampf(.55+.45*c.get_luminance()/maxf(.05,mean),.45,1.22)
			var target = charge if inside[i]==1 else field
			var out = Color(target.r*shade,target.g*shade,target.b*shade,1).clamp()
			# One-texel darker rim where charge meets field reads at small size.
			if inside[i]==1:
				for d in [Vector2i(1,0),Vector2i(-1,0),Vector2i(0,1),Vector2i(0,-1)]:
					var p = Vector2i(x,y)+d
					if p.x>=0 and p.y>=0 and p.x<w and p.y<h and mask[p.y*w+p.x]==1 and inside[p.y*w+p.x]==0:
						out = out.darkened(.28)
						break
			image.set_pixel(x,y,out)
	return image

static func _in_charge(design: String, p: Vector2, box: Rect2, facing: int) -> bool:
	var u = (p.x-box.position.x)/box.size.x
	var v = (p.y-box.position.y)/box.size.y
	if facing<0:
		u = 1.0-u
	match design:
		"chevron":
			var apex = Vector2(.5,.30)
			var arm = absf(u-.5)
			var line_v = apex.y+arm*1.05
			return v>=line_v and v<=line_v+.17
		"cross":
			return absf(u-.5)<=.11 or absf(v-.40)<=.075
		"diamond":
			return absf(u-.5)/.22+absf(v-.44)/.25<=1.0
		"bend":
			# Bend: dexter chief (viewer's left top) to sinister base.
			var d = (u-.08)*.82-(v-.04)*.57
			return absf(d)<=.10
		_:
			# FEEL-093 designs: the shield charges spread over the cloth box.
			# u has already been mirrored for facing<0, so test unmirrored.
			return Heraldry.charge_contains(design,Vector2((u-.5)*80.0,(v-.5)*104.0),1)

# ------------------------------------------------------------------ output

func _save(image: Image, rel: String) -> void:
	var review = out_dir.path_join(rel)
	DirAccess.make_dir_recursive_absolute(review.get_base_dir())
	image.save_png(review)
	if install:
		var path = ProjectSettings.globalize_path(INSTALL_DIR.path_join(rel))
		DirAccess.make_dir_recursive_absolute(path.get_base_dir())
		image.save_png(path)

static func _zoom(image: Image, factor: int) -> Image:
	var copy = image.duplicate()
	copy.resize(image.get_width()*factor,image.get_height()*factor,Image.INTERPOLATE_NEAREST)
	var flat = Image.create_empty(copy.get_width(),copy.get_height(),false,Image.FORMAT_RGBA8)
	flat.fill(Color("4b5859"))
	flat.blend_rect(copy,Rect2i(Vector2i.ZERO,copy.get_size()),Vector2i.ZERO)
	return flat

static func _mask_view(sprite: Image, mask: PackedByteArray) -> Image:
	var image = sprite.duplicate()
	var w = image.get_width()
	for i in range(mask.size()):
		if mask[i]==1:
			image.set_pixel(i%w,i/w,Color(1,0,1))
	return image

static func _row(cells: Array) -> Image:
	var width = 0
	var height = 0
	for cell in cells:
		width += cell.get_width()+6
		height = maxi(height,cell.get_height())
	var row = Image.create_empty(width,height,false,Image.FORMAT_RGBA8)
	row.fill(Color.BLACK)
	var x = 0
	for cell in cells:
		row.blit_rect(cell,Rect2i(Vector2i.ZERO,cell.get_size()),Vector2i(x,0))
		x += cell.get_width()+6
	return row

static func _stack(rows: Array[Image]) -> Image:
	var width = 0
	var height = 0
	for row in rows:
		width = maxi(width,row.get_width())
		height += row.get_height()+6
	var sheet = Image.create_empty(maxi(1,width),maxi(1,height),false,Image.FORMAT_RGBA8)
	sheet.fill(Color.BLACK)
	var y = 0
	for row in rows:
		sheet.blit_rect(row,Rect2i(Vector2i.ZERO,row.get_size()),Vector2i(0,y))
		y += row.get_height()+6
	return sheet
