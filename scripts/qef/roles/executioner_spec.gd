extends "res://scripts/qef/roles/role_spec_base.gd"
class_name ExecutionerSpec

func _init() -> void:
	spec = build_base_spec(
		"executioner",
		"处刑人",
		"断罪时刻",
		{
			"q_open_sec": 2.50,
			"q_close_sec": 1.60,
			"e_sec": 0.22,
			"f_sec": 10.0,
		},
		{
			"q_line_cost_per_10px": 0.40,
			"q_close_cost": 95.0,
			"e_cost": 40.0,
			"f_cost_percent": 28.0,
		}
	)
	spec["q_open"] = {
		"summary": "断罪线持续压阈值并标出线下名单。",
		"assets": ["断罪线", "线下高亮"],
	}
	spec["q_close"] = {
		"summary": "断头区高亮低血目标并暴露处决机会。",
		"assets": ["断头区", "处刑名单"],
	}
	spec["e"] = {
		"summary": "追斩保底，开线校准阈值，闭合后断头追裁。",
		"default_target_slot": "e",
	}
	spec["dash_link"] = {
		"summary": "本角色无专属左键联动，保持默认冲撞。",
	}
	spec["f_energy"] = {
		"q_line_cost_discount": 0.20,
		"q_close_cost_discount": 0.20,
		"e_cost_discount": 0.20,
	}
	spec["f"] = {
		"pack_sources": ["线下目标", "追斩终点", "断头区边缘"],
		"first_pack_reward_id": "executioner_chase_order",
		"jackpot_chance": 0.12,
		"core_pool": [
			build_core_reward(
				"executioner_chase_order",
				"追斩令",
				"e",
				{
					"damage_amp_bonus": 0.28,
					"duration_amp_bonus": 0.16,
					"charges": 2,
					"effect_hint": "下一次 E 双追斩",
				},
				"rare",
				["double_dash"]
			),
			build_core_reward(
				"executioner_raise_line",
				"抬线札",
				"q_close",
				{
					"q_damage_amp_bonus": 0.22,
					"q_duration_amp_bonus": 0.22,
					"threshold_bonus": 0.08,
					"effect_hint": "下一次 Q 闭合临时抬高处决线",
				},
				"rare",
				["raise_threshold"]
			),
		],
		"utility_pool": [
			build_utility_reward(
				"executioner_cold_blood",
				"冷血",
				{
					"energy_gain": 80.0,
					"temp_meta_key": "buff_speed_boost",
					"temp_meta_delta": 0.14,
					"temp_meta_duration": 2.0,
				}
			),
		],
		"jackpot_pool": [
			build_linked_reward(
				"executioner_license",
				"断头执照",
				{
					"damage_amp_bonus": 0.32,
					"duration_amp_bonus": 0.18,
					"effect_hint": "下一次 E 带瞬斩资格",
				},
				{
					"q_damage_amp_bonus": 0.30,
					"q_duration_amp_bonus": 0.20,
					"effect_hint": "下一次 Q 闭合带瞬斩资格",
				}
			),
		],
	}
