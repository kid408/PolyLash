extends "res://scripts/qef/roles/role_spec_base.gd"
class_name JailerSpec

func _init() -> void:
	spec = build_base_spec(
		"jailer",
		"狱警",
		"终审态",
		{
			"q_open_sec": 3.00,
			"q_close_sec": 2.10,
			"e_sec": 0.24,
			"f_sec": 10.0,
		},
		{
			"q_line_cost_per_10px": 0.40,
			"q_close_cost": 90.0,
			"e_cost": 38.0,
			"f_cost_percent": 27.0,
		}
	)
	spec["q_open"] = {
		"summary": "审判门与栅栏改写路径，让敌人走错边。",
		"assets": ["门框", "栅栏", "错路判定"],
	}
	spec["q_close"] = {
		"summary": "闭成禁域走廊，错路会被回弹、追电与减速。",
		"assets": ["禁域走廊", "错边回弹"],
	}
	spec["e"] = {
		"summary": "单按锁门保底，开线后转门补门，闭合后审判回弹。",
		"default_target_slot": "e",
	}
	spec["dash_link"] = {
		"summary": "总表未定义额外左键冲撞联动。",
	}
	spec["f_energy"] = {
		"q_line_cost_discount": 0.20,
		"q_close_cost_discount": 0.25,
		"e_cost_discount": 0.20,
	}
	spec["f"] = {
		"pack_sources": ["门边", "回弹终点", "走廊口"],
		"pickup_hint": {
			"effect_id": "jailer_dossier",
			"pickup_text": "卷宗",
			"vfx_color": Color(0.72, 0.90, 1.0, 0.92),
			"text_color": Color(0.78, 0.92, 1.0),
			"effect_scale": 0.56,
		},
		"first_pack_reward_id": "jailer_shock_verdict",
		"jackpot_chance": 0.10,
		"core_pool": [
			build_core_reward(
				"jailer_shock_verdict",
				"追电裁定",
				"e",
				{
					"damage_amp_bonus": 0.24,
					"duration_amp_bonus": 0.18,
					"charges": 1,
					"effect_hint": "下一次 E 锁门带追电",
				},
				"rare",
				["shock_lock"]
			),
			build_core_reward(
				"jailer_misjudgment_order",
				"误判令",
				"q_close",
				{
					"q_damage_amp_bonus": 0.22,
					"q_duration_amp_bonus": 0.20,
					"effect_hint": "下一次 Q 闭合增加一道内门",
				},
				"rare",
				["inner_gate"]
			),
		],
		"utility_pool": [
			build_utility_reward(
				"jailer_prosecution_shard",
				"公诉能片",
				{
					"energy_gain": 80.0,
				}
			),
		],
		"jackpot_pool": [
			build_core_reward(
				"jailer_final_gavel",
				"终审法槌",
				"e",
				{
					"damage_amp_bonus": 0.30,
					"duration_amp_bonus": 0.22,
					"effect_hint": "下一次 E 回弹双判一次",
				},
				"legendary",
				["double_verdict"]
			),
		],
	}
