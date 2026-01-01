extends WeaponBehavior
class_name RangeBehavior

@onready var muzzle: Marker2D = %Muzzle

func execute_attack() -> void:
	weapon.is_attacking = true
	
	# 增强打击感：射击时轻微顿帧和指向性震动
	Global.frame_freeze(0.01, 0.7)  # 减弱顿帧
	
	# 指向性震动：根据射击方向产生后坐力震动（减弱强度）
	var shoot_direction = Vector2.RIGHT.rotated(weapon.rotation)
	Global.on_directional_shake.emit(shoot_direction, 0.5)  # 从1.5降低到0.5
	
	create_projectile()
	var tween := create_tween()
	var attack_pos:= Vector2(weapon.atk_start_pos.x - weapon.data.stats.recoil,weapon.atk_start_pos.y)
	tween.tween_property(weapon.sprite,"position",attack_pos,weapon.data.stats.recoil_duration)
	tween.tween_property(weapon.sprite,"position",weapon.atk_start_pos,weapon.data.stats.recoil_duration)
	
	await tween.finished
	
	weapon.is_attacking = false
	critical = false
	
func create_projectile() -> void:
	# 安全检查
	if not weapon or not weapon.data or not weapon.data.stats:
		printerr("[RangeBehavior] 错误: weapon 或 weapon.data 或 weapon.data.stats 为空")
		return
	
	if not weapon.data.stats.projectile_scene:
		printerr("[RangeBehavior] 错误: projectile_scene 为空 - 武器: ", weapon.data.item_name if weapon.data else "未知")
		return
	
	var instance := weapon.data.stats.projectile_scene.instantiate() as Projectile
	get_tree().root.add_child(instance)
	instance.global_position = muzzle.global_position
	
	var velocity := Vector2.RIGHT.rotated(weapon.rotation) * weapon.data.stats.projectile_speed
	instance.set_projectile(velocity,get_damage(),critical,weapon.data.stats.knockback,weapon.get_parent())
