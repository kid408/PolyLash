extends "res://scripts/qef/roles/role_spec_base.gd"
class_name RuneblazerSpec

func _init() -> void:
	spec = build_base_spec(
		"runeblazer",
		"符焰师",
		"圣典态",
		{
			"q_open_sec": 3.00,
			"q_close_sec": 1.90,
			"e_sec": 0.26,
			"f_sec": 10.0,
		},
		{
			"q_line_cost_per_10px": 0.38,
			"q_close_cost": 82.0,
			"e_cost": 39.0,
			"f_cost_percent": 26.0,
		}
	)
	spec["q_open"] = {
		"summary": "落空符点和符焰节点，留出可接管资产。",
		"assets": ["空符点", "符焰节点"],
	}
	spec["q_close"] = {
		"summary": "节点闭合成圣典环并进入连锁爆燃。",
		"assets": ["圣典环", "连锁爆燃轨迹"],
	}
	spec["e"] = {
		"summary": "焚步迁跃保底，接管最近节点并触发连爆。",
		"default_target_slot": "e",
	}
	spec["dash_link"] = {
		"summary": "本角色无专属左键联动，保持默认冲撞。",
	}
	spec["f"] = {
		"pack_sources": ["符点", "连爆终点", "闭合节点"],
		"first_pack_reward_id": "runeblazer_takeover_page",
		"jackpot_chance": 0.12,
		"core_pool": [
			build_core_reward(
				"runeblazer_takeover_page",
				"接管页",
				"e",
				{
					"damage_amp_bonus": 0.24,
					"duration_amp_bonus": 0.16,
					"extra_asset_count": 1,
					"effect_hint": "下一次 E 多接一个点",
				},
				"rare",
				["asset_takeover"]
			),
			build_core_reward(
				"runeblazer_codex_page",
				"圣典页",
				"q_close",
				{
					"q_damage_amp_bonus": 0.26,
					"q_duration_amp_bonus": 0.18,
					"effect_hint": "下一次 Q 闭合追加一轮连爆",
				},
				"rare",
				["ring_chain"]
			),
		],
		"utility_pool": [
			build_utility_reward(
				"runeblazer_ember",
				"余烬",
				{
					"energy_gain": 80.0,
					"temp_meta_key": "attack_boost",
					"temp_meta_delta": 0.12,
					"temp_meta_duration": 2.0,
				}
			),
		],
		"jackpot_pool": [
			build_linked_reward(
				"runeblazer_vertex_edict",
				"顶点敕令",
				{
					"damage_amp_bonus": 0.30,
					"duration_amp_bonus": 0.18,
					"effect_hint": "下一次 E 双连锁",
				},
				{
					"q_damage_amp_bonus": 0.32,
					"q_duration_amp_bonus": 0.20,
					"effect_hint": "下一次闭合双连锁",
				}
			),
		],
	}
