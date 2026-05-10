extends RefCounted
class_name CombatEventTypes

enum DamageType {
	DIRECT,
	AOE,
	DOT,
	TRUE_DAMAGE,
}

static func normalize_damage_type(raw_value: Variant, default_value: int = DamageType.DIRECT) -> int:
	if raw_value is int:
		var type_value: int = int(raw_value)
		if type_value >= DamageType.DIRECT and type_value <= DamageType.TRUE_DAMAGE:
			return type_value

	var text_value: String = str(raw_value).strip_edges().to_upper()
	match text_value:
		"AOE", "DMG_AOE":
			return DamageType.AOE
		"DOT", "DMG_DOT":
			return DamageType.DOT
		"TRUE_DAMAGE", "TRUE", "DMG_TRUE", "DMG_TRUE_DAMAGE":
			return DamageType.TRUE_DAMAGE
		"DIRECT", "DMG_DIRECT":
			return DamageType.DIRECT
		_:
			return default_value

static func damage_type_to_name(raw_value: Variant) -> String:
	match normalize_damage_type(raw_value):
		DamageType.AOE:
			return "aoe"
		DamageType.DOT:
			return "dot"
		DamageType.TRUE_DAMAGE:
			return "true_damage"
		_:
			return "direct"
