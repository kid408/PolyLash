extends "res://scripts/qef/roles/role_spec_base.gd"
class_name PyroSpec

func _init() -> void:
	spec = build_base_spec(
		"pyro",
		"焰术师",
		"炉心态",
		{
			"q_open_sec": 2.60,
			"q_close_sec": 1.80,
			"e_sec": 0.24,
			"f_sec": 10.0,
		},
		{
			"q_line_cost_per_10px": 0.38,
			"q_close_cost": 85.0,
			"e_cost": 44.0,
			"f_cost_percent": 26.0,
		}
	)
	spec["q_open"] = {
		"summary": "油膜带与喷焰口形成可顺跑、可逼穿的火路。",
		"assets": ["油膜带", "喷焰口", "返燃火路"],
	}
	spec["q_close"] = {
		"summary": "闭成炉环并让整条火路返燃倒卷。",
		"assets": ["炉环", "内卷火"],
	}
	spec["e"] = {
		"summary": "单按火脉跃燃，开线后第二火头或反喷，闭合后返燃扫环。",
		"default_target_slot": "e",
	}
	spec["dash_link"] = {
		"summary": "左键冲撞若在油膜带上发生，会沿轨迹补一条临时点火带。",
	}
	spec["f"] = {
		"pack_sources": ["喷焰口", "返燃终点", "炉环内侧"],
		"pickup_hint": {
			"effect_id": "pyro_core",
			"pickup_text": "炉芯",
			"vfx_color": Color(1.0, 0.42, 0.12, 0.92),
			"text_color": Color(1.0, 0.62, 0.24),
			"effect_scale": 0.58,
		},
		"first_pack_reward_id": "pyro_rekindle_core",
		"jackpot_chance": 0.10,
		"core_pool": [
			build_core_reward(
				"pyro_rekindle_core",
				"返燃芯",
				"e",
				{
					"damage_amp_bonus": 0.26,
					"duration_amp_bonus": 0.18,
					"charges": 2,
					"effect_hint": "下一次 E 双返燃",
				},
				"rare",
				["double_rekindle"]
			),
			build_core_reward(
				"pyro_firecrown_page",
				"火冠页",
				"q_close",
				{
					"q_damage_amp_bonus": 0.24,
					"q_duration_amp_bonus": 0.20,
					"effect_hint": "下一次 Q 闭合追加一轮内卷火",
				},
				"rare",
				["inner_fire"]
			),
		],
		"utility_pool": [
			build_utility_reward(
				"pyro_heat_pressure",
				"热压",
				{
					"energy_gain": 80.0,
					"temp_meta_key": "buff_speed_boost",
					"temp_meta_delta": 0.18,
					"temp_meta_duration": 2.0,
				}
			),
		],
		"jackpot_pool": [
			build_linked_reward(
				"pyro_inferno_order",
				"炼狱令",
				{
					"damage_amp_bonus": 0.28,
					"duration_amp_bonus": 0.18,
					"effect_hint": "E 附加第二条火路",
				},
				{
					"q_damage_amp_bonus": 0.28,
					"q_duration_amp_bonus": 0.20,
					"effect_hint": "Q 闭合附加第二条火路",
				}
			),
		],
	}
