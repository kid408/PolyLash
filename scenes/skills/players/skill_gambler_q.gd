extends SkillDrawingBase
class_name SkillGamblerQ

var random_buff_value: float = 0.28
var random_debuff_value: float = 0.28
var zone_duration: float = 5.5
var line_bonus_proc_chance: float = 0.35
var line_bonus_damage: int = 10
var jackpot_bonus_attack: float = 0.5
var jackpot_bonus_cooldown: float = 0.28
var jackpot_damage: int = 28
var jackpot_streak_limit: int = 2

var _non_jackpot_streak: int = 0

const LINE_BONUS_OPTIONS := [
	{"type": "slow", "value": 0.42, "duration": 2.2, "color": Color(0.75, 0.75, 0.2, 0.35)},
	{"type": "poison", "value": 8.0, "duration": 2.8, "color": Color(0.8, 0.85, 0.25, 0.35)},
	{"type": "fear", "value": 1.0, "duration": 0.7, "color": Color(0.9, 0.7, 0.2, 0.35)}
]

func _spawn_line_effect(start: Vector2, end: Vector2) -> void:
	SkillEffectManager.create_debuff_zone({
		"start": start,
		"end": end,
		"width": 24.0,
		"duration": _get_line_duration(),
		"debuff_type": "damage_amp",
		"debuff_value": random_debuff_value,
		"debuff_duration": 2.6,
		"tick_interval": 0.5,
		"damage": line_bonus_damage,
		"damage_interval": 0.5,
		"color": Color(0.95, 0.78, 0.2, 0.5)
	})

	if randf() > line_bonus_proc_chance:
		return

	var bonus: Dictionary = LINE_BONUS_OPTIONS[randi() % LINE_BONUS_OPTIONS.size()]
	SkillEffectManager.create_debuff_zone({
		"start": start,
		"end": end,
		"width": 20.0,
		"duration": _get_line_duration(),
		"debuff_type": bonus["type"],
		"debuff_value": bonus["value"],
		"debuff_duration": bonus["duration"],
		"tick_interval": 0.65,
		"color": bonus["color"]
	})

func _spawn_area_effect(polygon: PackedVector2Array) -> void:
	var center := _calculate_polygon_center(polygon)
	match _roll_area_outcome():
		"buff":
			SkillEffectManager.create_buff_zone({
				"polygon": polygon,
				"duration": zone_duration,
				"buff_type": "attack_boost",
				"buff_value": random_buff_value,
				"tick_interval": 0.5,
				"color": Color(0.95, 0.85, 0.2, 0.4)
			})
			SkillEffectManager.create_buff_zone({
				"polygon": polygon,
				"duration": zone_duration,
				"buff_type": "speed_boost",
				"buff_value": random_buff_value * 0.75,
				"tick_interval": 0.5,
				"color": Color(1.0, 0.9, 0.3, 0.3)
			})
			Global.spawn_floating_text(center, "SAFE BET", Color(1.0, 0.9, 0.3))

		"debuff":
			SkillEffectManager.create_debuff_zone({
				"polygon": polygon,
				"duration": zone_duration,
				"debuff_type": "damage_amp",
				"debuff_value": random_debuff_value + 0.1,
				"debuff_duration": zone_duration,
				"tick_interval": 0.8,
				"color": Color(0.85, 0.62, 0.12, 0.35)
			})
			SkillEffectManager.create_debuff_zone({
				"polygon": polygon,
				"duration": zone_duration,
				"debuff_type": "fear",
				"debuff_value": 1.0,
				"debuff_duration": 0.7,
				"tick_interval": 1.1,
				"color": Color(0.9, 0.65, 0.15, 0.25)
			})
			Global.spawn_floating_text(center, "BAD ODDS", Color(0.95, 0.65, 0.15))

		"jackpot":
			SkillEffectManager.create_buff_zone({
				"polygon": polygon,
				"duration": zone_duration,
				"buff_type": "attack_boost",
				"buff_value": jackpot_bonus_attack,
				"tick_interval": 0.5,
				"color": Color(1.0, 0.88, 0.18, 0.45)
			})
			SkillEffectManager.create_buff_zone({
				"polygon": polygon,
				"duration": zone_duration,
				"buff_type": "cooldown_reduction",
				"buff_value": jackpot_bonus_cooldown,
				"tick_interval": 0.5,
				"color": Color(1.0, 0.93, 0.28, 0.35)
			})
			SkillEffectManager.create_area_effect({
				"polygon": polygon,
				"damage": jackpot_damage,
				"damage_interval": 0.45,
				"duration": zone_duration,
				"color": Color(0.95, 0.75, 0.12, 0.22)
			})
			Global.spawn_floating_text(center, "JACKPOT!", Color(1.0, 0.92, 0.25))

func _roll_area_outcome() -> String:
	if _non_jackpot_streak >= jackpot_streak_limit:
		_non_jackpot_streak = 0
		return "jackpot"

	var roll := randf()
	if roll < 0.22:
		_non_jackpot_streak = 0
		return "jackpot"
	if roll < 0.62:
		_non_jackpot_streak += 1
		return "buff"

	_non_jackpot_streak += 1
	return "debuff"

func _get_line_color() -> Color:
	return Color(0.95, 0.78, 0.2, 1.0)

func _get_closure_color() -> Color:
	return Color(0.95, 0.68, 0.1, 1.0)
