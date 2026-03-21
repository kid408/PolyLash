extends "res://scripts/qef/roles/role_spec_base.gd"
class_name FatebinderSpec

func _init() -> void:
	spec = build_base_spec(
		"fatebinder",
		"命契师",
		"梭哈态",
		{
			"q_open_sec": 2.80,
			"q_close_sec": 1.80,
			"e_sec": 0.22,
			"f_sec": 10.0,
		},
		{
			"q_line_cost_per_10px": 0.35,
			"q_close_cost": 76.0,
			"e_cost": 33.0,
			"f_cost_percent": 25.0,
		}
	)
	spec["q_open"] = {
		"summary": "下签与下注让目标进入高波动状态。",
		"assets": ["签路", "下注标记", "锁奖高亮"],
	}
	spec["q_close"] = {
		"summary": "闭成开奖域并把赌注集中兑现。",
		"assets": ["开奖域", "结算表"],
	}
	spec["e"] = {
		"summary": "单按止损保底，开线后转注或锁奖，闭合后整域提前开奖。",
		"default_target_slot": "e",
	}
	spec["dash_link"] = {
		"summary": "总表未定义额外左键冲撞联动。",
	}
	spec["f"] = {
		"pack_sources": ["下注点", "开奖终点", "开奖域边缘"],
		"pickup_hint": {
			"effect_id": "fatebinder_chips",
			"pickup_text": "赌筹",
			"vfx_color": Color(0.98, 0.72, 0.28, 0.92),
			"text_color": Color(1.0, 0.84, 0.46),
			"effect_scale": 0.56,
		},
		"first_pack_reward_id": "fatebinder_lock_ticket",
		"jackpot_chance": 0.10,
		"core_pool": [
			build_core_reward(
				"fatebinder_lock_ticket",
				"锁奖签",
				"e",
				{
					"damage_amp_bonus": 0.22,
					"duration_amp_bonus": 0.18,
					"charges": 2,
					"effect_hint": "下一次 E 双开奖",
				},
				"rare",
				["double_settle"]
			),
			build_core_reward(
				"fatebinder_allin_page",
				"梭哈页",
				"q_close",
				{
					"q_damage_amp_bonus": 0.22,
					"q_duration_amp_bonus": 0.20,
					"effect_hint": "下一次 Q 闭合追加一轮结算",
				},
				"rare",
				["extra_resolve"]
			),
		],
		"utility_pool": [
			build_utility_reward(
				"fatebinder_comeback_chips",
				"翻盘筹",
				{
					"energy_gain": 80.0,
				}
			),
		],
		"jackpot_pool": [
			build_linked_reward(
				"fatebinder_jackpot_deed",
				"头奖契据",
				{
					"damage_amp_bonus": 0.24,
					"duration_amp_bonus": 0.20,
					"effect_hint": "E 带头奖概率且不亏本",
				},
				{
					"q_damage_amp_bonus": 0.24,
					"q_duration_amp_bonus": 0.20,
					"effect_hint": "Q 闭合带头奖概率且不亏本",
				}
			),
		],
	}
