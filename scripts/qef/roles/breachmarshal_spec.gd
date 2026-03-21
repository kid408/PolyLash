extends "res://scripts/qef/roles/role_spec_base.gd"
class_name BreachmarshalSpec

func _init() -> void:
	spec = build_base_spec(
		"breachmarshal",
		"破阵督军",
		"军令态",
		{
			"q_open_sec": 2.40,
			"q_close_sec": 1.70,
			"e_sec": 0.28,
			"f_sec": 10.0,
		},
		{
			"q_line_cost_per_10px": 0.41,
			"q_close_cost": 90.0,
			"e_cost": 37.0,
			"f_cost_percent": 28.0,
		}
	)
	spec["q_open"] = {
		"summary": "冲击楔犁出破阵沟并撕开活路。",
		"assets": ["冲击楔", "破阵沟", "推进箭头"],
	}
	spec["q_close"] = {
		"summary": "震压口把敌人反复震回边缘并吃破甲。",
		"assets": ["震压口", "回震方向"],
	}
	spec["e"] = {
		"summary": "肩撞开口保底，开线后起爆楔头，闭合后回震收口。",
		"default_target_slot": "e",
	}
	spec["dash_link"] = {
		"summary": "E 生效后 0.4 秒内穿过破阵沟会补一次二段扫沟冲击。",
	}
	spec["f_energy"] = {
		"q_line_cost_discount": 0.15,
		"q_close_cost_discount": 0.25,
		"e_cost_discount": 0.20,
	}
	spec["f"] = {
		"pack_sources": ["沟口", "回震终点", "闭口边缘"],
		"first_pack_reward_id": "breachmarshal_reverb_order",
		"jackpot_chance": 0.10,
		"core_pool": [
			build_core_reward(
				"breachmarshal_reverb_order",
				"回震令",
				"e",
				{
					"damage_amp_bonus": 0.26,
					"duration_amp_bonus": 0.18,
					"charges": 2,
					"effect_hint": "下一次 E 追加回震",
				},
				"rare",
				["double_reverb"]
			),
			build_core_reward(
				"breachmarshal_wide_mouth",
				"扩口片",
				"q_close",
				{
					"q_damage_amp_bonus": 0.24,
					"q_duration_amp_bonus": 0.20,
					"effect_hint": "下一次 Q 闭合加宽震压口",
				},
				"rare",
				["wide_gate"]
			),
		],
		"utility_pool": [
			build_utility_reward(
				"breachmarshal_charge_oil",
				"冲锋火油",
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
				"breachmarshal_army_order",
				"破阵军令",
				"e",
				{
					"damage_amp_bonus": 0.32,
					"duration_amp_bonus": 0.20,
					"effect_hint": "下一次 E 双肩撞并带双线回震",
				},
				"legendary",
				["double_charge"]
			),
		],
	}
