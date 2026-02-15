extends SkillDrawingBase
class_name SkillVampireQ

## ==============================================================================
## 血族Q技能 - 血路与血池
## ==============================================================================
## 
## 功能说明:
## - 画线：消耗自身HP，沿路径创建血路，对接触的敌人造成伤害
## - 画圈闭合：在闭合区域内创建血池，为区域内队友提供100%生命偷取
## 
## ==============================================================================

# ==============================================================================
# 血族技能专属参数（从CSV加载）
# ==============================================================================

## 自伤比例（10%最大生命值）
var hp_cost_percent: float = 0.1

## 血路伤害
var blood_damage: int = 30

## 血池吸血比例（100%）
var lifesteal_value: float = 1.0

## 血池持续时间
var blood_pool_duration: float = 5.0

# ==============================================================================
# 实现基类虚函数
# ==============================================================================

## 生成血路效果（未闭合状态）
func _spawn_line_effect(start: Vector2, end: Vector2) -> void:
	# 自伤：消耗自身HP
	if skill_owner and skill_owner.has_node("HealthComponent"):
		var hc = skill_owner.health_component
		var cost = int(hc.max_health * hp_cost_percent)
		# 确保不会自杀，至少保留1点HP
		if hc.current_health > 1:
			var actual_cost = min(cost, int(hc.current_health) - 1)
			hc.take_damage(actual_cost)
			Global.spawn_floating_text(skill_owner.global_position, "-%d HP" % actual_cost, Color(0.7, 0.1, 0.1))

	# 创建血路（伤害线段效果）
	SkillEffectManager.create_line_effect({
		"start": start,
		"end": end,
		"width": 24.0,
		"damage": blood_damage,
		"damage_interval": 0.5,
		"duration": _get_line_duration(),
		"color": Color(0.7, 0.1, 0.1, 0.7)
	})

## 生成血池效果（闭合状态）
func _spawn_area_effect(polygon: PackedVector2Array) -> void:
	SkillEffectManager.create_buff_zone({
		"polygon": polygon,
		"duration": blood_pool_duration,
		"buff_type": "lifesteal",
		"buff_value": lifesteal_value,
		"tick_interval": 0.5,
		"color": Color(0.5, 0.0, 0.0, 0.5)
	})

## 获取规划线条颜色（暗红色/血色）
func _get_line_color() -> Color:
	return Color(0.7, 0.1, 0.1, 1.0)

## 获取闭合提示颜色
func _get_closure_color() -> Color:
	return Color(0.5, 0.0, 0.0, 1.0)
