extends "test_journey110.gd"
## Actual new PCK only; persistent progress is isolated from all earlier QA.
func profile_root110()->String:return "E:/GALUMU/docs/development/logs/dev113-"
func run()->void:
	if OS.has_feature("editor") or ProjectSettings.get_setting("application/config/version") not in ["0.4.60-c3","0.4.60-c4","0.4.60-c5"]:quit(2);return
	await super.run()
