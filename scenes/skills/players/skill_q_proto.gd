extends SkillDrawingBase
class_name SkillQProto

var q_profile_id: int = 1

const PROFILE_COUNT: int = 32

const META_LAST_PROFILE: String = "q_proto_last_profile"
const META_LAST_MODE: String = "q_proto_last_mode"
const META_LAST_CENTER: String = "q_proto_last_center"
const META_LAST_RADIUS: String = "q_proto_last_radius"
const META_LAST_CLOSED: String = "q_proto_last_closed"
const META_LAST_TIME: String = "q_proto_last_time_msec"
const META_LAST_POLYGON: String = "q_proto_last_polygon"
const META_NODE_MINES: String = "q_proto_nodes_mines"
const META_NODE_ANCHORS: String = "q_proto_nodes_anchors"
const META_NODE_DECOYS: String = "q_proto_nodes_decoys"
const META_NODE_SEEDS: String = "q_proto_nodes_seeds"
const META_NODE_CRYSTALS: String = "q_proto_nodes_crystals"
const META_NODE_BAITS: String = "q_proto_nodes_baits"
const META_TEMP_Q_AMP: String = "q_proto_temp_amp"

const PROFILE_NAMES: Array[String] = [
	"chain_execution",
	"web_recall",
	"fence_herd",
	"fire_arena",
	"mine_gambit",
	"ice_lock",
	"decoy_stake",
	"wind_recall",
	"rail_ballistic",
	"curse_trigger",
	"medical_lockfield",
	"time_replay",
	"mirror_counter",
	"rail_rewrite",
	"anchor_combo",
	"blood_pact",
	"phase_disrupt",
	"lightning_chain",
	"toxin_pressure",
	"shadow_gate",
	"gravity_well",
	"ricochet_chamber",
	"barricade_lane",
	"blade_orbit",
	"crystal_resonance",
	"bait_control",
	"thermal_clear",
	"spear_verdict",
	"tide_cycle",
	"verdict_stack",
	"echo_counter",
	"rift_terminal"
]

const LINE_MODES: Array[String] = [
	"saw_launch",
	"web_thread",
	"fence_dash",
	"fire_wall",
	"mine_track",
	"ice_wall",
	"decoy_line",
	"wind_pull",
	"rail_line",
	"curse_line",
	"medic_line",
	"time_mark",
	"mirror_line",
	"rail_shift",
	"anchor_line",
	"blood_line",
	"phase_line",
	"lightning_line",
	"toxin_line",
	"shadow_line",
	"gravity_line",
	"ricochet_line",
	"barricade_line",
	"blade_line",
	"crystal_line",
	"bait_line",
	"thermal_line",
	"spear_line",
	"tide_line",
	"verdict_line",
	"echo_line",
	"rift_seed"
]

const AREA_MODES: Array[String] = [
	"chain_cage",
	"recall_net",
	"pen_lock",
	"inferno_field",
	"minefield",
	"freeze_ring",
	"decoy_network",
	"wind_recall",
	"rail_nodes",
	"mark_burst",
	"medic_field",
	"time_replay",
	"mirror_room",
	"track_rearrange",
	"anchor_core",
	"blood_pool",
	"phase_shuffle",
	"lightning_net",
	"outside_toxin",
	"shadow_maze",
	"gravity_well",
	"echo_reflect",
	"barricade_ring",
	"blade_center",
	"crystal_resonance",
	"bait_tower",
	"thermal_blast",
	"spear_return",
	"tide_cycle",
	"verdict_zone",
	"echo_field",
	"rift_closure"
]

func _ready() -> void:
	if q_profile_id < 1:
		q_profile_id = 1
	elif q_profile_id > PROFILE_COUNT:
		q_profile_id = PROFILE_COUNT

	if cooldown_time <= 0.0:
		cooldown_time = 0.45
	if energy_per_10px <= 0.0:
		energy_per_10px = 0.40
	if energy_threshold_distance <= 0.0:
		energy_threshold_distance = 1800.0
	if energy_scale_multiplier <= 0.0:
		energy_scale_multiplier = 0.0006
	if base_line_duration <= 0.0:
		base_line_duration = _line_duration_scale()
	super._ready()

