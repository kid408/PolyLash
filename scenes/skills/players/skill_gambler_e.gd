extends SkillBase
class_name SkillGamblerE

## ==============================================================================
## 赌徒E技能 - 掷硬币
## ==============================================================================
## 
## 功能说明:
## - 按E键掷硬币，50%概率获得双倍攻击力Buff，50%概率自伤
## - 赌赢显示 "JACKPOT!" 浮动文字，赌输显示 "BUST!"
## 
## ==============================================================================

# ==============================================================================
# 技能参数（从CSV加载）
# ==============================================================================

## 赌赢攻击加成（1.0 = 100%）
var buff_value: float = 1.0

## 赌赢Buff持续时间
var buff_duration: float = 5.0

## 赌输自伤值
var self_damage: int = 30

# ==============================================================================
# 技能执行
# ==============================================================================

## 执行技能
func execute() -> void:
	if not consume_energy():
		if skill_owner:
			Global.spawn_floating_text(skill_owner.global_position, "No Energy!", Color.RED)
		return

	var owner_pos: Vector2 = skill_owner.global_position

	# 50/50 掷硬币
	if randf() < 0.5:
		# 赌赢：双倍攻击力Buff
		skill_owner.set_meta("attack_boost", buff_value)

		# Buff持续时间后移除
		var timer = get_tree().create_timer(buff_duration)
		var owner_ref = weakref(skill_owner)
		timer.timeout.connect(func():
			var owner = owner_ref.get_ref()
			if owner and is_instance_valid(owner) and owner.has_meta("attack_boost"):
				owner.remove_meta("attack_boost")
		)

		Global.on_camera_shake.emit(8.0, 0.2)
		Global.spawn_floating_text(owner_pos, "JACKPOT!", Color(1.0, 0.85, 0.0))
	else:
		# 赌输：自伤
		if skill_owner.has_node("HealthComponent"):
			skill_owner.health_component.take_damage(self_damage)
		elif "hp" in skill_owner:
			skill_owner.hp = max(skill_owner.hp - self_damage, 0)

		Global.on_camera_shake.emit(5.0, 0.15)
		Global.spawn_floating_text(owner_pos, "BUST!", Color(0.8, 0.2, 0.2))

	start_cooldown()
