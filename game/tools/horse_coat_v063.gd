extends SceneTree
## ART-063 horse coat tool. Runs headless through Start-MemoryBound.
##
## The four horse coats are repainted from ONE master: the measured v050 bay
## plate whose landmarks drive the skin rig. Silhouette, black outline, tack,
## hooves, eye and the mane/tail strand structure are kept from that master;
## the coat itself is repainted with smooth volume shading (normals inferred
## from the silhouette at two scales), a weak band of the master's muscle
## detail and realistic colour ramps. All four coats share one alignment.
##
## --mode=preview : display-scale comparisons of the current plates.
## --mode=paint   : classify the master, paint four coats, write review sheets.
##                  Add --install to also write runtime textures to
##                  res://assets/art/horse_coats063/ (this tool's own folder).
## Outputs go to --out=<new absolute dir>; existing evidence is never reused.

const PLATES = {
	"bay":"res://assets/art/pixel_v050/horse_complete_skin_v050_01.png",
	"grey":"res://assets/art/horse_coats060/grey.png",
	"flaxen":"res://assets/art/horse_coats060/flaxen.png",
	"black":"res://assets/art/horse_coats060/black.png"}
const BACKDROP = Color("4b5859")
const INSTALL_DIR = "res://assets/art/horse_coats063"
const RUNTIME_SIZE = Vector2i(1024,683)

enum {CLEAR,COAT,OUTLINE,CREASE,MANE,WHITE,KEEP,MUZZLE}

# Source-pixel polygons on the 1536x1024 master (see horse_skin.gd landmarks).
# The tail boundary follows the dark line that separates it from the croup,
# then the transparent gap in front of the hock.
const TAIL_POLY = [Vector2(30,276),Vector2(326,276),Vector2(334,298),Vector2(316,318),Vector2(296,344),Vector2(281,380),Vector2(271,425),Vector2(264,470),Vector2(276,520),Vector2(298,560),Vector2(284,650),Vector2(268,700),Vector2(265,800),Vector2(256,902),Vector2(250,965),Vector2(30,965)]
const MANE_POLY = [Vector2(868,365),Vector2(872,262),Vector2(960,180),Vector2(1070,108),Vector2(1170,52),Vector2(1262,12),Vector2(1350,4),Vector2(1392,52),Vector2(1342,116),Vector2(1268,156),Vector2(1188,206),Vector2(1108,264),Vector2(1028,324),Vector2(968,365)]
const SADDLE_POLY = [Vector2(548,222),Vector2(908,222),Vector2(962,328),Vector2(968,492),Vector2(852,502),Vector2(832,624),Vector2(742,628),Vector2(738,502),Vector2(568,482),Vector2(542,300)]
const BRIDLE_POLY = [Vector2(1262,36),Vector2(1334,36),Vector2(1484,196),Vector2(1494,326),Vector2(1262,326)]
# Joint zones: the belly's silhouette outline here is dragged by the limb
# weights when a leg swings, which drew black lines across elbow and stifle.
const ELBOW_ZONE = [Vector2(872,566),Vector2(992,566),Vector2(1004,664),Vector2(948,676),Vector2(872,644)]
const STIFLE_ZONE = [Vector2(498,468),Vector2(624,478),Vector2(644,578),Vector2(560,594),Vector2(502,578)]
const MUZZLE_RECT = Rect2(1392,212,110,126)
# Marking regions of the master's white pixels.
const HIND_SOCK = Rect2(250,700,240,300)
const FORE_SOCK = Rect2(940,700,220,300)
const FACE = Rect2(1240,40,280,300)
# Hoof capsules keep their own dark coronet/sole lines.
const HOOVES = [Rect2(296,926,150,74),Rect2(982,928,146,72)]
# Light from above, slightly in front and toward the viewer.
const LIGHT = Vector3(.30,-.88,.37)
# Authored anatomy (source px of the v050 master, horse facing right). The
# master's own muscle shading was AI zig-zag striation that read as cracks,
# so form comes from these masses: [cx, cy, rx, ry, rotation_deg, height_px].
# Gaussian profile exp(-2q): no hard rim, so masses blend like real muscle.
const MUSCLES = [
	[455,360,130,95,-8,15],   # croup / gluteal mass
	[548,352,34,30,0,4],      # point of hip
	[410,500,120,60,55,9],    # biceps femoris
	[500,505,70,40,70,6],     # quadriceps above the stifle
	[392,640,75,36,142,6],    # gaskin
	[322,722,26,22,0,3],      # hock
	[760,470,230,130,0,10],   # rib cage / barrel
	[600,450,55,70,0,-3],     # flank hollow
	[930,575,30,22,0,-2],     # girth pocket behind the elbow
	[1020,420,115,55,52,10],  # shoulder (scapula, deltoid)
	[1118,512,32,28,0,4],     # point of shoulder
	[985,535,62,55,0,8],      # triceps
	[1112,585,26,55,85,4],    # pectoral
	[1022,640,70,30,92,6],    # forearm muscles
	[1013,752,22,20,0,3],     # knee
	[1110,330,95,60,-50,8],   # neck, lower mass
	[1185,250,85,50,-55,7],   # neck, middle
	[1255,175,65,40,-60,5],   # neck below the poll
	[1352,200,48,40,0,7],     # cheek / masseter
	[1405,190,75,28,38,3],    # nasal plane
	[1462,282,32,28,0,3]]     # muzzle
# Posterising was tried (paint06): with muscle masses it cut tone islands that
# read as dirty patches, so shading stays continuous. 0 disables banding.
const TONES = 0.0
# Few, wide, shallow grooves: [x0, y0, x1, y1, width_px, depth_px].
const CREASES = [
	[560,470,520,560,22,2],   # flank fold before the stifle
	[1130,430,1265,285,18,1.5]] # jugular groove

