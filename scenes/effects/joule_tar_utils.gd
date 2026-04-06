extends RefCounted
class_name JouleTarUtils

const TAR_TAG: String = "joule_tar"
const TAR_MAX_TAG: String = "joule_tar_max"

const TAR_SLOW_ID: String = "joule_tar_slow"
const TAR_VULN_ID: String = "joule_tar_vuln"
const TAR_DOT_ID: String = "joule_tar_dot"
const TAR_MARKER_ID: String = "joule_tar_marker"
const TAR_MAX_MARKER_ID: String = "joule_tar_max_marker"

static func has_tar(enemy: Enemy) -> bool:
	if enemy == null or not is_instance_valid(enemy):
		return false
	var component: CombatModifierComponent = enemy.combat_modifier_component
	return component != null and component.has_tag_marker(TAR_TAG)

static func has_tar_max(enemy: Enemy) -> bool:
	if enemy == null or not is_instance_valid(enemy):
		return false
	var component: CombatModifierComponent = enemy.combat_modifier_component
	return component != null and component.has_tag_marker(TAR_MAX_TAG)

static func apply_tar(
	enemy: Enemy,
	source: Node,
	attack_value: float,
	empowered: bool = false,
	base_duration: float = 8.0,
	max_duration: float = 10.0,
	move_speed_multiplier: float = 0.7,
	skill_damage_taken_multiplier: float = 1.2,
	dot_ratio: float = 0.15,
	tick_interval: float = 0.5
) -> void:
	if enemy == null or not is_instance_valid(enemy) or enemy.is_dead:
		return
	var apply_empowered: bool = empowered or has_tar_max(enemy)
	var duration: float = max_duration if apply_empowered else base_duration
	var dot_damage: float = max(1.0, attack_value) * dot_ratio

	enemy.apply_move_speed_modifier(
		TAR_SLOW_ID,
		move_speed_multiplier,
		duration,
		CombatModifierComponent.STACK_REFRESH,
		source,
		{"kind": "joule_tar", "empowered": apply_empowered}
	)
	enemy.apply_vulnerable_modifier(
		TAR_VULN_ID,
		skill_damage_taken_multiplier,
		duration,
		CombatModifierComponent.STACK_REFRESH,
		source,
		{"kind": "joule_tar", "empowered": apply_empowered}
	)
	enemy.apply_damage_over_time_modifier(
		TAR_DOT_ID,
		dot_damage,
		duration,
		tick_interval,
		CombatModifierComponent.STACK_REFRESH,
		source,
		{"kind": "joule_tar_dot", "true_damage": true, "empowered": apply_empowered}
	)
	enemy.apply_tag_marker(
		TAR_MARKER_ID,
		TAR_TAG,
		duration,
		CombatModifierComponent.STACK_REFRESH,
		source,
		{"kind": "joule_tar", "empowered": apply_empowered}
	)
	if apply_empowered:
		enemy.apply_tag_marker(
			TAR_MAX_MARKER_ID,
			TAR_MAX_TAG,
			duration,
			CombatModifierComponent.STACK_REFRESH,
			source,
			{"kind": "joule_tar_max"}
		)

static func clear_tar(enemy: Enemy) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	var component: CombatModifierComponent = enemy.combat_modifier_component
	if component == null:
		return
	component.remove_modifier(TAR_SLOW_ID)
	component.remove_modifier(TAR_VULN_ID)
	component.remove_modifier(TAR_DOT_ID)
	component.clear_tag_marker(TAR_TAG)
	component.clear_tag_marker(TAR_MAX_TAG)
