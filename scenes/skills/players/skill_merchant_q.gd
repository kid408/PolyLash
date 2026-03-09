extends SkillDrawingBase
class_name SkillMerchantQ

var bounty_damage_amp: float = 0.2
var bounty_duration: float = 3.0
var discount_speed_boost: float = 0.15
var market_duration: float = 6.0
var market_coin_count: int = 3

func _spawn_line_effect(start: Vector2, end: Vector2) -> void:
	SkillEffectManager.create_debuff_zone({
		"start": start,
		"end": end,
		"width": 24.0,
		"duration": _get_line_duration(),
		"debuff_type": "damage_amp",
		"debuff_value": bounty_damage_amp,
		"debuff_duration": bounty_duration,
		"tick_interval": 0.6,
		"color": Color(1.0, 0.8, 0.2, 0.5)
	})

func _spawn_area_effect(polygon: PackedVector2Array) -> void:
	SkillEffectManager.create_buff_zone({
		"polygon": polygon,
		"duration": market_duration,
		"buff_type": "speed_boost",
		"buff_value": discount_speed_boost,
		"tick_interval": 0.5,
		"color": Color(1.0, 0.7, 0.1, 0.4)
	})
	_spawn_market_coin_burst(polygon, market_coin_count)

func _spawn_market_coin_burst(polygon: PackedVector2Array, coin_count: int) -> void:
	if coin_count <= 0 or polygon.size() < 3:
		return
	var center: Vector2 = _calculate_polygon_center(polygon)
	for i in range(coin_count):
		var angle := TAU * float(i) / float(max(coin_count, 1))
		var pos := center + Vector2.RIGHT.rotated(angle) * 40.0
		Global.spawn_coin(pos, 1)
	Global.spawn_floating_text(center, "MARKET!", Color(1.0, 0.8, 0.2))

func _get_line_color() -> Color:
	return Color(1.0, 0.8, 0.2, 1.0)

func _get_closure_color() -> Color:
	return Color(1.0, 0.7, 0.1, 1.0)
