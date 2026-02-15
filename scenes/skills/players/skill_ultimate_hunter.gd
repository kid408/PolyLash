extends SkillUltimate
class_name SkillUltimateHunter

## ==============================================================================
## 猎人大招 - 猎杀本能
## ==============================================================================
## 
## 效果：激活期间，持续标记范围内所有敌人（伤害放大）
## ==============================================================================

var mark_radius: float = 400.0
var mark_damage_amp: float = 0.5  # 50%伤害放大

func _on_ultimate_activated() -> void:
	if player_ref:
		Global.spawn_floating_text(player_ref.global_position, "猎杀本能!", Color(0.2, 0.6, 0.2))

func _on_ultimate_deactivated() -> void:
	pass

func _on_ultimate_update(delta: float) -> void:
	if not player_ref or not is_instance_valid(player_ref):
		return
	# 每0.5秒标记范围内所有敌人
	if not has_meta("_mark_timer"):
		set_meta("_mark_timer", 0.0)
	var t = get_meta("_mark_timer") + delta
	if t >= 0.5:
		t -= 0.5
		var owner_pos = player_ref.global_position
		var enemies = get_tree().get_nodes_in_group("enemies")
		for enemy in enemies:
			if not is_instance_valid(enemy):
				continue
			if owner_pos.distance_to(enemy.global_position) > mark_radius:
				continue
			if enemy.has_method("apply_status"):
				enemy.apply_status("marked", 1.0, mark_damage_amp, 1, 999.0)
	set_meta("_mark_timer", t)
