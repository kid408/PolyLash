extends Node

# Runtime bond resonance dispatcher driven by config.
const RESONANCE_CONFIG_PATH := "res://config/player/bond_resonance_config.csv"

var _resonance_rows: Dictionary = {} # {player_id: [row, ...]}
var _last_trigger_at: Dictionary = {} # {"player_id:resonance_id": timestamp}

func _ready() -> void:
	_load_resonance_config()
	if BondManager:
		if not BondManager.bond_level_changed.is_connected(_on_bond_level_changed):
			BondManager.bond_level_changed.connect(_on_bond_level_changed)
		if not BondManager.bonds_recalculated.is_connected(_on_bonds_recalculated):
			BondManager.bonds_recalculated.connect(_on_bonds_recalculated)
	print("[ResonanceRuntimeService] init complete, players=%d" % _resonance_rows.size())

func _load_resonance_config() -> void:
	_resonance_rows.clear()
	var rows: Array = ConfigRepository.load_bond_resonance_configs()
	for row in rows:
		if not (row is Dictionary):
			continue
		var player_id: String = str(row.get("player_id", "")).strip_edges()
		if player_id.is_empty():
			continue
		if not _resonance_rows.has(player_id):
			_resonance_rows[player_id] = []
		_resonance_rows[player_id].append(row)

func on_player_activated(player: Node) -> void:
	if not is_instance_valid(player):
		return
	if not ("player_id" in player):
		return
	_try_trigger_for_player(str(player.player_id), player, "player_activated")

func _on_bond_level_changed(_bond_id: String, _old_level: int, _new_level: int) -> void:
	if not is_instance_valid(Global.player):
		return
	on_player_activated(Global.player)

func _on_bonds_recalculated(_active_bonds: Dictionary) -> void:
	if not is_instance_valid(Global.player):
		return
	on_player_activated(Global.player)

func _try_trigger_for_player(player_id: String, player: Node, source: String) -> void:
	if player_id.is_empty() or not _resonance_rows.has(player_id):
		return

	var rows: Array = _resonance_rows[player_id] if _resonance_rows[player_id] is Array else []
	var now: float = _now_seconds()

	for row in rows:
		if not (row is Dictionary):
			continue
		var trigger_bond: String = str(row.get("trigger_bond", "")).strip_edges()
		var trigger_level: int = int(row.get("trigger_level", 3))
		var resonance_id: String = str(row.get("resonance_id", "")).strip_edges()
		var icd: float = max(0.0, float(row.get("icd", 8.0)))
		var duration: float = max(0.0, float(row.get("duration", 4.0)))

		if trigger_bond.is_empty() or resonance_id.is_empty():
			continue
		if BondManager.get_active_bond_level(trigger_bond) < trigger_level:
			continue

		var key: String = "%s:%s" % [player_id, resonance_id]
		var last: float = float(_last_trigger_at.get(key, -99999.0))
		if now - last < icd:
			continue

		var params: Dictionary = _parse_params_json(str(row.get("params_json", "{}")))
		if _apply_resonance(resonance_id, player, params, duration, source):
			_last_trigger_at[key] = now
			var telemetry: Node = get_node_or_null("/root/RunTelemetryService")
			if telemetry and telemetry.has_method("record_resonance_trigger"):
				telemetry.call("record_resonance_trigger", player_id, resonance_id, source)

func _apply_resonance(resonance_id: String, player: Node, params: Dictionary, duration: float, source: String) -> bool:
	match resonance_id:
		"resonance_switch_overdrive":
			return _apply_switch_overdrive(player, params, duration, source)
		"resonance_draw_echo":
			return _apply_draw_echo(player, params, source)
		"resonance_pulse_burst":
			return _apply_pulse_burst(player, params, source)
		"resonance_guard_link":
			return _apply_guard_link(player, params, source)
		_:
			if is_instance_valid(player):
				Global.spawn_floating_text(player.global_position, "RESONANCE!", Color(1.2, 1.4, 2.0))
			return true