# Colour ramps, sRGB 0-255, keys at s = 0,.18,.38,.58,.78,1.
const RAMP_KEYS = [0.0,.18,.38,.58,.78,1.0]
const COATS = {
	"bay":{"coat":[[26,10,6],[54,20,9],[90,34,14],[128,54,24],[164,82,40],[198,120,72]],
		"points":[[16,9,6],[32,16,9],[52,26,14],[74,38,22],[98,54,34],[124,76,52]],
		"mane":[],"muzzle":[],"markings":["hind","fore","face"],"points_weight":0.0,"legs_weight":.45,"gamma":1.0,
		"sheen":[236,170,118],"sheen_strength":.28},
	"flaxen":{"coat":[[50,16,5],[98,32,9],[146,52,16],[186,76,28],[216,106,50],[238,148,88]],
		"points":[[42,14,5],[80,28,9],[118,44,15],[152,64,26],[180,88,42],[206,122,70]],
		"mane":[[96,70,42],[142,108,68],[186,152,104],[218,192,146],[238,220,182],[250,240,214]],
		"muzzle":[],"markings":["fore","face"],"points_weight":0.0,"legs_weight":.30,"gamma":1.0,
		"sheen":[250,196,136],"sheen_strength":.26},
	"grey":{"coat":[[46,50,56],[78,83,90],[114,119,126],[152,156,162],[186,189,193],[220,222,224]],
		"points":[[28,31,35],[46,50,55],[68,72,78],[92,97,103],[118,123,129],[146,151,157]],
		"mane":[[22,24,28],[42,45,50],[68,72,78],[98,103,110],[138,144,150],[178,184,190]],
		"muzzle":[[18,19,22],[34,36,40],[54,57,62],[76,80,86],[100,105,111],[128,133,139]],
		"markings":[],"points_weight":0.0,"legs_weight":.78,"gamma":1.0,
		"sheen":[246,248,250],"sheen_strength":.18},
	"black":{"coat":[[6,6,8],[13,14,17],[22,24,29],[35,38,45],[54,59,69],[86,94,110]],
		"points":[],"mane":[[5,5,7],[13,14,17],[22,24,28],[36,39,45],[56,60,68],[84,90,100]],
		"muzzle":[[8,8,10],[16,17,20],[26,27,31],[38,40,45],[54,57,63],[76,80,88]],
		"markings":["hind","face"],"points_weight":0.0,"legs_weight":0.0,"gamma":1.2,
		"sheen":[140,154,182],"sheen_strength":.42}}

var out_dir = ""
var mode = ""
var install = false

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="): out_dir = arg.trim_prefix("--out=")
		if arg.begins_with("--mode="): mode = arg.trim_prefix("--mode=")
		if arg=="--install": install = true
	if out_dir.is_empty() or mode.is_empty() or OS.get_environment("GALUMU_MEMORY_BOUND")!="1024":
		printerr("ART063 usage: --mode=preview|paint --out=<new dir> [--install], via Start-MemoryBound")
		quit(2)
		return
	if DirAccess.dir_exists_absolute(out_dir):
		printerr("ART063 refusing to reuse evidence directory ",out_dir)
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(out_dir)
	var code = 0
	var started = Time.get_ticks_msec()
	if mode=="preview":
		code = preview()
	elif mode=="paint":
		code = paint()
	elif mode=="crop":
		code = crop_frames()
	else:
		printerr("ART063 unknown mode ",mode)
		code = 2
	log_line("done mode=%s code=%d ms=%d" % [mode,code,Time.get_ticks_msec()-started])
	quit(code)

func log_line(text: String) -> void:
	print("ART063 ",text)
	# .jsonl, not .txt: endpoint software on this machine re-encodes .txt
	# files written by any process into an unreadable container.
	var path = out_dir.path_join("log.jsonl")
	var file = FileAccess.open(path,FileAccess.READ_WRITE if FileAccess.file_exists(path) else FileAccess.WRITE)
	if file==null:
		return
	file.seek_end()
	file.store_line(JSON.stringify({"line":text}))
	file.close()

static func load_plate(path: String) -> Image:
	var image = Image.load_from_file(ProjectSettings.globalize_path(path))
	if image==null or image.is_empty():
		return null
	image.convert(Image.FORMAT_RGBA8)
	return image

static func over_backdrop(image: Image) -> Image:
	var flat = Image.create_empty(image.get_width(),image.get_height(),false,Image.FORMAT_RGBA8)
	flat.fill(BACKDROP)
	flat.blend_rect(image,Rect2i(Vector2i.ZERO,image.get_size()),Vector2i.ZERO)
	return flat

static func thresholded(image: Image) -> Image:
	# The game discards alpha below .5 (mounted_pixel.gdshader).
	var data = image.get_data()
	for i in range(3,data.size(),4):
		data[i] = 255 if data[i]>=128 else 0
	return Image.create_from_data(image.get_width(),image.get_height(),false,Image.FORMAT_RGBA8,data)

static func filtered_view(plate: Image, factor: float, enlarge: float) -> Image:
	var size = Vector2i(roundi(plate.get_width()*factor),roundi(plate.get_height()*factor))
	var small = plate.duplicate()
	small.resize(size.x,size.y,Image.INTERPOLATE_TRILINEAR)
	small = thresholded(small)
	small.resize(roundi(size.x*enlarge),roundi(size.y*enlarge),Image.INTERPOLATE_NEAREST)
	return over_backdrop(small)

# ---------------------------------------------------------------- preview

