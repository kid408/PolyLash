extends "res://scripts/qef/roles/role_spec_base.gd"
class_name NecroSpec

func _init() -> void:
	spec = build_base_spec(
		"necro",
		"死灵师",
		"冥行态",
		{
			"q_open_sec": 3.00,
			"q_close_sec": 2.00,
			"e_sec": 0.30,
			"f_sec": 10.0,
		},
		{
			"q_line_cost_per_10px": 0.38,
			"q_close_cost": 84.0,
			"e_cost": 36.0,
			"f_cost_percent": 26.0,
		}
	)
	spec["q_open"] = {
		"summary": "回魂碑和回收线给自己留下可回撤的碑线。",
		"assets": ["回魂碑", "回收线", "返程拖影"],
	}
	spec["q_close"] = {
		"summary": "闭成冥域回路，把目标持续拉回核心死线。",
		"assets": ["冥域回路", "内拉方向"],
	}
	spec["e"] = {
		"summary": "单按召回保底，开线后换碑或迁尸契，闭合后批量召回。",
		"default_target_slot": "e",
	}
	spec["dash_link"] = {
		"summary": "总表未定义额外左键冲撞联动。",
	}
	spec["f"] = {
		"pack_sources": ["碑底", "召回终点", "回路边缘"],
		"pickup_hint": {
			"effect_id": "necro_bone_card",
			"pickup_text": "骨牌",
			"vfx_color": Color(0.78, 0.54, 0.96, 0.92),
			"text_color": Color(0.88, 0.72, 1.0),
			"effect_scale": 0.54,
		},
		"first_pack_reward_id": "necro_soul_call",
		"jackpot_chance": 0.10,
		"core_pool": [
			build_core_reward(
				"necro_soul_call",
				"招魂牌",
				"e",
				{
					"damage_amp_bonus": 0.22,
					"duration_amp_bonus": 0.18,
					"charges": 2,
					"effect_hint": "下一次 E 双召回",
				},
				"rare",
				["double_recall"]
			),
			build_core_reward(
				"necro_underworld_bone",
				"冥域骨签",
				"q_close",
				{
					"q_damage_amp_bonus": 0.22,
					"q_duration_amp_bonus": 0.20,
					"effect_hint": "下一次 Q 闭合追加一轮内拉",
				},
				"rare",
				["extra_pull"]
			),
		],
		"utility_pool": [
			build_utility_reward(
				"necro_soulfire",
				"魂火",
				{
					"energy_gain": 80.0,
					"temp_meta_key": "attack_boost",
					"temp_meta_delta": 0.10,
					"temp_meta_duration": 2.0,
				}
			),
		],
		"jackpot_pool": [
			build_core_reward(
				"necro_march_order",
				"行军诏令",
				"e",
				{
					"damage_amp_bonus": 0.26,
					"duration_amp_bonus": 0.20,
					"effect_hint": "下一次 E 召出短命骨卫并保留回收线",
				},
				"legendary",
				["bone_guard"]
			),
		],
	}
