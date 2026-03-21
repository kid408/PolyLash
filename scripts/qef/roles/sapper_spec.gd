extends "res://scripts/qef/roles/role_spec_base.gd"
class_name SapperSpec

func _init() -> void:
	spec = build_base_spec(
		"sapper",
		"工兵",
		"工爆态",
		{
			"q_open_sec": 3.20,
			"q_close_sec": 2.00,
			"e_sec": 0.24,
			"f_sec": 10.0,
		},
		{
			"q_line_cost_per_10px": 0.37,
			"q_close_cost": 82.0,
			"e_cost": 36.0,
			"f_cost_percent": 25.0,
		}
	)
	spec["q_open"] = {
		"summary": "埋雷线与排爆点会定义爆炸顺序，少量线段就能做出口袋。",
		"assets": ["雷线", "排爆点", "引信顺序"],
	}
	spec["q_close"] = {
		"summary": "闭成连爆回路并让余波顺回路追爆整圈。",
		"assets": ["连爆回路", "余爆节点"],
	}
	spec["e"] = {
		"summary": "单按补爆保底，开线后顺爆或反爆改引信，闭合后整回路提前结算。",
		"default_target_slot": "e",
	}
	spec["dash_link"] = {
		"summary": "总表未定义额外左键冲撞联动。",
	}
	spec["f"] = {
		"pack_sources": ["雷点", "余波终点", "回路边缘"],
		"pickup_hint": {
			"effect_id": "sapper_bolt",
			"pickup_text": "雷栓",
			"vfx_color": Color(1.0, 0.68, 0.24, 0.92),
			"text_color": Color(1.0, 0.82, 0.46),
			"effect_scale": 0.56,
		},
		"first_pack_reward_id": "sapper_chain_bolt",
		"jackpot_chance": 0.10,
		"core_pool": [
			build_core_reward(
				"sapper_chain_bolt",
				"顺爆栓",
				"e",
				{
					"damage_amp_bonus": 0.24,
					"duration_amp_bonus": 0.18,
					"charges": 2,
					"effect_hint": "下一次 E 双顺爆",
				},
				"rare",
				["double_chain"]
			),
			build_core_reward(
				"sapper_loop_coil",
				"回路线圈",
				"q_close",
				{
					"q_damage_amp_bonus": 0.24,
					"q_duration_amp_bonus": 0.22,
					"effect_hint": "下一次 Q 闭合追加一轮余爆",
				},
				"rare",
				["extra_aftershock"]
			),
		],
		"utility_pool": [
			build_utility_reward(
				"sapper_firework_pack",
				"火工包",
				{
					"energy_gain": 80.0,
				}
			),
		],
		"jackpot_pool": [
			build_core_reward(
				"sapper_demolition_license",
				"爆破执照",
				"e",
				{
					"damage_amp_bonus": 0.30,
					"duration_amp_bonus": 0.20,
					"effect_hint": "下一次 E 可同时指定两段爆炸顺序",
				},
				"legendary",
				["dual_fuse"]
			),
		],
	}