func _spawn_line_effect(start: Vector2, end: Vector2) -> void:
	var line_mode: String = _line_mode()
	var line_damage: int = _line_damage()
	var line_width: float = _line_width()
	var line_duration: float = _line_duration_scale()
	var line_color: Color = _line_color()
	var pull_force: float = _line_pull_force()
	var status_value: float = _line_status_value()

	match line_mode:
		"fire_wall", "ice_wall", "barricade_line", "fence_dash":
			SkillEffectManager.create_wall_effect({
				"start": start,
				"end": end,
				"width": line_width,
				"duration": line_duration,
				"block_enemies": true,
				"block_bullets": line_mode == "ice_wall" or line_mode == "mirror_line",
				"contact_damage": line_damage,
				"contact_interval": 0.24,
				"color": line_color
			})
		"mine_track", "rift_seed":
			_spawn_segment_traps(start, end, META_NODE_MINES, line_damage, 78.0, 0.75, line_color)
		"anchor_line":
			_spawn_segment_traps(start, end, META_NODE_ANCHORS, line_damage, 72.0, 0.9, line_color)
		"crystal_line":
			_spawn_segment_traps(start, end, META_NODE_CRYSTALS, line_damage, 86.0, 1.0, line_color)
		"bait_line":
			_spawn_segment_traps(start, end, META_NODE_BAITS, line_damage, 82.0, 0.85, line_color)
		"decoy_line":
			_spawn_segment_traps(start, end, META_NODE_DECOYS, line_damage, 74.0, 0.95, line_color)
		"wind_pull", "gravity_line", "tide_line", "rail_shift":
			SkillEffectManager.create_line_effect({
				"start": start,
				"end": end,
				"width": line_width,
				"damage": line_damage,
				"damage_interval": 0.30,
				"duration": line_duration,
				"pull_to_line": true,
				"pull_force": pull_force,
				"pull_interval": 0.05,
				"color": line_color
			})
		"web_thread", "toxin_line", "curse_line", "verdict_line":
			SkillEffectManager.create_debuff_zone({
				"start": start,
				"end": end,
				"width": line_width,
				"duration": line_duration,
				"debuff_type": _line_debuff_type(),
				"debuff_value": status_value,
				"debuff_duration": 1.4,
				"tick_interval": 0.35,
				"damage": line_damage,
				"damage_interval": 0.35,
				"color": line_color
			})
		"medic_line":
			SkillEffectManager.create_debuff_zone({
				"start": start,
				"end": end,
				"width": line_width,
				"duration": line_duration,
				"debuff_type": "slow",
				"debuff_value": 0.45,
				"debuff_duration": 0.9,
				"tick_interval": 0.4,
				"damage": line_damage,
				"damage_interval": 0.4,
				"color": line_color
			})
			SkillEffectManager.create_buff_zone({
				"start": start,
				"end": end,
				"width": line_width + 10.0,
				"duration": line_duration,
				"buff_type": "heal",
				"buff_value": max(1.0, float(line_damage) * 0.10),
				"tick_interval": 0.8,
				"color": Color(0.35, 1.0, 0.75, 0.26),
				"target_group": "player"
			})
		_:
			SkillEffectManager.create_line_effect({
				"start": start,
				"end": end,
				"width": line_width,
				"damage": line_damage,
				"damage_interval": 0.28,
				"duration": line_duration,
				"color": line_color
			})

	_cache_line_context(start, end, line_mode)