func preview() -> int:
	# In battle the plate is drawn at 180/666 game units per pixel times a
	# camera zoom of .68 (run-up) to 1.65 (contact): .18-.45 of the source.
	var scales = [.18,.30,.45]
	for key in PLATES:
		var plate = load_plate(PLATES[key])
		if plate==null:
			log_line("cannot load "+PLATES[key])
			return 1
		log_line("%s size=%s" % [key,plate.get_size()])
		if save_scale_sheet(plate,scales,"display-%s.png"%key)!=OK:
			return 1
		var crops = {"croup":Rect2i(250,250,420,420),"shoulder":Rect2i(880,280,380,420),"hindleg":Rect2i(270,560,300,440)}
		for name in crops:
			var crop = over_backdrop(plate.get_region(crops[name]))
			if crop.save_png(out_dir.path_join("crop-%s-%s.png"%[key,name]))!=OK:
				return 1
	return 0

func save_scale_sheet(plate: Image, scales: Array, file: String) -> int:
	# Left column: nearest sampling of the alpha-cut plate (what the game did
	# through v0.4.21). Right column: area-filtered (mipmapped sampling).
	var cut = thresholded(plate)
	var rows: Array[Image] = []
	var width = 0
	var height = 0
	for factor in scales:
		var size = Vector2i(roundi(plate.get_width()*factor),roundi(plate.get_height()*factor))
		var nearest = cut.duplicate()
		nearest.resize(size.x,size.y,Image.INTERPOLATE_NEAREST)
		var filtered = plate.duplicate()
		filtered.resize(size.x,size.y,Image.INTERPOLATE_TRILINEAR)
		filtered = thresholded(filtered)
		var view = Vector2i(roundi(size.x*2.7/(factor/.18)),roundi(size.y*2.7/(factor/.18)))
		for candidate in [nearest,filtered]:
			candidate.resize(view.x,view.y,Image.INTERPOLATE_NEAREST)
		var row = Image.create_empty(view.x*2+8,view.y,false,Image.FORMAT_RGBA8)
		row.fill(Color.BLACK)
		row.blit_rect(over_backdrop(nearest),Rect2i(Vector2i.ZERO,view),Vector2i.ZERO)
		row.blit_rect(over_backdrop(filtered),Rect2i(Vector2i.ZERO,view),Vector2i(view.x+8,0))
		rows.append(row)
		width = maxi(width,row.get_width())
		height += row.get_height()+8
	return stack_rows(rows,width,height).save_png(out_dir.path_join(file))

static func stack_rows(rows: Array[Image], width: int, height: int) -> Image:
	var sheet = Image.create_empty(width,height,false,Image.FORMAT_RGBA8)
	sheet.fill(Color.BLACK)
	var y = 0
	for row in rows:
		sheet.blit_rect(row,Rect2i(Vector2i.ZERO,row.get_size()),Vector2i(0,y))
		y += row.get_height()+8
	return sheet

func crop_frames() -> int:
	# Enlarge the belly/elbow/stifle band of every frame of a render sheet
	# (test_horse_art063 cells are 600x420 with 8px gaps) to inspect seams.
	var source = ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--src="): source = arg.trim_prefix("--src=")
	var sheet = Image.load_from_file(source)
	if sheet==null or sheet.is_empty():
		return 1
	sheet.convert(Image.FORMAT_RGBA8)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--rect="):
			# Any one rectangle x,y,w,h enlarged 3x.
			var p = arg.trim_prefix("--rect=").split(",")
			var region = sheet.get_region(Rect2i(int(p[0]),int(p[1]),int(p[2]),int(p[3])))
			region.resize(region.get_width()*3,region.get_height()*3,Image.INTERPOLATE_NEAREST)
			return region.save_png(out_dir.path_join(source.get_file().get_basename()+"-rect.png"))
	var rows: Array[Image] = []
	var frames = int((sheet.get_height()+8)/428)
	for k in range(frames):
		var band = sheet.get_region(Rect2i(120,k*428+120,360,170))
		band.resize(band.get_width()*3,band.get_height()*3,Image.INTERPOLATE_NEAREST)
		rows.append(band)
	return stack_rows(rows,rows[0].get_width(),(rows[0].get_height()+8)*rows.size()).save_png(out_dir.path_join(source.get_file().get_basename()+"-joints.png"))

# ---------------------------------------------------------------- helpers

static func rasterize(polygon: Array, w: int, h: int) -> PackedByteArray:
	var mask = PackedByteArray()
	mask.resize(w*h)
	var count = polygon.size()
	for y in range(h):
		var py = y+.5
		var xs: Array[float] = []
		for i in range(count):
			var a: Vector2 = polygon[i]
			var b: Vector2 = polygon[(i+1)%count]
			if (a.y<=py and b.y>py) or (b.y<=py and a.y>py):
				xs.append(a.x+(py-a.y)/(b.y-a.y)*(b.x-a.x))
		xs.sort()
		for i in range(0,xs.size()-1,2):
			var x0 = clampi(int(ceil(xs[i]-.5)),0,w)
			var x1 = clampi(int(floor(xs[i+1]-.5)),-1,w-1)
			for x in range(x0,x1+1):
				mask[y*w+x] = 1
	return mask

