extends WeaponBehavior
class_name MeleeBehavior

@export var hitbox:HitboxComponent

func execute_attack() -> void:
	weapon.is_attacking = true
	
	# 增强打击感：攻击时轻微顿帧
	Global.frame_freeze(0.02, 0.5)
	
	# 指向性震动：根据武器朝向产生震动（减弱强度）
	var attack_direction = Vector2.RIGHT.rotated(weapon.rotation)
	Global.on_directional_shake.emit(attack_direction, 0.8)  # 从2.0降低到0.8
	
	var tween := create_tween()
	
	var recoil_pos := Vector2(weapon.atk_start_pos.x - weapon.data.stats.recoil,weapon.atk_start_pos.y)
	tween.tween_property(weapon.sprite,"position",recoil_pos,weapon.data.stats.recoil_duration)
	
	hitbox.enable()
	hitbox.setup(get_damage(),critical,weapon.data.stats.knockback,weapon.get_parent())
	
	var attack_pos := Vector2(weapon.atk_start_pos.x + weapon.data.stats.max_range,weapon.atk_start_pos.y)
	
	tween.tween_property(weapon.sprite,"position",attack_pos,weapon.data.stats.attack_duration)
	
	tween.tween_property(weapon.sprite,"position",weapon.atk_start_pos,weapon.data.stats.back_duration)
	
	tween.finished.connect(func():
		hitbox.disable()
		weapon.is_attacking = false
		critical = false
	)
