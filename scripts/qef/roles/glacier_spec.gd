extends "res://scripts/qef/roles/role_spec_base.gd"
class_name GlacierSpec

func _init() -> void:
	spec = build_base_spec(
		"glacier",
		"冰河",
		"极夜态",
		{
			"q_open_sec": 2.80,
			"q_close_sec": 2.00,
			"e_sec": 0.30,
			"f_sec": 10.0,
		},
		{
			"q_line_cost_per_10px": 0.40,
			"q_close_cost": 100.0,
			"e_cost": 38.0,
			"f_cost_percent": 28.0,
		}
	)
	spec["q_open"] = {
		"summary": "厚重冰脊给路权与安全面。",
		"assets": ["冰脊", "安全面"],
	}
	spec["q_close"] = {
		"summary": "寒楔囚场把怪压回边角并触发碎裂。",
		"assets": ["寒楔囚场", "碎棱回卷"],
	}
	spec["e"] = {
		"summary": "爆棱反推保底，开线回卷，闭合后囚场碎裂。",
		"default_target_slot": "e",
	}
	spec["dash_link"] = {
		"summary": "本角色无专属左键联动，保持默认冲撞。",
	}
	spec["f_energy"] = {
		"q_line_cost_discount": 0.20,
		"q_close_cost_discount": 0.30,
		"e_cost_discount": 0.15,
	}
	spec["f"] = {
		"pack_sources": ["裂点", "回卷终点", "囚场边角"],
		"first_pack_reward_id": "glacier_return_edge",
		"jackpot_chance": 0.12,
		"core_pool": [
			build_core_reward(
				"glacier_return_edge",
				"回棱令",
				"e",
				{
					"damage_amp_bonus": 0.28,
					"duration_amp_bonus": 0.22,
					"charges": 2,
					"effect_hint": "下一次 E 双爆棱",
				},
				"rare",
				["double_shatter"]
			),
			build_core_reward(
				"glacier_wedge_lock",
				"寒楔扣",
				"q_close",
				{
					"q_damage_amp_bonus": 0.24,
					"q_duration_amp_bonus": 0.24,
					"effect_hint": "下一次 Q 闭合追加内缩",
				},
				"rare",
				["extra_shrink"]
			),
		],
		"utility_pool": [
			build_utility_reward(
				"glacier_frost_armor",
				"霜甲",
				{
					"energy_gain": 70.0,
					"armor_gain": 1,
				}
			),
		],
		"jackpot_pool": [
			build_linked_reward(
				"glacier_polar_contract",
				"极夜契",
				{
					"damage_amp_bonus": 0.32,
					"duration_amp_bonus": 0.22,
					"effect_hint": "下一次 E 带回卷",
				},
				{
					"q_damage_amp_bonus": 0.30,
					"q_duration_amp_bonus": 0.22,
					"effect_hint": "下一次 Q 闭合带回卷",
				}
			),
		],
	}