func _apply_switch_overdrive(player: Node, params: Dictionary, duration: float, _source: String) -> bool:
	if not is_instance_valid(player):
		return false
	var cd_reduction: float = float(params.get("cooldown_reduction", 0.25))
	if cd_reduction <= 0.0:
		return false

	var old_value: float = 0.0
	if player.has_meta("buff_cooldown_reduction"):
		old_value = float(player.get_meta("buff_cooldown_reduction"))
	var apply_value: float = clamp(old_value + cd_reduction, 0.0, 0.9)
	player.set_meta("buff_cooldown_reduction", apply_value)

	if duration > 0.0:
		var player_ref: WeakRef = weakref(player)
		get_tree().create_timer(duration).timeout.connect(func() -> void:
			var p: Object = player_ref.get_ref()
			if not p or not is_instance_valid(p):
				return
			var cur: float = float(p.get_meta("buff_cooldown_reduction", 0.0))
			var restored: float = max(0.0, cur - cd_reduction)
			if restored <= 0.0 and p.has_meta("buff_cooldown_reduction"):
				p.remove_meta("buff_cooldown_reduction")
			else:
				p.set_meta("buff_cooldown_reduction", restored)
		)

	Global.spawn_floating_text(player.global_position, "RESONANCE: OVERDRIVE", Color(1.4, 0.9, 2.0))
	SoundManager.play("bond_trigger_generic")
	return true

func _apply_draw_echo(player: Node, params: Dictionary, _source: String) -> bool:
	if not is_instance_valid(player) or not ("player_id" in player):
		return false
	var damage_scale: float = float(params.get("damage_scale", 0.35))
	var base_damage: float = 15.0
	if "damage" in player:
		base_damage = float(player.damage)
	var hits: int = Global.trigger_mirror_draw_from_player(str(player.player_id), player.global_position, base_damage * damage_scale)
	return hits > 0

func _apply_pulse_burst(player: Node, params: Dictionary, _source: String) -> bool:
	if not is_instance_valid(player):
		return false
	var radius: float = max(40.0, float(params.get("radius", 220.0)))
	var damage_scale: float = max(0.05, float(params.get("damage_scale", 0.45)))
	var base_damage: float = 20.0
	if "damage" in player:
		base_damage = float(player.damage)
	var damage: int = max(1, int(round(base_damage * damage_scale)))
	var hit_count: int = 0

	var enemies: Array = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if not is_instance_valid(enemy) or not enemy.has_node("HealthComponent"):
			continue
		if enemy.global_position.distance_to(player.global_position) > radius:
			continue
		var hc: Variant = enemy.get_node("HealthComponent")
		hc.take_damage(damage)
		hit_count += 1
		Global.spawn_floating_text(enemy.global_position, "PULSE!", Color(1.0, 1.5, 2.0))

	if hit_count > 0:
		Global.spawn_floating_text(player.global_position, "RESONANCE BURST", Color(1.2, 1.6, 2.0))
		SoundManager.play("bond_trigger_generic")
	return hit_count > 0

func _apply_guard_link(player: Node, params: Dictionary, _source: String) -> bool:
	if not is_instance_valid(player):
		return false
	if not ("armor" in player) or not ("max_armor" in player):
		return false
	var armor_bonus: int = max(1, int(params.get("armor_bonus", 1)))
	player.armor = min(int(player.max_armor), int(player.armor) + armor_bonus)
	if player.has_method("update_ui_signals"):
		player.update_ui_signals()
	Global.spawn_floating_text(player.global_position, "RESONANCE: GUARD", Color(0.8, 1.2, 2.0))
	SoundManager.play("bond_trigger_generic")
	return true

func _parse_params_json(text: String) -> Dictionary:
	var raw: String = text.strip_edges()
	if raw.is_empty():
		return {}
	var parsed: Variant = JSON.parse_string(raw)
	return parsed if parsed is Dictionary else {}

func _now_seconds() -> float:
	return float(Time.get_ticks_msec()) / 1000.0
