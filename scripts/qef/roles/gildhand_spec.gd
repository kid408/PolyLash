extends "res://scripts/qef/roles/role_spec_base.gd"
class_name GildhandSpec

func _init() -> void:
	spec = build_base_spec(
		"gildhand",
		"点金师",
		"黄金法典态",
		{
			"q_open_sec": 2.60,
			"q_close_sec": 1.80,
			"e_sec": 0.24,
			"f_sec": 10.0,
		},
		{
			"q_line_cost_per_10px": 0.36,
			"q_close_cost": 82.0,
			"e_cost": 35.0,
			"f_cost_percent": 26.0,
		}
	)
	spec["q_open"] = {
		"summary": "镀金线和镀金壳把目标变成更值钱的结算对象。",
		"assets": ["镀金线", "镀金壳", "金粉裂痕"],
	}
	spec["q_close"] = {
		"summary": "闭成法典环，环内目标进入高回报结算区。",
		"assets": ["法典环", "结算名单"],
	}
	spec["e"] = {
		"summary": "单按点金重击，开线后敲碎或提前结算，闭合后统一清算。",
		"default_target_slot": "e",
	}
	spec["dash_link"] = {
		"summary": "总表未定义额外左键冲撞联动。",
	}
	spec["f"] = {
		"pack_sources": ["碎壳点", "结算终点", "法典边缘"],
		"pickup_hint": {
			"effect_id": "gildhand_coin",
			"pickup_text": "镀金币",
			"vfx_color": Color(1.0, 0.84, 0.24, 0.92),
			"text_color": Color(1.0, 0.92, 0.46),
			"effect_scale": 0.56,
		},
		"first_pack_reward_id": "gildhand_settlement_mark",
		"jackpot_chance": 0.10,
		"core_pool": [
			build_core_reward(
				"gildhand_settlement_mark",
				"结算印",
				"e",
				{
					"damage_amp_bonus": 0.22,
					"duration_amp_bonus": 0.18,
					"charges": 2,
					"effect_hint": "下一次 E 双重敲碎",
				},
				"rare",
				["double_break"]
			),
			build_core_reward(
				"gildhand_codex_page",
				"法典页",
				"q_close",
				{
					"q_damage_amp_bonus": 0.22,
					"q_duration_amp_bonus": 0.20,
					"effect_hint": "下一次 Q 闭合多一次提前结算",
				},
				"rare",
				["extra_settle"]
			),
		],
		"utility_pool": [
			build_utility_reward(
				"gildhand_gold_blossom",
				"金花",
				{
					"energy_gain": 90.0,
				}
			),
		],
		"jackpot_pool": [
			build_linked_reward(
				"gildhand_golden_edict",
				"黄金敕令",
				{
					"damage_amp_bonus": 0.24,
					"duration_amp_bonus": 0.20,
					"effect_hint": "E 带提前结算资格",
				},
				{
					"q_damage_amp_bonus": 0.24,
					"q_duration_amp_bonus": 0.20,
					"effect_hint": "Q 闭合带提前结算资格",
				}
			),
		],
	}
