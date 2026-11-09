extends SceneTree
## EQUIP-066 caparison (马衣) painter. Runs headless through Start-MemoryBound.
##
## A caparison is drawn as a second texture over the SAME skinned horse mesh,
## so it bends with the body and upper legs exactly like the coat. This tool
## paints it in the horse master's 1536x1024 source space, then writes runtime
## textures (1024x683, same as the coats) for 3 cloth styles x 4 arms.
##
## Cloth stays inside the horse silhouette (no hanging skirt: the mesh only
## covers the horse) and never covers the black silhouette outline, the saddle
## or bridle (tack pixels are those identical on the bay and grey master plates),
## the head, the tail hair or the lower legs.
##
## --out=<new absolute dir> [--install]
const Coat = preload("res://tools/horse_coat_v063.gd")
const Heraldry = preload("res://scripts/visual/heraldry.gd")
const Shield = preload("res://scripts/core/shield_geometry.gd")
const INSTALL_DIR = "res://assets/art/caparison066"
const RUNTIME_SIZE = Vector2i(1024,683)

# Hem lines (source px, x ascending) for each cut. caparison01 review: a hem at
# the knee/hock wrapped the legs like trousers, so cloth now ends at the belly
# line and only just crosses the top of the forearm and gaskin.
const HEM_FULL = [Vector2(240,628),Vector2(470,636),Vector2(560,628),Vector2(620,618),Vector2(860,618),Vector2(920,640),Vector2(1100,646),Vector2(1200,630)]
const HEM_HALF = [Vector2(240,592),Vector2(470,600),Vector2(560,596),Vector2(620,596),Vector2(860,596),Vector2(920,604),Vector2(1100,606),Vector2(1200,596)]
# Half cut leaves the neck bare: cloth only behind this withers->chest line.
const HALF_FRONT = [Vector2(915,230),Vector2(1150,640)]
const FULL_FRONT = [Vector2(1236,10),Vector2(1290,330)]
# Escutcheons on the haunch and the shoulder (and the neck on full cuts):
# [center, scale]. caparison01 used 1.35/1.2: unreadable at battle size.
const PANELS = [[Vector2(410,458),1.95],[Vector2(1062,505),1.62]]
const NECK_PANEL = [Vector2(1150,292),1.15]
const STYLES = {
	# hem cut, border colour ("" = charge tincture), dagged edge, gold fringe
	"linen":{"hem":"half","border":"","dagged":false,"fringe":false,"cloth_shade":.85,"neck":false},
	"wool":{"hem":"full","border":"","dagged":true,"fringe":false,"cloth_shade":.80,"neck":true},
	"velvet":{"hem":"full","border":"d9b04a","dagged":false,"fringe":true,"cloth_shade":.70,"neck":true}}

var out_dir = ""
var install = false

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="): out_dir = arg.trim_prefix("--out=")
		if arg=="--install": install = true
	if out_dir.is_empty() or OS.get_environment("GALUMU_MEMORY_BOUND")!="1024" or DirAccess.dir_exists_absolute(out_dir):
		printerr("CAPARISON066 usage: --out=<new dir> [--install], via Start-MemoryBound")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(out_dir)
	var started = Time.get_ticks_msec()
	var code = paint()
	print("CAPARISON066 done code=%d ms=%d" % [code,Time.get_ticks_msec()-started])
	quit(code)

static func hem_y(points: Array, x: float) -> float:
	if x<=points[0].x:
		return points[0].y
	for i in range(1,points.size()):
		if x<=points[i].x:
			return lerpf(points[i-1].y,points[i].y,(x-points[i-1].x)/(points[i].x-points[i-1].x))
	return points[-1].y

static func behind(line: Array, p: Vector2) -> bool:
	# True when p lies on the tail side of the directed line a->b.
	var a: Vector2 = line[0]
	var b: Vector2 = line[1]
	return (b-a).cross(p-a)>=0.0

