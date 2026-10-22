extends Node3D

var payload := 97

func to_dict() -> Dictionary:
	_credit_the_undrawn()
	return {"type":"robotic_arm","position":position,"tier":1}

func _credit_the_undrawn() -> void:
	payload = 0
