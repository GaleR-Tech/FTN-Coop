# Copied over the controller only in an isolated native test runtime.
extends "res://mods/ftn_coop/network_controller_base.gd"

var perf := {}
var maximum_queue_bytes := 0
var maximum_queue_packets := 0
var action_arrivals := {}

func _queue(peer: int, kind: String, body: Dictionary, reliable: bool=true) -> Dictionary:
	var stamped := body.duplicate()
	var now := int(Time.get_unix_time_from_system()*1000000.0)
	if kind=="ACTION": stamped._test_sent_us = now
	elif kind=="ACTION_RESULT" and action_arrivals.has(Vector2i(peer,int(body.get("sequence",0)))):
		var arrival: Dictionary = action_arrivals[Vector2i(peer,int(body.sequence))]
		stamped._test_sent_us = arrival.sent
		stamped._test_arrived_us = arrival.arrived
		stamped._test_ack_us = now
	return super._queue(peer,kind,stamped,reliable)

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
	return result

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
	super._on_message(peer,channel,bytes)
	record("receive_message",Time.get_ticks_usec()-started)

func record(key: String, micros: int) -> void:
	if not perf.has(key): perf[key] = []
	if perf[key].size()<20000: perf[key].append(micros/1000.0)