func _spawn_area_effect(polygon: PackedVector2Array) -> void:
	if polygon.size() < 3:
		return

	var area_mode: String = _area_mode()
	var center: Vector2 = _polygon_center(polygon)
	var radius: float = _polygon_radius(polygon, center)
	var area_damage: int = _area_damage()
	var area_duration: float = _area_duration_scale()
	var area_color: Color = _closure_color()
	var pull_force: float = _area_pull_force()

	_cache_area_context(center, radius, area_mode, polygon)

	match area_mode:
		"chain_cage":
			_create_area_core(polygon, area_damage, area_duration, area_color, true, pull_force)
			_create_polygon_debuff(polygon, area_duration, "slow", 0.52, 1.1, 0.34, Color(1.0, 0.42, 0.35, 0.26))
		"recall_net":
			_create_area_core(polygon, area_damage, area_duration, area_color, false, 0.0)
			_create_polygon_debuff(polygon, area_duration, "damage_amp", 0.24, 1.3, 0.44, Color(0.5, 1.0, 1.2, 0.22))
			_schedule_polygon_pulse(polygon, 0.42, int(round(float(area_damage) * 0.72)), "slow", 0.9, 0.42, 360.0, true)
		"pen_lock":
			_spawn_polygon_walls(polygon, 16.0, area_duration, int(round(float(area_damage) * 0.55)), area_color)
			_create_polygon_debuff(polygon, area_duration, "slow", 0.5, 1.0, 0.4, Color(1.0, 0.86, 0.28, 0.22))
		"inferno_field", "thermal_blast":
			_create_area_core(polygon, area_damage, area_duration, area_color, false, 0.0)
			_create_polygon_debuff(polygon, area_duration, "poison", max(4.0, float(area_damage) * 0.12), 1.5, 0.38, Color(1.1, 0.36, 0.2, 0.22))
			_schedule_polygon_pulse(polygon, 0.55, int(round(float(area_damage) * 0.82)), "slow", 0.8, 0.3, 320.0, false)
		"minefield":
			_spawn_polygon_nodes(polygon, META_NODE_MINES, 8, int(round(float(area_damage) * 0.72)), 84.0, 0.65, area_color)
		"freeze_ring":
			_spawn_polygon_walls(polygon, 18.0, area_duration, int(round(float(area_damage) * 0.48)), area_color)
			_create_polygon_debuff(polygon, area_duration, "freeze", 0.0, 0.7, 0.9, Color(0.55, 0.85, 1.0, 0.22))
		"decoy_network":
			_spawn_polygon_nodes(polygon, META_NODE_DECOYS, 6, int(round(float(area_damage) * 0.58)), 72.0, 0.75, area_color)
			_create_polygon_debuff(polygon, area_duration, "fear", 0.0, 0.85, 0.9, Color(0.75, 0.55, 1.0, 0.20))
		"wind_recall", "gravity_well":
			_create_area_core(polygon, area_damage, area_duration, area_color, true, pull_force)
			_create_polygon_debuff(polygon, area_duration, "slow", 0.42, 0.9, 0.3, Color(0.55, 1.0, 1.0, 0.18))
		"rail_nodes", "blade_center":
			_create_area_core(polygon, int(round(float(area_damage) * 0.62)), area_duration, area_color, false, 0.0)
			_spawn_center_crossfire(center, radius, area_damage, area_duration, area_color)
		"mark_burst", "verdict_zone":
			_create_polygon_debuff(polygon, area_duration, "damage_amp", 0.28, 1.5, 0.42, Color(1.0, 0.45, 0.42, 0.22))
			_schedule_polygon_pulse(polygon, 0.50, int(round(float(area_damage) * 1.05)), "slow", 0.9, 0.45, 240.0, false)
		"medic_field":
			_create_area_core(polygon, int(round(float(area_damage) * 0.48)), area_duration, area_color, false, 0.0)
			SkillEffectManager.create_buff_zone({
				"polygon": polygon,
				"duration": area_duration,
				"buff_type": "heal",
				"buff_value": max(1.0, float(area_damage) * 0.10),
				"tick_interval": 0.7,
				"target_group": "player",
				"color": Color(0.35, 1.0, 0.75, 0.22)
			})
		"time_replay", "echo_field":
			_create_area_core(polygon, int(round(float(area_damage) * 0.58)), area_duration, area_color, false, 0.0)
			_schedule_polygon_pulse(polygon, 0.35, int(round(float(area_damage) * 0.62)), "slow", 0.8, 0.32, 0.0, false)
			_schedule_polygon_pulse(polygon, 0.85, int(round(float(area_damage) * 0.88)), "slow", 0.8, 0.36, 0.0, false)
		"mirror_room", "echo_reflect":
			_create_area_core(polygon, area_damage, area_duration, area_color, false, 0.0)
			_create_polygon_debuff(polygon, area_duration, "fear", 0.0, 0.9, 1.0, Color(0.75, 0.8, 1.0, 0.2))
		"track_rearrange", "phase_shuffle":
			_create_area_core(polygon, int(round(float(area_damage) * 0.72)), area_duration, area_color, true, pull_force * 0.8)
			_schedule_polygon_shuffle(polygon, area_duration, 0.48)
		"anchor_core":
			_spawn_polygon_nodes(polygon, META_NODE_ANCHORS, 7, int(round(float(area_damage) * 0.62)), 74.0, 0.75, area_color)
			_create_polygon_debuff(polygon, area_duration, "slow", 0.44, 1.0, 0.35, area_color)
		"blood_pool":
			_create_area_core(polygon, area_damage, area_duration, area_color, false, 0.0)
			_schedule_lifesteal_pulse(polygon, area_duration, int(round(float(area_damage) * 0.55)))
		"lightning_net":
			_create_area_core(polygon, int(round(float(area_damage) * 0.52)), area_duration, area_color, false, 0.0)
			_schedule_chain_lightning(polygon, area_duration, int(round(float(area_damage) * 0.86)))
		"outside_toxin":
			_create_area_core(polygon, int(round(float(area_damage) * 0.48)), area_duration, area_color, false, 0.0)
			_schedule_outside_polygon_damage(polygon, area_duration, int(round(float(area_damage) * 0.58)))
		"shadow_maze":
			_create_area_core(polygon, area_damage, area_duration, area_color, false, 0.0)
			_create_polygon_debuff(polygon, area_duration, "curse", max(4.0, float(area_damage) * 0.11), 1.4, 0.42, area_color)
		"barricade_ring":
			_spawn_polygon_walls(polygon, 20.0, area_duration, int(round(float(area_damage) * 0.52)), area_color)
		"crystal_resonance":
			_spawn_polygon_nodes(polygon, META_NODE_CRYSTALS, 9, int(round(float(area_damage) * 0.64)), 88.0, 0.82, area_color)
			_schedule_polygon_pulse(polygon, 0.66, int(round(float(area_damage) * 0.70)), "slow", 0.9, 0.36, 120.0, true)
		"bait_tower":
			_spawn_polygon_nodes(polygon, META_NODE_BAITS, 6, int(round(float(area_damage) * 0.54)), 76.0, 0.7, area_color)
			_create_polygon_debuff(polygon, area_duration, "slow", 0.40, 1.0, 0.34, area_color)
		"spear_return":
			_create_area_core(polygon, int(round(float(area_damage) * 0.68)), area_duration, area_color, false, 0.0)
			_schedule_polygon_pulse(polygon, 0.40, int(round(float(area_damage) * 0.75)), "damage_amp", 1.1, 0.20, 300.0, true)
		"tide_cycle":
			_create_area_core(polygon, int(round(float(area_damage) * 0.56)), area_duration, area_color, false, 0.0)
			_schedule_tide_cycle(polygon, area_duration, int(round(float(area_damage) * 0.62)))
		"rift_closure":
			_spawn_polygon_nodes(polygon, META_NODE_SEEDS, 10, int(round(float(area_damage) * 0.66)), 82.0, 0.58, area_color)
			_schedule_polygon_pulse(polygon, 0.74, int(round(float(area_damage) * 1.08)), "slow", 0.95, 0.45, 420.0, true)
		_:
			_create_area_core(polygon, area_damage, area_duration, area_color, false, 0.0)
			_create_polygon_debuff(polygon, area_duration, "slow", 0.36, 0.8, 0.3, area_color)

