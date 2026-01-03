extends SkillBase
class_name SkillHerderExplosion

## ==============================================================================
## 牧羊人E技能 - 范围爆炸
## ==============================================================================
## 
## 功能说明:
## - 在玩家位置释放范围爆炸
## - 对范围内敌人造成伤害和击退
## - 爆炸后增加护甲
## - 显示视觉效果和震屏
## 
## 使用方法:
##   - 按E键触发
##   - 自动影响范围内所有敌人
## 
## ==============================================================================

# ==============================================================================
# 技能参数（从CSV加载）
# ==============================================================================

## 爆炸半径
var explosion_radius: float = 200.0

## 爆炸伤害
var explosion_damage: int = 100

## 击退力度
var explosion_knockback: float = 500.0

# ==============================================================================
# 视觉配置
# ==============================================================================

## 爆炸视觉颜色
var explosion_color: Color = Color(1, 0.0, 0.0, 0.6)

# ==============================================================================
# 生命周期
# ==============================================================================

func _ready() -> void:
	super._ready()

# ==============================================================================
# 技能执行
# ==============================================================================

## 执行爆炸技能
func execute() -> void:
	# 检查是否可以执行
	if not can_execute():
		if is_on_cooldown:
			if skill_owner:
				Global.spawn_floating_text(skill_owner.global_position, "Cooldown!", Color.YELLOW)
		return
	
	# 消耗能量
	if not consume_energy():
		if skill_owner:
			Global.spawn_floating_text(skill_owner.global_position, "No Energy!", Color.RED)
		return
	
	# 执行爆炸效果
	_perform_explosion()
	
	# 开始冷却
	start_cooldown()

## 执行爆炸效果
func _perform_explosion() -> void:
	if not skill_owner:
		return
	
	# 震屏效果
	Global.on_camera_shake.emit(10.0, 0.3)
	
	# 播放音效
	Global.play_player_explosion()
	
	# 创建视觉效果
	_create_explosion_visual(explosion_radius)
	
	# 查找并伤害范围内的敌人
	var enemies = get_tree().get_nodes_in_group("enemies")
	var hit_count = 0
	
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		
		# 检查距离
		if skill_owner.global_position.distance_to(enemy.global_position) < explosion_radius:
			_apply_explosion_damage(enemy)
			hit_count += 1
	
	# 增加护甲
	_apply_armor_bonus()
	
	# 显示命中提示
	if hit_count > 0:
		Global.spawn_floating_text(skill_owner.global_position, "HIT x%d" % hit_count, Color.ORANGE)

## 应用爆炸伤害到单个敌人
func _apply_explosion_damage(enemy: Node2D) -> void:
	if not skill_owner:
		return
	
	# 应用击退
	if enemy.has_method("apply_knockback"):
		var dir = (enemy.global_position - skill_owner.global_position).normalized()
		enemy.apply_knockback(dir, explosion_knockback)
	
	# 应用伤害
	if enemy.has_node("HealthComponent"):
		enemy.health_component.take_damage(explosion_damage)
		Global.spawn_floating_text(enemy.global_position, str(explosion_damage), Color.ORANGE)

## 应用护甲加成
func _apply_armor_bonus() -> void:
	if not skill_owner:
		return
	
	# 检查是否有护甲系统
	if "armor" in skill_owner and "max_armor" in skill_owner:
		if skill_owner.armor < skill_owner.max_armor:
			skill_owner.armor += 1
			Global.spawn_floating_text(skill_owner.global_position, "+Armor", Color.CYAN)
			
			# 触发护甲变化信号
			if skill_owner.has_signal("armor_changed"):
				skill_owner.armor_changed.emit(skill_owner.armor)

## 创建爆炸视觉效果
func _create_explosion_visual(radius: float) -> void:
	if not skill_owner:
		return
	
	# 创建圆形多边形
	var circle_node = Polygon2D.new()
	var points = PackedVector2Array()
	
	# 生成圆形多边形
	for i in range(32):
		var angle = i * TAU / 32
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	
	circle_node.polygon = points
	circle_node.color = explosion_color
	circle_node.color.a = 0.6
	circle_node.z_index = 90
	circle_node.global_position = skill_owner.global_position
	
	# 添加到场景
	get_tree().current_scene.add_child(circle_node)
	
	# 动画效果
	var tween = circle_node.create_tween()
	tween.tween_property(circle_node, "color:a", 0.0, 0.4)
	tween.tween_callback(_cleanup_visual_node.bind(circle_node))

## 清理视觉节点
func _cleanup_visual_node(node: Node2D) -> void:
	if is_instance_valid(node):
		node.queue_free()

# ==============================================================================
# 辅助方法
# ==============================================================================

## 打印调试信息
func print_debug_info() -> void:
	print("[SkillHerderExplosion] 调试信息:")
	print("  - explosion_radius: %.0f" % explosion_radius)
	print("  - explosion_damage: %d" % explosion_damage)
	print("  - explosion_knockback: %.0f" % explosion_knockback)
	print("  - energy_cost: %.0f" % energy_cost)
	print("  - cooldown_time: %.1f" % cooldown_time)
