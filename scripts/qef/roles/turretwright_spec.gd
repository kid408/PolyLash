extends "res://scripts/qef/roles/role_spec_base.gd"
class_name TurretwrightSpec

func _init() -> void:
	spec = build_base_spec(
		"turretwright",
		"炮械师",
		"超频态",
		{
			"q_open_sec": 3.40,
			"q_close_sec": 2.20,
			"e_sec": 0.30,
			"f_sec": 10.0,
		},
		{
			"q_line_cost_per_10px": 0.36,
			"q_close_cost": 80.0,
			"e_cost": 33.0,
			"f_cost_percent": 25.0,
		}
	)
	spec["q_open"] = {
		"summary": "炮点和空炮位让单炮点就能看住一路。",
		"assets": ["炮点", "空炮位", "火线缓存"],
	}
	spec["q_close"] = {
		"summary": "闭成交叉火网并让交叉火线短时超频。",
		"assets": ["交叉火网", "超频蓄能圈"],
	}
	spec["e"] = {
		"summary": "单按速建微炮，开线后转炮或串炮，闭合后火网超频。",
		"default_target_slot": "e",
	}
	spec["dash_link"] = {
		"summary": "总表未定义额外左键冲撞联动。",
	}
	spec["f"] = {
		"pack_sources": ["炮座", "交叉火点", "超频终点"],
		"pickup_hint": {
			"effect_id": "turretwright_chip",
			"pickup_text": "插芯",
			"vfx_color": Color(0.68, 0.86, 0.44, 0.92),
			"text_color": Color(0.84, 0.96, 0.62),
			"effect_scale": 0.56,
		},
		"first_pack_reward_id": "turretwright_chain_chip",
		"jackpot_chance": 0.10,
		"core_pool": [
			build_core_reward(
				"turretwright_chain_chip",
				"串炮芯",
				"e",
				{
					"damage_amp_bonus": 0.22,
					"duration_amp_bonus": 0.18,
					"charges": 1,
					"effect_hint": "下一次 E 多串一座炮",
				},
				"rare",
				["extra_turret"]
			),
			build_core_reward(
				"turretwright_overclock_plate",
				"超频片",
				"q_close",
				{
					"q_damage_amp_bonus": 0.22,
					"q_duration_amp_bonus": 0.20,
					"effect_hint": "下一次 Q 闭合追加一轮重炮扫线",
				},
				"rare",
				["extra_barrage"]
			),
		],
		"utility_pool": [
			build_utility_reward(
				"turretwright_powder_box",
				"火药箱",
				{
					"energy_gain": 80.0,
				}
			),
		],
		"jackpot_pool": [
			build_core_reward(
				"turretwright_tactical_overclock",
				"战术超频",
				"e",
				{
					"damage_amp_bonus": 0.28,
					"duration_amp_bonus": 0.20,
					"effect_hint": "下一次 E 转炮后复制一条交叉火",
				},
				"legendary",
				["copy_fireline"]
			),
		],
	}
