extends "res://scripts/qef/roles/role_spec_base.gd"
class_name WindSpec

func _init() -> void:
	spec = build_base_spec(
		"wind",
		"风行者",
		"升华态",
		{
			"q_open_sec": 2.20,
			"q_close_sec": 1.60,
			"e_sec": 0.22,
			"f_sec": 10.0,
		},
		{
			"q_line_cost_per_10px": 0.34,
			"q_close_cost": 72.0,
			"e_cost": 32.0,
			"f_cost_percent": 24.0,
		}
	)
	spec["q_open"] = {
		"summary": "放出去程风路，改写玩家与怪的行进线。",
		"assets": ["去程风路", "折返点"],
	}
	spec["q_close"] = {
		"summary": "飓眼环形成吸入再折返切的二段节奏。",
		"assets": ["回程线", "飓眼环"],
	}
	spec["e"] = {
		"summary": "风步保底，开线后折返，闭合后眼折重切。",
		"default_target_slot": "e",
	}
	spec["dash_link"] = {
		"summary": "E 后 0.3 秒内横切风路会补一次镜像回风斩。",
	}
	spec["f"] = {
		"pack_sources": ["折返点", "回程终点", "飓眼边缘"],
		"first_pack_reward_id": "wind_return_feather",
		"jackpot_chance": 0.10,
		"core_pool": [
			build_core_reward(
				"wind_return_feather",
				"折返羽",
				"e",
				{
					"damage_amp_bonus": 0.26,
					"duration_amp_bonus": 0.18,
					"charges": 2,
					"effect_hint": "下一次 E 双折返",
				},
				"rare",
				["double_return"]
			),
			build_core_reward(
				"wind_eye_pattern",
				"飓眼纹",
				"q_close",
				{
					"q_damage_amp_bonus": 0.22,
					"q_duration_amp_bonus": 0.20,
					"effect_hint": "下一次 Q 闭合多一轮风切",
				},
				"rare",
				["extra_slice"]
			),
		],
		"utility_pool": [
			build_utility_reward(
				"wind_breeze",
				"清风",
				{
					"energy_gain": 80.0,
					"temp_meta_key": "buff_speed_boost",
					"temp_meta_delta": 0.18,
					"temp_meta_duration": 2.0,
				}
			),
		],
		"jackpot_pool": [
			build_core_reward(
				"wind_ascension_edict",
				"升华谕令",
				"e",
				{
					"damage_amp_bonus": 0.30,
					"duration_amp_bonus": 0.20,
					"effect_hint": "下一次 E 折返后再送一轮镜像风切",
				},
				"legendary",
				["mirror_slice"]
			),
		],
	}
