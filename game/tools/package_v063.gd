extends SceneTree
## ART-063 release folder helper. Byte-copies the root resource protector into
## the build folder and prints/writes SHA256 sums for the five shipped files.
## On this machine endpoint software re-encodes any written .txt file (Godot's
## too), so the sums are also printed: verify SHA256SUMS.txt reads as text and
## rewrite it from the printed lines if it does not.
## Run headless through Start-MemoryBound.

const FILES = ["LanceAndLaurel.exe","LanceAndLaurel.pck","Play-Safe.cmd","README.txt","Start-MemoryBound.ps1"]
# Used for v0.4.22 (ART-063) and v0.4.23 (RIDER-064).

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var build = ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--build="): build = arg.trim_prefix("--build=")
	if build.is_empty() or OS.get_environment("GALUMU_MEMORY_BOUND")!="1024" or not DirAccess.dir_exists_absolute(build):
		printerr("PACKAGE063 usage: --build=<existing release folder>")
		quit(2)
		return
	var protector = "E:/GALUMU/Start-MemoryBound.ps1"
	var target = build.path_join("Start-MemoryBound.ps1")
	if FileAccess.file_exists(target):
		printerr("PACKAGE063 refusing to overwrite ",target)
		quit(2)
		return
	if DirAccess.copy_absolute(protector,target)!=OK:
		quit(1)
		return
	var source_sum = FileAccess.get_sha256(protector)
	if FileAccess.get_sha256(target)!=source_sum:
		printerr("PACKAGE063 protector copy differs")
		quit(1)
		return
	var lines = PackedStringArray()
	for name in FILES:
		var path = build.path_join(name)
		if not FileAccess.file_exists(path):
			printerr("PACKAGE063 missing ",path)
			quit(1)
			return
		var sum = FileAccess.get_sha256(path).to_upper()
		lines.append(sum+"  "+name)
		print("PACKAGE063 ",sum,"  ",name)
	# Sums are printed only; the release SHA256SUMS.txt is written by hand
	# from these lines (see header).
	print("PACKAGE063 protector sha256 ",source_sum.to_upper())
	quit(0)
