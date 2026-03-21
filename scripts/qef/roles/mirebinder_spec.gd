extends "res://scripts/qef/roles/role_spec_base.gd"
class_name MirebinderSpec

func _init() -> void:
	spec = build_base_spec(
		"mirebinder",
		"墨沼师",
		"裂涌态",
		{
			"q_open_sec": 2.80,
			"q_close_sec": 2.00,
			"e_sec": 0.28,
			"f_sec": 10.0,
		},
		{
			"q_line_cost_per_10px": 0.37,
			"q_close_cost": 80.0,
			"e_cost": 35.0,
			"f_cost_percent": 25.0,
		}
	)
	spec["q_open"] = {
		"summary": "墨沼脉形成黏路和缓冲带，让敌人越追越慢。",
		"assets": ["墨沼脉", "鼓泡纹理", "黏路"],
	}
	spec["q_close"] = {
		"summary": "闭成吞足潭，把目标拖沉到中心。",
		"assets": ["吞足潭", "中心吸附"],
	}
	spec["e"] = {
		"summary": "单按翻浆拆脸，开线后抽泥或凝泥，闭合后中心吸沉。",
		"default_target_slot": "e",
	}
	spec["dash_link"] = {
		"summary": "总表未定义额外左键冲撞联动。",
	}
	spec["f"] = {
		"pack_sources": ["翻浆点", "吞没中心", "沼脉交点"],
		"pickup_hint": {
			"effect_id": "mirebinder_mud",
			"pickup_text": "沼印",
			"vfx_color": Color(0.42, 0.72, 0.38, 0.92),
			"text_color": Color(0.64, 0.86, 0.58),
			"effect_scale": 0.54,
		},
		"first_pack_reward_id": "mirebinder_thick_mud",
		"jackpot_chance": 0.10,
		"core_pool": [
			build_core_reward(
				"mirebinder_thick_mud",
				"厚泥签",
				"e",
				{
					"damage_amp_bonus": 0.22,
					"duration_amp_bonus": 0.18,
					"charges": 2,
					"effect_hint": "下一次 E 双翻浆",
				},
				"rare",
				["double_surge"]
			),
			build_core_reward(
				"mirebinder_rift_tide",
				"裂涌片",
				"q_close",
				{
					"q_damage_amp_bonus": 0.22,
					"q_duration_amp_bonus": 0.20,
					"effect_hint": "下一次 Q 闭合追加一层内潭",
				},
				"rare",
				["inner_pool"]
			),
		],
		"utility_pool": [
			build_utility_reward(
				"mirebinder_wet_shell",
				"湿壳",
				{
					"energy_gain": 70.0,
					"temp_meta_key": "damage_taken_mult",
					"temp_meta_delta": -0.10,
					"temp_meta_duration": 2.0,
				}
			),
		],
		"jackpot_pool": [
			build_linked_reward(
				"mirebinder_edict",
				"墨沼谕令",
				{
					"damage_amp_bonus": 0.26,
					"duration_amp_bonus": 0.20,
					"effect_hint": "E 附强吸附",
				},
				{
					"q_damage_amp_bonus": 0.26,
					"q_duration_amp_bonus": 0.20,
					"effect_hint": "Q 闭合附强吸附",
				}
			),
		],
	}
