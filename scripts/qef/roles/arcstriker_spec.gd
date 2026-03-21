extends "res://scripts/qef/roles/role_spec_base.gd"
class_name ArcstrikerSpec

func _init() -> void:
	spec = build_base_spec(
		"arcstriker",
		"霆击者",
		"雷暴态",
		{
			"q_open_sec": 2.40,
			"q_close_sec": 1.70,
			"e_sec": 0.24,
			"f_sec": 10.0,
		},
		{
			"q_line_cost_per_10px": 0.35,
			"q_close_cost": 78.0,
			"e_cost": 36.0,
			"f_cost_percent": 25.0,
		}
	)
	spec["q_open"] = {
		"summary": "雷枪与导电链构成会持续压停怪的电网。",
		"assets": ["雷枪", "导电链", "跳电轨迹"],
	}
	spec["q_close"] = {
		"summary": "闭成雷暴网并高频改接跳电。",
		"assets": ["雷暴网", "跳电突刺"],
	}
	spec["e"] = {
		"summary": "单按过载突进，开线后并网或改接，闭合后进入高频跳电场。",
		"default_target_slot": "e",
	}
	spec["dash_link"] = {
		"summary": "总表未定义额外左键冲撞联动。",
	}
	spec["f"] = {
		"pack_sources": ["雷枪脚下", "跳电终点", "闭网边缘"],
		"pickup_hint": {
			"effect_id": "arcstriker_capacitor",
			"pickup_text": "电容",
			"vfx_color": Color(0.42, 0.95, 1.0, 0.92),
			"text_color": Color(0.64, 1.0, 1.0),
			"effect_scale": 0.56,
		},
		"first_pack_reward_id": "arcstriker_overload_core",
		"jackpot_chance": 0.10,
		"core_pool": [
			build_core_reward(
				"arcstriker_overload_core",
				"过载芯",
				"e",
				{
					"damage_amp_bonus": 0.24,
					"duration_amp_bonus": 0.18,
					"charges": 2,
					"effect_hint": "下一次 E 双跳",
				},
				"rare",
				["double_arc"]
			),
			build_core_reward(
				"arcstriker_mesh_plate",
				"并网片",
				"q_close",
				{
					"q_damage_amp_bonus": 0.22,
					"q_duration_amp_bonus": 0.20,
					"effect_hint": "下一次 Q 闭合多一次改接",
				},
				"rare",
				["extra_link"]
			),
		],
		"utility_pool": [
			build_utility_reward(
				"arcstriker_charge_pulse",
				"蓄电脉",
				{
					"energy_gain": 80.0,
				}
			),
		],
		"jackpot_pool": [
			build_core_reward(
				"arcstriker_storm_order",
				"雷暴军令",
				"e",
				{
					"damage_amp_bonus": 0.28,
					"duration_amp_bonus": 0.20,
					"effect_hint": "下一次 E 过载后自动把附近节点并成网",
				},
				"legendary",
				["auto_mesh"]
			),
		],
	}