static func chamfer(clear: PackedByteArray, w: int, h: int) -> PackedFloat32Array:
	# Approximate Euclidean distance (px) to the nearest transparent pixel.
	var d = PackedFloat32Array()
	d.resize(w*h)
	var big = 1.0e9
	var diag = 1.41421
	for i in range(w*h):
		d[i] = 0.0 if clear[i]==1 else big
	for y in range(h):
		var row = y*w
		for x in range(w):
			var i = row+x
			var v = d[i]
			if v==0.0:
				continue
			if x>0: v = minf(v,d[i-1]+1.0)
			if y>0:
				v = minf(v,d[i-w]+1.0)
				if x>0: v = minf(v,d[i-w-1]+diag)
				if x<w-1: v = minf(v,d[i-w+1]+diag)
			d[i] = v
	for y in range(h-1,-1,-1):
		var row = y*w
		for x in range(w-1,-1,-1):
			var i = row+x
			var v = d[i]
			if v==0.0:
				continue
			if x<w-1: v = minf(v,d[i+1]+1.0)
			if y<h-1:
				v = minf(v,d[i+w]+1.0)
				if x<w-1: v = minf(v,d[i+w+1]+diag)
				if x>0: v = minf(v,d[i+w-1]+diag)
			d[i] = v
	return d

static func smooth_field(source: Image, divisor: int, channel: int) -> PackedFloat32Array:
	# Area-average down (C++), then Catmull-Rom up in FLOAT. An 8-bit cubic
	# upsample left 1/255 steps that the normals turned into contour lines.
	var w = source.get_width()
	var h = source.get_height()
	var sw = maxi(4,w/divisor)
	var sh = maxi(4,h/divisor)
	var small = source.duplicate()
	small.resize(sw,sh,Image.INTERPOLATE_TRILINEAR)
	var data = small.get_data()
	var grid = PackedFloat32Array()
	grid.resize(sw*sh)
	for i in range(sw*sh):
		grid[i] = data[i*4+channel]/255.0
	var rows = PackedFloat32Array()
	rows.resize(w*sh)
	for x in range(w):
		var taps = _catmull_taps((x+.5)*sw/float(w)-.5,sw)
		for y in range(sh):
			var base = y*sw
			rows[y*w+x] = grid[base+int(taps[0])]*taps[4]+grid[base+int(taps[1])]*taps[5]+grid[base+int(taps[2])]*taps[6]+grid[base+int(taps[3])]*taps[7]
	var out = PackedFloat32Array()
	out.resize(w*h)
	for y in range(h):
		var taps = _catmull_taps((y+.5)*sh/float(h)-.5,sh)
		var r0 = int(taps[0])*w
		var r1 = int(taps[1])*w
		var r2 = int(taps[2])*w
		var r3 = int(taps[3])*w
		var w0 = taps[4]
		var w1 = taps[5]
		var w2 = taps[6]
		var w3 = taps[7]
		var row = y*w
		for x in range(w):
			out[row+x] = rows[r0+x]*w0+rows[r1+x]*w1+rows[r2+x]*w2+rows[r3+x]*w3
	return out

static func _catmull_taps(position: float, size: int) -> PackedFloat32Array:
	var i0 = floori(position)
	var t = position-i0
	return PackedFloat32Array([clampi(i0-1,0,size-1),clampi(i0,0,size-1),clampi(i0+1,0,size-1),clampi(i0+2,0,size-1),
		((-t+2.0)*t-1.0)*t*.5,((3.0*t-5.0)*t*t+2.0)*.5,((-3.0*t+4.0)*t+1.0)*t*.5,(t-1.0)*t*t*.5])

static func ramp(keys: Array, s: float) -> Color:
	s = clampf(s,0.0,1.0)
	for k in range(1,RAMP_KEYS.size()):
		if s<=RAMP_KEYS[k] or k==RAMP_KEYS.size()-1:
			var t = (s-RAMP_KEYS[k-1])/(RAMP_KEYS[k]-RAMP_KEYS[k-1])
			t = t*t*(3.0-2.0*t)*.35+t*.65
			var a: Array = keys[k-1]
			var b: Array = keys[k]
			return Color8(int(lerpf(a[0],b[0],t)),int(lerpf(a[1],b[1],t)),int(lerpf(a[2],b[2],t)))
	return Color.MAGENTA

static func percentile(histogram: PackedInt32Array, total: int, fraction: float) -> float:
	var target = total*fraction
	var running = 0
	for i in range(histogram.size()):
		running += histogram[i]
		if running>=target:
			return i/255.0
	return 1.0

static func smooth01(e0: float, e1: float, x: float) -> float:
	var t = clampf((x-e0)/(e1-e0),0.0,1.0)
	return t*t*(3.0-2.0*t)

static func lift(a: float) -> float:
	# Smooth sqrt-like rise. Thin legs sit where the coarse fields undershoot
	# zero; sqrt(max(a,0)) made a kink there that drew hard bands on the legs.
	var positive = .5*(a+sqrt(a*a+.0004))
	return sqrt(positive+.0025)-.05

static func add_muscles(height: PackedFloat32Array, clear: PackedByteArray, w: int, h: int) -> void:
	for muscle in MUSCLES:
		var cx = float(muscle[0])
		var cy = float(muscle[1])
		var rx = float(muscle[2])
		var ry = float(muscle[3])
		var rotation = deg_to_rad(float(muscle[4]))
		var amplitude = float(muscle[5])
		var cr = cos(rotation)
		var sr = sin(rotation)
		var extent = 2.0*maxf(rx,ry)
		for y in range(maxi(0,int(cy-extent)),mini(h,int(cy+extent)+1)):
			var dy = y-cy
			for x in range(maxi(0,int(cx-extent)),mini(w,int(cx+extent)+1)):
				var i = y*w+x
				if clear[i]==1:
					continue
				var dx = x-cx
				var u = (dx*cr+dy*sr)/rx
				var v = (-dx*sr+dy*cr)/ry
				var q = u*u+v*v
				if q<4.0:
					height[i] += amplitude*exp(-2.0*q)

