extends Node
class_name CombatModifierComponent

const COMBAT_EVENT_TYPES := preload("res://scenes/components/combat_event_types.gd")

const STACK_REFRESH := "refresh"
const STACK_REPLACE_STRONGER := "replace_stronger"
const STACK_ADD := "add"
const STACK_INDEPENDENT := "independent"

var _modifiers: Dictionary = {}
var _sequence: int = 0

func _process(delta: float) -> void:
	if _modifiers.is_empty():
		return

	var expired_ids: Array[String] = []
	var modifier_ids: Array = _modifiers.keys().duplicate()
	for modifier_id_variant: Variant in modifier_ids:
		var modifier_id: String = str(modifier_id_variant)
		var modifier_variant: Variant = _modifiers.get(modifier_id, {})
		if not (modifier_variant is Dictionary):
			expired_ids.append(modifier_id)
			continue

		var modifier: Dictionary = (modifier_variant as Dictionary).duplicate(true)
		modifier["remaining"] = max(0.0, float(modifier.get("remaining", 0.0)) - delta)

		if str(modifier.get("type", "")) == "damage_over_time":
			var tick_interval: float = max(0.01, float(modifier.get("tick_interval", 1.0)))
			modifier["tick_timer"] = float(modifier.get("tick_timer", tick_interval)) - delta
			while float(modifier.get("tick_timer", 0.0)) <= 0.0 and float(modifier.get("remaining", 0.0)) > 0.0:
				modifier["tick_timer"] = float(modifier.get("tick_timer", 0.0)) + tick_interval
				_apply_dot_tick(modifier)

		_modifiers[modifier_id] = modifier
		if float(modifier.get("remaining", 0.0)) <= 0.0:
			expired_ids.append(modifier_id)

	for modifier_id: String in expired_ids:
		_modifiers.erase(modifier_id)

func apply_move_speed_multiplier(modifier_id: String, multiplier: float, duration: float, stacking_rule: String = STACK_REFRESH, source: Variant = null, payload: Dictionary = {}) -> String:
	return _apply_modifier({
		"id": modifier_id,
		"type": "move_speed_multiplier",
		"value": multiplier,
		"duration": duration,
		"remaining": duration,
		"stacking_rule": stacking_rule,
		"source": source,
		"payload": payload.duplicate(true),
	})

func apply_damage_over_time(modifier_id: String, damage_per_tick: float, duration: float, tick_interval: float, stacking_rule: String = STACK_REFRESH, source: Variant = null, payload: Dictionary = {}) -> String:
	var dot_payload: Dictionary = payload.duplicate(true)
	if not dot_payload.has("damage_type"):
		dot_payload["damage_type"] = COMBAT_EVENT_TYPES.DamageType.DOT
	return _apply_modifier({
		"id": modifier_id,
		"type": "damage_over_time",
		"value": damage_per_tick,
		"duration": duration,
		"remaining": duration,
		"tick_interval": tick_interval,
		"tick_timer": tick_interval,
		"stacking_rule": stacking_rule,
		"source": source,
		"payload": dot_payload,
	})

func apply_vulnerable(modifier_id: String, multiplier: float, duration: float, stacking_rule: String = STACK_REFRESH, source: Variant = null, payload: Dictionary = {}) -> String:
	return _apply_modifier({
		"id": modifier_id,
		"type": "vulnerable",
		"value": multiplier,
		"duration": duration,
		"remaining": duration,
		"stacking_rule": stacking_rule,
		"source": source,
		"payload": payload.duplicate(true),
	})

func apply_tag_marker(modifier_id: String, tag_name: String, duration: float, stacking_rule: String = STACK_REFRESH, source: Variant = null, payload: Dictionary = {}) -> String:
	var marker_payload: Dictionary = payload.duplicate(true)
	marker_payload["tag"] = tag_name
	return _apply_modifier({
		"id": modifier_id,
		"type": "tag_marker",
		"value": 1.0,
		"duration": duration,
		"remaining": duration,
		"stacking_rule": stacking_rule,
		"source": source,
		"payload": marker_payload,
	})

func remove_modifier(modifier_id: String) -> void:
	_modifiers.erase(modifier_id)

func clear_tag_marker(tag_name: String) -> void:
	var remove_ids: Array[String] = []
	for modifier_id_variant: Variant in _modifiers.keys():
		var modifier_id: String = str(modifier_id_variant)
		var modifier_variant: Variant = _modifiers.get(modifier_id, {})
		if not (modifier_variant is Dictionary):
			remove_ids.append(modifier_id)
			continue
		var modifier: Dictionary = modifier_variant as Dictionary
		if str(modifier.get("type", "")) != "tag_marker":
			continue
		var payload_variant: Variant = modifier.get("payload", {})
		var payload: Dictionary = payload_variant if payload_variant is Dictionary else {}
		if str(payload.get("tag", "")) == tag_name:
			remove_ids.append(modifier_id)
	for modifier_id: String in remove_ids:
		_modifiers.erase(modifier_id)

