extends "res://scripts/qef/roles/role_spec_base.gd"
class_name BrokerSpec

func _init() -> void:
	spec = build_base_spec(
		"broker",
		"清算商",
		"黑市清算态",
		{
			"q_open_sec": 2.80,
			"q_close_sec": 1.80,
			"e_sec": 0.22,
			"f_sec": 10.0,
		},
		{
			"q_line_cost_per_10px": 0.36,
			"q_close_cost": 76.0,
			"e_cost": 30.0,
			"f_cost_percent": 24.0,
		}
	)
	spec["q_open"] = {
		"summary": "摆摊、挂债、留清算点，让目标先进入可结算状态。",
		"assets": ["摊位", "债务标记", "清算点"],
	}
	spec["q_close"] = {
		"summary": "闭成黑市局并让所有债务加速兑现。",
		"assets": ["黑市局", "账本提示"],
	}
	spec["e"] = {
		"summary": "单按收债保底，开线后搬摊或转债，闭合后黑市对账快速收账。",
		"default_target_slot": "e",
	}
	spec["dash_link"] = {
		"summary": "总表未定义额外左键冲撞联动。",
	}
	spec["f"] = {
		"pack_sources": ["债务目标", "搬摊终点", "黑市局边缘"],
		"pickup_hint": {
			"effect_id": "broker_ledger",
			"pickup_text": "清算",
			"vfx_color": Color(1.0, 0.86, 0.30, 0.92),
			"text_color": Color(1.0, 0.94, 0.56),
			"effect_scale": 0.56,
		},
		"first_pack_reward_id": "broker_collection_note",
		"jackpot_chance": 0.10,
		"core_pool": [
			build_core_reward(
				"broker_collection_note",
				"收债札",
				"e",
				{
					"damage_amp_bonus": 0.24,
					"duration_amp_bonus": 0.18,
					"charges": 2,
					"effect_hint": "下一次 E 双收债",
				},
				"rare",
				["double_collect"]
			),
			build_core_reward(
				"broker_statement",
				"对账单",
				"q_close",
				{
					"q_damage_amp_bonus": 0.22,
					"q_duration_amp_bonus": 0.20,
					"effect_hint": "下一次 Q 闭合追加一轮自动结算",
				},
				"rare",
				["extra_settlement"]
			),
		],
		"utility_pool": [
			build_utility_reward(
				"broker_cashflow",
				"现金流",
				{
					"energy_gain": 90.0,
				}
			),
		],
		"jackpot_pool": [
			build_core_reward(
				"broker_clearance_writ",
				"清算批文",
				"e",
				{
					"damage_amp_bonus": 0.28,
					"duration_amp_bonus": 0.20,
					"effect_hint": "下一次 E 清算后把附近一名目标也拉进账本",
				},
				"legendary",
				["spread_debt"]
			),
		],
	}
