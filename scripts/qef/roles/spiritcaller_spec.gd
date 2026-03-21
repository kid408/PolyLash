extends "res://scripts/qef/roles/role_spec_base.gd"
class_name SpiritcallerSpec

func _init() -> void:
	spec = build_base_spec(
		"spiritcaller",
		"祖灵祭司",
		"祖灵共鸣态",
		{
			"q_open_sec": 3.20,
			"q_close_sec": 2.20,
			"e_sec": 0.30,
			"f_sec": 10.0,
		},
		{
			"q_line_cost_per_10px": 0.37,
			"q_close_cost": 84.0,
			"e_cost": 34.0,
			"f_cost_percent": 25.0,
		}
	)
	spec["q_open"] = {
		"summary": "图腾、空节点与并网让单节点也可站位。",
		"assets": ["图腾", "空节点", "并网连线"],
	}
	spec["q_close"] = {
		"summary": "闭成祖灵阵并沿阵边触发共鸣回震。",
		"assets": ["祖灵阵", "共鸣脉冲"],
	}
	spec["e"] = {
		"summary": "单按搬点保命，开线后并网或搬点，闭合后整阵回震。",
		"default_target_slot": "e",
	}
	spec["dash_link"] = {
		"summary": "总表未定义额外左键冲撞联动。",
	}
	spec["f"] = {
		"pack_sources": ["图腾底座", "共鸣终点", "阵边缘"],
		"pickup_hint": {
			"effect_id": "spiritcaller_bone",
			"pickup_text": "骨片",
			"vfx_color": Color(0.84, 0.82, 0.72, 0.92),
			"text_color": Color(0.94, 0.92, 0.84),
			"effect_scale": 0.54,
		},
		"first_pack_reward_id": "spiritcaller_weave_sign",
		"jackpot_chance": 0.10,
		"core_pool": [
			build_core_reward(
				"spiritcaller_weave_sign",
				"并网签",
				"e",
				{
					"damage_amp_bonus": 0.22,
					"duration_amp_bonus": 0.18,
					"charges": 1,
					"effect_hint": "下一次 E 多并一个节点",
				},
				"rare",
				["extra_node"]
			),
			build_core_reward(
				"spiritcaller_reverb_shard",
				"回震片",
				"q_close",
				{
					"q_damage_amp_bonus": 0.20,
					"q_duration_amp_bonus": 0.20,
					"effect_hint": "下一次 Q 闭合多一次共鸣脉冲",
				},
				"rare",
				["extra_reverb"]
			),
		],
		"utility_pool": [
			build_utility_reward(
				"spiritcaller_ash",
				"灵灰",
				{
					"energy_gain": 70.0,
					"temp_meta_key": "armor_gain",
					"temp_meta_delta": 0.0,
					"temp_meta_duration": 0.0,
					"armor_gain": 1,
				}
			),
		],
		"jackpot_pool": [
			build_core_reward(
				"spiritcaller_oracle",
				"祖灵谕令",
				"e",
				{
					"damage_amp_bonus": 0.26,
					"duration_amp_bonus": 0.20,
					"effect_hint": "下一次 E 搬点后复制一个副图腾",
				},
				"legendary",
				["echo_totem"]
			),
		],
	}
