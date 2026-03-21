extends "res://scripts/qef/roles/role_spec_base.gd"
class_name TrapperSpec

func _init() -> void:
	spec = build_base_spec(
		"trapper",
		"伏猎者",
		"伏猎季态",
		{
			"q_open_sec": 3.00,
			"q_close_sec": 1.90,
			"e_sec": 0.24,
			"f_sec": 10.0,
		},
		{
			"q_line_cost_per_10px": 0.36,
			"q_close_cost": 78.0,
			"e_cost": 33.0,
			"f_cost_percent": 25.0,
		}
	)
	spec["q_open"] = {
		"summary": "伏线和夹口会把敌人的必经路改成高代价路线。",
		"assets": ["伏线", "夹口", "亮标目标"],
	}
	spec["q_close"] = {
		"summary": "闭成终猎袋并让每次触线都继续收紧袋口。",
		"assets": ["终猎袋", "袋口处刑点"],
	}
	spec["e"] = {
		"summary": "单按收线拆脸，开线后强触发或改夹口，闭合后整体收紧到处刑点。",
		"default_target_slot": "e",
	}
	spec["dash_link"] = {
		"summary": "左键冲撞若横切己方伏线，则在冲撞终点触发一次强收线，优先拉最近亮标目标。",
	}
	spec["f"] = {
		"pack_sources": ["伏线节点", "收线终点", "猎袋口"],
		"pickup_hint": {
			"effect_id": "trapper_clamp",
			"pickup_text": "猎夹",
			"vfx_color": Color(0.96, 0.94, 0.54, 0.92),
			"text_color": Color(1.0, 0.98, 0.70),
			"effect_scale": 0.56,
		},
		"first_pack_reward_id": "trapper_extra_clamp",
		"jackpot_chance": 0.10,
		"core_pool": [
			build_core_reward(
				"trapper_extra_clamp",
				"补夹牌",
				"e",
				{
					"damage_amp_bonus": 0.24,
					"duration_amp_bonus": 0.18,
					"charges": 2,
					"effect_hint": "下一次 E 双收线",
				},
				"rare",
				["double_reel"]
			),
			build_core_reward(
				"trapper_hunt_bag_seal",
				"猎袋章",
				"q_close",
				{
					"q_damage_amp_bonus": 0.22,
					"q_duration_amp_bonus": 0.20,
					"effect_hint": "下一次 Q 闭合追加一道内夹线",
				},
				"rare",
				["inner_snare"]
			),
		],
		"utility_pool": [
			build_utility_reward(
				"trapper_adrenal_water",
				"肾上水",
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
				"trapper_hunt_season",
				"猎时令",
				"e",
				{
					"damage_amp_bonus": 0.28,
					"duration_amp_bonus": 0.20,
					"effect_hint": "下一次 E 收线后自动补出一条新伏线",
				},
				"legendary",
				["auto_new_snare"]
			),
		],
	}
