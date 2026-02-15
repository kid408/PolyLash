extends SkillUltimate
class_name SkillUltimateGambler

## ==============================================================================
## 赌徒大招 - 全押
## ==============================================================================
## 
## 效果：激活期间，所有攻击必定暴击
## - 通过 meta "ult_guaranteed_crit" 标记玩家
## - 武器攻击逻辑检查此 meta
## - 同时攻击力翻倍
## ==============================================================================

var attack_boost: float = 1.0  # +100% 攻击力

func _on_ultimate_activated() -> void:
	if player_ref:
		player_ref.set_meta("ult_guaranteed_crit", true)
		player_ref.set_meta("attack_boost", attack_boost)
		Global.spawn_floating_text(player_ref.global_position, "ALL IN!", Color(1.0, 0.85, 0.0))

func _on_ultimate_deactivated() -> void:
	if player_ref:
		if player_ref.has_meta("ult_guaranteed_crit"):
			player_ref.remove_meta("ult_guaranteed_crit")
		if player_ref.has_meta("attack_boost"):
			player_ref.remove_meta("attack_boost")

func _on_ultimate_update(delta: float) -> void:
	pass