static func add_creases(height: PackedFloat32Array, clear: PackedByteArray, w: int, h: int) -> void:
	for crease in CREASES:
		var a = Vector2(crease[0],crease[1])
		var b = Vector2(crease[2],crease[3])
		var width = float(crease[4])
		var depth = float(crease[5])
		var box = Rect2(a,Vector2.ZERO).expand(b).grow(width)
		for y in range(maxi(0,int(box.position.y)),mini(h,int(box.end.y)+1)):
			for x in range(maxi(0,int(box.position.x)),mini(w,int(box.end.x)+1)):
				var i = y*w+x
				if clear[i]==1:
					continue
				var p = Vector2(x,y)
				var d = p.distance_to(Geometry2D.get_closest_point_to_segment(p,a,b))/width
				if d<1.0:
					var t = 1.0-d*d
					height[i] -= depth*t*t

# ---------------------------------------------------------------- paint

func paint() -> int:
	var master = load_plate(PLATES.bay)
	var flaxen = load_plate(PLATES.flaxen)
	var grey = load_plate(PLATES.grey)
	if master==null or flaxen==null or grey==null:
		log_line("cannot load plates")
		return 1
	var w = master.get_width()
	var h = master.get_height()
	if flaxen.get_size()!=master.get_size() or grey.get_size()!=master.get_size():
		log_line("plate sizes differ")
		return 1
	var n = w*h
	var src = master.get_data()
	var fx = flaxen.get_data()
	var gy = grey.get_data()
	flaxen = null
	grey = null
	var tail = rasterize(TAIL_POLY,w,h)
	var mane_area = rasterize(MANE_POLY,w,h)
	var saddle = rasterize(SADDLE_POLY,w,h)
	var bridle = rasterize(BRIDLE_POLY,w,h)
	var joints = rasterize(ELBOW_ZONE,w,h)
	var stifle = rasterize(STIFLE_ZONE,w,h)
	var tack = PackedByteArray()
	tack.resize(n)
	for i in range(n):
		tack[i] = 1 if saddle[i]==1 or bridle[i]==1 else 0
		joints[i] = 1 if joints[i]==1 or stifle[i]==1 else 0
	for rect in HOOVES:
		for y in range(int(rect.position.y),int(rect.end.y)):
			for x in range(int(rect.position.x),int(rect.end.x)):
				tack[y*w+x] = 2
	bridle = PackedByteArray()
	stifle = PackedByteArray()
	var clear = PackedByteArray()
	clear.resize(n)
	for i in range(n):
		clear[i] = 1 if src[i*4+3]<128 else 0
	var dist = chamfer(clear,w,h)
	log_line("distance transform ready")
	var cls = PackedByteArray()
	cls.resize(n)
	var counts = PackedInt32Array()
	counts.resize(8)
	for i in range(n):
		var o = i*4
		if clear[i]==1:
			cls[i] = CLEAR
			counts[CLEAR] += 1
			continue
		var x = i%w
		var y = i/w
		var point = Vector2(x,y)
		var r = src[o]/255.0
		var g = src[o+1]/255.0
		var b = src[o+2]/255.0
		var mx = maxf(r,maxf(g,b))
		var mn = minf(r,minf(g,b))
		var c = mx-mn
		var s = 0.0 if mx<=0.0 else c/mx
		var hue = 0.0
		if c>.00001:
			if mx==r: hue = 60.0*fposmod((g-b)/c,6.0)
			elif mx==g: hue = 60.0*((b-r)/c+2.0)
			else: hue = 60.0*((r-g)/c+4.0)
		# Coat changes colour between master and the grey/flaxen plates;
		# tack, hooves and eye were kept identical by their author.
		var vary_grey = maxi(absi(src[o]-gy[o]),maxi(absi(src[o+1]-gy[o+1]),absi(src[o+2]-gy[o+2])))
		var lum_master = .299*src[o]+.587*src[o+1]+.114*src[o+2]
		var lum_flaxen = .299*fx[o]+.587*fx[o+1]+.114*fx[o+2]
		var coat_hue = hue>=6.0 and hue<=40.0 and mx>=.16 and (s>=.56 or (mx>=.6 and s>=.42))
		var in_mane = mane_area[i]==1 and tack[i]==0
		var kind = KEEP
		if tack[i]==2:
			kind = OUTLINE if mx<.13 and dist[i]<=9.0 else KEEP
		elif mx<.13:
			if joints[i]==1 and tail[i]==0 and not in_mane and tack[i]==0:
				kind = CREASE
			elif dist[i]<=9.0:
				kind = OUTLINE
			elif tail[i]==1 or in_mane:
				kind = MANE
			elif tack[i]==1:
				kind = KEEP
			else:
				kind = CREASE
		# Hair is dark on the master and turns cream on the flaxen plate; the
		# croup and neck coat inside these polygons do neither and stay coat.
		elif tail[i]==1 and (mx<.45 or lum_flaxen-lum_master>45.0):
			kind = MANE
		elif in_mane and (mx<.30 or (lum_flaxen-lum_master>45.0 and mx<.62)):
			kind = MANE
		elif coat_hue and (tack[i]==0 or vary_grey>70):
			kind = COAT
		elif joints[i]==1 and tack[i]==0 and mx<.45:
			# Anti-aliased fringe of the removed joint outline.
			kind = CREASE
		elif MUZZLE_RECT.has_point(point) and vary_grey>40 and s<.5:
			kind = MUZZLE
		elif (HIND_SOCK.has_point(point) or FORE_SOCK.has_point(point)) and saddle[i]==0:
			kind = WHITE
		elif FACE.has_point(point) and s<.22 and mx>.62:
			kind = WHITE
		elif vary_grey>45 and saddle[i]==0:
			# Anything else that changes with the coat (chin, lips, shaded hair
			# below the hue test) is coat; tack never changes between plates.
			kind = MUZZLE if MUZZLE_RECT.has_point(point) else COAT
		cls[i] = kind
		counts[kind] += 1
	fx = PackedByteArray()
	gy = PackedByteArray()
	joints = PackedByteArray()
	tack = PackedByteArray()
	saddle = PackedByteArray()
	tail = PackedByteArray()
	mane_area = PackedByteArray()
	log_line("classes clear=%d coat=%d outline=%d crease=%d mane=%d white=%d keep=%d muzzle=%d" % Array(counts))
	if save_class_preview(cls,w,h)!=OK:
		return 1
	# Recolour ranges for mane/tail and muzzle.
	var mane_hist = PackedInt32Array()
	mane_hist.resize(256)
	var muzzle_hist = PackedInt32Array()
	muzzle_hist.resize(256)
	var mane_total = 0
	var muzzle_total = 0
	var silhouette_src = PackedByteArray()
	silhouette_src.resize(n*4)
	for i in range(n):
		var o = i*4
		var lum = int(.299*src[o]+.587*src[o+1]+.114*src[o+2])
		silhouette_src[o] = 0 if clear[i]==1 else 255
		silhouette_src[o+3] = 255
		if cls[i]==MANE:
			mane_hist[lum] += 1
			mane_total += 1
		elif cls[i]==MUZZLE:
			muzzle_hist[lum] += 1
			muzzle_total += 1
	var mane_lo = percentile(mane_hist,mane_total,.03)
	var mane_hi = percentile(mane_hist,mane_total,.97)
	var muzzle_lo = percentile(muzzle_hist,muzzle_total,.03)
	var muzzle_hi = percentile(muzzle_hist,muzzle_total,.97)
	# Height field: the silhouette inflated at two scales (barrel and limbs
	# read as volumes), plus the authored muscle masses and grooves.
	var silhouette = Image.create_from_data(w,h,false,Image.FORMAT_RGBA8,silhouette_src)
	silhouette_src = PackedByteArray()
	# Three scales: the barrel curves all the way across (not a flat plateau
	# with a rim), neck/thighs and limbs keep their own rounding. No upper clamp:
	# clamping the Catmull-Rom overshoot at 1 put kinks (hard lines) in normals.
	var a_huge = smooth_field(silhouette,128,0)
	var a_global = smooth_field(silhouette,40,0)
	var a_local = smooth_field(silhouette,12,0)
	silhouette = null
	var height = PackedFloat32Array()
	height.resize(n)
	for i in range(n):
		if clear[i]==1:
			continue
		height[i] = 70.0*lift(a_huge[i])+34.0*lift(a_global[i])+16.0*lift(a_local[i])
	a_huge = PackedFloat32Array()
	a_global = PackedFloat32Array()
	a_local = PackedFloat32Array()
	add_muscles(height,clear,w,h)
	add_creases(height,clear,w,h)
	clear = PackedByteArray()
	# Cavities (grooves, pockets) catch less light: blurred height - height.
	var height_src = PackedByteArray()
	height_src.resize(n*4)
	for i in range(n):
		height_src[i*4] = clampi(int(height[i]*2.0),0,255)
		height_src[i*4+3] = 255
	var height_blur = smooth_field(Image.create_from_data(w,h,false,Image.FORMAT_RGBA8,height_src),10,0)
	height_src = PackedByteArray()
	log_line("height field ready mane %.3f-%.3f muzzle %.3f-%.3f" % [mane_lo,mane_hi,muzzle_lo,muzzle_hi])
	var shade = PackedFloat32Array()
	shade.resize(n)
	var gloss = PackedFloat32Array()
	gloss.resize(n)
	var light = LIGHT.normalized()
	var half = (light+Vector3(0,0,1)).normalized()
	for i in range(n):
		var kind = cls[i]
		if kind!=COAT and kind!=CREASE and kind!=WHITE and kind!=MUZZLE:
			continue
		var x = i%w
		var y = i/w
		if x<4 or y<4 or x>=w-4 or y>=h-4:
			shade[i] = .5
			continue
		var slope_x = (height[i+3]-height[i-3])/6.0
		var slope_y = (height[i+3*w]-height[i-3*w])/6.0
		var normal = Vector3(-slope_x*1.2,-slope_y*1.2,1.0).normalized()
		var wrap = clampf((normal.dot(light)+.15)/1.15,0.0,1.0)
		var cavity = maxf(0.0,height_blur[i]*127.5-height[i])
		var occlusion = 1.0-.35*smooth01(0.0,12.0,cavity)
		var s = (.04+.92*wrap)*occlusion
		# Sky light: back and croup a little brighter than belly and legs.
		s += .10*(.5-smooth01(250.0,900.0,float(y)))
		s *= .90+.10*smooth01(0.0,10.0,dist[i])
		# Former outline pixels inside the body: a faint fold only. A darker
		# value redrew the jagged black seam at the elbow and stifle.
		if kind==CREASE:
			s -= .03
		shade[i] = s
		gloss[i] = pow(maxf(normal.dot(half),0.0),10.0)
	# Review aids: the raw shading coordinate and the height field.
	var debug_shade = PackedByteArray()
	debug_shade.resize(n*4)
	var debug_height = PackedByteArray()
	debug_height.resize(n*4)
	for i in range(n):
		var value = clampi(int(shade[i]*255.0),0,255)
		var lift = clampi(int(height[i]*2.0),0,255)
		for c in range(3):
			debug_shade[i*4+c] = value
			debug_height[i*4+c] = lift
		debug_shade[i*4+3] = 255
		debug_height[i*4+3] = 255
	Image.create_from_data(w,h,false,Image.FORMAT_RGBA8,debug_shade).save_png(out_dir.path_join("debug-shade.png"))
	Image.create_from_data(w,h,false,Image.FORMAT_RGBA8,debug_height).save_png(out_dir.path_join("debug-height.png"))
	debug_shade = PackedByteArray()
	debug_height = PackedByteArray()
	height = PackedFloat32Array()
	height_blur = PackedByteArray()
	var dapples = PackedFloat32Array()
	dapples.resize(w*h)
	log_line("shading and dapple field ready")
	var sheets: Array[Image] = []
	for key in COATS:
		var image = paint_coat(key,src,cls,shade,gloss,dapples,w,h,mane_lo,mane_hi,muzzle_lo,muzzle_hi)
		if image.save_png(out_dir.path_join("coat-%s-master.png"%key))!=OK:
			return 1
		var runtime = image.duplicate()
		runtime.resize(RUNTIME_SIZE.x,RUNTIME_SIZE.y,Image.INTERPOLATE_LANCZOS)
		_fix_runtime_alpha(runtime)
		if runtime.save_png(out_dir.path_join("coat-%s.png"%key))!=OK:
			return 1
		if install:
			DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(INSTALL_DIR))
			if runtime.save_png(ProjectSettings.globalize_path(INSTALL_DIR.path_join("%s.png"%key)))!=OK:
				return 1
		var crops = {"croup":Rect2i(250,250,420,420),"shoulder":Rect2i(880,280,380,420),"hindleg":Rect2i(270,560,300,440),"head":Rect2i(1150,20,380,340),"elbow":Rect2i(820,500,260,260)}
		for name in crops:
			if over_backdrop(image.get_region(crops[name])).save_png(out_dir.path_join("crop-new-%s-%s.png"%[key,name]))!=OK:
				return 1
		# Before/after at the contact zoom (.45 of the plate), area-filtered.
		var before = load_plate(PLATES[key])
		var left = filtered_view(before,.30,1.5)
		var right = filtered_view(image,.30,1.5)
		var row = Image.create_empty(left.get_width()*2+8,left.get_height(),false,Image.FORMAT_RGBA8)
		row.fill(Color.BLACK)
		row.blit_rect(left,Rect2i(Vector2i.ZERO,left.get_size()),Vector2i.ZERO)
		row.blit_rect(right,Rect2i(Vector2i.ZERO,right.get_size()),Vector2i(left.get_width()+8,0))
		sheets.append(row)
		log_line("painted "+key)
	var total_height = 0
	for row in sheets:
		total_height += row.get_height()+8
	if stack_rows(sheets,sheets[0].get_width(),total_height).save_png(out_dir.path_join("before-after.png"))!=OK:
		return 1
	return 0

