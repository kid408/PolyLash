extends "res://scripts/qef/roles/role_spec_base.gd"
class_name HexwardenSpec

func _init() -> void:
	spec = build_base_spec(
		"hexwarden",
		"咒铠师",
		"大巫态",
		{
			"q_open_sec": 2.60,
			"q_close_sec": 1.90,
			"e_sec": 0.26,
			"f_sec": 10.0,
		},
		{
			"q_line_cost_per_10px": 0.40,
			"q_close_cost": 90.0,
			"e_cost": 38.0,
			"f_cost_percent": 27.0,
		}
	)
	spec["q_open"] = {
		"summary": "咒铠片和咒甲钉把自身周围变成危险咒面。",
		"assets": ["咒铠片", "咒甲钉", "贴身惩罚"],
	}
	spec["q_close"] = {
		"summary": "闭成封咒廊，让内部目标共享衰弱与减速。",
		"assets": ["封咒廊", "牵连线"],
	}
	spec["e"] = {
		"summary": "单按碎甲反咬，开线后换铠面或转咒，闭合后反冲前排。",
		"default_target_slot": "e",
	}
	spec["dash_link"] = {
		"summary": "总表未定义额外左键冲撞联动。",
	}
	spec["f_energy"] = {
		"q_line_cost_discount": 0.20,
		"q_close_cost_discount": 0.25,
		"e_cost_discount": 0.20,
	}
	spec["f"] = {
		"pack_sources": ["碎甲点", "反冲终点", "咒廊夹角"],
		"pickup_hint": {
			"effect_id": "hexwarden_nail",
			"pickup_text": "咒钉",
			"vfx_color": Color(0.78, 0.42, 1.0, 0.92),
			"text_color": Color(0.86, 0.62, 1.0),
			"effect_scale": 0.56,
		},
		"first_pack_reward_id": "hexwarden_bite_sign",
		"jackpot_chance": 0.10,
		"core_pool": [
			build_core_reward(
				"hexwarden_bite_sign",
				"反咬签",
				"e",
				{
					"damage_amp_bonus": 0.26,
					"duration_amp_bonus": 0.18,
					"charges": 2,
					"effect_hint": "下一次 E 双重反咬",
				},
				"rare",
				["double_bite"]
			),
			build_core_reward(
				"hexwarden_seal_nail",
				"封咒钉",
				"q_close",
				{
					"q_damage_amp_bonus": 0.22,
					"q_duration_amp_bonus": 0.20,
					"effect_hint": "下一次 Q 闭合追加一道牵连线",
				},
				"rare",
				["extra_link"]
			),
		],
		"utility_pool": [
			build_utility_reward(
				"hexwarden_witch_blood",
				"巫血",
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
				"hexwarden_godform",
				"大巫降神",
				"e",
				{
					"damage_amp_bonus": 0.30,
					"duration_amp_bonus": 0.22,
					"effect_hint": "下一次 E 反咬并把周围怪拖进咒廊",
				},
				"legendary",
				["hall_pull"]
			),
		],
	}
