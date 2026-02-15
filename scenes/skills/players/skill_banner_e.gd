extends SkillBase
class_name SkillBannerE

## ==============================================================================
## 旗手E技能 - 全队移速爆发
## ==============================================================================
## 
## 功能说明:
## - 按E键吹响号角，为全队提供短暂的移速爆发加成
## - 通过 set_meta("buff_speed_boost") 为所有队友添加移速加成
## 
## ==============================================================================

# ==============================================================================
# 旗手E技能专属参数（从CSV加载）
# ==============================================================================

## 移速加成值（50%）
var speed_boost_value: float = 0.5

## 移速加成持续时间
var speed_boost_duration: float = 4.0

# ==============================================================================
# 技能执行
# ==============================================================================

## 执行技能
func execute() -> void:
	if not consume_energy():
		if skill_owner:
			Global.spawn_floating_text(skill_owner.global_position, "No Energy!", Color.RED)
		return

	# 为全队添加移速加成
	var players = get_tree().get_nodes_in_group("player")
	for player in players:
		if not is_instance_valid(player):
			continue
		player.set_meta("buff_speed_boost", speed_boost_value)
		var p = player
		var timer = get_tree().create_timer(speed_boost_duration)
		timer.timeout.connect(func():
			if is_instance_valid(p):
				if p.has_meta("buff_speed_boost"):
					p.remove_meta("buff_speed_boost")
		)

	Global.on_camera_shake.emit(5.0, 0.15)
	Global.spawn_floating_text(skill_owner.global_position, "CHARGE!", Color(0.9, 0.2, 0.2))
	start_cooldown()
