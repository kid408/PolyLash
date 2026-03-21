extends "res://scripts/qef/roles/role_spec_base.gd"
class_name WeaverSpec

func _init() -> void:
	spec = build_base_spec(
		"weaver",
		"织网者",
		"万丝态",
		{
			"q_open_sec": 3.00,
			"q_close_sec": 2.00,
			"e_sec": 0.30,
			"f_sec": 10.0,
		},
		{
			"q_line_cost_per_10px": 0.36,
			"q_close_cost": 80.0,
			"e_cost": 38.0,
			"f_cost_percent": 26.0,
		}
	)
	spec["q_open"] = {
		"summary": "丝线切路并保留返程回收价值。",
		"assets": ["丝线", "返程线", "收网中心"],
	}
	spec["q_close"] = {
		"summary": "闭合成网囊并把散怪拉成一团。",
		"assets": ["网囊", "囊口"],
	}
	spec["e"] = {
		"summary": "强收拆脸，开线回收，闭合后网囊强收。",
		"default_target_slot": "e",
	}
	spec["dash_link"] = {
		"summary": "左键穿过丝线会触发一次绷断反拉。",
	}
	spec["f"] = {
		"pack_sources": ["返程线末端", "收网中心", "囊口边缘"],
		"first_pack_reward_id": "weaver_return_core",
		"jackpot_chance": 0.10,
		"core_pool": [
			build_core_reward(
				"weaver_return_core",
				"返核签",
				"e",
				{
					"damage_amp_bonus": 0.26,
					"duration_amp_bonus": 0.22,
					"charges": 2,
					"effect_hint": "下一次 E 追加二段收网",
				},
				"rare",
				["double_pull"]
			),
			build_core_reward(
				"weaver_pouch_needle",
				"囊口针",
				"q_close",
				{
					"q_damage_amp_bonus": 0.24,
					"q_duration_amp_bonus": 0.22,
					"effect_hint": "下一次 Q 闭合囊口自动缩一次",
				},
				"rare",
				["auto_shrink"]
			),
		],
		"utility_pool": [
			build_utility_reward(
				"weaver_spider_tonic",
				"蛛丝药",
				{
					"energy_gain": 70.0,
					"temp_meta_key": "buff_speed_boost",
					"temp_meta_delta": 0.14,
					"temp_meta_duration": 2.0,
				}
			),
		],
		"jackpot_pool": [
			build_core_reward(
				"weaver_homecoming",
				"万丝归巢",
				"e",
				{
					"damage_amp_bonus": 0.30,
					"duration_amp_bonus": 0.24,
					"effect_hint": "下一次 E 双收网并保留一个返程核",
				},
				"legendary",
				["persistent_core"]
			),
		],
	}
