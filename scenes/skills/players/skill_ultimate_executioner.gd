extends SkillUltimate
class_name SkillUltimateExecutioner

## ==============================================================================
## 处刑大招 - 死刑宣告
## ==============================================================================
## 
## 效果：激活期间，处决阈值提升至50%
## - 通过 meta "ult_execute_threshold" 标记玩家
## - 处刑E技能和普通攻击可以读取此 meta
## - 同时每秒对范围内低血量敌人造成额外伤害
## ==============================================================================

var enhanced_threshold: float = 0.5
var execute_radius: float = 250.0
var execute_damage: int = 9999

func _on_ultimate_activated() -> void:
	if player_ref:
		player_ref.set_meta("ult_execute_threshold", enhanced_threshold)
		Global.spawn_floating_text(player_ref.global_position, "死刑宣告!", Color(0.6, 0.0, 0.0))

func _on_ultimate_deactivated() -> void:
	if player_ref and player_ref.has_meta("ult_execute_threshold"):
		player_ref.remove_meta("ult_execute_threshold")

func _on_ultimate_update(delta: float) -> void:
	if not player_ref or not is_instance_valid(player_ref):
		return
	# 每1秒扫描一次，处决低血量敌人
	if not has_meta("_exec_timer"):
		set_meta("_exec_timer", 0.0)
	var t = get_meta("_exec_timer") + delta
	if t >= 1.0:
		t -= 1.0
		var owner_pos = player_ref.global_position
		var enemies = get_tree().get_nodes_in_group("enemies")
		for enemy in enemies:
			if not is_instance_valid(enemy):
				continue
			if owner_pos.distance_to(enemy.global_position) > execute_radius:
				continue
			if enemy.has_node("HealthComponent"):
				var hc = enemy.get_node("HealthComponent")
				if hc.max_health > 0 and hc.current_health <= hc.max_health * enhanced_threshold:
					hc.take_damage(execute_damage)
					Global.spawn_floating_text(enemy.global_position, "EXECUTE!", Color(0.6, 0.1, 0.1))
	set_meta("_exec_timer", t)
