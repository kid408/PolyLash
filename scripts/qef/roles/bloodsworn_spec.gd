extends "res://scripts/qef/roles/role_spec_base.gd"
class_name BloodswornSpec

func _init() -> void:
	spec = build_base_spec(
		"bloodsworn",
		"血契者",
		"盛宴态",
		{
			"q_open_sec": 2.40,
			"q_close_sec": 1.60,
			"e_sec": 0.24,
			"f_sec": 10.0,
		},
		{
			"q_line_cost_per_10px": 0.36,
			"q_close_cost": 88.0,
			"e_cost": 38.0,
			"f_cost_percent": 26.0,
		}
	)
	spec["q_open"] = {
		"summary": "血债印与猩红回路把目标压成可追猎状态。",
		"assets": ["血债印", "猩红回路", "猎物标记"],
	}
	spec["q_close"] = {
		"summary": "闭成盛宴圈，让低血目标持续被追猎。",
		"assets": ["盛宴圈", "追猎名单"],
	}
	spec["e"] = {
		"summary": "单按扑击保底，开线后收债连扑，闭合后沿圈连续追猎。",
		"default_target_slot": "e",
	}
	spec["dash_link"] = {
		"summary": "左键冲撞命中血债目标后，0.2 秒内允许 E 追加一次免费次扑。",
	}
	spec["f"] = {
		"pack_sources": ["债印目标", "扑击终点", "盛宴圈边缘"],
		"pickup_hint": {
			"effect_id": "bloodsworn_contract",
			"pickup_text": "血契",
			"vfx_color": Color(0.98, 0.18, 0.24, 0.92),
			"text_color": Color(1.0, 0.42, 0.48),
			"effect_scale": 0.56,
		},
		"first_pack_reward_id": "bloodsworn_hunt_mark",
		"jackpot_chance": 0.10,
		"core_pool": [
			build_core_reward(
				"bloodsworn_hunt_mark",
				"猎印",
				"e",
				{
					"damage_amp_bonus": 0.24,
					"duration_amp_bonus": 0.18,
					"charges": 2,
					"effect_hint": "下一次 E 双扑",
				},
				"rare",
				["double_pounce"]
			),
			build_core_reward(
				"bloodsworn_feast_skewer",
				"盛宴肉签",
				"q_close",
				{
					"q_damage_amp_bonus": 0.22,
					"q_duration_amp_bonus": 0.18,
					"effect_hint": "下一次 Q 闭合多一段追猎",
				},
				"rare",
				["extra_hunt"]
			),
		],
		"utility_pool": [
			build_utility_reward(
				"bloodsworn_hot_blood",
				"热血",
				{
					"energy_gain": 70.0,
					"temp_meta_key": "lifesteal",
					"temp_meta_delta": 0.10,
					"temp_meta_duration": 2.0,
				}
			),
		],
		"jackpot_pool": [
			build_core_reward(
				"bloodsworn_crimson_edict",
				"猩红敕令",
				"e",
				{
					"damage_amp_bonus": 0.30,
					"duration_amp_bonus": 0.20,
					"effect_hint": "下一次 E 连扑并刷新一次血债",
				},
				"legendary",
				["refresh_debt"]
			),
		],
	}
