extends SkillDrawingBase
class_name SkillGooQ

## ==============================================================================
## 软泥Q技能 - 超级胶水与分裂池
## ==============================================================================
## 
## 功能说明:
## - 画线：沿路径创建超级胶水区域，对经过的敌人施加 90% 减速
## - 画圈闭合：创建分裂池，对区域内敌人造成伤害并在中心生成迷你史莱姆
## 
## ==============================================================================

# ==============================================================================
# 软泥技能专属参数（从CSV加载）
# ==============================================================================

## 超级胶水减速值（90%）
var slow_value: float = 0.9

## 减速持续时间
var slow_duration: float = 4.0

## 分裂池伤害
var pool_damage: int = 20

## 分裂池持续时间
var pool_duration: float = 5.0

## 迷你史莱姆数量
var slime_count: int = 2

# ==============================================================================
# 实现基类虚函数
# ==============================================================================

## 生成超级胶水效果（未闭合状态）
## 沿路径创建 debuff zone，施加 90% 减速
func _spawn_line_effect(start: Vector2, end: Vector2) -> void:
	SkillEffectManager.create_debuff_zone({
		"start": start,
		"end": end,
		"width": 24.0,
		"duration": _get_line_duration(),
		"debuff_type": "slow",
		"debuff_value": slow_value,
		"debuff_duration": slow_duration,
		"tick_interval": 0.5,
		"color": Color(0.3, 0.9, 0.2, 0.5)
	})

## 生成分裂池效果（闭合状态）
## 创建伤害区域 + 在中心生成迷你史莱姆
func _spawn_area_effect(polygon: PackedVector2Array) -> void:
	# 分裂池伤害区域
	SkillEffectManager.create_area_effect({
		"polygon": polygon,
		"damage": pool_damage,
		"damage_interval": 1.0,
		"duration": pool_duration,
		"color": Color(0.2, 0.8, 0.1, 0.4)
	})

	# 在多边形中心生成迷你史莱姆
	var center = _get_polygon_center(polygon)
	for i in range(slime_count):
		var offset = Vector2(randf_range(-40, 40), randf_range(-40, 40))
		SkillEffectManager.create_summon({
			"position": center + offset,
			"summon_type": "slime",
			"duration": pool_duration,
			"damage": pool_damage,
			"attack_interval": 1.0,
			"attack_range": 100.0,
			"max_count": 6,
			"owner_skill_id": "skill_goo_q",
			"color": Color(0.3, 0.9, 0.2, 0.8)
		})

## 计算多边形中心点
func _get_polygon_center(polygon: PackedVector2Array) -> Vector2:
	var center = Vector2.ZERO
	for p in polygon:
		center += p
	return center / polygon.size()

## 获取规划线条颜色（石灰绿/史莱姆色）
func _get_line_color() -> Color:
	return Color(0.3, 0.9, 0.2, 1.0)

## 获取闭合提示颜色
func _get_closure_color() -> Color:
	return Color(0.2, 0.8, 0.1, 1.0)
