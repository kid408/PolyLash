extends RefCounted
class_name SilkLinkUtils

const LINK_TAG: String = "soul_link"
const LINK_EMPOWERED_TAG: String = "soul_link_empowered"

const LINK_MARKER_ID: String = "soul_link_marker"
const LINK_EMPOWERED_MARKER_ID: String = "soul_link_empowered_marker"

static var _normal_transmission_ratio: float = 0.30
static var _empowered_transmission_ratio: float = 0.80

static func has_link(enemy: Enemy) -> bool:
	if enemy == null or not is_instance_valid(enemy):
		return false
	var component: CombatModifierComponent = enemy.combat_modifier_component
	return component != null and component.has_tag_marker(LINK_TAG)

static func has_empowered_link(enemy: Enemy) -> bool:
	if enemy == null or not is_instance_valid(enemy):
		return false
	var component: CombatModifierComponent = enemy.combat_modifier_component
	return component != null and component.has_tag_marker(LINK_EMPOWERED_TAG)

static func set_transmission_ratios(normal_ratio: float, empowered_ratio: float) -> void:
	_normal_transmission_ratio = max(0.0, normal_ratio)
	_empowered_transmission_ratio = max(_normal_transmission_ratio, empowered_ratio)

static func get_transmission_ratio(empowered: bool = false) -> float:
	return _empowered_transmission_ratio if empowered else _normal_transmission_ratio

static func apply_link(enemy: Enemy, source: Node, duration: float = 10.0, empowered: bool = false, empowered_duration: float = 15.0) -> void:
	if enemy == null or not is_instance_valid(enemy) or enemy.is_dead:
		return
	enemy.apply_tag_marker(
		LINK_MARKER_ID,
		LINK_TAG,
		duration,
		CombatModifierComponent.STACK_REFRESH,
		source,
		{
			"kind": "soul_link",
			"soul_link_skip_share": true,
		}
	)
	if empowered:
		enemy.apply_tag_marker(
			LINK_EMPOWERED_MARKER_ID,
			LINK_EMPOWERED_TAG,
			empowered_duration,
			CombatModifierComponent.STACK_REFRESH,
			source,
			{
				"kind": "soul_link_empowered",
				"soul_link_skip_share": true,
			}
		)

static func clear_link(enemy: Enemy) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	var component: CombatModifierComponent = enemy.combat_modifier_component
	if component == null:
		return
	component.clear_tag_marker(LINK_TAG)
	component.clear_tag_marker(LINK_EMPOWERED_TAG)
