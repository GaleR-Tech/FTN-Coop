extends RefCounted

const REQUIRED := [
	"snapshot_capture", "snapshot_restore", "action_capture", "host_apply",
	"guest_mutation_guard", "machine_host_only", "player_pose", "isolated_guest_session", "host_save",
]

func required_capabilities() -> PackedStringArray:
	return PackedStringArray(REQUIRED)

func verified_evidence(build: String) -> Dictionary:
	# Verified by the flagged native integration check; see integration-report.md.
	if build != "25963876":
		return {}
	var evidence := {}
	for capability in REQUIRED:
		evidence[capability] = true
	return evidence

func check_evidence(evidence: Dictionary) -> Dictionary:
	for capability in REQUIRED:
		if evidence.get(capability) != true:
			return {"ok": false, "code": "CAPABILITY_MISSING", "value": null}
	return {"ok": true, "code": "OK", "value": evidence.duplicate()}