func _create_area_core(
	polygon: PackedVector2Array,
	damage: int,
	duration: float,
	color: Color,
	enable_pull: bool,
	pull_force: float
) -> void:
	SkillEffectManager.create_area_effect({
		"polygon": polygon,
		"damage": max(1, damage),
		"damage_interval": 0.34,
		"duration": max(0.5, duration),
		"color": color,
		"pull_to_center": enable_pull,
		"pull_force": max(0.0, pull_force),
		"pull_interval": 0.05
	})

func _create_polygon_debuff(
	polygon: PackedVector2Array,
	duration: float,
	debuff_type: String,
	debuff_value: float,
	debuff_duration: float,
	tick_interval: float,
	color: Color
) -> void:
	SkillEffectManager.create_debuff_zone({
		"polygon": polygon,
		"duration": max(0.5, duration),
		"debuff_type": debuff_type,
		"debuff_value": debuff_value,
		"debuff_duration": max(0.1, debuff_duration),
		"tick_interval": max(0.08, tick_interval),
		"color": color
	})

func _spawn_polygon_walls(
	polygon: PackedVector2Array,
	width: float,
	duration: float,
	contact_damage: int,
	color: Color
) -> void:
	var count: int = polygon.size()
	if count < 3:
		return
	for index: int in range(count):
		var next_index: int = (index + 1) % count
		var start: Vector2 = polygon[index]
		var end_pos: Vector2 = polygon[next_index]
		SkillEffectManager.create_wall_effect({
			"start": start,
			"end": end_pos,
			"width": width,
			"duration": duration,
			"block_enemies": true,
			"block_bullets": false,
			"contact_damage": max(1, contact_damage),
			"contact_interval": 0.3,
			"color": color
		})

func _spawn_center_crossfire(center: Vector2, radius: float, damage: int, duration: float, color: Color) -> void:
	var beams: int = 6
	for i: int in range(beams):
		var angle: float = TAU * float(i) / float(beams)
		var dir: Vector2 = Vector2(cos(angle), sin(angle))
		var start: Vector2 = center - dir * radius * 0.62
		var end_pos: Vector2 = center + dir * radius * 0.62
		SkillEffectManager.create_line_effect({
			"start": start,
			"end": end_pos,
			"width": 16.0,
			"damage": max(1, int(round(float(damage) * 0.68))),
			"damage_interval": 0.33,
			"duration": max(0.6, duration * 0.66),
			"color": color
		})

func _spawn_segment_traps(
	start: Vector2,
	end_pos: Vector2,
	meta_key: String,
	damage: int,
	radius: float,
	delay: float,
	color: Color
) -> void:
	var seg_len: float = start.distance_to(end_pos)
	var sample_count: int = max(1, int(floor(seg_len / 56.0)))
	for idx: int in range(sample_count + 1):
		var ratio: float = float(idx) / float(max(1, sample_count))
		var pos: Vector2 = start.lerp(end_pos, ratio)
		_spawn_timed_node(meta_key, pos, max(1, damage), radius, delay + ratio * 0.28, color)

func _spawn_polygon_nodes(
	polygon: PackedVector2Array,
	meta_key: String,
	count: int,
	damage: int,
	radius: float,
	delay: float,
	color: Color
) -> void:
	var points: Array[Vector2] = _sample_points_in_polygon(polygon, count)
	for idx: int in range(points.size()):
		var pos: Vector2 = points[idx]
		var extra_delay: float = delay + float(idx) * 0.08
		_spawn_timed_node(meta_key, pos, max(1, damage), radius, extra_delay, color)

