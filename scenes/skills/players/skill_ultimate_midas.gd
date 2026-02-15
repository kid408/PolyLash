extends SkillUltimate
class_name SkillUltimateMidas

## ==============================================================================
## 炼金大招 - 黄金领域
## ==============================================================================
## 
## 效果：激活期间，周围敌人持续受到减速和伤害
## - 模拟"点金"光环，范围内敌人被石化减速
## ==============================================================================

var aura_radius: float = 200.0
var aura_damage: float = 15.0
var slow_amount: float = 0.8  # 80%减速

func _on_ultimate_activated() -> void:
	if player_ref:
		Global.spawn_floating_text(player_ref.global_position, "黄金领域!", Color(0.9, 0.7, 0.1))

func _on_ultimate_deactivated() -> void:
	pass

func _on_ultimate_update(delta: float) -> void:
	if not player_ref or not is_instance_valid(player_ref):
		return
	# 每0.5秒对范围内敌人造成伤害和减速
	if not has_meta("_aura_timer"):
		set_meta("_aura_timer", 0.0)
	var t = get_meta("_aura_timer") + delta
	if t >= 0.5:
		t -= 0.5
		var enemies = get_tree().get_nodes_in_group("enemies")
		for enemy in enemies:
			if not is_instance_valid(enemy):
				continue
			var dist = player_ref.global_position.distance_to(enemy.global_position)
			if dist <= aura_radius:
				if enemy.has_node("HealthComponent"):
					enemy.get_node("HealthComponent").take_damage(aura_damage)
				if enemy.has_method("apply_status"):
					enemy.apply_status("slow", 0.6, slow_amount, 1, 999.0)
	set_meta("_aura_timer", t)
