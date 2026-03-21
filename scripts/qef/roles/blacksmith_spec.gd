extends "res://scripts/qef/roles/role_spec_base.gd"
class_name BlacksmithSpec

func _init() -> void:
	spec = build_base_spec(
		"blacksmith",
		"铁匠",
		"过热态",
		{
			"q_open_sec": 3.20,
			"q_close_sec": 2.20,
			"e_sec": 0.28,
			"f_sec": 10.0,
		},
		{
			"q_line_cost_per_10px": 0.38,
			"q_close_cost": 85.0,
			"e_cost": 36.0,
			"f_cost_percent": 26.0,
		}
	)
	spec["q_open"] = {
		"summary": "热锻槽与空锻位构成可继续装填与重锻的资产线。",
		"assets": ["热锻槽", "空锻位", "重锻火星"],
	}
	spec["q_close"] = {
		"summary": "熔锻环会把投射物、节点与陷阱统一升一拍。",
		"assets": ["熔锻环", "重锻脉冲"],
	}
	spec["e"] = {
		"summary": "单按回火重击，开线后重锻或装填，闭合后整环脉冲升级。",
		"default_target_slot": "e",
	}
	spec["dash_link"] = {
		"summary": "总表未定义额外左键冲撞联动。",
	}
	spec["f_energy"] = {
		"q_line_cost_discount": 0.15,
		"q_close_cost_discount": 0.25,
		"e_cost_discount": 0.20,
	}
	spec["f"] = {
		"pack_sources": ["锻槽口", "重锻命中点", "熔环节点"],
		"pickup_hint": {
			"effect_id": "blacksmith_shard",
			"pickup_text": "钢片",
			"vfx_color": Color(1.0, 0.56, 0.22, 0.92),
			"text_color": Color(1.0, 0.72, 0.38),
			"effect_scale": 0.58,
		},
		"first_pack_reward_id": "blacksmith_reforge_token",
		"jackpot_chance": 0.10,
		"core_pool": [
			build_core_reward(
				"blacksmith_reforge_token",
				"重锻签",
				"e",
				{
					"damage_amp_bonus": 0.24,
					"duration_amp_bonus": 0.18,
					"cooldown_slot": "e",
					"cooldown_refund": 1.2,
					"effect_hint": "下一次 E 免费且重击版",
				},
				"rare",
				["free_reforge"]
			),
			build_core_reward(
				"blacksmith_molten_ridge",
				"熔脊片",
				"q_close",
				{
					"q_damage_amp_bonus": 0.24,
					"q_duration_amp_bonus": 0.20,
					"effect_hint": "下一次 Q 闭合多一轮重锻脉冲",
				},
				"rare",
				["extra_pulse"]
			),
		],
		"utility_pool": [
			build_utility_reward(
				"blacksmith_furnace_pressure",
				"炉压",
				{
					"energy_gain": 70.0,
					"temp_meta_key": "attack_boost",
					"temp_meta_delta": 0.10,
					"temp_meta_duration": 2.0,
				}
			),
		],
		"jackpot_pool": [
			build_core_reward(
				"blacksmith_master_hammer",
				"神工锤令",
				"e",
				{
					"damage_amp_bonus": 0.30,
					"duration_amp_bonus": 0.20,
					"charges": 2,
					"effect_hint": "下一次 E 双重锻并影响两个资产",
				},
				"legendary",
				["dual_reforge"]
			),
		],
	}