func _spawn_timed_node(
	meta_key: String,
	pos: Vector2,
	damage: int,
	radius: float,
	delay: float,
	color: Color
) -> void:
	var node: Node2D = Node2D.new()
	node.name = "QProtoNode"
	node.global_position = pos
	node.z_index = 52

	var marker: Polygon2D = Polygon2D.new()
	marker.polygon = _circle_polygon(radius * 0.22, 14)
	marker.color = Color(color.r, color.g, color.b, 0.46)
	marker.z_index = 52
	node.add_child(marker)

	var scene: Node = get_tree().current_scene if get_tree() else null
	if scene != null:
		scene.add_child(node)
	else:
		add_child(node)

	_append_owner_ref(meta_key, node)

	var timer: Timer = Timer.new()
	timer.wait_time = max(0.1, delay)
	timer.one_shot = true
	timer.autostart = true
	node.add_child(timer)
	var node_ref: WeakRef = weakref(node)
	timer.timeout.connect(func() -> void:
		var raw: Variant = node_ref.get_ref() if node_ref != null else null
		if raw == null or not is_instance_valid(raw):
			return
		if not (raw is Node2D):
			return
		var effect_node: Node2D = raw
		var hit_count: int = _damage_enemies_in_radius(
			effect_node.global_position,
			radius,
			damage,
			"slow",
			1.0,
			0.36,
			260.0,
			true
		)
		if hit_count > 0:
			spawn_skill_vfx(effect_node.global_position, color, 0.55)
		effect_node.queue_free()
	)

func _schedule_polygon_pulse(
	polygon: PackedVector2Array,
	delay: float,
	damage: int,
	status_type: String,
	status_duration: float,
	status_value: float,
	force: float,
	pull_to_center: bool
) -> void:
	var poly_copy: PackedVector2Array = PackedVector2Array(polygon)
	get_tree().create_timer(max(0.05, delay)).timeout.connect(func() -> void:
		var center: Vector2 = _polygon_center(poly_copy)
		var radius: float = _polygon_radius(poly_copy, center)
		var hit_count: int = _damage_enemies_in_radius(
			center,
			radius,
			max(1, damage),
			status_type,
			status_duration,
			status_value,
			force,
			pull_to_center
		)
		if hit_count > 0:
			spawn_skill_vfx(center, _closure_color(), 0.6)
	)

func _schedule_polygon_shuffle(polygon: PackedVector2Array, duration: float, interval: float) -> void:
	var controller: Node = Node.new()
	controller.name = "QProtoShuffleController"
	var scene: Node = get_tree().current_scene if get_tree() else null
	if scene != null:
		scene.add_child(controller)
	else:
		add_child(controller)

	var elapsed: float = 0.0
	var poly_copy: PackedVector2Array = PackedVector2Array(polygon)
	var timer: Timer = Timer.new()
	timer.wait_time = max(0.08, interval)
	timer.one_shot = false
	timer.autostart = true
	controller.add_child(timer)
	var controller_ref: WeakRef = weakref(controller)
	timer.timeout.connect(func() -> void:
		var holder_raw: Variant = controller_ref.get_ref() if controller_ref != null else null
		if holder_raw == null or not is_instance_valid(holder_raw):
			return
		elapsed += timer.wait_time
		var center: Vector2 = _polygon_center(poly_copy)
		var radius: float = _polygon_radius(poly_copy, center)
		var enemies: Array = get_tree().get_nodes_in_group("enemies")
		for enemy_obj: Variant in enemies:
			if enemy_obj == null or not is_instance_valid(enemy_obj):
				continue
			if not (enemy_obj is Node2D):
				continue
			var enemy: Node2D = enemy_obj
			if enemy.global_position.distance_to(center) > radius:
				continue
			var random_dir: Vector2 = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0))
			if random_dir.length_squared() <= 0.01:
				random_dir = Vector2.RIGHT
			_apply_enemy_force(enemy, random_dir.normalized(), 260.0)
			_apply_enemy_status(enemy, "fear", 0.6, 0.0)
		if elapsed >= duration:
			var holder: Node = holder_raw as Node
			if holder != null:
				holder.queue_free()
	)

