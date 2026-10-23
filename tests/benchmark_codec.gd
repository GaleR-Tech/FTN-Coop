extends SceneTree

func _initialize() -> void:
	var path := "res://mods/ftn_coop/value_codec.gd"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--codec="): path = argument.trim_prefix("--codec=")
	var codec: RefCounted = load(path).new()
	var rows := []
	for index in range(1000):
		rows.append({"type":"hay","strands":index+1,"xform":Transform3D(Basis.IDENTITY,Vector3(index*0.1,1.0,2.0))})
	var event := {"kind":"native","revision":101,"patch":{"belts":{"paths":[{"a":Vector3.ZERO,"b":Vector3(10,0,0),"records":rows}]}}}
	var encoded: Dictionary = codec.encode(event,64*1024*1024)
	var started := Time.get_ticks_usec()
	for repeat in range(10):
		var result: Dictionary = codec.decode(encoded.value,64*1024*1024)
		if not result.ok or result.value!=event:
			printerr("Round-trip failed")
			quit(1)
			return
	print(JSON.stringify({"bytes":encoded.value.size(),"decode_mean_ms":(Time.get_ticks_usec()-started)/10000.0}))
	quit()
