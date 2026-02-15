extends SkillDrawingBase
class_name SkillNewTotemQ

## ==============================================================================
## 萨满Q技能 - 图腾+闪电链与地震
## ==============================================================================
## 
## 功能说明:
## - 画线：在起点和终点各放置一个图腾（create_summon），闪电链连接造成伤害
## - 画圈闭合：在闭合区域内创建地震效果（伤害 + slow）
## 
## ==============================================================================

# ==============================================================================
# 萨满技能专属参数（从CSV加载）
# ==============================================================================

## 图腾攻击伤害
var totem_damage: int = 20

## 图腾存活时间
var totem_duration: float = 10.0

## 闪电链伤害
var chain_damage: int = 15

## 地震伤害
var quake_damage: int = 35

## 地震减速比例（50%）
var slow_value: float = 0.5

## 地震持续时间
var quake_duration: float = 4.0

# ==============================================================================
# 实现基类虚函数
# ==============================================================================

## 生成图腾+闪电链效果（未闭合状态）
## 在起点和终点各放置一个图腾，闪电链连接
func _spawn_line_effect(start: Vector2, end: Vector2) -> void:
	# 在起点放置图腾
	SkillEffectManager.create_summon({
		"position": start,
		"summon_type": "turret",
		"duration": totem_duration,
		"damage": totem_damage,
		"attack_interval": 1.5,
		"attack_range": 200.0,
		"max_count": 6,
		"owner_skill_id": "skill_new_totem_q",
		"color": Color(0.6, 0.3, 0.8)
	})
	# 在终点放置图腾
	SkillEffectManager.create_summon({
		"position": end,
		"summon_type": "turret",
		"duration": totem_duration,
		"damage": totem_damage,
		"attack_interval": 1.5,
		"attack_range": 200.0,
		"max_count": 6,
		"owner_skill_id": "skill_new_totem_q",
		"color": Color(0.6, 0.3, 0.8)
	})
	# 闪电链连接两个图腾
	SkillEffectManager.create_line_effect({
		"start": start,
		"end": end,
		"width": 8.0,
		"damage": chain_damage,
		"damage_interval": 0.5,
		"duration": _get_line_duration(),
		"color": Color(0.7, 0.4, 1.0, 0.6)
	})

## 生成地震效果（闭合状态）
## 在闭合区域内创建地震伤害 + 减速
func _spawn_area_effect(polygon: PackedVector2Array) -> void:
	# 地震伤害区域
	SkillEffectManager.create_area_effect({
		"polygon": polygon,
		"damage": quake_damage,
		"damage_interval": 0.5,
		"duration": quake_duration,
		"color": Color(0.5, 0.2, 0.7, 0.4)
	})
	# 减速 Debuff 区域
	SkillEffectManager.create_debuff_zone({
		"polygon": polygon,
		"duration": quake_duration,
		"debuff_type": "slow",
		"debuff_value": slow_value,
		"debuff_duration": 2.0,
		"tick_interval": 0.5,
		"color": Color(0.4, 0.2, 0.6, 0.3)
	})

## 获取规划线条颜色（紫色/图腾色）
func _get_line_color() -> Color:
	return Color(0.6, 0.3, 0.8, 1.0)

## 获取闭合提示颜色
func _get_closure_color() -> Color:
	return Color(0.5, 0.2, 0.7, 1.0)