static func _fix_runtime_alpha(image: Image) -> void:
	# Clean alpha after resampling: keep the .5 contour, no soft halo.
	var data = image.get_data()
	for i in range(3,data.size(),4):
		data[i] = 255 if data[i]>=128 else 0
		if data[i]==0:
			data[i-3] = 11
			data[i-2] = 10
			data[i-1] = 10
	image.set_data(image.get_width(),image.get_height(),false,Image.FORMAT_RGBA8,data)

func save_class_preview(cls: PackedByteArray, w: int, h: int) -> int:
	var colors = [Color(BACKDROP),Color("d08a4a"),Color.BLACK,Color("ff2bd6"),Color("2f6dff"),Color.WHITE,Color("39c46a"),Color("9a4dff")]
	var bytes = PackedByteArray()
	bytes.resize(w*h*4)
	for i in range(w*h):
		var c: Color = colors[cls[i]]
		bytes[i*4] = c.r8
		bytes[i*4+1] = c.g8
		bytes[i*4+2] = c.b8
		bytes[i*4+3] = 255
	var image = Image.create_from_data(w,h,false,Image.FORMAT_RGBA8,bytes)
	for polygon in [TAIL_POLY,MANE_POLY,SADDLE_POLY,BRIDLE_POLY,ELBOW_ZONE,STIFLE_ZONE]:
		for k in range(polygon.size()):
			var a: Vector2 = polygon[k]
			var b: Vector2 = polygon[(k+1)%polygon.size()]
			var steps = int(a.distance_to(b))
			for t in range(steps+1):
				var p = a.lerp(b,t/float(maxi(1,steps)))
				image.set_pixel(clampi(int(p.x),0,w-1),clampi(int(p.y),0,h-1),Color.YELLOW)
	if image.save_png(out_dir.path_join("classes.png"))!=OK:
		return FAILED
	var regions = {"saddle":Rect2i(540,200,440,440),"head":Rect2i(1150,0,386,340),"hind":Rect2i(240,440,420,560),"fore":Rect2i(840,480,320,520)}
	for name in regions:
		if image.get_region(regions[name]).save_png(out_dir.path_join("classes-%s.png"%name))!=OK:
			return FAILED
	return OK

