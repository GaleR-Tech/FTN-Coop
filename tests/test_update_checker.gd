extends RefCounted

func run(tree: SceneTree) -> Array[String]:
	if not FileAccess.file_exists("res://mods/ftn_coop/update_checker.gd"): return ["Optional bounded update checking is missing."]
	var script: Script = load("res://mods/ftn_coop/update_checker.gd")
	var errors: Array[String] = []
	for row in [["0.3.10","0.3.9",1],["0.10.0","0.3.0",1],["0.3.0","0.3.0",0],["0.2.0","0.3.0",-1]]:
		if script.compare_versions(row[0],row[1])!=row[2]: errors.append("Version comparisons must use numeric components: "+str(row))
	for row in [["v0.3.10","newer"],["v0.3.0","current"],["v0.2.0","older"]]:
		var result: Dictionary = script.parse_release(200,JSON.stringify({"tag_name":row[0],"draft":false,"prerelease":false}).to_utf8_buffer(),"0.3.0")
		if not result.ok or result.value.status!=row[1]: errors.append("A valid release must report its real relation to the installed version.")
	for data in [{"tag_name":"v0.4.0","draft":true,"prerelease":false},{"tag_name":"v0.4.0","draft":false,"prerelease":true},{"tag_name":"run.exe","draft":false,"prerelease":false},{}]:
		if script.parse_release(200,JSON.stringify(data).to_utf8_buffer(),"0.3.0").ok: errors.append("Draft, prerelease and malformed releases must not be offered as updates.")
	for body in [PackedByteArray([255]),"broken".to_utf8_buffer(),"x".repeat(262145).to_utf8_buffer()]:
		if script.parse_release(200,body,"0.3.0").ok: errors.append("Invalid or oversized update data must fail safely.")
	var emoji := '{"tag_name":"v0.4.0","draft":false,"prerelease":false,"body":"\\ud83d\\udc4d"}'
	if not script.parse_release(200,emoji.to_utf8_buffer(),"0.3.0").ok: errors.append("A valid escaped emoji in release notes must not prevent update checking.")
	if script.parse_release(200,emoji.replace("\\ud83d\\udc4d","\\ud800").to_utf8_buffer(),"0.3.0").ok: errors.append("Unpaired Unicode escapes must be rejected before the native JSON parser.")
	for row in [[404,"UPDATE_NO_RELEASE"],[403,"UPDATE_RATE_LIMITED"],[429,"UPDATE_RATE_LIMITED"]]:
		if script.parse_release(row[0],PackedByteArray(),"0.3.0").code!=row[1]: errors.append("HTTP failures must retain an actionable update reason.")
	var client: Node = load("res://tests/fixtures/update_http.gd").new()
	var checker: Node = script.new(client)
	tree.root.add_child(checker)
	checker.configure("0.3.0")
	if client.request_count!=0: errors.append("Opening/configuring the mod must never start an update request.")
	var results: Array = []
	checker.completed.connect(func(result: Dictionary): results.append(result))
	if not checker.check().ok or checker.check().ok: errors.append("Only one requested update check may run at a time.")
	var deadline := Time.get_ticks_msec()+2500
	while results.is_empty() and Time.get_ticks_msec()<deadline: await tree.process_frame
	if results.is_empty() or not results[0].ok or results[0].value.version!="0.3.10": errors.append("A real HTTP reply must reach the parsed update result.")
	if client.request_count!=1 or client.requested_url!="https://api.github.com/repos/GaleR-Tech/FTN-Coop/releases/latest" or checker.check().ok: errors.append("Requests must use the fixed public endpoint and respect the one-minute cooldown.")
	checker._process(60.0)
	client.response_code = 429
	checker.check()
	deadline = Time.get_ticks_msec()+2500
	while results.size()<2 and Time.get_ticks_msec()<deadline: await tree.process_frame
	if results.size()<2 or results[1].code!="UPDATE_RATE_LIMITED": errors.append("Real rate limiting must finish the request with a translated error code.")
	checker._process(60.0)
	client._server.stop()
	checker.check()
	# The production client permits ten seconds; Windows may retry a refused
	# TCP connection before reporting it. Keep processing frames throughout.
	deadline = Time.get_ticks_msec()+12000
	while results.size()<3 and Time.get_ticks_msec()<deadline: await tree.process_frame
	if results.size()<3 or results[2].code!="UPDATE_CONNECTION": errors.append("An unreachable HTTP endpoint must complete without blocking play. replies="+str(results)+" busy="+str(checker._busy))
	checker.queue_free()
	await tree.process_frame
	return errors