func paint() -> int:
	var master = Coat.load_plate(Coat.PLATES.bay)
	var grey = Coat.load_plate(Coat.PLATES.grey)
	if master==null or grey==null:
		return 1
	var w = master.get_width()
	var h = master.get_height()
	var n = w*h
	var src = master.get_data()
	var gy = grey.get_data()
	var tail = Coat.rasterize(Coat.TAIL_POLY,w,h)
	var saddle = Coat.rasterize(Coat.SADDLE_POLY,w,h)
	var bridle = Coat.rasterize(Coat.BRIDLE_POLY,w,h)
	var clear = PackedByteArray()
	clear.resize(n)
	for i in range(n):
		clear[i] = 1 if src[i*4+3]<128 else 0
	var dist = Coat.chamfer(clear,w,h)
	# Body volume for cloth shading (same inflation idea as the coat tool).
	var silhouette_src = PackedByteArray()
	silhouette_src.resize(n*4)
	for i in range(n):
		silhouette_src[i*4] = 0 if clear[i]==1 else 255
		silhouette_src[i*4+3] = 255
	var silhouette = Image.create_from_data(w,h,false,Image.FORMAT_RGBA8,silhouette_src)
	silhouette_src = PackedByteArray()
	var a_big = Coat.smooth_field(silhouette,64,0)
	var a_small = Coat.smooth_field(silhouette,16,0)
	silhouette = null
	var height = PackedFloat32Array()
	height.resize(n)
	for i in range(n):
		if clear[i]==0:
			height[i] = 60.0*Coat.lift(a_big[i])+22.0*Coat.lift(a_small[i])
	a_big = PackedFloat32Array()
	a_small = PackedFloat32Array()
	var light = Coat.LIGHT.normalized()
	var shade = PackedFloat32Array()
	shade.resize(n)
	for i in range(n):
		if clear[i]==1:
			continue
		var x = i%w
		var y = i/w
		if x<4 or y<4 or x>=w-4 or y>=h-4:
			shade[i] = .6
			continue
		var normal = Vector3(-(height[i+3]-height[i-3])/6.0*1.1,-(height[i+3*w]-height[i-3*w])/6.0*1.1,1.0).normalized()
		shade[i] = clampf((normal.dot(light)+.25)/1.25,0.0,1.0)
	height = PackedFloat32Array()
	var sheets: Array[Image] = []
	var coat_preview = Coat.load_plate("res://assets/art/horse_coats063/bay.png")
	for style in STYLES:
		var config: Dictionary = STYLES[style]
		var hem: Array = HEM_HALF if config.hem=="half" else HEM_FULL
		# Cloth mask and edge distance (for border band and outline).
		var cloth = PackedByteArray()
		cloth.resize(n)
		var tack = PackedByteArray()
		tack.resize(n)
		for i in range(n):
			if clear[i]==1 or dist[i]<4.0 or tail[i]==1 or bridle[i]==1:
				continue
			var x = i%w
			var y = i/w
			var p = Vector2(x,y)
			if x>1240:
				continue
			if not behind(FULL_FRONT if config.neck else HALF_FRONT,p):
				continue
			var limit = hem_y(hem,x)
			if config.dagged:
				var s = fposmod(float(x),36.0)/18.0-1.0
				limit -= 15.0*(1.0-sqrt(maxf(0.0,1.0-s*s)))
			if y>limit:
				continue
			# Tack sits on top of the cloth: identical on both master plates.
			# The red/gold saddle pad is replaced by the caparison itself
			# (it clashed with every arms colour in caparison01); leather,
			# girth and stirrup leathers stay on top.
			if saddle[i]==1:
				var o = i*4
				var vary = maxi(absi(src[o]-gy[o]),maxi(absi(src[o+1]-gy[o+1]),absi(src[o+2]-gy[o+2])))
				if vary<=45 and not _is_saddle_pad(src[o],src[o+1],src[o+2]):
					tack[i] = 1
					continue
			cloth[i] = 1
		# Distance from the cloth's own hem/front edge, i.e. where it meets the
		# visible coat. Tack lies on the cloth, so it is not an edge (caparison02
		# drew the trim band around the saddle).
		var edge_clear = PackedByteArray()
		edge_clear.resize(n)
		for i in range(n):
			edge_clear[i] = 0 if cloth[i]==1 or tack[i]==1 or clear[i]==1 or dist[i]<4.0 else 1
		var edge = Coat.chamfer(edge_clear,w,h)
		edge_clear = PackedByteArray()
		# EQUIP-067: a rider facing left draws the horse mirrored, which turned
		# the bend into a bend sinister; "bend_l" pre-mirrors the charge.
		var variants: Array = []
		for key in Heraldry.ARMS:
			variants.append([key,1])
		variants.append(["bend",-1])
		for variant in variants:
			var design: String = variant[0]
			var facing: int = variant[1]
			var field = Heraldry.field_color(design)
			var charge = Heraldry.charge_color(design)
			var border = Color(str(config.border)) if str(config.border)!="" else charge
			var data = PackedByteArray()
			data.resize(n*4)
			for i in range(n):
				if cloth[i]==0:
					continue
				var x = i%w
				var y = i/w
				var color = field
				var e = edge[i]
				# Border trim band along the hem and front edge.
				if e<14.0:
					color = border
				if config.fringe and e<5.0:
					color = border.darkened(.25) if (x/4)%2==0 else border.lightened(.15)
				# Soft vertical folds where cloth hangs below the back.
				var hang = Coat.smooth01(470.0,620.0,float(y))
				var fold = sin((x+.18*y)*TAU/34.0)*.06*hang
				var s = lerpf(.62,1.08,shade[i])+fold
				if style=="velvet" and e>=14.0:
					# Woven damask lattice, a few percent darker.
					var u = fposmod(float(x+y),46.0)
					var v = fposmod(float(x-y),46.0)
					if absf(u-23.0)<1.6 or absf(v-23.0)<1.6:
						s -= .07
				var final = color*clampf(s*float(config.cloth_shade)+(1.0-float(config.cloth_shade))*.95,0.25,1.15)
				if e<2.5:
					final = Color("1d1612")
				var o = i*4
				data[o] = int(clampf(final.r,0,1)*255)
				data[o+1] = int(clampf(final.g,0,1)*255)
				data[o+2] = int(clampf(final.b,0,1)*255)
				data[o+3] = 255
			# Escutcheons bearing the arms.
			var panels = PANELS.duplicate()
			if config.neck:
				panels.append(NECK_PANEL)
			var rim = Color("e2bf5a") if style=="velvet" else Color("1d1612")
			for panel in panels:
				_paint_escutcheon(data,cloth,shade,w,h,panel[0],float(panel[1]),design,rim,facing)
			var image = Image.create_from_data(w,h,false,Image.FORMAT_RGBA8,data)
			var name = "%s_%s%s" % [style,design,"_l" if facing<0 else ""]
			var runtime = image.duplicate()
			runtime.resize(RUNTIME_SIZE.x,RUNTIME_SIZE.y,Image.INTERPOLATE_LANCZOS)
			Coat._fix_runtime_alpha(runtime)
			if runtime.save_png(out_dir.path_join(name+".png"))!=OK:
				return 1
			if install:
				DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(INSTALL_DIR))
				if runtime.save_png(ProjectSettings.globalize_path(INSTALL_DIR.path_join(name+".png")))!=OK:
					return 1
			if coat_preview!=null:
				var dressed = coat_preview.duplicate()
				dressed.blend_rect(runtime,Rect2i(Vector2i.ZERO,runtime.get_size()),Vector2i.ZERO)
				sheets.append(Coat.filtered_view(dressed,.42,1.0))
			print("CAPARISON066 painted ",name)
	if not sheets.is_empty():
		var columns = 4
		var cell = sheets[0].get_size()
		var sheet = Image.create_empty(cell.x*columns+8*(columns-1),(cell.y+8)*ceili(sheets.size()/float(columns)),false,Image.FORMAT_RGBA8)
		sheet.fill(Color.BLACK)
		for k in range(sheets.size()):
			sheet.blit_rect(sheets[k],Rect2i(Vector2i.ZERO,cell),Vector2i((k%columns)*(cell.x+8),(k/columns)*(cell.y+8)))
		sheet.save_png(out_dir.path_join("caparisons.png"))
	return 0