func dapple_field(w: int, h: int) -> PackedFloat32Array:
	# Dapple grey: light round centres in a darker net, strongest over barrel
	# and quarters, fading on neck, absent on head and lower legs.
	var rng = RandomNumberGenerator.new()
	rng.seed = 63
	var cell = 46
	var gw = int(ceil(w/float(cell)))
	var gh = int(ceil(h/float(cell)))
	var points = PackedVector2Array()
	var radii = PackedFloat32Array()
	for gy in range(gh):
		for gx in range(gw):
			points.append(Vector2((gx+rng.randf_range(.15,.85))*cell,(gy+rng.randf_range(.15,.85))*cell))
			radii.append(rng.randf_range(13.0,21.0))
	var field = PackedFloat32Array()
	field.resize(w*h)
	for y in range(h):
		for x in range(w):
			var zone = smooth01(250,330,y)*(1.0-smooth01(560,660,y))*smooth01(260,360,x)*(1.0-smooth01(1100,1220,x))
			zone = maxf(zone,.55*smooth01(240,300,y)*(1.0-smooth01(520,600,y))*smooth01(1000,1080,x)*(1.0-smooth01(1180,1250,x)))
			if zone<=.001:
				continue
			var gx = int(x/cell)
			var gyy = int(y/cell)
			var best = 1.0e9
			var radius = 16.0
			for oy in range(-1,2):
				var cy = gyy+oy
				if cy<0 or cy>=gh:
					continue
				for ox in range(-1,2):
					var cx = gx+ox
					if cx<0 or cx>=gw:
						continue
					var k = cy*gw+cx
					var p = points[k]
					var dd = (p.x-x)*(p.x-x)+(p.y-y)*(p.y-y)
					if dd<best:
						best = dd
						radius = radii[k]
			# Soft light blotches in a slightly darker net; no ring outline,
			# which read as bubbles.
			var d = sqrt(best)/radius
			var inner = 1.0-smooth01(.25,1.0,d)
			field[y*w+x] = (inner-.32)*zone
	return field

