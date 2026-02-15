extends SkillUltimate
class_name SkillUltimateVacuum

## ==============================================================================
## 吸尘器大招 - 黑洞引擎
## ==============================================================================
## 
## 效果：激活期间，持续将周围敌人拉向玩家
## ==============================================================================

var pull_radius: float = 350.0
var pull_strength: float = 200.0

func _on_ultimate_activated() -> void:
	if player_ref:
		Global.spawn_floating_text(player_ref.global_position, "黑洞引擎!", Color(0.4, 0.2, 0.8))

func _on_ultimate_deactivated() -> void:
	pass

func _on_ultimate_update(delta: float) -> void:
	if not player_ref or not is_instance_valid(player_ref):
		return
	var owner_pos = player_ref.global_position
	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		var diff = owner_pos - enemy.global_position
		var dist = diff.length()
		if dist <= pull_radius and dist > 30.0:
			var pull_dir = diff.normalized()
			enemy.global_position += pull_dir * pull_strength * delta
