extends Node

var robotic_arms: Array = []

func to_array() -> Array:
	var rows := []
	for arm in robotic_arms: rows.append(arm.call("to_dict"))
	return rows