func paint_coat(key: String, src: PackedByteArray, cls: PackedByteArray, shade: PackedFloat32Array, gloss: PackedFloat32Array, dapples: PackedFloat32Array, w: int, h: int, mane_lo: float, mane_hi: float, muzzle_lo: float, muzzle_hi: float) -> Image:
	var spec: Dictionary = COATS[key]
	var coat_keys: Array = spec.coat
	var point_keys: Array = spec.points
	var mane_keys: Array = spec.mane
	var muzzle_keys: Array = spec.muzzle
	var markings: Array = spec.markings
	var points_weight = float(spec.points_weight)
	var legs_weight = float(spec.legs_weight)
	var gamma = float(spec.gamma)
	var sheen_rgb: Array = spec.sheen
	var sheen = Color8(sheen_rgb[0],sheen_rgb[1],sheen_rgb[2])
	var sheen_strength = float(spec.sheen_strength)
	var out = PackedByteArray()
	out.resize(w*h*4)
	var mane_span = maxf(.05,mane_hi-mane_lo)
	var muzzle_span = maxf(.05,muzzle_hi-muzzle_lo)
	for i in range(w*h):
		var o = i*4
		var kind = cls[i]
		if kind==CLEAR:
			out[o] = 11
			out[o+1] = 10
			out[o+2] = 10
			out[o+3] = 0
			continue
		var x = i%w
		var y = i/w
		out[o+3] = 255
		var point = Vector2(x,y)
		if kind==WHITE:
			var marking = "face" if FACE.has_point(point) else ("hind" if HIND_SOCK.has_point(point) else "fore")
			if markings.has(marking):
				out[o] = src[o]
				out[o+1] = src[o+1]
				out[o+2] = src[o+2]
				continue
			kind = COAT
		if kind==MUZZLE and not muzzle_keys.is_empty():
			var lum = (.299*src[o]+.587*src[o+1]+.114*src[o+2])/255.0
			var tone = ramp(muzzle_keys,(lum-muzzle_lo)/muzzle_span)
			out[o] = tone.r8
			out[o+1] = tone.g8
			out[o+2] = tone.b8
			continue
		if kind==OUTLINE or kind==KEEP or kind==MUZZLE:
			out[o] = src[o]
			out[o+1] = src[o+1]
			out[o+2] = src[o+2]
			continue
		if kind==MANE:
			if mane_keys.is_empty():
				out[o] = src[o]
				out[o+1] = src[o+1]
				out[o+2] = src[o+2]
			else:
				var lum = (.299*src[o]+.587*src[o+1]+.114*src[o+2])/255.0
				var c = ramp(mane_keys,(lum-mane_lo)/mane_span)
				out[o] = c.r8
				out[o+1] = c.g8
				out[o+2] = c.b8
			continue
		# COAT and CREASE.
		var s = shade[i]
		if key=="grey":
			# RIDER-065: user rejected coat patterns; the grey is a plain iron
			# grey now (dapple_field kept for the paint07-12 record, unused).
			var muzzle = point.distance_to(Vector2(1452,282))
			s -= .32*(1.0-smooth01(50.0,230.0,muzzle))
		if gamma!=1.0:
			s = pow(clampf(s,0.0,1.0),gamma)
		if TONES>1.0:
			s = roundf(clampf(s,0.0,1.0)*(TONES-1.0))/(TONES-1.0)
		var color = ramp(coat_keys,s)
		# Lower legs: true bay points, darker grey and chestnut legs.
		var leg = 0.0
		if (x<580 and y>600) or (x>900 and x<1160 and y>600):
			var start = 688.0 if x<580 else 700.0
			leg = smooth01(start,start+92.0,float(y))
		if leg>0.0 and points_weight>0.0:
			color = color.lerp(ramp(point_keys,s),leg*points_weight)
		elif leg>0.0 and legs_weight>0.0:
			color = color.lerp(ramp(point_keys,s),leg*legs_weight)
		# Soft coat sheen on the convex masses, weaker on the dull lower legs.
		color = color.lerp(sheen,clampf(gloss[i]*sheen_strength*(1.0-.6*leg),0.0,1.0))
		out[o] = color.r8
		out[o+1] = color.g8
		out[o+2] = color.b8
	return Image.create_from_data(w,h,false,Image.FORMAT_RGBA8,out)
