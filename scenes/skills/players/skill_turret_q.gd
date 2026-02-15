extends SkillDrawingBase
class_name SkillTurretQ

## ==============================================================================
## 工程Q技能 - 炮塔部署与维修站
## ==============================================================================
## 
## 功能说明:
## - 画线：沿路径等距放置 3 个自动炮塔（create_summon）
## - 画圈闭合：创建维修站，区域内炮塔获得双倍攻速（attack_boost）
## 
## ==============================================================================

# ==============================================================================
# 工程技能专属参数（从CSV加载）
# ==============================================================================

## 炮塔伤害
var turret_damage: int = 20

## 部署炮塔数量
var turret_count: int = 3

## 炮塔存活时间
var turret_duration: float = 12.0

## 维修站攻击加成100%
var repair_boost: float = 1.0

## 维修站持续时间
var repair_duration: float = 6.0

# ==============================================================================
# 实现基类虚函数
# ==============================================================================

## 生成炮塔部署效果（未闭合状态）
## 沿路径等距放置炮塔
func _spawn_line_effect(start: Vector2, end: Vector2) -> void:
	for i in range(turret_count):
		var t = float(i) / max(turret_count - 1, 1)
		var pos = start.lerp(end, t)
		SkillEffectManager.create_summon({
			"position": pos,
			"summon_type": "turret",
			"duration": turret_duration,
			"damage": turret_damage,
			"attack_interval": 1.0,
			"attack_range": 250.0,
			"max_count": 6,
			"owner_skill_id": "skill_turret_q",
			"color": Color(0.4, 0.5, 0.3)
		})

## 生成维修站效果（闭合状态）
## 区域内炮塔获得双倍攻速
func _spawn_area_effect(polygon: PackedVector2Array) -> void:
	SkillEffectManager.create_buff_zone({
		"polygon": polygon,
		"duration": repair_duration,
		"buff_type": "attack_boost",
		"buff_value": repair_boost,
		"tick_interval": 0.5,
		"color": Color(0.3, 0.4, 0.2, 0.4)
	})

## 获取规划线条颜色（军事灰绿色）
func _get_line_color() -> Color:
	return Color(0.4, 0.5, 0.3, 1.0)

## 获取闭合提示颜色
func _get_closure_color() -> Color:
	return Color(0.3, 0.4, 0.2, 1.0)