func _schedule_lifesteal_pulse(polygon: PackedVector2Array, duration: float, damage: int) -> void:
	if not is_instance_valid(skill_owner):
		return
	var controller: Node = Node.new()
	controller.name = "QProtoLifestealController"
	var scene: Node = get_tree().current_scene if get_tree() else null
	if scene != null:
		scene.add_child(controller)
	else:
		add_child(controller)

	var poly_copy: PackedVector2Array = PackedVector2Array(polygon)
	var elapsed: float = 0.0
	var timer: Timer = Timer.new()
	timer.wait_time = 0.55
	timer.one_shot = false
	timer.autostart = true
	controller.add_child(timer)
	var owner_ref: WeakRef = weakref(skill_owner)
	var controller_ref: WeakRef = weakref(controller)
	timer.timeout.connect(func() -> void:
		var owner_raw: Variant = owner_ref.get_ref() if owner_ref != null else null
		var holder_raw: Variant = controller_ref.get_ref() if controller_ref != null else null
		if owner_raw == null or not is_instance_valid(owner_raw):
			if holder_raw != null and is_instance_valid(holder_raw):
				var holder_node: Node = holder_raw as Node
				if holder_node != null:
					holder_node.queue_free()
			return
		elapsed += timer.wait_time
		var center: Vector2 = _polygon_center(poly_copy)
		var radius: float = _polygon_radius(poly_copy, center)
		var hit_count: int = _damage_enemies_in_radius(center, radius, damage, "slow", 0.8, 0.32, 0.0, false)
		if hit_count > 0 and owner_raw is Node2D:
			var owner_node: Node2D = owner_raw
			if owner_node.has_node("HealthComponent"):
				var hc: Node = owner_node.get_node("HealthComponent")
				if hc != null and hc.has_method("heal"):
					hc.call("heal", max(1, hit_count))
		if elapsed >= duration:
			if holder_raw != null and is_instance_valid(holder_raw):
				var holder_node2: Node = holder_raw as Node
				if holder_node2 != null:
					holder_node2.queue_free()
	)

func _schedule_chain_lightning(polygon: PackedVector2Array, duration: float, damage: int) -> void:
	var controller: Node = Node.new()
	controller.name = "QProtoChainController"
	var scene: Node = get_tree().current_scene if get_tree() else null
	if scene != null:
		scene.add_child(controller)
	else:
		add_child(controller)

	var poly_copy: PackedVector2Array = PackedVector2Array(polygon)
	var elapsed: float = 0.0
	var timer: Timer = Timer.new()
	timer.wait_time = 0.48
	timer.one_shot = false
	timer.autostart = true
	controller.add_child(timer)
	var controller_ref: WeakRef = weakref(controller)
	timer.timeout.connect(func() -> void:
		var holder_raw: Variant = controller_ref.get_ref() if controller_ref != null else null
		if holder_raw == null or not is_instance_valid(holder_raw):
			return
		elapsed += timer.wait_time
		var center: Vector2 = _polygon_center(poly_copy)
		var radius: float = _polygon_radius(poly_copy, center)
		var enemies: Array[Node2D] = _collect_enemies_in_radius(center, radius)
		var jump_count: int = min(4, enemies.size())
		for i: int in range(jump_count):
			var enemy: Node2D = enemies[i]
			_apply_enemy_damage(enemy, max(1, damage))
			_apply_enemy_status(enemy, "freeze", 0.55, 0.0)
		if elapsed >= duration:
			var holder: Node = holder_raw as Node
			if holder != null:
				holder.queue_free()
	)

func _schedule_outside_polygon_damage(polygon: PackedVector2Array, duration: float, damage: int) -> void:
	var controller: Node = Node.new()
	controller.name = "QProtoOutsideDamageController"
	var scene: Node = get_tree().current_scene if get_tree() else null
	if scene != null:
		scene.add_child(controller)
	else:
		add_child(controller)

	var poly_copy: PackedVector2Array = PackedVector2Array(polygon)
	var elapsed: float = 0.0
	var timer: Timer = Timer.new()
	timer.wait_time = 0.42
	timer.one_shot = false
	timer.autostart = true
	controller.add_child(timer)
	var controller_ref: WeakRef = weakref(controller)
	timer.timeout.connect(func() -> void:
		var holder_raw: Variant = controller_ref.get_ref() if controller_ref != null else null
		if holder_raw == null or not is_instance_valid(holder_raw):
			return
		elapsed += timer.wait_time
		var enemies: Array = get_tree().get_nodes_in_group("enemies")
		for enemy_obj: Variant in enemies:
			if enemy_obj == null or not is_instance_valid(enemy_obj):
				continue
			if not (enemy_obj is Node2D):
				continue
			var enemy: Node2D = enemy_obj
			if Geometry2D.is_point_in_polygon(enemy.global_position, poly_copy):
				continue
			_apply_enemy_damage(enemy, max(1, damage))
			_apply_enemy_status(enemy, "poison", 1.1, max(4.0, float(damage) * 0.12))
		if elapsed >= duration:
			var holder: Node = holder_raw as Node
			if holder != null:
				holder.queue_free()
	)

func _schedule_tide_cycle(polygon: PackedVector2Array, duration: float, damage: int) -> void:
	var controller: Node = Node.new()
	controller.name = "QProtoTideController"
	var scene: Node = get_tree().current_scene if get_tree() else null
	if scene != null:
		scene.add_child(controller)
	else:
		add_child(controller)

	var poly_copy: PackedVector2Array = PackedVector2Array(polygon)
	var elapsed: float = 0.0
	var pull_phase: bool = false
	var timer: Timer = Timer.new()
	timer.wait_time = 0.46
	timer.one_shot = false
	timer.autostart = true
	controller.add_child(timer)
	var controller_ref: WeakRef = weakref(controller)
	timer.timeout.connect(func() -> void:
		var holder_raw: Variant = controller_ref.get_ref() if controller_ref != null else null
		if holder_raw == null or not is_instance_valid(holder_raw):
			return
		elapsed += timer.wait_time
		pull_phase = not pull_phase
		var center: Vector2 = _polygon_center(poly_copy)
		var radius: float = _polygon_radius(poly_copy, center)
		_damage_enemies_in_radius(center, radius, max(1, damage), "slow", 0.8, 0.32, 260.0, pull_phase)
		if elapsed >= duration:
			var holder: Node = holder_raw as Node
			if holder != null:
				holder.queue_free()
	)

