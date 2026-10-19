extends SceneTree

func _initialize() -> void:
	_trigger_error.call_deferred()
	create_timer(0.05).timeout.connect(func(): quit(0))

func _trigger_error() -> void:
	var invalid_receiver: Variant = 42
	invalid_receiver.method_that_does_not_exist()
