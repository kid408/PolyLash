extends "res://scripts/qef/roles/role_spec_base.gd"
class_name SwarmSpec

func _init() -> void:
	spec = build_base_spec(
		"swarm",
		"巢母",
		"母巢解放态",
		{
			"q_open_sec": 3.00,
			"q_close_sec": 2.00,
			"e_sec": 0.26,
			"f_sec": 10.0,
		},
		{
			"q_line_cost_per_10px": 0.37,
			"q_close_cost": 82.0,
			"e_cost": 34.0,
			"f_cost_percent": 25.0,
		}
	)
	spec["q_open"] = {
		"summary": "虫路与虫卵会做出持续骚扰带，把一侧战线交给虫潮拖住。",
		"assets": ["虫路", "虫卵", "骚扰脉冲"],
	}
	spec["q_close"] = {
		"summary": "闭成母巢圈并让圈内虫群回补、换路、再扑。",
		"assets": ["母巢圈", "回扑终点"],
	}
	spec["e"] = {
		"summary": "单按孵化爆裂保底，开线后转巢或同步孵化，闭合后催孵再扑。",
		"default_target_slot": "e",
	}
	spec["dash_link"] = {
		"summary": "总表未定义额外左键冲撞联动。",
	}
	spec["f"] = {
		"pack_sources": ["虫路节点", "回扑终点", "母巢圈边缘"],
		"pickup_hint": {
			"effect_id": "swarm_egg",
			"pickup_text": "虫卵",
			"vfx_color": Color(0.84, 0.94, 0.38, 0.92),
			"text_color": Color(0.94, 1.0, 0.58),
			"effect_scale": 0.56,
		},
		"first_pack_reward_id": "swarm_rehatch_core",
		"jackpot_chance": 0.10,
		"core_pool": [
			build_core_reward(
				"swarm_rehatch_core",
				"再孵核",
				"e",
				{
					"damage_amp_bonus": 0.24,
					"duration_amp_bonus": 0.18,
					"charges": 2,
					"effect_hint": "下一次 E 双孵化",
				},
				"rare",
				["double_hatch"]
			),
			build_core_reward(
				"swarm_brood_membrane",
				"巢圈膜",
				"q_close",
				{
					"q_damage_amp_bonus": 0.22,
					"q_duration_amp_bonus": 0.22,
					"effect_hint": "下一次 Q 闭合追加一轮回扑",
				},
				"rare",
				["extra_return_swarm"]
			),
		],
		"utility_pool": [
			build_utility_reward(
				"swarm_slurry",
				"虫浆",
				{
					"energy_gain": 70.0,
				}
			),
		],
		"jackpot_pool": [
			build_core_reward(
				"swarm_queen_will",
				"母巢旨意",
				"e",
				{
					"damage_amp_bonus": 0.28,
					"duration_amp_bonus": 0.20,
					"effect_hint": "下一次 E 转巢后自动补一条副虫路",
				},
				"legendary",
				["extra_brood_path"]
			),
		],
	}