func _damage_enemies_in_radius(
	center: Vector2,
	radius: float,
	damage: int,
	status_type: String,
	status_duration: float,
	status_value: float,
	force: float,
	pull_to_center: bool
) -> int:
	var hit_count: int = 0
	var enemies: Array = get_tree().get_nodes_in_group("enemies")
	for enemy_obj: Variant in enemies:
		if enemy_obj == null or not is_instance_valid(enemy_obj):
			continue
		if not (enemy_obj is Node2D):
			continue
		var enemy: Node2D = enemy_obj
		if enemy.global_position.distance_to(center) > radius:
			continue
		_apply_enemy_damage(enemy, max(1, damage))
		if not status_type.is_empty():
			_apply_enemy_status(enemy, status_type, status_duration, status_value)
		if force > 0.0:
			var dir: Vector2 = (center - enemy.global_position).normalized() if pull_to_center else (enemy.global_position - center).normalized()
			if dir.length_squared() <= 0.001:
				dir = Vector2.RIGHT
			_apply_enemy_force(enemy, dir, force)
		hit_count += 1
	return hit_count

func _collect_enemies_in_radius(center: Vector2, radius: float) -> Array[Node2D]:
	var result: Array[Node2D] = []
	var enemies: Array = get_tree().get_nodes_in_group("enemies")
	for enemy_obj: Variant in enemies:
		if enemy_obj == null or not is_instance_valid(enemy_obj):
			continue
		if not (enemy_obj is Node2D):
			continue
		var enemy: Node2D = enemy_obj
		if enemy.global_position.distance_to(center) <= radius:
			result.append(enemy)
	return result

func _apply_enemy_damage(enemy: Node2D, amount: int) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	if not enemy.has_node("HealthComponent"):
		return
	var hc: Node = enemy.get_node("HealthComponent")
	if hc != null and hc.has_method("take_damage"):
		hc.call("take_damage", max(1, amount))

func _apply_enemy_status(enemy: Node2D, status_type: String, duration: float, value: float) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	if enemy.has_method("apply_status"):
		enemy.call("apply_status", status_type, max(0.1, duration), value)

func _apply_enemy_force(enemy: Node2D, direction: Vector2, force: float) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	if enemy.has_method("apply_knockback"):
		enemy.call("apply_knockback", direction, force)
	else:
		enemy.global_position += direction * min(80.0, force * 0.02)

func _append_owner_ref(meta_key: String, node: Node2D) -> void:
	if not is_instance_valid(skill_owner):
		return
	var refs: Array = []
	if skill_owner.has_meta(meta_key):
		var raw: Variant = skill_owner.get_meta(meta_key)
		if raw is Array:
			refs = raw
	refs.append(weakref(node))
	skill_owner.set_meta(meta_key, refs)

func _cache_line_context(start: Vector2, end_pos: Vector2, mode: String) -> void:
	var center: Vector2 = (start + end_pos) * 0.5
	var radius: float = max(24.0, start.distance_to(end_pos) * 0.5)
	_cache_common_context(center, radius, mode, false)

func _cache_area_context(center: Vector2, radius: float, mode: String, polygon: PackedVector2Array) -> void:
	_cache_common_context(center, radius, mode, true)
	if is_instance_valid(skill_owner):
		skill_owner.set_meta(META_LAST_POLYGON, PackedVector2Array(polygon))

func _cache_common_context(center: Vector2, radius: float, mode: String, closed: bool) -> void:
	if not is_instance_valid(skill_owner):
		return
	skill_owner.set_meta(META_LAST_PROFILE, q_profile_id)
	skill_owner.set_meta(META_LAST_MODE, mode)
	skill_owner.set_meta(META_LAST_CENTER, center)
	skill_owner.set_meta(META_LAST_RADIUS, radius)
	skill_owner.set_meta(META_LAST_CLOSED, closed)
	skill_owner.set_meta(META_LAST_TIME, Time.get_ticks_msec())

func _line_mode() -> String:
	var idx: int = clamp(q_profile_id, 1, PROFILE_COUNT) - 1
	return LINE_MODES[idx]

func _area_mode() -> String:
	var idx: int = clamp(q_profile_id, 1, PROFILE_COUNT) - 1
	return AREA_MODES[idx]

func _line_damage() -> int:
	var base_damage: float = _owner_damage()
	var scale: float = 0.70 + float((q_profile_id - 1) % 6) * 0.07
	var amp: float = _consume_temp_amp()
	return max(1, int(round(base_damage * scale * amp)))