func get_move_speed_multiplier() -> float:
	var multiplier: float = 1.0
	for modifier_variant: Variant in _modifiers.values():
		if not (modifier_variant is Dictionary):
			continue
		var modifier: Dictionary = modifier_variant as Dictionary
		if str(modifier.get("type", "")) != "move_speed_multiplier":
			continue
		multiplier *= max(0.0, float(modifier.get("value", 1.0)))
	return max(0.0, multiplier)

func get_damage_taken_multiplier() -> float:
	var multiplier: float = 1.0
	for modifier_variant: Variant in _modifiers.values():
		if not (modifier_variant is Dictionary):
			continue
		var modifier: Dictionary = modifier_variant as Dictionary
		if str(modifier.get("type", "")) != "vulnerable":
			continue
		multiplier *= max(0.0, float(modifier.get("value", 1.0)))
	return max(0.0, multiplier)

func has_tag_marker(tag_name: String) -> bool:
	for modifier_variant: Variant in _modifiers.values():
		if not (modifier_variant is Dictionary):
			continue
		var modifier: Dictionary = modifier_variant as Dictionary
		if str(modifier.get("type", "")) != "tag_marker":
			continue
		var payload_variant: Variant = modifier.get("payload", {})
		var payload: Dictionary = payload_variant if payload_variant is Dictionary else {}
		if str(payload.get("tag", "")) == tag_name:
			return true
	return false

func get_tag_markers() -> Array[String]:
	var tags: Array[String] = []
	for modifier_variant: Variant in _modifiers.values():
		if not (modifier_variant is Dictionary):
			continue
		var modifier: Dictionary = modifier_variant as Dictionary
		if str(modifier.get("type", "")) != "tag_marker":
			continue
		var payload_variant: Variant = modifier.get("payload", {})
		var payload: Dictionary = payload_variant if payload_variant is Dictionary else {}
		var tag_name: String = str(payload.get("tag", ""))
		if not tag_name.is_empty() and not tags.has(tag_name):
			tags.append(tag_name)
	return tags

func get_modifiers_by_type(type_name: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for modifier_variant: Variant in _modifiers.values():
		if not (modifier_variant is Dictionary):
			continue
		var modifier: Dictionary = modifier_variant as Dictionary
		if str(modifier.get("type", "")) == type_name:
			result.append(modifier.duplicate(true))
	return result

func _apply_modifier(modifier: Dictionary) -> String:
	var stacking_rule: String = str(modifier.get("stacking_rule", STACK_REFRESH))
	var requested_id: String = str(modifier.get("id", ""))
	var final_id: String = requested_id

	if stacking_rule == STACK_INDEPENDENT or requested_id.is_empty():
		final_id = _next_modifier_id(requested_id)
		modifier["id"] = final_id
		_modifiers[final_id] = modifier.duplicate(true)
		return final_id

	if not _modifiers.has(requested_id):
		_modifiers[requested_id] = modifier.duplicate(true)
		return requested_id

	var existing_variant: Variant = _modifiers.get(requested_id, {})
	var existing: Dictionary = existing_variant if existing_variant is Dictionary else {}
	match stacking_rule:
		STACK_REPLACE_STRONGER:
			var existing_value: float = abs(float(existing.get("value", 0.0)))
			var incoming_value: float = abs(float(modifier.get("value", 0.0)))
			if incoming_value >= existing_value:
				_modifiers[requested_id] = modifier.duplicate(true)
			else:
				existing["remaining"] = max(float(existing.get("remaining", 0.0)), float(modifier.get("duration", 0.0)))
				_modifiers[requested_id] = existing
		STACK_ADD:
			existing["value"] = float(existing.get("value", 0.0)) + float(modifier.get("value", 0.0))
			existing["remaining"] = max(float(existing.get("remaining", 0.0)), float(modifier.get("duration", 0.0)))
			existing["stacks"] = int(existing.get("stacks", 1)) + 1
			_modifiers[requested_id] = existing
		_:
			existing["value"] = modifier.get("value", existing.get("value", 0.0))
			existing["duration"] = float(modifier.get("duration", existing.get("duration", 0.0)))
			existing["remaining"] = float(modifier.get("duration", existing.get("duration", 0.0)))
			if modifier.has("tick_interval"):
				existing["tick_interval"] = float(modifier.get("tick_interval", existing.get("tick_interval", 1.0)))
				existing["tick_timer"] = float(existing.get("tick_interval", 1.0))
			existing["payload"] = modifier.get("payload", existing.get("payload", {}))
			existing["source"] = modifier.get("source", existing.get("source", null))
			_modifiers[requested_id] = existing

	return requested_id

func _next_modifier_id(prefix: String) -> String:
	_sequence += 1
	if prefix.is_empty():
		return "modifier_%d" % _sequence
	return "%s_%d" % [prefix, _sequence]

func _apply_dot_tick(modifier: Dictionary) -> void:
	var owner_node: Node = get_parent()
	if owner_node == null:
		return
	if not owner_node.has_method("apply_modifier_damage"):
		return
	var payload_variant: Variant = modifier.get("payload", {})
	var payload: Dictionary = payload_variant if payload_variant is Dictionary else {}
	owner_node.call(
		"apply_modifier_damage",
		float(modifier.get("value", 0.0)),
		modifier.get("source", null),
		payload
	)
