extends "res://scripts/qef/roles/role_spec_base.gd"
class_name PlagueSpec

func _init() -> void:
	spec = build_base_spec(
		"plague",
		"疫师",
		"进化态",
		{
			"q_open_sec": 3.00,
			"q_close_sec": 2.20,
			"e_sec": 0.24,
			"f_sec": 10.0,
		},
		{
			"q_line_cost_per_10px": 0.37,
			"q_close_cost": 80.0,
			"e_cost": 34.0,
			"f_cost_percent": 25.0,
		}
	)
	spec["q_open"] = {
		"summary": "毒带和毒种会持续压血、拖战，并把敌人变成可迁移宿主。",
		"assets": ["毒带", "毒种", "宿主跳转"],
	}
	spec["q_close"] = {
		"summary": "闭成瘴界并同时加快传播、叠层与宿主交换。",
		"assets": ["瘴界", "传播脉冲"],
	}
	spec["e"] = {
		"summary": "单按爆种保底，开线后迁毒或换宿主，闭合后催化瘴界跳毒。",
		"default_target_slot": "e",
	}
	spec["dash_link"] = {
		"summary": "总表未定义额外左键冲撞联动。",
	}
	spec["f"] = {
		"pack_sources": ["毒种", "迁毒终点", "瘴界边缘"],
		"pickup_hint": {
			"effect_id": "plague_bladder",
			"pickup_text": "毒囊",
			"vfx_color": Color(0.56, 0.94, 0.30, 0.92),
			"text_color": Color(0.74, 1.0, 0.48),
			"effect_scale": 0.56,
		},
		"first_pack_reward_id": "plague_burst_sac",
		"jackpot_chance": 0.10,
		"core_pool": [
			build_core_reward(
				"plague_burst_sac",
				"爆囊签",
				"e",
				{
					"damage_amp_bonus": 0.24,
					"duration_amp_bonus": 0.18,
					"charges": 2,
					"effect_hint": "下一次 E 双爆种",
				},
				"rare",
				["double_bloom"]
			),
			build_core_reward(
				"plague_miasma_sac",
				"瘴界囊",
				"q_close",
				{
					"q_damage_amp_bonus": 0.22,
					"q_duration_amp_bonus": 0.22,
					"effect_hint": "下一次 Q 闭合追加一轮传播",
				},
				"rare",
				["extra_spread"]
			),
		],
		"utility_pool": [
			build_utility_reward(
				"plague_serum",
				"疫液",
				{
					"energy_gain": 80.0,
				}
			),
		],
		"jackpot_pool": [
			build_core_reward(
				"plague_evolution_matron",
				"进化母囊",
				"e",
				{
					"damage_amp_bonus": 0.28,
					"duration_amp_bonus": 0.20,
					"effect_hint": "下一次 E 迁毒后自动再换一次宿主",
				},
				"legendary",
				["double_host_swap"]
			),
		],
	}
