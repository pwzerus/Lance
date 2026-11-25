extends "test_journey110.gd"
## Keep the earned-profile campaign independent of all prior QA saves.
## Source runs must say so explicitly; release runs require the new version.
func profile_root110() -> String:
	return "E:/GALUMU/docs/development/logs/phys115-"

func run() -> void:
	var source=OS.has_feature("editor")
	if source and not "--source-workspace" in OS.get_cmdline_user_args():quit(2);return
	if not source and not str(ProjectSettings.get_setting("application/config/version")).begins_with("0.5.0-"):quit(2);return
	await super.run()
