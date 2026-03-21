extends "res://scripts/qef/roles/role_spec_base.gd"
class_name LurewardenSpec

func _init() -> void:
	spec = build_base_spec(
		"lurewarden",
		"诱猎师",
		"号令态",
		{
			"q_open_sec": 2.80,
			"q_close_sec": 1.90,
			"e_sec": 0.24,
			"f_sec": 10.0,
		},
		{
			"q_line_cost_per_10px": 0.36,
			"q_close_cost": 78.0,
			"e_cost": 40.0,
			"f_cost_percent": 25.0,
		}
	)
	spec["q_open"] = {
		"summary": "诱饵桩 + 假路径，重写怪物追击关系。",
		"assets": ["诱饵桩", "假路径", "仇恨标记"],
	}
	spec["q_close"] = {
		"summary": "诱猎环让怪反复转头并露背。",
		"assets": ["诱猎环", "第二诱口"],
	}
	spec["e"] = {
		"summary": "换位或爆饵保底，开线后再导怪一次。",
		"default_target_slot": "e",
	}
	spec["dash_link"] = {
		"summary": "左键穿过诱饵桩会在终点留下 0.9 秒假残影。",
	}
	spec["f"] = {
		"pack_sources": ["诱饵桩", "转头点", "诱口边缘"],
		"first_pack_reward_id": "lurewarden_bait_whistle",
		"jackpot_chance": 0.10,
		"core_pool": [
			build_core_reward(
				"lurewarden_bait_whistle",
				"爆饵哨",
				"e",
				{
					"damage_amp_bonus": 0.24,
					"duration_amp_bonus": 0.20,
					"charges": 2,
					"effect_hint": "下一次 E 双爆饵",
				},
				"rare",
				["bait_burst"]
			),
			build_core_reward(
				"lurewarden_return_whistle",
				"回哨牌",
				"q_close",
				{
					"q_damage_amp_bonus": 0.22,
					"q_duration_amp_bonus": 0.22,
					"effect_hint": "下一次 Q 闭合追加一个诱口",
				},
				"rare",
				["second_gate"]
			),
		],
		"utility_pool": [
			build_utility_reward(
				"lurewarden_adrenaline",
				"肾上腺",
				{
					"energy_gain": 80.0,
					"temp_meta_key": "buff_speed_boost",
					"temp_meta_delta": 0.16,
					"temp_meta_duration": 2.0,
				}
			),
		],
		"jackpot_pool": [
			build_core_reward(
				"lurewarden_hunt_order",
				"围捕令",
				"e",
				{
					"damage_amp_bonus": 0.30,
					"duration_amp_bonus": 0.22,
					"effect_hint": "下一次 E 换位后全场最近怪短时转头",
				},
				"legendary",
				["global_taunt"]
			),
		],
	}
