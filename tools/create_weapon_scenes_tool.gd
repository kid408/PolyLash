@tool
extends EditorScript

## 武器场景自动创建工具
## 使用方法：
## 1. 在 Godot 编辑器中打开此脚本
## 2. 点击 File → Run（或按 Ctrl+Shift+X）
## 3. 检查输出面板查看创建结果

const OVERWRITE_EXISTING := false

func _run() -> void:
	print("========================================")
	print("开始创建武器场景...")
	print("========================================")
	
	# 确保文件夹存在
	ensure_directories()
	
	# 创建近战武器场景（4 个）
	create_melee_scene("weapon_melee_point", "拳头类")
	create_melee_scene("weapon_melee_thrust", "长矛类")
	create_melee_scene("weapon_melee_sector", "斧头类")
	create_melee_scene("weapon_melee_circle", "弯刀类")
	
	# 创建远程武器场景（3 个）
	create_range_scene("weapon_range_physical", "手枪/霰弹枪类", 50.0)
	create_range_scene("weapon_range_beam", "激光类", 60.0)
	create_range_scene("weapon_range_magic", "魔法棒类", 40.0)
	
	print("========================================")
	print("✅ 场景创建完成！")
	print("========================================")
	print("请在编辑器中打开场景验证：")
	print("  - scenes/weapons/melee/weapon_melee_point.tscn")
	print("  - scenes/weapons/melee/weapon_melee_thrust.tscn")
	print("  - scenes/weapons/melee/weapon_melee_sector.tscn")
	print("  - scenes/weapons/melee/weapon_melee_circle.tscn")
	print("  - scenes/weapons/range/weapon_range_physical.tscn")
	print("  - scenes/weapons/range/weapon_range_beam.tscn")
	print("  - scenes/weapons/range/weapon_range_magic.tscn")

## 确保必要的文件夹存在
func ensure_directories() -> void:
	var dir = DirAccess.open("res://")
	
	if not dir.dir_exists("scenes/weapons/melee"):
		dir.make_dir_recursive("scenes/weapons/melee")
		print("✓ 创建文件夹: scenes/weapons/melee")
	
	if not dir.dir_exists("scenes/weapons/range"):
		dir.make_dir_recursive("scenes/weapons/range")
		print("✓ 创建文件夹: scenes/weapons/range")

## 创建近战武器场景
func create_melee_scene(scene_name: String, description: String) -> void:
	print("\n--- 创建近战武器场景: %s (%s) ---" % [scene_name, description])
	
	# 创建根节点
	var weapon = Node2D.new()
	weapon.name = "Weapon"
	
	# 附加 Weapon 脚本
	var weapon_script = load("res://scenes/weapons/weapon.gd")
	if weapon_script:
		weapon.set_script(weapon_script)
		print("  ✓ 附加脚本: weapon.gd")
	else:
		push_warning("  ⚠ 警告: 未找到 weapon.gd 脚本")
	
	# 添加 Sprite2D
	var sprite = Sprite2D.new()
	sprite.name = "Sprite2D"
	sprite.unique_name_in_owner = true
	weapon.add_child(sprite)
	sprite.owner = weapon
	print("  ✓ 添加节点: Sprite2D")
	
	# 添加 HitboxComponent (Area2D)
	var hitbox = Area2D.new()
	hitbox.name = "HitboxComponent"
	hitbox.unique_name_in_owner = true
	
	# 设置碰撞层和掩码
	hitbox.collision_layer = 4  # Layer 3 (武器层)
	hitbox.collision_mask = 2   # Layer 2 (敌人层)
	
	# 附加 HitboxComponent 脚本
	var hitbox_script = load("res://scenes/components/hitbox_component.gd")
	if hitbox_script:
		hitbox.set_script(hitbox_script)
		print("  ✓ 附加脚本: hitbox_component.gd")
	else:
		push_warning("  ⚠ 警告: 未找到 hitbox_component.gd 脚本")
	
	weapon.add_child(hitbox)
	hitbox.owner = weapon
	print("  ✓ 添加节点: HitboxComponent (Area2D)")
	
	# 添加 CollisionShape2D（不设置 shape，由代码动态创建）
	var collision_shape = CollisionShape2D.new()
	collision_shape.name = "CollisionShape2D"
	collision_shape.disabled = true  # 初始禁用
	hitbox.add_child(collision_shape)
	collision_shape.owner = weapon
	print("  ✓ 添加节点: CollisionShape2D (初始禁用)")
	
	# 添加 CooldownTimer
	var timer = Timer.new()
	timer.name = "CooldownTimer"
	timer.unique_name_in_owner = true
	timer.one_shot = true
	timer.autostart = false
	weapon.add_child(timer)
	timer.owner = weapon
	print("  ✓ 添加节点: CooldownTimer")
	
	# 添加 WeaponBehavior (MeleeBehavior)
	var behavior = Node2D.new()
	behavior.name = "WeaponBehavior"
	behavior.unique_name_in_owner = true
	
	# 附加 MeleeBehavior 脚本
	var melee_script = load("res://scenes/weapons/melee/melee_behavior.gd")
	if melee_script:
		behavior.set_script(melee_script)
		print("  ✓ 附加脚本: melee_behavior.gd")
	else:
		push_warning("  ⚠ 警告: 未找到 melee_behavior.gd 脚本")
	
	weapon.add_child(behavior)
	behavior.owner = weapon
	print("  ✓ 添加节点: WeaponBehavior (MeleeBehavior)")
	
	# 保存场景
	var scene_path = "res://scenes/weapons/melee/%s.tscn" % scene_name
	if FileAccess.file_exists(scene_path) and not OVERWRITE_EXISTING:
		print("  ⚠ 场景已存在，跳过覆盖: %s" % scene_path)
		weapon.queue_free()
		return
	var packed_scene = PackedScene.new()
	var result = packed_scene.pack(weapon)
	
	if result == OK:
		var save_result = ResourceSaver.save(packed_scene, scene_path)
		if save_result == OK:
			print("  ✅ 场景已保存: %s" % scene_path)
		else:
			printerr("  ❌ 保存失败: %s (错误码: %d)" % [scene_path, save_result])
	else:
		printerr("  ❌ 打包失败: %s (错误码: %d)" % [scene_path, result])
	
	# 清理
	weapon.queue_free()

