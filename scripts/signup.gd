extends SplashMenu

func _ready() -> void:
	super()
	$ColorRect/Label3.set_is_valid_call(func(input):
		return input == $ColorRect/Label2.text and len(input)> 0)

func _resultate(data: Dictionary):
	if "go_login" in data:
		can_go = false
		go_away()
		await quitting
		queue_free()
		ui.splash_and_get_result("login", splashed_from, emitter, true)
	else:
		ui.hourglass_on()
		var answer = await web.POST("create_user", {"user": data["user"], "pass": data["pass"]})
		if answer.ok:
			var parsed = JSON.parse_string(answer.body.get_string_from_utf8())
			if parsed.answer == "ok":
				emitter.res.emit(data)
				glob.set_logged_in(data["user"], data["pass"])
				go_away()
			else:
				ui.error("This username is already occupied. Choose a different one, please!")
		else:
			ui.error("Either your internet or the server itself is down. Sorry!")
		ui.hourglass_off()


func _on_train_2_releaseda() -> void:
	resultate({"go_login": true})


func _on_label_2_text_changed(new_text: String) -> void:
	$ColorRect/Label3.update_valid()


func _on_train_releasedd() -> void:
	$ColorRect/Label2.update_valid()
	$ColorRect/Label.update_valid()
	$ColorRect/Label3.update_valid()
	if $ColorRect/Label2.is_valid and $ColorRect/Label.is_valid and $ColorRect/Label3.is_valid:
		resultate({"user": $ColorRect/Label.text, "pass": $ColorRect/Label2.text})