static func _is_saddle_pad(r: int, g: int, b: int) -> bool:
	# Saturated red/orange/yellow cloth of the master's saddle pad (the leather
	# is low-saturation brown, the metal fittings small).
	# caparison02: v>.38 also caught the reddish-brown seat leather.
	var c = Color8(r,g,b)
	return c.s>.60 and c.v>.62 and (c.h<.15 or c.h>.94)

static func _paint_escutcheon(data: PackedByteArray, cloth: PackedByteArray, shade: PackedFloat32Array, w: int, h: int, center: Vector2, scale: float, design: String, rim: Color = Color("1d1612"), facing: int = 1) -> void:
	var outline = Shield.outline("heater")
	var face = PackedVector2Array()
	for point in outline:
		face.append(point*scale)
	var inner = PackedVector2Array()
	for point in outline:
		inner.append(point*scale*.88)
	var charges = Heraldry.clipped_charges(design,inner,scale,facing)
	var field = Heraldry.field_color(design)
	var charge = Heraldry.charge_color(design)
	var bounds = Rect2(center+Vector2(-40,-46)*scale,Vector2(80,98)*scale)
	for y in range(int(bounds.position.y),int(bounds.end.y)+1):
		for x in range(int(bounds.position.x),int(bounds.end.x)+1):
			if x<0 or y<0 or x>=w or y>=h:
				continue
			var i = y*w+x
			if cloth[i]==0:
				continue
			var local = Vector2(x,y)-center
			if not Geometry2D.is_point_in_polygon(local,face):
				continue
			var color = rim
			if Geometry2D.is_point_in_polygon(local,inner):
				color = field
				for piece in charges:
					if Geometry2D.is_point_in_polygon(local,piece):
						color = charge
						break
				color = color*lerpf(.80,1.05,shade[i])
			var o = i*4
			data[o] = int(clampf(color.r,0,1)*255)
			data[o+1] = int(clampf(color.g,0,1)*255)
			data[o+2] = int(clampf(color.b,0,1)*255)
			data[o+3] = 255
