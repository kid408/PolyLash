extends "res://scripts/qef/roles/role_spec_base.gd"
class_name PaladinSpec

func _init() -> void:
	spec = build_base_spec(
		"paladin",
		"圣卫",
		"圣谕态",
		{
			"q_open_sec": 2.80,
			"q_close_sec": 2.00,
			"e_sec": 0.30,
			"f_sec": 10.0,
		},
		{
			"q_line_cost_per_10px": 0.40,
			"q_close_cost": 100.0,
			"e_cost": 40.0,
			"f_cost_percent": 27.0,
		}
	)
	spec["q_open"] = {
		"summary": "誓墙和圣障形成可贴着走的前线推进面。",
		"assets": ["誓墙", "圣障", "推进面"],
	}
	spec["q_close"] = {
		"summary": "守誓庭压向指定边并露出推进口。",
		"assets": ["守誓庭", "压庭口"],
	}
	spec["e"] = {
		"summary": "单按誓约突进，开线后前推或接伤，闭合后压庭裁决。",
		"default_target_slot": "e",
	}
	spec["dash_link"] = {
		"summary": "E 后 0.35 秒内穿过誓墙会补一次小型圣障回推。",
	}
	spec["f_energy"] = {
		"q_line_cost_discount": 0.20,
		"q_close_cost_discount": 0.30,
		"e_cost_discount": 0.15,
	}
	spec["f"] = {
		"pack_sources": ["墙边", "推进终点", "压庭口"],
		"pickup_hint": {
			"effect_id": "paladin_seal",
			"pickup_text": "圣印",
			"vfx_color": Color(1.0, 0.88, 0.42, 0.92),
			"text_color": Color(1.0, 0.94, 0.62),
			"effect_scale": 0.58,
		},
		"first_pack_reward_id": "paladin_forward_oath",
		"jackpot_chance": 0.10,
		"core_pool": [
			build_core_reward(
				"paladin_forward_oath",
				"前推誓印",
				"e",
				{
					"damage_amp_bonus": 0.24,
					"duration_amp_bonus": 0.18,
					"charges": 2,
					"effect_hint": "下一次 E 多一次前推",
				},
				"rare",
				["double_push"]
			),
			build_core_reward(
				"paladin_court_order",
				"审庭令",
				"q_close",
				{
					"q_damage_amp_bonus": 0.24,
					"q_duration_amp_bonus": 0.20,
					"effect_hint": "下一次 Q 闭合追加内推",
				},
				"rare",
				["inner_push"]
			),
		],
		"utility_pool": [
			build_utility_reward(
				"paladin_prayer_guard",
				"祷护",
				{
					"energy_gain": 60.0,
					"armor_gain": 1,
				}
			),
		],
		"jackpot_pool": [
			build_linked_reward(
				"paladin_revelation",
				"圣谕降临",
				{
					"damage_amp_bonus": 0.28,
					"duration_amp_bonus": 0.18,
					"effect_hint": "E 附净化与推庭",
				},
				{
					"q_damage_amp_bonus": 0.28,
					"q_duration_amp_bonus": 0.20,
					"effect_hint": "Q 闭合附净化与推庭",
				}
			),
		],
	}
