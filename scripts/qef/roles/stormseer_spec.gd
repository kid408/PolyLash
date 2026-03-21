extends "res://scripts/qef/roles/role_spec_base.gd"
class_name StormseerSpec

func _init() -> void:
	spec = build_base_spec(
		"stormseer",
		"岚眼术士",
		"主宰态",
		{
			"q_open_sec": 3.00,
			"q_close_sec": 2.00,
			"e_sec": 0.28,
			"f_sec": 10.0,
		},
		{
			"q_line_cost_per_10px": 0.35,
			"q_close_cost": 78.0,
			"e_cost": 35.0,
			"f_cost_percent": 25.0,
		}
	)
	spec["q_open"] = {
		"summary": "主眼和流场会搬运怪群与改写路线。",
		"assets": ["主眼", "流场箭头", "副眼"],
	}
	spec["q_close"] = {
		"summary": "多眼闭成台风核并协同吸放。",
		"assets": ["台风核", "多眼连线"],
	}
	spec["e"] = {
		"summary": "单按换眼保底，开线后并眼或甩眼，闭合后整体重排怪群。",
		"default_target_slot": "e",
	}
	spec["dash_link"] = {
		"summary": "总表未定义额外左键冲撞联动。",
	}
	spec["f"] = {
		"pack_sources": ["主眼", "副眼", "交点"],
		"pickup_hint": {
			"effect_id": "stormseer_glyph",
			"pickup_text": "岚签",
			"vfx_color": Color(0.58, 0.94, 0.90, 0.92),
			"text_color": Color(0.78, 1.0, 0.96),
			"effect_scale": 0.56,
		},
		"first_pack_reward_id": "stormseer_bind_sign",
		"jackpot_chance": 0.10,
		"core_pool": [
			build_core_reward(
				"stormseer_bind_sign",
				"并眼签",
				"e",
				{
					"damage_amp_bonus": 0.22,
					"duration_amp_bonus": 0.18,
					"charges": 1,
					"effect_hint": "下一次 E 多并一个眼",
				},
				"rare",
				["extra_eye"]
			),
			build_core_reward(
				"stormseer_typhoon_badge",
				"台风章",
				"q_close",
				{
					"q_damage_amp_bonus": 0.22,
					"q_duration_amp_bonus": 0.20,
					"effect_hint": "下一次 Q 闭合追加一轮内吸",
				},
				"rare",
				["extra_pull"]
			),
		],
		"utility_pool": [
			build_utility_reward(
				"stormseer_eye_breath",
				"风眼息",
				{
					"energy_gain": 80.0,
					"temp_meta_key": "cooldown_mult",
					"temp_meta_delta": -0.10,
					"temp_meta_duration": 2.0,
				}
			),
		],
		"jackpot_pool": [
			build_core_reward(
				"stormseer_dominion_edict",
				"主宰敕令",
				"e",
				{
					"damage_amp_bonus": 0.28,
					"duration_amp_bonus": 0.20,
					"effect_hint": "下一次 E 换眼后额外甩出一颗副眼",
				},
				"legendary",
				["extra_throw_eye"]
			),
		],
	}
