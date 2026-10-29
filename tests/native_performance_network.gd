# Copied over the controller only in an isolated native test runtime.
extends "res://mods/ftn_coop/network_controller_base.gd"

var perf := {}
var maximum_queue_bytes := 0
var maximum_queue_packets := 0
var action_arrivals := {}
var trace := []
var event_shape_active := false
var _peak_patch := {}
var _peak_packed := 0
var _peak_raw := 0
var compact_hold_events := 0

func _queue(peer: int, kind: String, body: Dictionary, reliable: bool=true) -> Dictionary:
	var stamped := body.duplicate()
	var now := int(Time.get_unix_time_from_system()*1000000.0)
	if kind=="ACTION": stamped._test_sent_us = now
	elif kind=="ACTION_RESULT" and action_arrivals.has(Vector2i(peer,int(body.get("sequence",0)))):
		var arrival: Dictionary = action_arrivals[Vector2i(peer,int(body.sequence))]
		stamped._test_sent_us = arrival.sent
		stamped._test_arrived_us = arrival.arrived
		stamped._test_ack_us = now
	var result := super._queue(peer,kind,stamped,reliable)
	if result.ok and kind=="ACTION_RESULT" and not _tx.is_empty():
		_tx[-1]._test_ack_sequence = int(body.get("sequence",0))
		_tx[-1]._test_ack_queued_us = Time.get_ticks_usec()
	return result

func _drain_packets(delta: float) -> void:
	var acknowledgements := []
	for packet in _tx:
		if packet.has("_test_ack_sequence"): acknowledgements.append(packet)
	super._drain_packets(delta)
	for packet in acknowledgements:
		if packet not in _tx and trace.size()<4096:
			trace.append({"phase":"ack_sent","peer":packet.peer,"sequence":packet._test_ack_sequence,"queue_ms":(Time.get_ticks_usec()-int(packet._test_ack_queued_us))/1000.0})

func _process(delta: float) -> void:
	var started := Time.get_ticks_usec()
	super._process(delta)
	record("network_tick",Time.get_ticks_usec()-started)
	maximum_queue_bytes = maxi(maximum_queue_bytes,_tx_bytes)
	maximum_queue_packets = maxi(maximum_queue_packets,_tx.size())

func _prepare_event(event: Dictionary) -> Dictionary:
	var started := Time.get_ticks_usec()
	var result := super._prepare_event(event)
	record("encode_event",Time.get_ticks_usec()-started)
	if event_shape_active and result.ok and not result.value.is_empty():
		if event.get("patch",{}).has("held_loose_links"): compact_hold_events += 1
		var header: Dictionary = result.value[0]
		if int(header.get("total_bytes",0))>_peak_packed:
			_peak_packed = int(header.total_bytes)
			_peak_raw = int(header.raw_bytes)
			_peak_patch = event.get("patch",{})
	return result

func profile_event_fields() -> Dictionary:
	var fields := {}
	for key in _peak_patch:
		var encoded: Dictionary = load(get_script().resource_path.get_base_dir()+"/value_codec.gd").new().encode({key:_peak_patch[key]},64*1024*1024)
		if encoded.ok: fields[str(key)] = {"raw":encoded.value.size(),"packed":encoded.value.compress(FileAccess.COMPRESSION_ZSTD).size()}
	return {"raw":_peak_raw,"packed":_peak_packed,"fields":fields,"compact_hold_events":compact_hold_events}

func _on_message(peer: int, channel: int, bytes: PackedByteArray) -> void:
	var started := Time.get_ticks_usec()
	if channel==0 and bytes.size()<2048 and bytes.get_string_from_utf8().contains("ACTION"):
		var decoded: Dictionary = _protocol.decode(bytes)
		if decoded.ok:
			var body: Dictionary = decoded.value.body
			var now := int(Time.get_unix_time_from_system()*1000000.0)
			if decoded.value.type=="ACTION" and body.has("_test_sent_us"):
				action_arrivals[Vector2i(peer,int(body.sequence))] = {"sent":body._test_sent_us,"arrived":now}
			elif decoded.value.type=="ACTION_RESULT" and body.has("_test_ack_us"):
				record("action_outbound",int(body._test_arrived_us)-int(body._test_sent_us))
				record("action_host",int(body._test_ack_us)-int(body._test_arrived_us))
				record("action_return",now-int(body._test_ack_us))
				if trace.size()<4096: trace.append({"phase":"ack_received","sequence":body.sequence,"outbound_ms":(int(body._test_arrived_us)-int(body._test_sent_us))/1000.0,"host_ms":(int(body._test_ack_us)-int(body._test_arrived_us))/1000.0,"return_ms":(now-int(body._test_ack_us))/1000.0})
	super._on_message(peer,channel,bytes)
	record("receive_message",Time.get_ticks_usec()-started)

func record(key: String, micros: int) -> void:
	if not perf.has(key): perf[key] = []
	if perf[key].size()<20000: perf[key].append(micros/1000.0)
