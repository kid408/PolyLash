extends "res://scripts/qef/roles/role_spec_base.gd"
class_name ButcherSpec

func _init() -> void:
	spec = build_base_spec(
		"butcher",
		"屠夫",
		"屠场态",
		{
			"q_open_sec": 2.60,
			"q_close_sec": 1.80,
			"e_sec": 0.32,
			"f_sec": 10.0,
		},
		{
			"q_line_cost_per_10px": 0.42,
			"q_close_cost": 95.0,
			"e_cost": 42.0,
			"f_cost_percent": 28.0,
		}
	)
	spec["q_open"] = {
		"summary": "飞锯锚 + 锯线危险带，围线切角。",
		"assets": ["飞锯锚", "锯线危险带", "危险中心"],
	}
	spec["q_close"] = {
		"summary": "血锯环收成明确处刑口。",
		"assets": ["血锯环", "处刑口"],
	}
	spec["e"] = {
		"summary": "单按回钩拆脸，开线拖回锚点，闭合后收口挤杀。",
		"default_target_slot": "e",
	}
	spec["dash_link"] = {
		"summary": "E 命中后 0.26 秒内左键冲撞触发链锯拖行。",
	}
	spec["f_energy"] = {
		"q_line_cost_discount": 0.20,
		"q_close_cost_discount": 0.25,
		"e_cost_discount": 0.20,
	}
	spec["f"] = {
		"pack_sources": ["锚点", "拖拽终点", "处刑口边缘"],
		"first_pack_reward_id": "butcher_blood_hook_mark",
		"jackpot_chance": 0.10,
		"core_pool": [
			build_core_reward(
				"butcher_blood_hook_mark",
				"血钩印",
				"e",
				{
					"damage_amp_bonus": 0.28,
					"duration_amp_bonus": 0.18,
					"charges": 2,
					"effect_hint": "下一次 E 双回钩",
				},
				"rare",
				["double_hook"]
			),
			build_core_reward(
				"butcher_saw_gap_tooth",
				"锯口牙",
				"q_close",
				{
					"q_damage_amp_bonus": 0.30,
					"q_duration_amp_bonus": 0.20,
					"effect_hint": "下一次 Q 闭合二次收口",
				},
				"rare",
				["double_close"]
			),
		],
		"utility_pool": [
			build_utility_reward(
				"butcher_frenzy_blood",
				"狂热血",
				{
					"energy_gain": 90.0,
					"temp_meta_key": "buff_speed_boost",
					"temp_meta_delta": 0.18,
					"temp_meta_duration": 2.0,
				}
			),
		],
		"jackpot_pool": [
			build_linked_reward(
				"butcher_slaughter_edict",
				"屠场敕令",
				{
					"damage_amp_bonus": 0.32,
					"duration_amp_bonus": 0.20,
					"effect_hint": "E 与 Q 闭合同时强化",
				},
				{
					"q_damage_amp_bonus": 0.34,
					"q_duration_amp_bonus": 0.20,
					"effect_hint": "E 与 Q 闭合同时强化",
				}
			),
		],
	}
