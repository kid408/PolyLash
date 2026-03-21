extends "res://scripts/qef/roles/role_spec_base.gd"
class_name SingularistSpec

func _init() -> void:
	spec = build_base_spec(
		"singularist",
		"坍缩师",
		"牵引态",
		{
			"q_open_sec": 2.80,
			"q_close_sec": 1.90,
			"e_sec": 0.28,
			"f_sec": 10.0,
		},
		{
			"q_line_cost_per_10px": 0.36,
			"q_close_cost": 82.0,
			"e_cost": 36.0,
			"f_cost_percent": 25.0,
		}
	)
	spec["q_open"] = {
		"summary": "移动奇点牵引怪群伴走。",
		"assets": ["移动奇点", "牵引轨迹"],
	}
	spec["q_close"] = {
		"summary": "坍缩环把一路拖的东西回卷到中心。",
		"assets": ["坍缩环", "中心回卷"],
	}
	spec["e"] = {
		"summary": "极性脉冲保底，开线后换极甩极，闭合后反转。",
		"default_target_slot": "e",
	}
	spec["dash_link"] = {
		"summary": "奇点存在时左键会把最近已牵引目标甩极跟冲。",
	}
	spec["f"] = {
		"pack_sources": ["奇点轨迹", "甩极终点", "闭环边缘"],
		"first_pack_reward_id": "singularist_polarity_core",
		"jackpot_chance": 0.10,
		"core_pool": [
			build_core_reward(
				"singularist_polarity_core",
				"换极核",
				"e",
				{
					"damage_amp_bonus": 0.24,
					"duration_amp_bonus": 0.18,
					"charges": 2,
					"effect_hint": "下一次 E 双换极",
				},
				"rare",
				["double_polarity"]
			),
			build_core_reward(
				"singularist_collapse_shard",
				"坍缩片",
				"q_close",
				{
					"q_damage_amp_bonus": 0.24,
					"q_duration_amp_bonus": 0.22,
					"effect_hint": "下一次 Q 闭合追加一轮回卷",
				},
				"rare",
				["extra_implode"]
			),
		],
		"utility_pool": [
			build_utility_reward(
				"singularist_vacuum_shell",
				"真空壳",
				{
					"energy_gain": 80.0,
					"temp_meta_key": "damage_reduction",
					"temp_meta_delta": 0.10,
					"temp_meta_duration": 2.0,
				}
			),
		],
		"jackpot_pool": [
			build_core_reward(
				"singularist_law",
				"奇点律令",
				"e",
				{
					"damage_amp_bonus": 0.30,
					"duration_amp_bonus": 0.22,
					"effect_hint": "下一次 E 甩极后再送一次自动回拉",
				},
				"legendary",
				["auto_pullback"]
			),
		],
	}