func _area_damage() -> int:
	var base_damage: float = _owner_damage()
	var scale: float = 1.00 + float((q_profile_id - 1) % 5) * 0.11
	var amp: float = _consume_temp_amp()
	return max(1, int(round(base_damage * scale * amp)))

func _line_width() -> float:
	return 18.0 + float((q_profile_id - 1) % 5) * 2.8

func _line_duration_scale() -> float:
	return 4.2 + float((q_profile_id - 1) % 4) * 0.65

func _area_duration_scale() -> float:
	return 4.8 + float((q_profile_id - 1) % 5) * 0.55

func _line_pull_force() -> float:
	return 280.0 + float((q_profile_id - 1) % 4) * 85.0

func _area_pull_force() -> float:
	return 340.0 + float((q_profile_id - 1) % 4) * 90.0

func _line_status_value() -> float:
	var mode: String = _line_mode()
	if mode == "web_thread" or mode == "medic_line":
		return 0.44
	if mode == "toxin_line":
		return 8.0
	if mode == "curse_line" or mode == "verdict_line":
		return 0.24
	return 0.36

func _line_debuff_type() -> String:
	var mode: String = _line_mode()
	if mode == "toxin_line":
		return "poison"
	if mode == "curse_line" or mode == "verdict_line":
		return "damage_amp"
	return "slow"

func _owner_damage() -> float:
	if is_instance_valid(skill_owner) and ("damage" in skill_owner):
		return max(1.0, float(skill_owner.damage))
	return 30.0

func _consume_temp_amp() -> float:
	if not is_instance_valid(skill_owner):
		return 1.0
	if not skill_owner.has_meta(META_TEMP_Q_AMP):
		return 1.0
	var raw: Variant = skill_owner.get_meta(META_TEMP_Q_AMP)
	var amp: float = max(0.5, float(raw))
	skill_owner.remove_meta(META_TEMP_Q_AMP)
	return amp

func _polygon_center(polygon: PackedVector2Array) -> Vector2:
	if polygon.is_empty():
		return Vector2.ZERO
	var center: Vector2 = Vector2.ZERO
	for point: Vector2 in polygon:
		center += point
	return center / float(polygon.size())

func _polygon_radius(polygon: PackedVector2Array, center: Vector2) -> float:
	var radius: float = 0.0
	for point: Vector2 in polygon:
		radius = max(radius, center.distance_to(point))
	return max(24.0, radius)

func _sample_points_in_polygon(polygon: PackedVector2Array, count: int) -> Array[Vector2]:
	var points: Array[Vector2] = []
	var bound_rect: Rect2 = _polygon_bounds(polygon)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.randomize()
	var target_count: int = max(1, count)
	var guard: int = 0
	while points.size() < target_count and guard < target_count * 20:
		guard += 1
		var px: float = rng.randf_range(bound_rect.position.x, bound_rect.position.x + bound_rect.size.x)
		var py: float = rng.randf_range(bound_rect.position.y, bound_rect.position.y + bound_rect.size.y)
		var candidate: Vector2 = Vector2(px, py)
		if Geometry2D.is_point_in_polygon(candidate, polygon):
			points.append(candidate)
	if points.is_empty():
		points.append(_polygon_center(polygon))
	return points

func _polygon_bounds(polygon: PackedVector2Array) -> Rect2:
	if polygon.is_empty():
		return Rect2(Vector2.ZERO, Vector2.ONE)
	var min_x: float = polygon[0].x
	var min_y: float = polygon[0].y
	var max_x: float = polygon[0].x
	var max_y: float = polygon[0].y
	for point: Vector2 in polygon:
		min_x = min(min_x, point.x)
		min_y = min(min_y, point.y)
		max_x = max(max_x, point.x)
		max_y = max(max_y, point.y)
	return Rect2(Vector2(min_x, min_y), Vector2(max(1.0, max_x - min_x), max(1.0, max_y - min_y)))

func _circle_polygon(radius: float, segments: int) -> PackedVector2Array:
	var result: PackedVector2Array = PackedVector2Array()
	var seg_count: int = max(6, segments)
	for i: int in range(seg_count):
		var angle: float = TAU * float(i) / float(seg_count)
		result.append(Vector2(cos(angle), sin(angle)) * radius)
	return result

func _line_color() -> Color:
	var hue: float = float((q_profile_id - 1) % PROFILE_COUNT) / float(PROFILE_COUNT)
	return Color.from_hsv(hue, 0.72, 1.0, 0.95)

func _closure_color() -> Color:
	var hue: float = fposmod(float((q_profile_id + 7) % PROFILE_COUNT) / float(PROFILE_COUNT), 1.0)
	return Color.from_hsv(hue, 0.78, 1.0, 0.62)

func _get_line_color() -> Color:
	return _line_color()

func _get_closure_color() -> Color:
	return _closure_color()
