extends "res://scripts/qef/roles/role_spec_base.gd"
class_name IllusionistSpec

func _init() -> void:
	spec = build_base_spec(
		"illusionist",
		"幻术师",
		"镜域态",
		{
			"q_open_sec": 2.60,
			"q_close_sec": 1.80,
			"e_sec": 0.24,
			"f_sec": 10.0,
		},
		{
			"q_line_cost_per_10px": 0.34,
			"q_close_cost": 74.0,
			"e_cost": 31.0,
			"f_cost_percent": 24.0,
		}
	)
	spec["q_open"] = {
		"summary": "镜点与假身改写追击目标，制造错位窗。",
		"assets": ["镜点", "假身", "返程线"],
	}
	spec["q_close"] = {
		"summary": "闭成镜域并复演关键动作。",
		"assets": ["镜域", "复演数据"],
	}
	spec["e"] = {
		"summary": "单按换位保底，开线后开错位窗或复演，闭合后镜域复写。",
		"default_target_slot": "e",
	}
	spec["dash_link"] = {
		"summary": "左键冲撞若从真身穿向镜点，会在终点追加一次镜换判定。",
	}
	spec["f"] = {
		"pack_sources": ["返程轨迹", "复演终点", "镜域边缘"],
		"pickup_hint": {
			"effect_id": "illusionist_shard",
			"pickup_text": "镜片",
			"vfx_color": Color(0.86, 0.72, 1.0, 0.92),
			"text_color": Color(0.94, 0.84, 1.0),
			"effect_scale": 0.56,
		},
		"first_pack_reward_id": "illusionist_replay_shard",
		"jackpot_chance": 0.10,
		"core_pool": [
			build_core_reward(
				"illusionist_replay_shard",
				"复演片",
				"e",
				{
					"damage_amp_bonus": 0.22,
					"duration_amp_bonus": 0.18,
					"charges": 2,
					"effect_hint": "下一次 E 双换位或双复演",
				},
				"rare",
				["double_replay"]
			),
			build_core_reward(
				"illusionist_misalign_page",
				"错位页",
				"q_close",
				{
					"q_damage_amp_bonus": 0.22,
					"q_duration_amp_bonus": 0.20,
					"effect_hint": "下一次 Q 闭合保留一个假位",
				},
				"rare",
				["retain_decoy"]
			),
		],
		"utility_pool": [
			build_utility_reward(
				"illusionist_clarity_tonic",
				"清醒药",
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
				"illusionist_oracle",
				"镜域圣谕",
				"e",
				{
					"damage_amp_bonus": 0.28,
					"duration_amp_bonus": 0.20,
					"effect_hint": "下一次 E 换位后再复制一次关键动作",
				},
				"legendary",
				["copy_action"]
			),
		],
	}
