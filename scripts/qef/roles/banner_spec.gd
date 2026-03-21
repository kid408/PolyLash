extends "res://scripts/qef/roles/role_spec_base.gd"
class_name BannerSpec

func _init() -> void:
	spec = build_base_spec(
		"banner",
		"旗令官",
		"总攻态",
		{
			"q_open_sec": 2.80,
			"q_close_sec": 1.80,
			"e_sec": 0.26,
			"f_sec": 10.0,
		},
		{
			"q_line_cost_per_10px": 0.35,
			"q_close_cost": 76.0,
			"e_cost": 33.0,
			"f_cost_percent": 24.0,
		}
	)
	spec["q_open"] = {
		"summary": "插旗与推进线给出战线方向，让跟旗走更安全。",
		"assets": ["战旗", "推进线", "冲锋箭头"],
	}
	spec["q_close"] = {
		"summary": "闭成总攻战阵并持续点名压进。",
		"assets": ["总攻战阵", "合围口"],
	}
	spec["e"] = {
		"summary": "单按军号冲阵，开线后推旗或点名总攻，闭合后送入口子。",
		"default_target_slot": "e",
	}
	spec["dash_link"] = {
		"summary": "左键冲撞沿推进线发生时，会在终点补一次短程总攻波。",
	}
	spec["f"] = {
		"pack_sources": ["旗底", "推进终点", "战阵边缘"],
		"pickup_hint": {
			"effect_id": "banner_cloth",
			"pickup_text": "布片",
			"vfx_color": Color(0.96, 0.86, 0.34, 0.92),
			"text_color": Color(1.0, 0.94, 0.58),
			"effect_scale": 0.56,
		},
		"first_pack_reward_id": "banner_assault_order",
		"jackpot_chance": 0.10,
		"core_pool": [
			build_core_reward(
				"banner_assault_order",
				"总攻令",
				"e",
				{
					"damage_amp_bonus": 0.22,
					"duration_amp_bonus": 0.18,
					"charges": 2,
					"effect_hint": "下一次 E 双推进",
				},
				"rare",
				["double_charge"]
			),
			build_core_reward(
				"banner_battle_knot",
				"战阵旗结",
				"q_close",
				{
					"q_damage_amp_bonus": 0.22,
					"q_duration_amp_bonus": 0.20,
					"effect_hint": "下一次 Q 闭合追加一轮前推",
				},
				"rare",
				["extra_push"]
			),
		],
		"utility_pool": [
			build_utility_reward(
				"banner_rations",
				"军粮",
				{
					"energy_gain": 70.0,
					"temp_meta_key": "buff_speed_boost",
					"temp_meta_delta": 0.16,
					"temp_meta_duration": 2.0,
				}
			),
		],
		"jackpot_pool": [
			build_core_reward(
				"banner_army_order",
				"总攻军令",
				"e",
				{
					"damage_amp_bonus": 0.28,
					"duration_amp_bonus": 0.20,
					"effect_hint": "下一次 E 后旗线自动补出一段冲锋波",
				},
				"legendary",
				["follow_wave"]
			),
		],
	}
