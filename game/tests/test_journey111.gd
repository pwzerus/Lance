extends "test_journey110.gd"
func profile_root110()->String:return "E:/GALUMU/docs/development/logs/qa111-"
func run()->void:
	if OS.has_feature("editor") or ProjectSettings.get_setting("application/config/version")!="0.4.59-c1":quit(2);return
	await super.run()
