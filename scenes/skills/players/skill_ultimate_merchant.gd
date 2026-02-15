extends SkillUltimate
class_name SkillUltimateMerchant

## ==============================================================================
## 商人大招 - 金币风暴
## ==============================================================================
## 
## 效果：激活期间，击杀敌人额外掉落金币
## - 通过 meta "ult_gold_bonus" 标记玩家
## - 敌人死亡逻辑检查此 meta 并额外生成金币
## ==============================================================================

var gold_bonus_per_kill: int = 10

func _on_ultimate_activated() -> void:
	if player_ref:
		player_ref.set_meta("ult_gold_bonus", gold_bonus_per_kill)
		Global.spawn_floating_text(player_ref.global_position, "金币风暴!", Color(1.0, 0.85, 0.0))

func _on_ultimate_deactivated() -> void:
	if player_ref and player_ref.has_meta("ult_gold_bonus"):
		player_ref.remove_meta("ult_gold_bonus")

func _on_ultimate_update(delta: float) -> void:
	# 每秒在玩家周围生成少量金币
	if not player_ref or not is_instance_valid(player_ref):
		return
	# 使用计数器控制频率（每2秒一次）
	if not has_meta("_gold_timer"):
		set_meta("_gold_timer", 0.0)
	var t = get_meta("_gold_timer") + delta
	if t >= 2.0:
		t -= 2.0
		Global.spawn_coin(player_ref.global_position + Vector2(randf_range(-50, 50), randf_range(-50, 50)), 5)
	set_meta("_gold_timer", t)
