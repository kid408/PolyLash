extends RefCounted
class_name PurchaseEffectPipeline

# ============================================================================
# PurchaseEffectPipeline - 商店效果处理器注册表
# ============================================================================

static var _handlers: Dictionary = {}
static var _target_handlers: Dictionary = {}
static var _initialized: bool = false

static func register_handler(effect_type: String, handler: Callable) -> void:
	if effect_type.is_empty() or not handler.is_valid():
		return
	_handlers[effect_type] = handler

static func register_target_handler(effect_target: String, handler: Callable) -> void:
	if effect_target.is_empty() or not handler.is_valid():
		return
	_target_handlers[effect_target] = handler

static func has_handler(effect_type: String) -> bool:
	_ensure_initialized()
	return _handlers.has(effect_type)

static func has_target_handler(effect_target: String) -> bool:
	_ensure_initialized()
	return _target_handlers.has(effect_target)

static func apply_from_tags(player: PlayerBase, target_tags: Array, value: float, effect_type: String = "", context: Dictionary = {}) -> bool:
	_ensure_initialized()

	var key := effect_type.strip_edges()
	if key in ["flat_add", "percent_add", "percent", "flat"]:
		key = ""
	if key.is_empty() and not target_tags.is_empty():
		key = str(target_tags[0])

	if key.is_empty():
		return false

	var handler: Callable = _handlers.get(key, Callable())
	if not handler.is_valid():
		push_warning("[PurchaseEffectPipeline] 未注册 effect handler: %s" % key)
		return false

	return bool(handler.call(player, value, context))

static func apply_effect(player: PlayerBase, effect: Dictionary, context: Dictionary = {}) -> bool:
	_ensure_initialized()
	if effect.is_empty():
		return true

	var effect_target := str(effect.get("effect_target", "stat")).strip_edges()
	if effect_target.is_empty():
		effect_target = "stat"

	var target_handler: Callable = _target_handlers.get(effect_target, Callable())
	if not target_handler.is_valid():
		push_warning("[PurchaseEffectPipeline] 未注册 effect_target handler: %s" % effect_target)
		return false

	return bool(target_handler.call(player, effect, context))

static func _ensure_initialized() -> void:
	if _initialized:
		return
	_initialized = true

	register_target_handler("stat", Callable(PurchaseEffectPipeline, "_handle_stat_target"))
	register_target_handler("modifier", Callable(PurchaseEffectPipeline, "_handle_modifier_target"))
	register_target_handler("bond", Callable(PurchaseEffectPipeline, "_handle_bond_target"))

	register_handler("max_health", Callable(PurchaseEffectPipeline, "_handle_max_health"))
	register_handler("speed", Callable(PurchaseEffectPipeline, "_handle_speed"))
	register_handler("damage", Callable(PurchaseEffectPipeline, "_handle_damage"))
	register_handler("armor", Callable(PurchaseEffectPipeline, "_handle_armor"))
	register_handler("crit_chance", Callable(PurchaseEffectPipeline, "_handle_crit_chance"))
	register_handler("attack_speed", Callable(PurchaseEffectPipeline, "_handle_attack_speed"))
	register_handler("regen", Callable(PurchaseEffectPipeline, "_handle_regen"))
	register_handler("gold_gain", Callable(PurchaseEffectPipeline, "_handle_gold_gain"))
	register_handler("exp_gain", Callable(PurchaseEffectPipeline, "_handle_exp_gain"))

static func _handle_stat_target(player: PlayerBase, effect: Dictionary, context: Dictionary) -> bool:
	var tags_raw = effect.get("target_tags", [])
	var tags: Array = tags_raw if tags_raw is Array else []
	var value: float = float(effect.get("effect_value", effect.get("value", 0.0)))
	var effect_type: String = str(effect.get("effect_type", "")).strip_edges()
	var value_type: String = str(effect.get("value_type", "flat")).strip_edges()

	# stat 目标优先按目标标签分发，flat_add/percent_add 只是数值形态，不是处理器键。
	if effect_type in ["flat_add", "percent_add", "flat", "percent"]:
		effect_type = ""

	# 某些配置用 percent 且填写整数百分比（如 12），这里统一转换为小数。
	if value_type == "percent" and abs(value) > 1.0 and not tags.is_empty():
		if str(tags[0]) in ["gold_gain", "exp_gain", "attack_speed", "crit_chance"]:
			value = value / 100.0

	return apply_from_tags(player, tags, value, effect_type, context)

