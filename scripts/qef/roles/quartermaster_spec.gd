extends "res://scripts/qef/roles/role_spec_base.gd"
class_name QuartermasterSpec

func _init() -> void:
	spec = build_base_spec(
		"quartermaster",
		"军需官",
		"火力链路态",
		{
			"q_open_sec": 3.40,
			"q_close_sec": 2.00,
			"e_sec": 0.24,
			"f_sec": 10.0,
		},
		{
			"q_line_cost_per_10px": 0.36,
			"q_close_cost": 78.0,
			"e_cost": 33.0,
			"f_cost_percent": 25.0,
		}
	)
	spec["q_open"] = {
		"summary": "补给箱和补给线形成可持续装填节点。",
		"assets": ["补给箱", "补给线", "空装填槽"],
	}
	spec["q_close"] = {
		"summary": "军需回路自动强装最近资产。",
		"assets": ["军需回路", "交点"],
	}
	spec["e"] = {
		"summary": "战术换弹保底，能强装自己或接管最近资产。",
		"default_target_slot": "e",
	}
	spec["dash_link"] = {
		"summary": "左键穿过补给线会在终点自动装填一次轻型强装。",
	}
	spec["f"] = {
		"pack_sources": ["补给箱", "插牌点", "回路交点"],
		"first_pack_reward_id": "quartermaster_heavy_round",
		"jackpot_chance": 0.08,
		"core_pool": [
			build_core_reward(
				"quartermaster_heavy_round",
				"重弹牌",
				"e",
				{
					"damage_amp_bonus": 0.28,
					"duration_amp_bonus": 0.16,
					"charges": 2,
					"effect_hint": "下一次 E 双强装",
				},
				"rare",
				["double_reload"]
			),
			build_core_reward(
				"quartermaster_loop_card",
				"回路线卡",
				"q_close",
				{
					"q_damage_amp_bonus": 0.22,
					"q_duration_amp_bonus": 0.20,
					"effect_hint": "下一次 Q 闭合追加一次自动强装",
				},
				"rare",
				["auto_reload"]
			),
		],
		"utility_pool": [
			build_utility_reward(
				"quartermaster_battery",
				"干电池",
				{
					"energy_gain": 80.0,
				}
			),
		],
		"jackpot_pool": [
			build_core_reward(
				"quartermaster_fire_auth",
				"火力授权",
				"e",
				{
					"damage_amp_bonus": 0.32,
					"duration_amp_bonus": 0.20,
					"effect_hint": "下一次 E 同时强装自己和最近资产",
				},
				"legendary",
				["dual_reload"]
			),
		],
	}
