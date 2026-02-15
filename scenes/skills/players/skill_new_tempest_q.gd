extends SkillDrawingBase
class_name SkillNewTempestQ

## ==============================================================================
## 新风暴Q技能 - 风带与台风眼
## ==============================================================================
## 
## 功能说明:
## - 画线：沿路径创建风带，为经过的队友提供大幅移速加成
## - 画圈闭合：在闭合区域内创建台风眼效果，将区域内敌人持续拉向中心
## 
## ==============================================================================

# ==============================================================================
# 新风暴技能专属参数（从CSV加载）
# ==============================================================================

## 加速比例
var speed_boost_value: float = 0.5

## 风带Buff持续时间
var buff_duration: float = 4.0

## 台风眼每跳伤害
var pull_damage: int = 20

## 台风眼吸力
var pull_force: float = 300.0

## 台风眼持续时间
var area_duration: float = 5.0

# ==============================================================================
# 实现基类虚函数
# ==============================================================================

## 生成风带效果（未闭合状态）
func _spawn_line_effect(start: Vector2, end: Vector2) -> void:
	SkillEffectManager.create_buff_zone({
		"start": start,
		"end": end,
		"width": 48.0,
		"duration": _get_line_duration(),
		"buff_type": "speed_boost",
		"buff_value": speed_boost_value,
		"tick_interval": 0.5,
		"color": Color(0.3, 0.9, 0.8, 0.5)
	})

## 生成台风眼效果（闭合状态）
func _spawn_area_effect(polygon: PackedVector2Array) -> void:
	SkillEffectManager.create_area_effect({
		"polygon": polygon,
		"damage": pull_damage,
		"damage_interval": 0.5,
		"duration": area_duration,
		"color": Color(0.2, 0.8, 0.7, 0.5),
		"pull_to_center": true,
		"pull_force": pull_force
	})

## 获取规划线条颜色（青色/风色）
func _get_line_color() -> Color:
	return Color(0.3, 0.9, 0.8, 1.0)

## 获取闭合提示颜色
func _get_closure_color() -> Color:
	return Color(0.2, 0.8, 0.7, 1.0)