## 创建远程武器场景
func create_range_scene(scene_name: String, description: String, muzzle_x: float) -> void:
	print("\n--- 创建远程武器场景: %s (%s) ---" % [scene_name, description])
	
	# 创建根节点
	var weapon = Node2D.new()
	weapon.name = "Weapon"
	
	# 附加 Weapon 脚本
	var weapon_script = load("res://scenes/weapons/weapon.gd")
	if weapon_script:
		weapon.set_script(weapon_script)
		print("  ✓ 附加脚本: weapon.gd")
	else:
		push_warning("  ⚠ 警告: 未找到 weapon.gd 脚本")
	
	# 添加 Sprite2D
	var sprite = Sprite2D.new()
	sprite.name = "Sprite2D"
	sprite.unique_name_in_owner = true
	weapon.add_child(sprite)
	sprite.owner = weapon
	print("  ✓ 添加节点: Sprite2D")
	
	# 添加 HitboxComponent (Area2D)
	var hitbox = Area2D.new()
	hitbox.name = "HitboxComponent"
	hitbox.unique_name_in_owner = true
	hitbox.collision_layer = 4  # Layer 3
	hitbox.collision_mask = 2   # Layer 2
	
	var hitbox_script = load("res://scenes/components/hitbox_component.gd")
	if hitbox_script:
		hitbox.set_script(hitbox_script)
		print("  ✓ 附加脚本: hitbox_component.gd")
	else:
		push_warning("  ⚠ 警告: 未找到 hitbox_component.gd 脚本")
	
	weapon.add_child(hitbox)
	hitbox.owner = weapon
	print("  ✓ 添加节点: HitboxComponent (Area2D)")
	
	# 添加 CollisionShape2D
	var collision_shape = CollisionShape2D.new()
	collision_shape.name = "CollisionShape2D"
	collision_shape.disabled = true
	hitbox.add_child(collision_shape)
	collision_shape.owner = weapon
	print("  ✓ 添加节点: CollisionShape2D (初始禁用)")
	
	# 添加 CooldownTimer
	var timer = Timer.new()
	timer.name = "CooldownTimer"
	timer.unique_name_in_owner = true
	timer.one_shot = true
	timer.autostart = false
	weapon.add_child(timer)
	timer.owner = weapon
	print("  ✓ 添加节点: CooldownTimer")
	
	# 添加 WeaponBehavior (RangeBehavior)
	var behavior = Node2D.new()
	behavior.name = "WeaponBehavior"
	behavior.unique_name_in_owner = true
	
	var range_script = load("res://scenes/weapons/range/range_behavior.gd")
	if range_script:
		behavior.set_script(range_script)
		print("  ✓ 附加脚本: range_behavior.gd")
	else:
		push_warning("  ⚠ 警告: 未找到 range_behavior.gd 脚本")
	
	weapon.add_child(behavior)
	behavior.owner = weapon
	print("  ✓ 添加节点: WeaponBehavior (RangeBehavior)")
	
	# 添加 Muzzle (Marker2D) - 远程武器特有
	var muzzle = Marker2D.new()
	muzzle.name = "Muzzle"
	muzzle.unique_name_in_owner = true
	muzzle.position = Vector2(muzzle_x, 0)
	behavior.add_child(muzzle)
	muzzle.owner = weapon
	print("  ✓ 添加节点: Muzzle (Marker2D, position=%.1f)" % muzzle_x)
	
	# 保存场景
	var scene_path = "res://scenes/weapons/range/%s.tscn" % scene_name
	if FileAccess.file_exists(scene_path) and not OVERWRITE_EXISTING:
		print("  ⚠ 场景已存在，跳过覆盖: %s" % scene_path)
		weapon.queue_free()
		return
	var packed_scene = PackedScene.new()
	var result = packed_scene.pack(weapon)
	
	if result == OK:
		var save_result = ResourceSaver.save(packed_scene, scene_path)
		if save_result == OK:
			print("  ✅ 场景已保存: %s" % scene_path)
		else:
			printerr("  ❌ 保存失败: %s (错误码: %d)" % [scene_path, save_result])
	else:
		printerr("  ❌ 打包失败: %s (错误码: %d)" % [scene_path, result])
	
	# 清理
	weapon.queue_free()
