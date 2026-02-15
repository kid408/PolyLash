extends SkillDrawingBase
class_name SkillNecroQ

## ==============================================================================
## 死灵Q技能 - 骨墙与尸爆场
## ==============================================================================
## 
## 功能说明:
## - 画线：沿路径创建骨墙（StaticBody2D），骨墙在受到 3 次攻击后破碎
## - 画圈闭合：创建尸爆场，对区域内敌人造成高伤害
## 
## ==============================================================================

# ==============================================================================
# 死灵技能专属参数（从CSV加载）
# ==============================================================================

## 骨墙生命值（受到3次攻击后破碎）
var wall_health: int = 3

## 骨墙宽度
var wall_width: float = 16.0

## 尸爆伤害
var corpse_damage: int = 60

## 尸爆场持续时间
var corpse_duration: float = 6.0

# ==============================================================================
# 实现基类虚函数
# ==============================================================================

## 生成骨墙效果（未闭合状态）
## 创建可破坏的 StaticBody2D 墙体，health=3
func _spawn_line_effect(start: Vector2, end: Vector2) -> void:
	SkillEffectManager.create_wall_effect({
		"start": start,
		"end": end,
		"width": wall_width,
		"duration": _get_line_duration(),
		"health": wall_health,
		"block_enemies": true,
		"block_bullets": false,
		"color": Color(0.4, 0.1, 0.5, 0.7)
	})

## 生成尸爆场效果（闭合状态）
## 创建高伤害区域，代表尸爆场
func _spawn_area_effect(polygon: PackedVector2Array) -> void:
	SkillEffectManager.create_area_effect({
		"polygon": polygon,
		"damage": corpse_damage,
		"damage_interval": 1.0,
		"duration": corpse_duration,
		"color": Color(0.3, 0.0, 0.4, 0.5)
	})

## 获取规划线条颜色（暗紫色/死灵色）
func _get_line_color() -> Color:
	return Color(0.4, 0.1, 0.5, 1.0)

## 获取闭合提示颜色
func _get_closure_color() -> Color:
	return Color(0.3, 0.0, 0.4, 1.0)