static func _handle_modifier_target(_player: PlayerBase, effect: Dictionary, _context: Dictionary) -> bool:
	var tags_raw = effect.get("target_tags", [])
	var tags: Array = tags_raw if tags_raw is Array else []
	if tags.is_empty():
		return false

	var value: float = float(effect.get("effect_value", effect.get("value", 0.0)))
	var value_type: String = str(effect.get("value_type", "")).strip_edges()
	var modifier_type: String = str(effect.get("effect_type", "")).strip_edges()

	if modifier_type.is_empty():
		modifier_type = "percent_add" if value_type == "percent" else "flat_add"
	elif modifier_type == "percent":
		modifier_type = "percent_add"
	elif modifier_type == "flat":
		modifier_type = "flat_add"

	ModifierManager.add_modifier(tags, modifier_type, value)
	return true

static func _handle_bond_target(_player: PlayerBase, effect: Dictionary, _context: Dictionary) -> bool:
	var tags_raw = effect.get("target_tags", [])
	var tags: Array = tags_raw if tags_raw is Array else []
	if tags.is_empty():
		return false

	var changed := false
	for tag in tags:
		var tag_text := str(tag).strip_edges()
		if tag_text.is_empty():
			continue
		BondManager.add_temp_tag(tag_text)
		changed = true
	return changed

static func _handle_max_health(player: PlayerBase, value: float, _context: Dictionary) -> bool:
	if player == null or not player.has_node("HealthComponent"):
		return false
	var health_comp = player.get_node("HealthComponent")
	health_comp.max_health += value
	health_comp.current_health = min(health_comp.current_health, health_comp.max_health)
	return true

static func _handle_speed(player: PlayerBase, value: float, _context: Dictionary) -> bool:
	if player == null or not ("speed" in player):
		return false
	player.speed += value
	return true

static func _handle_damage(player: PlayerBase, value: float, _context: Dictionary) -> bool:
	if player == null or not ("damage" in player):
		return false
	player.damage += value
	return true

static func _handle_armor(player: PlayerBase, value: float, _context: Dictionary) -> bool:
	if player == null or not ("max_armor" in player):
		return false
	player.max_armor += int(value)
	player.armor = min(player.armor, player.max_armor)
	return true

static func _handle_crit_chance(_player: PlayerBase, value: float, _context: Dictionary) -> bool:
	UpgradeManager.add_attribute_bonus("crit_chance", value)
	return true

static func _handle_attack_speed(player: PlayerBase, value: float, _context: Dictionary) -> bool:
	if player == null:
		return false
	var old_bonus: float = 0.0
	if player.has_meta("buff_attack_speed_bonus"):
		old_bonus = float(player.get_meta("buff_attack_speed_bonus"))
	var new_bonus: float = clamp(old_bonus + value, -0.8, 3.0)
	player.set_meta("buff_attack_speed_bonus", new_bonus)
	return true

static func _handle_regen(player: PlayerBase, value: float, _context: Dictionary) -> bool:
	if player == null:
		return false
	if "regen" in player:
		player.regen += value
		return true
	if "health_regen" in player:
		player.health_regen += value
		return true
	return false

static func _handle_gold_gain(_player: PlayerBase, value: float, _context: Dictionary) -> bool:
	RunStateService.set_gold_gain_multiplier(max(0.0, RunStateService.get_gold_gain_multiplier() + value))
	return true

static func _handle_exp_gain(_player: PlayerBase, value: float, _context: Dictionary) -> bool:
	RunStateService.set_xp_gain_multiplier(max(0.0, RunStateService.get_xp_gain_multiplier() + value))
	return true
