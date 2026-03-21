extends "res://scripts/qef/roles/role_spec_base.gd"
class_name MedicSpec

func _init() -> void:
	spec = build_base_spec(
		"medic",
		"军医",
		"总医院态",
		{
			"q_open_sec": 3.20,
			"q_close_sec": 2.20,
			"e_sec": 0.22,
			"f_sec": 10.0,
		},
		{
			"q_line_cost_per_10px": 0.36,
			"q_close_cost": 76.0,
			"e_cost": 35.0,
			"f_cost_percent": 24.0,
		}
	)
	spec["q_open"] = {
		"summary": "落救治站与安全点，形成可绕可站的补给面。",
		"assets": ["救治站", "安全点", "补给面"],
	}
	spec["q_close"] = {
		"summary": "闭成野战医院并叠加治疗与急救窗。",
		"assets": ["野战医院", "急救窗"],
	}
	spec["e"] = {
		"summary": "单按急救抬血并给短盾，开线后前插屏障或移站，闭合后医院超压。",
		"default_target_slot": "e",
	}
	spec["dash_link"] = {
		"summary": "左键冲撞若在救治站范围内起始，则冲撞结束时补一个 0.60s 轻护盾。",
	}
	spec["f"] = {
		"pack_sources": ["站点边缘", "急救命中点", "医院边缘"],
		"pickup_hint": {
			"effect_id": "medic_kit",
			"pickup_text": "针包",
			"vfx_color": Color(0.48, 1.0, 0.84, 0.92),
			"text_color": Color(0.74, 1.0, 0.90),
			"effect_scale": 0.56,
		},
		"first_pack_reward_id": "medic_triage_needle",
		"jackpot_chance": 0.10,
		"core_pool": [
			build_core_reward(
				"medic_triage_needle",
				"急救针",
				"e",
				{
					"damage_amp_bonus": 0.22,
					"duration_amp_bonus": 0.22,
					"charges": 2,
					"effect_hint": "下一次 E 双急救",
				},
				"rare",
				["double_triage"]
			),
			build_core_reward(
				"medic_hospital_pass",
				"医院牌",
				"q_close",
				{
					"q_damage_amp_bonus": 0.18,
					"q_duration_amp_bonus": 0.24,
					"effect_hint": "下一次 Q 闭合追加一轮群疗",
				},
				"rare",
				["extra_heal_wave"]
			),
		],
		"utility_pool": [
			build_utility_reward(
				"medic_adrenal_shot",
				"肾上针",
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
				"medic_hospital_directive",
				"总医院批示",
				"e",
				{
					"damage_amp_bonus": 0.24,
					"duration_amp_bonus": 0.24,
					"effect_hint": "下一次 E 急救时自动补二次护盾",
				},
				"legendary",
				["second_shield"]
			),
		],
	}
