extends SkillBase
class_name SkillEProto

var e_profile_id: int = 1

const PROFILE_COUNT: int = 32

const META_LAST_PROFILE: String = "q_proto_last_profile"
const META_LAST_CENTER: String = "q_ctx_last_center"
const META_LAST_RADIUS: String = "q_ctx_last_radius"
const META_LAST_TIME: String = "q_ctx_last_time_msec"
const META_LAST_CLOSED: String = "q_ctx_last_closed"
const META_LAST_SEGMENTS: String = "q_ctx_last_segments"
const META_LAST_POLYGONS: String = "q_ctx_last_polygons"
const META_LEGACY_CENTER: String = "q_proto_last_center"
const META_LEGACY_RADIUS: String = "q_proto_last_radius"
const META_LEGACY_TIME: String = "q_proto_last_time_msec"
const CONTEXT_MAX_AGE_MSEC: int = 16000
const META_NODE_MINES: String = "q_proto_nodes_mines"
const META_NODE_ANCHORS: String = "q_proto_nodes_anchors"
const META_NODE_DECOYS: String = "q_proto_nodes_decoys"
const META_NODE_SEEDS: String = "q_proto_nodes_seeds"
const META_NODE_CRYSTALS: String = "q_proto_nodes_crystals"
const META_NODE_BAITS: String = "q_proto_nodes_baits"
const META_TEMP_Q_AMP: String = "q_proto_temp_amp"

const E_MODES: Array[String] = [
	"hook_pull",
	"net_recall",
	"gate_patch",
	"heat_push",
	"mine_detonate",
	"frost_anchor",
	"decoy_swap",
	"reverse_wind",
	"ballistic_tune",
	"mark_explode",
	"medic_barrier",
	"time_echo",
	"counter_stance",
	"rail_reverse",
	"anchor_jump",
	"blood_trade",
	"phase_swap",
	"chain_overload",
	"toxin_inject",
	"lure_signal",
	"gravity_boost",
	"smoke_cover",
	"suppression_order",
	"blade_reap",
	"crystal_overload",
	"bait_redeploy",
	"thermal_break",
	"execute_calibrate",
	"tide_reverse",
	"verdict_trigger",
	"echo_amplify",
	"rift_catalyst"
]

const CONTEXT_WINDOW_KEYS: Array[Dictionary] = [
	{"center": "ammo_supply_center", "radius": "ammo_supply_radius", "expire": "ammo_supply_expire_msec"},
	{"center": "banner_rally_center", "radius": "banner_rally_radius", "expire": "banner_rally_expire_msec"},
	{"center": "executioner_zone_center", "radius": "executioner_zone_radius", "expire": "executioner_zone_expire_msec"},
	{"center": "gambler_zone_center", "radius": "gambler_zone_radius", "expire": "gambler_zone_expire_msec"},
	{"center": "goo_pool_center", "radius": "goo_pool_radius", "expire": "goo_pool_expire_msec"},
	{"center": "hunter_trap_center", "radius": "hunter_trap_radius", "expire": "hunter_trap_expire_msec"},
	{"center": "illusion_mirror_center", "radius": "illusion_mirror_radius", "expire": "illusion_mirror_expire_msec"},
	{"center": "jailer_prison_center", "radius": "jailer_prison_radius", "expire": "jailer_prison_expire_msec"},
	{"center": "merchant_market_center", "radius": "merchant_market_radius", "expire": "merchant_market_expire_msec"},
	{"center": "midas_transmute_center", "radius": "midas_transmute_radius", "expire": "midas_transmute_expire_msec"},
	{"center": "necro_grave_center", "radius": "necro_grave_radius", "expire": "necro_grave_expire_msec"},
	{"center": "new_pyro_fire_center", "radius": "new_pyro_fire_radius", "expire": "new_pyro_fire_expire_msec"},
	{"center": "tempest_eye_center", "radius": "tempest_eye_radius", "expire": "tempest_eye_expire_msec"},
	{"center": "new_totem_field_center", "radius": "new_totem_field_radius", "expire": "new_totem_field_expire_msec"},
	{"center": "paladin_sanctuary_center", "radius": "paladin_sanctuary_radius", "expire": "paladin_sanctuary_expire_msec"},
	{"center": "plague_miasma_center", "radius": "plague_miasma_radius", "expire": "plague_miasma_expire_msec"},
	{"center": "swarm_brood_center", "radius": "swarm_brood_radius", "expire": "swarm_brood_expire_msec"},
	{"center": "tesla_field_center", "radius": "tesla_field_radius", "expire": "tesla_field_expire_msec"},
	{"center": "train_rail_center", "radius": "train_rail_radius", "expire": "train_rail_expire_msec"},
	{"center": "turret_fort_center", "radius": "turret_fort_radius", "expire": "turret_fort_expire_msec"},
	{"center": "vacuum_vortex_center", "radius": "vacuum_vortex_radius", "expire": "vacuum_vortex_expire_msec"},
	{"center": "vampire_blood_pool_center", "radius": "vampire_blood_pool_radius", "expire": "vampire_blood_pool_expire_msec"},
	{"center": "voodoo_hex_center", "radius": "voodoo_hex_radius", "expire": "voodoo_hex_expire_msec"}
]

func _ready() -> void:
	if e_profile_id < 1:
		e_profile_id = 1
	elif e_profile_id > PROFILE_COUNT:
		e_profile_id = PROFILE_COUNT

	if energy_cost <= 0.0:
		energy_cost = 30.0 + float((e_profile_id - 1) % 5) * 2.0
	if cooldown_time <= 0.0:
		cooldown_time = 8.2 + float((e_profile_id - 1) % 4) * 0.45
	if skill_tags.is_empty():
		set_skill_tags_from_value("e,active,burst")
	super._ready()

func execute() -> void:
	execute_with_mode(_mode())

func execute_with_mode(mode: String) -> void:
	if not can_execute():
		if is_on_cooldown and is_instance_valid(skill_owner):
			Global.spawn_floating_text(skill_owner.global_position, "Cooldown!", Color.YELLOW)
		return
	if not consume_energy():
		if is_instance_valid(skill_owner):
			Global.spawn_floating_text(skill_owner.global_position, "No Energy!", Color.RED)
		return
	if not is_instance_valid(skill_owner):
		return

	var center: Vector2 = _context_center()
	var radius: float = _context_radius()
	var damage: int = _base_damage()
	var duration: float = _duration_scale()

	match mode:
		"hook_pull":
			_cast_hook_pull(max(260.0, radius + 120.0), damage)
		"net_recall":
			_burst(center, radius * 1.1, damage, "slow", 1.0, 0.45, 460.0, true)
			_schedule_burst(0.35, center, radius, int(round(float(damage) * 0.72)), "damage_amp", 1.0, 0.18, 300.0, true)
		"gate_patch":
			_cast_gate_patch(center, damage, duration)
		"heat_push":
			_burst(skill_owner.global_position, max(140.0, radius * 0.9), int(round(float(damage) * 0.95)), "poison", 1.2, 8.0, 520.0, false)
		"mine_detonate":
			if _detonate_owner_nodes(META_NODE_MINES, int(round(float(damage) * 1.15)), 320.0, false) <= 0:
				_burst(center, radius, damage, "slow", 0.9, 0.42, 320.0, true)
		"frost_anchor":
			_burst(center, radius * 0.95, int(round(float(damage) * 0.72)), "freeze", 0.65, 0.0, 220.0, true)
			_spawn_debuff_zone(center, radius * 0.75, duration, "freeze", 0.0, 0.55, 0.85, Color(0.55, 0.85, 1.0, 0.26))
		"decoy_swap":
			_cast_decoy_swap(center, damage)
		"reverse_wind":
			_cast_reverse_wind(center, radius, damage)
		"ballistic_tune":
			_spawn_player_buff_zone(skill_owner.global_position, 120.0, 3.6, "attack_boost", 0.22, 0.45, Color(1.0, 0.88, 0.3, 0.22))
			_spawn_player_buff_zone(skill_owner.global_position, 120.0, 3.6, "cooldown_reduction", 0.16, 0.45, Color(1.0, 0.76, 0.22, 0.18))
			_burst(center, radius * 0.8, int(round(float(damage) * 0.68)), "slow", 0.7, 0.3, 180.0, false)
		"mark_explode":
			_cast_mark_explode(center, radius, damage)
		"medic_barrier":
			_spawn_player_buff_zone(skill_owner.global_position, 140.0, 4.2, "heal", max(2.0, float(damage) * 0.09), 0.7, Color(0.35, 1.0, 0.75, 0.25))
			_spawn_player_buff_zone(skill_owner.global_position, 140.0, 2.4, "invincible", 1.0, 0.35, Color(0.6, 1.0, 0.85, 0.2))
		"time_echo":
			_burst(center, radius, int(round(float(damage) * 0.62)), "slow", 0.8, 0.35, 180.0, true)
			_schedule_burst(0.55, center, radius, int(round(float(damage) * 0.9)), "slow", 0.9, 0.35, 220.0, true)
		"counter_stance":
			_set_invincible_window(max(0.8, duration * 0.45))
			_burst(skill_owner.global_position, max(120.0, radius * 0.72), int(round(float(damage) * 0.7)), "fear", 0.6, 0.0, 260.0, false)
		"rail_reverse":
			_burst(center, radius * 1.05, damage, "fear", 0.9, 0.0, 620.0, true)
		"anchor_jump":
			_dash_to_mouse(240.0)
			_burst(skill_owner.global_position, max(120.0, radius * 0.8), damage, "slow", 0.85, 0.38, 260.0, false)
		"blood_trade":
			_pay_health_cost(0.06)
			_burst(center, radius * 1.1, int(round(float(damage) * 1.18)), "damage_amp", 1.2, 0.2, 320.0, true)
		"phase_swap":
			_cast_phase_swap(max(220.0, radius), damage)
		"chain_overload":
			_cast_chain_overload(center, radius * 1.15, damage)
		"toxin_inject":
			_spawn_debuff_zone(center, radius, max(3.0, duration), "poison", max(6.0, float(damage) * 0.10), 1.2, 0.42, Color(0.55, 1.0, 0.45, 0.2))
		"lure_signal":
			_spawn_lure(center, max(2.0, duration), radius)
			_burst(center, radius * 0.9, int(round(float(damage) * 0.55)), "slow", 0.9, 0.32, 240.0, true)
		"gravity_boost":
			_spawn_area_puller(center, radius * 1.1, int(round(float(damage) * 0.6)), max(2.8, duration), 520.0)
		"smoke_cover":
			_spawn_player_buff_zone(skill_owner.global_position, 135.0, 3.4, "speed_boost", 0.35, 0.4, Color(0.82, 0.86, 1.0, 0.18))
			_spawn_player_buff_zone(skill_owner.global_position, 135.0, 1.5, "ignore_collision", 1.0, 0.3, Color(0.92, 0.92, 1.0, 0.15))
			_set_invincible_window(1.1)
		"suppression_order":
			_spawn_player_buff_zone(skill_owner.global_position, 130.0, 3.8, "attack_boost", 0.24, 0.45, Color(1.0, 0.9, 0.35, 0.2))
			_burst(center, radius, int(round(float(damage) * 0.78)), "damage_amp", 1.1, 0.18, 260.0, true)
		"blade_reap":
			_cast_blade_reap(center, radius, damage)
		"crystal_overload":
			if _detonate_owner_nodes(META_NODE_CRYSTALS, int(round(float(damage) * 1.2)), 320.0, true) <= 0:
				_burst(center, radius, damage, "slow", 1.0, 0.4, 300.0, true)
		"bait_redeploy":
			_redeploy_baits_to_mouse(max(180.0, radius), int(round(float(damage) * 0.74)))
		"thermal_break":
			_cast_thermal_break(center, radius, damage)
		"execute_calibrate":
			if is_instance_valid(skill_owner):
				skill_owner.set_meta(META_TEMP_Q_AMP, 1.22)
			_burst(center, radius, int(round(float(damage) * 0.8)), "damage_amp", 1.3, 0.22, 260.0, false)
		"tide_reverse":
			_burst(center, radius, int(round(float(damage) * 0.72)), "slow", 0.8, 0.34, 360.0, false)
			_schedule_burst(0.33, center, radius, int(round(float(damage) * 0.72)), "slow", 0.8, 0.34, 360.0, true)
		"verdict_trigger":
			_cast_verdict_trigger(center, radius, damage)
		"echo_amplify":
			if is_instance_valid(skill_owner):
				skill_owner.set_meta(META_TEMP_Q_AMP, 1.35)
			_burst(center, radius * 0.8, int(round(float(damage) * 0.62)), "slow", 0.7, 0.28, 160.0, false)
		"rift_catalyst":
			var hits: int = _detonate_owner_nodes(META_NODE_SEEDS, int(round(float(damage) * 1.15)), 420.0, true)
			if hits <= 0:
				_burst(center, radius * 1.15, int(round(float(damage) * 0.95)), "slow", 0.9, 0.4, 420.0, true)
		_:
			_burst(center, radius, damage, "slow", 0.9, 0.34, 260.0, true)

	_apply_mode_signature(mode, center, radius, damage, duration)

	var vfx_center: Vector2 = _context_center()
	var vfx_color: Color = _mode_vfx_color(mode)
	spawn_skill_vfx(vfx_center, vfx_color, 0.58)
	if is_instance_valid(skill_owner):
		Global.spawn_floating_text(skill_owner.global_position, _mode_vfx_text(mode), vfx_color)
	start_cooldown()

func _mode() -> String:
	var idx: int = int(clamp(e_profile_id, 1, PROFILE_COUNT)) - 1
	return E_MODES[idx]

func _mode_vfx_color(mode: String) -> Color:
	var idx: int = E_MODES.find(mode)
	if idx < 0:
		return Color(1.0, 0.82, 0.35, 0.75)
	var hue: float = fmod(float(idx) / float(PROFILE_COUNT), 1.0)
	return Color.from_hsv(hue, 0.66, 1.0, 0.78)

func _mode_vfx_text(mode: String) -> String:
	if mode.is_empty():
		return "E"
	return "E-%s" % mode.replace("_", "-").to_upper()

func _base_damage() -> int:
	var base_damage: float = 30.0
	if is_instance_valid(skill_owner) and ("damage" in skill_owner):
		base_damage = max(1.0, float(skill_owner.damage))
	var scale: float = 0.72 + float((e_profile_id - 1) % 6) * 0.08
	return max(1, int(round(base_damage * scale * get_e_damage_amp(0.4, 0.35))))

func _duration_scale() -> float:
	return 1.0 + float((e_profile_id - 1) % 4) * 0.16

func _context_center() -> Vector2:
	var ctx: Dictionary = _resolve_recent_q_context()
	if not ctx.is_empty():
		var raw: Variant = ctx.get("center", Vector2.ZERO)
		if raw is Vector2:
			return raw
	return skill_owner.global_position if is_instance_valid(skill_owner) else Vector2.ZERO

func _context_radius() -> float:
	var ctx: Dictionary = _resolve_recent_q_context()
	if not ctx.is_empty():
		return float(max(90.0, float(ctx.get("radius", 180.0))))
	return 180.0

func _context_is_closed() -> bool:
	var ctx: Dictionary = _resolve_recent_q_context()
	if ctx.is_empty():
		return false
	return bool(ctx.get("is_closed", false))

func _resolve_recent_q_context() -> Dictionary:
	var result: Dictionary = {}
	if not is_instance_valid(skill_owner):
		return result

	var now_msec: int = Time.get_ticks_msec()

	# 1) 新统一上下文键（优先）
	if skill_owner.has_meta(META_LAST_CENTER) and skill_owner.has_meta(META_LAST_RADIUS):
		var center_raw: Variant = skill_owner.get_meta(META_LAST_CENTER)
		var radius_raw: float = float(skill_owner.get_meta(META_LAST_RADIUS))
		var time_raw: int = int(skill_owner.get_meta(META_LAST_TIME)) if skill_owner.has_meta(META_LAST_TIME) else 0
		var age_ok: bool = (time_raw <= 0) or (now_msec - time_raw <= CONTEXT_MAX_AGE_MSEC)
		if center_raw is Vector2 and radius_raw > 0.0 and age_ok:
			result["center"] = center_raw
			result["radius"] = radius_raw
			result["time_msec"] = time_raw
			result["is_closed"] = bool(skill_owner.get_meta(META_LAST_CLOSED)) if skill_owner.has_meta(META_LAST_CLOSED) else false
			return result

	# 2) 兼容旧 q_proto 键
	if skill_owner.has_meta(META_LEGACY_CENTER) and skill_owner.has_meta(META_LEGACY_RADIUS):
		var old_center: Variant = skill_owner.get_meta(META_LEGACY_CENTER)
		var old_radius: float = float(skill_owner.get_meta(META_LEGACY_RADIUS))
		var old_time: int = int(skill_owner.get_meta(META_LEGACY_TIME)) if skill_owner.has_meta(META_LEGACY_TIME) else 0
		var old_age_ok: bool = (old_time <= 0) or (now_msec - old_time <= CONTEXT_MAX_AGE_MSEC)
		if old_center is Vector2 and old_radius > 0.0 and old_age_ok:
			result["center"] = old_center
			result["radius"] = old_radius
			result["time_msec"] = old_time
			result["is_closed"] = false
			return result

	# 3) 兼容各角色 Q 的窗口缓存键
	var best_expire: int = 0
	var best_center: Vector2 = Vector2.ZERO
	var best_radius: float = 0.0
	for item: Dictionary in CONTEXT_WINDOW_KEYS:
		var center_key: String = str(item.get("center", ""))
		var radius_key: String = str(item.get("radius", ""))
		var expire_key: String = str(item.get("expire", ""))
		if center_key == "" or radius_key == "" or expire_key == "":
			continue
		if not skill_owner.has_meta(center_key):
			continue
		if not skill_owner.has_meta(radius_key):
			continue
		var c_raw: Variant = skill_owner.get_meta(center_key)
		if not (c_raw is Vector2):
			continue
		var r_raw: float = float(skill_owner.get_meta(radius_key))
		if r_raw <= 0.0:
			continue
		var expire_msec: int = int(skill_owner.get_meta(expire_key)) if skill_owner.has_meta(expire_key) else 0
		if expire_msec <= 0:
			continue
		if expire_msec < now_msec:
			continue
		if expire_msec > best_expire:
			best_expire = expire_msec
			best_center = c_raw
			best_radius = r_raw

	if best_radius > 0.0:
		result["center"] = best_center
		result["radius"] = best_radius
		result["time_msec"] = now_msec
		result["is_closed"] = true
	return result

func _apply_mode_signature(mode: String, center: Vector2, radius: float, damage: int, duration: float) -> void:
	if not is_instance_valid(skill_owner):
		return

	var q_closed: bool = _context_is_closed()
	var aim_dir: Vector2 = _aim_direction_from(center)
	var side_dir: Vector2 = Vector2(-aim_dir.y, aim_dir.x)
	var local_radius: float = max(90.0, radius)
	var local_damage: int = max(1, damage)

	match mode:
		"hook_pull":
			if q_closed:
				_schedule_burst(0.16, center, local_radius * 0.82, int(round(float(local_damage) * 0.64)), "slow", 0.9, 0.28, 520.0, true)
				_schedule_burst(0.34, center, local_radius * 0.96, int(round(float(local_damage) * 0.72)), "damage_amp", 1.1, 0.18, 640.0, true)
				_schedule_segment_strike(0.12, skill_owner.global_position, center, 30.0, int(round(float(local_damage) * 0.56)), "slow", 0.9, 0.26, 560.0, true)
			else:
				var rope_end: Vector2 = center + aim_dir * min(140.0, local_radius * 0.62)
				_segment_strike(skill_owner.global_position, rope_end, 24.0, int(round(float(local_damage) * 0.48)), "slow", 0.7, 0.22, 420.0, true)
				_burst(center + aim_dir * min(120.0, local_radius * 0.56), local_radius * 0.56, int(round(float(local_damage) * 0.52)), "slow", 0.7, 0.22, 380.0, true)
		"net_recall":
			if q_closed:
				_schedule_ring_bursts(center, local_radius * 0.68, local_radius * 0.30, int(round(float(local_damage) * 0.54)), 4, 0.08, "slow", 0.9, 0.32, 280.0, true)
				_cross_segment_strike(center, aim_dir, local_radius * 1.10, 22.0, int(round(float(local_damage) * 0.52)), "slow", 1.0, 0.30, 320.0, true)
			else:
				_schedule_burst(0.22, center, local_radius * 0.72, int(round(float(local_damage) * 0.5)), "slow", 0.8, 0.3, 220.0, true)
				_segment_strike(center - side_dir * local_radius * 0.46, center + side_dir * local_radius * 0.46, 18.0, int(round(float(local_damage) * 0.42)), "slow", 0.8, 0.28, 220.0, true)
		"gate_patch":
			var gate_len: float = min(280.0, local_radius * 1.35)
			if q_closed:
				_spawn_gate_wall(center - side_dir * 56.0, aim_dir, gate_len * 0.82, int(round(float(local_damage) * 0.42)), max(1.2, 1.2 * duration), Color(1.0, 0.82, 0.35, 0.78))
				_spawn_gate_wall(center + side_dir * 56.0, aim_dir, gate_len * 0.82, int(round(float(local_damage) * 0.42)), max(1.2, 1.2 * duration), Color(1.0, 0.82, 0.35, 0.78))
				_spawn_corridor_fence(center, aim_dir, gate_len * 0.9, 42.0, max(1.1, duration), int(round(float(local_damage) * 0.28)))
			else:
				_spawn_gate_wall(center, side_dir, gate_len * 0.62, int(round(float(local_damage) * 0.32)), max(0.9, 0.8 * duration), Color(1.0, 0.9, 0.45, 0.68))
				_spawn_corridor_fence(center, side_dir, gate_len * 0.58, 30.0, max(0.8, duration * 0.7), int(round(float(local_damage) * 0.22)))
		"heat_push":
			if q_closed:
				_schedule_burst(0.10, center, local_radius * 0.95, int(round(float(local_damage) * 0.58)), "burn", 1.4, max(4.0, float(local_damage) * 0.10), 420.0, true)
				_schedule_burst(0.28, center, local_radius * 1.08, int(round(float(local_damage) * 0.62)), "burn", 1.6, max(5.0, float(local_damage) * 0.12), 520.0, false)
				_segment_strike(center - side_dir * local_radius * 0.86, center + side_dir * local_radius * 0.86, 22.0, int(round(float(local_damage) * 0.46)), "burn", 1.4, max(3.0, float(local_damage) * 0.08), 300.0, false)
			else:
				_segment_strike(center - aim_dir * local_radius * 0.82, center + aim_dir * local_radius * 0.22, 18.0, int(round(float(local_damage) * 0.38)), "burn", 1.2, max(2.0, float(local_damage) * 0.06), 220.0, false)
				_burst(center + aim_dir * 72.0, local_radius * 0.68, int(round(float(local_damage) * 0.54)), "burn", 1.2, max(3.0, float(local_damage) * 0.08), 360.0, false)
		"mine_detonate":
			if q_closed:
				_schedule_ring_bursts(center, local_radius * 0.62, local_radius * 0.28, int(round(float(local_damage) * 0.5)), 5, 0.12, "slow", 0.8, 0.28, 260.0, false)
				_schedule_segment_strike(0.20, center - aim_dir * local_radius * 0.72, center + aim_dir * local_radius * 0.72, 20.0, int(round(float(local_damage) * 0.42)), "slow", 0.8, 0.26, 260.0, false)
			else:
				_segment_strike(center - side_dir * local_radius * 0.46, center + side_dir * local_radius * 0.46, 16.0, int(round(float(local_damage) * 0.34)), "slow", 0.7, 0.22, 180.0, false)
				_schedule_burst(0.18, center, local_radius * 0.66, int(round(float(local_damage) * 0.48)), "slow", 0.7, 0.24, 220.0, false)
		"frost_anchor":
			if q_closed:
				_schedule_ring_bursts(center, local_radius * 0.62, local_radius * 0.34, int(round(float(local_damage) * 0.46)), 3, 0.10, "freeze", 0.7, 0.0, 240.0, true)
				_cross_segment_strike(center, aim_dir, local_radius * 0.92, 18.0, int(round(float(local_damage) * 0.34)), "freeze", 0.55, 0.0, 220.0, true)
			else:
				_segment_strike(center - aim_dir * local_radius * 0.54, center + aim_dir * local_radius * 0.54, 16.0, int(round(float(local_damage) * 0.32)), "freeze", 0.5, 0.0, 160.0, true)
				_burst(skill_owner.global_position, local_radius * 0.55, int(round(float(local_damage) * 0.45)), "freeze", 0.55, 0.0, 180.0, true)
		"decoy_swap":
			if q_closed:
				_set_invincible_window(0.8)
				_schedule_burst(0.16, center, local_radius * 0.7, int(round(float(local_damage) * 0.56)), "slow", 0.8, 0.3, 260.0, true)
				_segment_strike(skill_owner.global_position, center, 18.0, int(round(float(local_damage) * 0.42)), "fear", 0.6, 0.0, 220.0, true)
				_schedule_rotating_cross(center, local_radius * 0.84, 2, 0.18, 12.0, int(round(float(local_damage) * 0.30)), "slow", 0.8, 0.24, 220.0, true)
			else:
				_spawn_player_buff_zone(skill_owner.global_position, 110.0, 1.8, "speed_boost", 0.20, 0.35, Color(0.75, 0.9, 1.0, 0.18))
				_segment_strike(skill_owner.global_position - side_dir * 70.0, skill_owner.global_position + side_dir * 70.0, 14.0, int(round(float(local_damage) * 0.28)), "slow", 0.6, 0.2, 160.0, false)
				_spawn_moving_lure_trail(skill_owner.global_position, center, 0.85, local_radius * 0.42, int(round(float(local_damage) * 0.20)))
		"reverse_wind":
			if q_closed:
				_schedule_burst(0.24, center, local_radius, int(round(float(local_damage) * 0.62)), "slow", 0.9, 0.32, 460.0, false)
				_schedule_segment_strike(0.14, center - side_dir * local_radius * 0.82, center + side_dir * local_radius * 0.82, 24.0, int(round(float(local_damage) * 0.52)), "slow", 0.9, 0.30, 460.0, false)
			else:
				_segment_strike(center - aim_dir * local_radius * 0.66, center + aim_dir * local_radius * 0.66, 18.0, int(round(float(local_damage) * 0.42)), "slow", 0.7, 0.24, 360.0, false)
		"ballistic_tune":
			var burst_center: Vector2 = center + aim_dir * min(130.0, local_radius * 0.6)
			var burst_scale: float = 0.48 if q_closed else 0.36
			_burst(burst_center, local_radius * (0.62 if q_closed else 0.48), int(round(float(local_damage) * burst_scale)), "marked", 0.9, 0.16, 180.0, false)
			_segment_strike(center, center + aim_dir * min(260.0, local_radius * 1.34), 16.0, int(round(float(local_damage) * (0.45 if q_closed else 0.34))), "marked", 0.9, 0.16, 180.0, false)
		"mark_explode":
			if q_closed:
				_schedule_burst(0.2, center, local_radius * 0.82, int(round(float(local_damage) * 0.68)), "marked", 1.2, 0.2, 220.0, false)
				_cross_segment_strike(center, aim_dir, local_radius * 0.92, 16.0, int(round(float(local_damage) * 0.44)), "marked", 1.1, 0.18, 180.0, false)
			else:
				_segment_strike(center - aim_dir * local_radius * 0.86, center + aim_dir * local_radius * 0.30, 14.0, int(round(float(local_damage) * 0.34)), "marked", 0.9, 0.16, 140.0, false)
		"medic_barrier":
			if q_closed:
				_spawn_player_buff_zone(skill_owner.global_position, 140.0, 2.1, "cooldown_reduction", 0.14, 0.45, Color(0.72, 1.0, 0.86, 0.2))
				_spawn_gate_wall(center - aim_dir * local_radius * 0.36, side_dir, local_radius * 0.9, int(round(float(local_damage) * 0.26)), 1.4, Color(0.62, 1.0, 0.84, 0.68))
			else:
				_spawn_player_buff_zone(skill_owner.global_position, 120.0, 1.4, "speed_boost", 0.14, 0.35, Color(0.72, 1.0, 0.9, 0.16))
				_segment_strike(skill_owner.global_position - aim_dir * 70.0, skill_owner.global_position + aim_dir * 70.0, 12.0, int(round(float(local_damage) * 0.24)), "slow", 0.6, 0.2, 120.0, false)
		"time_echo":
			if q_closed:
				_schedule_burst(0.88, center + side_dir * 40.0, local_radius * 0.8, int(round(float(local_damage) * 0.76)), "slow", 0.8, 0.3, 240.0, true)
				_schedule_burst(0.88, center - side_dir * 40.0, local_radius * 0.8, int(round(float(local_damage) * 0.76)), "slow", 0.8, 0.3, 240.0, true)
				_schedule_segment_strike(0.92, center - aim_dir * local_radius * 0.84, center + aim_dir * local_radius * 0.84, 16.0, int(round(float(local_damage) * 0.46)), "slow", 0.9, 0.3, 220.0, true)
			else:
				_schedule_segment_strike(0.45, center - side_dir * local_radius * 0.72, center + side_dir * local_radius * 0.72, 14.0, int(round(float(local_damage) * 0.32)), "slow", 0.7, 0.24, 160.0, true)
		"counter_stance":
			if q_closed:
				_schedule_burst(0.14, skill_owner.global_position, local_radius * 0.55, int(round(float(local_damage) * 0.58)), "fear", 0.7, 0.0, 300.0, false)
				_schedule_burst(0.34, skill_owner.global_position, local_radius * 0.72, int(round(float(local_damage) * 0.62)), "damage_amp", 1.0, 0.18, 320.0, false)
				_cross_segment_strike(skill_owner.global_position, aim_dir, local_radius * 0.76, 14.0, int(round(float(local_damage) * 0.36)), "fear", 0.6, 0.0, 220.0, false)
				_schedule_rotating_cross(center, local_radius * 0.9, 3, 0.14, 12.0, int(round(float(local_damage) * 0.32)), "slow", 0.8, 0.24, 260.0, true)
			else:
				_segment_strike(skill_owner.global_position - side_dir * 78.0, skill_owner.global_position + side_dir * 78.0, 12.0, int(round(float(local_damage) * 0.28)), "fear", 0.5, 0.0, 160.0, false)
		"rail_reverse":
			if q_closed:
				_segment_strike(center - aim_dir * local_radius * 0.96, center + aim_dir * local_radius * 0.96, 20.0, int(round(float(local_damage) * 0.52)), "fear", 0.9, 0.0, 620.0, true)
				_schedule_segment_strike(0.20, center + side_dir * 52.0, center - side_dir * 52.0, 18.0, int(round(float(local_damage) * 0.44)), "slow", 0.8, 0.24, 380.0, false)
				_schedule_rotating_cross(center, local_radius * 0.84, 2, 0.22, 12.0, int(round(float(local_damage) * 0.28)), "freeze", 0.55, 0.0, 210.0, true)
			else:
				_segment_strike(center - side_dir * local_radius * 0.66, center + side_dir * local_radius * 0.66, 14.0, int(round(float(local_damage) * 0.30)), "freeze", 0.45, 0.0, 150.0, true)
		"anchor_jump":
			if q_closed:
				_schedule_burst(0.18, skill_owner.global_position - aim_dir * 42.0, local_radius * 0.56, int(round(float(local_damage) * 0.54)), "slow", 0.8, 0.30, 260.0, true)
				_segment_strike(skill_owner.global_position, skill_owner.global_position - aim_dir * min(200.0, local_radius * 1.05), 16.0, int(round(float(local_damage) * 0.48)), "slow", 0.8, 0.28, 300.0, true)
		"blood_trade":
			if q_closed:
				_spawn_player_buff_zone(skill_owner.global_position, 128.0, 2.0, "heal", max(1.0, float(local_damage) * 0.10), 0.6, Color(0.92, 0.2, 0.28, 0.18))
				_segment_strike(center - aim_dir * local_radius * 0.74, center + aim_dir * local_radius * 0.74, 18.0, int(round(float(local_damage) * 0.52)), "damage_amp", 1.1, 0.18, 220.0, false)
			else:
				_segment_strike(skill_owner.global_position, skill_owner.global_position + aim_dir * min(190.0, local_radius * 1.0), 14.0, int(round(float(local_damage) * 0.34)), "damage_amp", 0.9, 0.16, 140.0, false)
		"phase_swap":
			if q_closed:
				_schedule_burst(0.18, center, local_radius * 0.68, int(round(float(local_damage) * 0.58)), "freeze", 0.65, 0.0, 260.0, true)
				_cross_segment_strike(center, aim_dir, local_radius * 0.88, 16.0, int(round(float(local_damage) * 0.46)), "freeze", 0.58, 0.0, 260.0, true)
		"chain_overload":
			if q_closed:
				_schedule_burst(0.24, center, local_radius * 1.08, int(round(float(local_damage) * 0.66)), "freeze", 0.55, 0.0, 180.0, false)
				_cross_segment_strike(center, aim_dir, local_radius * 0.96, 16.0, int(round(float(local_damage) * 0.42)), "freeze", 0.45, 0.0, 180.0, false)
			else:
				_segment_strike(center - aim_dir * local_radius * 0.72, center + aim_dir * local_radius * 0.72, 14.0, int(round(float(local_damage) * 0.34)), "marked", 0.8, 0.16, 120.0, false)
		"toxin_inject":
			if q_closed:
				_schedule_ring_bursts(center, local_radius * 0.62, local_radius * 0.36, int(round(float(local_damage) * 0.42)), 4, 0.14, "poison", 1.4, max(3.0, float(local_damage) * 0.08), 180.0, false)
				_segment_strike(center - side_dir * local_radius * 0.90, center + side_dir * local_radius * 0.90, 20.0, int(round(float(local_damage) * 0.34)), "poison", 1.3, max(2.0, float(local_damage) * 0.06), 140.0, false)
			else:
				_segment_strike(center - aim_dir * local_radius * 0.64, center + aim_dir * local_radius * 0.24, 14.0, int(round(float(local_damage) * 0.26)), "poison", 1.0, max(1.0, float(local_damage) * 0.04), 120.0, false)
		"lure_signal":
			if q_closed:
				_spawn_lure(center + side_dir * 68.0, max(1.6, duration * 0.68), local_radius * 0.7)
				_spawn_lure(center - side_dir * 68.0, max(1.6, duration * 0.68), local_radius * 0.7)
				_segment_strike(center - aim_dir * local_radius * 0.82, center + aim_dir * local_radius * 0.82, 18.0, int(round(float(local_damage) * 0.36)), "slow", 0.8, 0.28, 220.0, true)
				_spawn_moving_lure_trail(center - aim_dir * local_radius * 0.44, center + aim_dir * local_radius * 0.66, 1.15, local_radius * 0.54, int(round(float(local_damage) * 0.24)))
			else:
				_spawn_lure(center, max(1.1, duration * 0.48), local_radius * 0.58)
				_segment_strike(center - side_dir * local_radius * 0.54, center + side_dir * local_radius * 0.54, 14.0, int(round(float(local_damage) * 0.24)), "slow", 0.7, 0.22, 160.0, true)
				_spawn_moving_lure_trail(center, center + aim_dir * local_radius * 0.62, 0.9, local_radius * 0.42, int(round(float(local_damage) * 0.20)))
		"gravity_boost":
			if q_closed:
				_schedule_burst(0.14, center + aim_dir * 56.0, local_radius * 0.76, int(round(float(local_damage) * 0.56)), "slow", 0.8, 0.30, 420.0, true)
				_schedule_burst(0.32, center - aim_dir * 56.0, local_radius * 0.76, int(round(float(local_damage) * 0.56)), "slow", 0.8, 0.30, 420.0, true)
				_segment_strike(center - side_dir * local_radius * 0.82, center + side_dir * local_radius * 0.82, 20.0, int(round(float(local_damage) * 0.44)), "slow", 0.8, 0.28, 440.0, true)
		"smoke_cover":
			if q_closed:
				_spawn_lure(skill_owner.global_position - aim_dir * 82.0, 1.6, local_radius * 0.52)
				_segment_strike(skill_owner.global_position - side_dir * 90.0, skill_owner.global_position + side_dir * 90.0, 14.0, int(round(float(local_damage) * 0.24)), "slow", 0.8, 0.22, 160.0, true)
			else:
				_spawn_player_buff_zone(skill_owner.global_position, 120.0, 1.5, "cooldown_reduction", 0.10, 0.35, Color(0.88, 0.9, 1.0, 0.14))
				_segment_strike(skill_owner.global_position - aim_dir * 72.0, skill_owner.global_position + aim_dir * 72.0, 12.0, int(round(float(local_damage) * 0.18)), "slow", 0.6, 0.18, 120.0, true)
		"suppression_order":
			if q_closed:
				skill_owner.set_meta(META_TEMP_Q_AMP, 1.18)
				_schedule_burst(0.16, center, local_radius * 0.82, int(round(float(local_damage) * 0.62)), "marked", 1.0, 0.18, 260.0, true)
				_cross_segment_strike(center, aim_dir, local_radius * 0.96, 16.0, int(round(float(local_damage) * 0.38)), "marked", 1.0, 0.18, 180.0, true)
			else:
				_segment_strike(center - aim_dir * local_radius * 0.68, center + aim_dir * local_radius * 0.68, 14.0, int(round(float(local_damage) * 0.28)), "marked", 0.8, 0.16, 120.0, true)
		"blade_reap":
			if q_closed:
				_schedule_burst(0.22, center, local_radius * 0.7, int(round(float(local_damage) * 0.66)), "slow", 0.8, 0.32, 220.0, true)
				_segment_strike(center - aim_dir * local_radius * 0.80, center + aim_dir * local_radius * 0.80, 18.0, int(round(float(local_damage) * 0.44)), "slow", 0.8, 0.30, 180.0, true)
			else:
				_segment_strike(center - aim_dir * local_radius * 0.60, center + aim_dir * local_radius * 0.32, 14.0, int(round(float(local_damage) * 0.30)), "slow", 0.7, 0.26, 130.0, true)
		"crystal_overload":
			if q_closed:
				_cast_chain_overload(center, local_radius * 0.92, int(round(float(local_damage) * 0.78)))
				_cross_segment_strike(center, aim_dir, local_radius * 0.9, 16.0, int(round(float(local_damage) * 0.42)), "freeze", 0.45, 0.0, 160.0, false)
				_spawn_line_mine_sequence(center - aim_dir * local_radius * 0.92, center + aim_dir * local_radius * 0.92, 5, 0.09, local_radius * 0.18, int(round(float(local_damage) * 0.34)), "slow", 0.8, 0.26, 240.0, false)
			else:
				_segment_strike(center - side_dir * local_radius * 0.66, center + side_dir * local_radius * 0.66, 14.0, int(round(float(local_damage) * 0.28)), "slow", 0.7, 0.24, 120.0, false)
				_spawn_line_mine_sequence(center - side_dir * local_radius * 0.72, center + side_dir * local_radius * 0.72, 3, 0.12, local_radius * 0.16, int(round(float(local_damage) * 0.22)), "slow", 0.7, 0.22, 180.0, false)
		"bait_redeploy":
			if q_closed:
				_set_invincible_window(0.55)
				_spawn_player_buff_zone(skill_owner.global_position, 120.0, 1.8, "speed_boost", 0.22, 0.35, Color(0.92, 0.92, 1.0, 0.16))
				_segment_strike(center - aim_dir * local_radius * 0.72, center + aim_dir * local_radius * 0.72, 16.0, int(round(float(local_damage) * 0.34)), "slow", 0.8, 0.26, 170.0, true)
			else:
				_segment_strike(skill_owner.global_position - side_dir * 72.0, skill_owner.global_position + side_dir * 72.0, 12.0, int(round(float(local_damage) * 0.22)), "slow", 0.6, 0.2, 120.0, true)
		"thermal_break":
			if q_closed:
				_schedule_burst(0.15, center, local_radius * 0.74, int(round(float(local_damage) * 0.7)), "burn", 1.4, max(4.0, float(local_damage) * 0.10), 260.0, false)
				_segment_strike(center - side_dir * local_radius * 0.84, center + side_dir * local_radius * 0.84, 18.0, int(round(float(local_damage) * 0.42)), "burn", 1.2, max(2.0, float(local_damage) * 0.06), 180.0, false)
			else:
				_segment_strike(center - aim_dir * local_radius * 0.74, center + aim_dir * local_radius * 0.34, 14.0, int(round(float(local_damage) * 0.30)), "burn", 1.0, max(1.0, float(local_damage) * 0.04), 130.0, false)
		"execute_calibrate":
			if q_closed:
				skill_owner.set_meta(META_TEMP_Q_AMP, 1.30)
				_schedule_burst(0.14, center, local_radius * 0.66, int(round(float(local_damage) * 0.62)), "marked", 1.2, 0.20, 220.0, true)
				_segment_strike(center - aim_dir * local_radius * 0.86, center + aim_dir * local_radius * 0.86, 16.0, int(round(float(local_damage) * 0.40)), "marked", 1.1, 0.2, 180.0, false)
			else:
				skill_owner.set_meta(META_TEMP_Q_AMP, 1.14)
				_segment_strike(center - side_dir * local_radius * 0.72, center + side_dir * local_radius * 0.72, 14.0, int(round(float(local_damage) * 0.28)), "marked", 0.8, 0.16, 120.0, false)
		"tide_reverse":
			if q_closed:
				_schedule_burst(0.56, center + side_dir * 52.0, local_radius * 0.78, int(round(float(local_damage) * 0.56)), "slow", 0.85, 0.30, 320.0, false)
				_schedule_burst(0.56, center - side_dir * 52.0, local_radius * 0.78, int(round(float(local_damage) * 0.56)), "slow", 0.85, 0.30, 320.0, true)
				_schedule_segment_strike(0.12, center - aim_dir * local_radius * 1.08, center + aim_dir * local_radius * 1.08, 22.0, int(round(float(local_damage) * 0.50)), "slow", 0.85, 0.30, 360.0, false)
				_schedule_segment_strike(0.42, center + aim_dir * local_radius * 1.08, center - aim_dir * local_radius * 1.08, 22.0, int(round(float(local_damage) * 0.50)), "slow", 0.85, 0.30, 360.0, true)
		"verdict_trigger":
			if q_closed:
				_schedule_burst(0.18, center, local_radius * 0.84, int(round(float(local_damage) * 0.58)), "marked", 1.1, 0.2, 160.0, false)
				_schedule_burst(0.38, center, local_radius * 0.84, int(round(float(local_damage) * 0.72)), "slow", 0.8, 0.28, 200.0, true)
				_cross_segment_strike(center, aim_dir, local_radius * 0.92, 16.0, int(round(float(local_damage) * 0.50)), "marked", 1.0, 0.18, 220.0, false)
		"echo_amplify":
			if q_closed:
				skill_owner.set_meta(META_TEMP_Q_AMP, 1.42)
				_schedule_burst(0.24, center, local_radius * 0.82, int(round(float(local_damage) * 0.54)), "slow", 0.8, 0.26, 180.0, false)
				_cross_segment_strike(center, aim_dir, local_radius * 1.0, 16.0, int(round(float(local_damage) * 0.34)), "slow", 0.8, 0.24, 150.0, false)
			else:
				skill_owner.set_meta(META_TEMP_Q_AMP, 1.18)
				_segment_strike(center - aim_dir * local_radius * 0.76, center + aim_dir * local_radius * 0.30, 14.0, int(round(float(local_damage) * 0.24)), "slow", 0.7, 0.22, 120.0, false)
		"rift_catalyst":
			if q_closed:
				_schedule_ring_bursts(center, local_radius * 0.72, local_radius * 0.34, int(round(float(local_damage) * 0.6)), 6, 0.10, "slow", 0.9, 0.30, 380.0, true)
				_cross_segment_strike(center, aim_dir, local_radius * 1.12, 20.0, int(round(float(local_damage) * 0.52)), "slow", 0.9, 0.30, 420.0, true)
		_:
			pass

func _aim_direction_from(center: Vector2) -> Vector2:
	if not is_instance_valid(skill_owner):
		return Vector2.RIGHT
	var dir: Vector2 = skill_owner.get_global_mouse_position() - center
	if dir.length_squared() <= 0.001:
		return Vector2.RIGHT
	return dir.normalized()

func _schedule_ring_bursts(
	center: Vector2,
	ring_radius: float,
	burst_radius: float,
	damage: int,
	count: int,
	interval: float,
	status_type: String,
	status_duration: float,
	status_value: float,
	force: float,
	pull_to_center: bool
) -> void:
	var burst_count: int = max(1, count)
	var safe_interval: float = max(0.04, interval)
	var safe_ring_radius: float = max(0.0, ring_radius)
	var safe_burst_radius: float = max(40.0, burst_radius)
	var safe_damage: int = max(1, damage)
	for idx: int in range(burst_count):
		var delay: float = safe_interval * float(idx)
		var angle: float = TAU * float(idx) / float(burst_count)
		var offset: Vector2 = Vector2(cos(angle), sin(angle)) * safe_ring_radius
		get_tree().create_timer(delay).timeout.connect(func() -> void:
			_burst(center + offset, safe_burst_radius, safe_damage, status_type, status_duration, status_value, force, pull_to_center)
		)

func _spawn_gate_wall(center: Vector2, dir: Vector2, length: float, contact_damage: int, duration: float, color: Color) -> void:
	var safe_dir: Vector2 = dir
	if safe_dir.length_squared() <= 0.001:
		safe_dir = Vector2.RIGHT
	else:
		safe_dir = safe_dir.normalized()
	var half: float = max(30.0, length * 0.5)
	SkillEffectManager.create_wall_effect({
		"start": center - safe_dir * half,
		"end": center + safe_dir * half,
		"width": 16.0,
		"duration": max(0.6, duration),
		"block_enemies": true,
		"block_bullets": false,
		"contact_damage": max(1, contact_damage),
		"contact_interval": 0.26,
		"color": color
	})

func _spawn_corridor_fence(center: Vector2, dir: Vector2, length: float, half_gap: float, duration: float, contact_damage: int) -> void:
	var safe_dir: Vector2 = dir
	if safe_dir.length_squared() <= 0.001:
		safe_dir = Vector2.RIGHT
	else:
		safe_dir = safe_dir.normalized()
	var side_dir: Vector2 = Vector2(-safe_dir.y, safe_dir.x)
	var safe_len: float = max(90.0, length)
	var safe_gap: float = max(16.0, half_gap)
	var safe_duration: float = max(0.6, duration)
	var safe_damage: int = max(1, contact_damage)
	_spawn_gate_wall(center + side_dir * safe_gap, safe_dir, safe_len, safe_damage, safe_duration, Color(1.0, 0.9, 0.45, 0.72))
	_spawn_gate_wall(center - side_dir * safe_gap, safe_dir, safe_len, safe_damage, safe_duration, Color(1.0, 0.9, 0.45, 0.72))
	_segment_strike(center - safe_dir * safe_len * 0.45, center + safe_dir * safe_len * 0.45, safe_gap * 0.72, safe_damage, "slow", 0.8, 0.24, 180.0, true)

func _schedule_rotating_cross(
	center: Vector2,
	length: float,
	sweeps: int,
	interval: float,
	half_width: float,
	damage: int,
	status_type: String,
	status_duration: float,
	status_value: float,
	force: float,
	pull_to_segment: bool
) -> void:
	var safe_sweeps: int = max(1, sweeps)
	var safe_interval: float = max(0.05, interval)
	var safe_length: float = max(70.0, length)
	var safe_half_width: float = max(8.0, half_width)
	var safe_damage: int = max(1, damage)
	for idx: int in range(safe_sweeps):
		var delay: float = safe_interval * float(idx)
		var angle: float = TAU * float(idx) / float(safe_sweeps)
		var dir: Vector2 = Vector2(cos(angle), sin(angle))
		get_tree().create_timer(delay).timeout.connect(func() -> void:
			_cross_segment_strike(center, dir, safe_length, safe_half_width, safe_damage, status_type, status_duration, status_value, force, pull_to_segment)
		)

func _spawn_line_mine_sequence(
	start: Vector2,
	finish: Vector2,
	count: int,
	interval: float,
	burst_radius: float,
	damage: int,
	status_type: String,
	status_duration: float,
	status_value: float,
	force: float,
	pull_to_center: bool
) -> void:
	var safe_count: int = max(1, count)
	var safe_interval: float = max(0.04, interval)
	var safe_radius: float = max(40.0, burst_radius)
	var safe_damage: int = max(1, damage)
	for idx: int in range(safe_count):
		var t: float = 0.5
		if safe_count > 1:
			t = float(idx) / float(safe_count - 1)
		var pos: Vector2 = start.lerp(finish, t)
		var delay: float = safe_interval * float(idx)
		get_tree().create_timer(delay).timeout.connect(func() -> void:
			_burst(pos, safe_radius, safe_damage, status_type, status_duration, status_value, force, pull_to_center)
		)

func _spawn_moving_lure_trail(start: Vector2, finish: Vector2, duration: float, pulse_radius: float, damage: int) -> void:
	var safe_duration: float = max(0.3, duration)
	var safe_radius: float = max(60.0, pulse_radius)
	var safe_damage: int = max(1, damage)
	var steps: int = max(2, int(round(safe_duration / 0.2)))
	for idx: int in range(steps):
		var t: float = 0.0
		if steps > 1:
			t = float(idx) / float(steps - 1)
		var pos: Vector2 = start.lerp(finish, t)
		var delay: float = safe_duration * t
		get_tree().create_timer(delay).timeout.connect(func() -> void:
			_spawn_lure(pos, 0.75, safe_radius * 0.75)
			_burst(pos, safe_radius, safe_damage, "slow", 0.7, 0.22, 180.0, true)
		)

func _segment_strike(
	start: Vector2,
	finish: Vector2,
	half_width: float,
	damage: int,
	status_type: String,
	status_duration: float,
	status_value: float,
	force: float,
	pull_to_segment: bool
) -> int:
	var hit_count: int = 0
	var width: float = max(8.0, half_width)
	var enemies: Array = get_tree().get_nodes_in_group("enemies")
	for enemy_obj: Variant in enemies:
		if enemy_obj == null or not is_instance_valid(enemy_obj):
			continue
		if not (enemy_obj is Node2D):
			continue
		var enemy: Node2D = enemy_obj
		var closest: Vector2 = _closest_point_on_segment(enemy.global_position, start, finish)
		if enemy.global_position.distance_to(closest) > width:
			continue
		_apply_enemy_damage(enemy, max(1, damage))
		if not status_type.is_empty():
			_apply_enemy_status(enemy, status_type, status_duration, status_value)
		if force > 0.0:
			var dir: Vector2 = (closest - enemy.global_position).normalized() if pull_to_segment else (enemy.global_position - closest).normalized()
			if dir.length_squared() <= 0.001:
				var seg_dir: Vector2 = (finish - start).normalized()
				if seg_dir.length_squared() <= 0.001:
					seg_dir = Vector2.RIGHT
				dir = Vector2(-seg_dir.y, seg_dir.x)
			_apply_enemy_force(enemy, dir, force)
		hit_count += 1
	return hit_count

func _schedule_segment_strike(
	delay: float,
	start: Vector2,
	finish: Vector2,
	half_width: float,
	damage: int,
	status_type: String,
	status_duration: float,
	status_value: float,
	force: float,
	pull_to_segment: bool
) -> void:
	get_tree().create_timer(max(0.05, delay)).timeout.connect(func() -> void:
		_segment_strike(start, finish, half_width, damage, status_type, status_duration, status_value, force, pull_to_segment)
	)

func _cross_segment_strike(
	center: Vector2,
	dir: Vector2,
	length: float,
	half_width: float,
	damage: int,
	status_type: String,
	status_duration: float,
	status_value: float,
	force: float,
	pull_to_segment: bool
) -> int:
	var main_dir: Vector2 = dir
	if main_dir.length_squared() <= 0.001:
		main_dir = Vector2.RIGHT
	else:
		main_dir = main_dir.normalized()
	var side_dir: Vector2 = Vector2(-main_dir.y, main_dir.x)
	var half_len: float = max(40.0, length * 0.5)
	var total_hit: int = 0
	total_hit += _segment_strike(center - main_dir * half_len, center + main_dir * half_len, half_width, damage, status_type, status_duration, status_value, force, pull_to_segment)
	total_hit += _segment_strike(center - side_dir * half_len, center + side_dir * half_len, half_width, damage, status_type, status_duration, status_value, force, pull_to_segment)
	return total_hit

func _closest_point_on_segment(point: Vector2, a: Vector2, b: Vector2) -> Vector2:
	var ab: Vector2 = b - a
	var ab_len_sq: float = ab.length_squared()
	if ab_len_sq <= 0.0001:
		return a
	var t: float = float(clamp((point - a).dot(ab) / ab_len_sq, 0.0, 1.0))
	return a + ab * t

func _burst(
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

func _schedule_burst(
	delay: float,
	center: Vector2,
	radius: float,
	damage: int,
	status_type: String,
	status_duration: float,
	status_value: float,
	force: float,
	pull_to_center: bool
) -> void:
	get_tree().create_timer(max(0.05, delay)).timeout.connect(func() -> void:
		_burst(center, radius, damage, status_type, status_duration, status_value, force, pull_to_center)
	)

func _cast_hook_pull(search_radius: float, damage: int) -> void:
	var target: Node2D = _nearest_enemy(search_radius)
	if target == null:
		Global.spawn_floating_text(skill_owner.global_position, "MISS", Color(1.0, 0.82, 0.35))
		return
	_apply_enemy_damage(target, damage)
	_apply_enemy_status(target, "damage_amp", 1.2, 0.2)
	var pull_dir: Vector2 = (skill_owner.global_position - target.global_position).normalized()
	if pull_dir.length_squared() <= 0.001:
		pull_dir = Vector2.LEFT
	_apply_enemy_force(target, pull_dir, 760.0)

func _cast_gate_patch(center: Vector2, damage: int, duration_scale: float) -> void:
	var mouse_pos: Vector2 = skill_owner.get_global_mouse_position()
	var dir: Vector2 = mouse_pos - center
	if dir.length() <= 1.0:
		dir = Vector2.RIGHT
	var end_pos: Vector2 = center + dir.normalized() * min(260.0, dir.length())
	SkillEffectManager.create_wall_effect({
		"start": center,
		"end": end_pos,
		"width": 18.0,
		"duration": max(1.0, 2.8 * duration_scale),
		"block_enemies": true,
		"block_bullets": false,
		"contact_damage": max(1, int(round(float(damage) * 0.65))),
		"contact_interval": 0.28,
		"color": Color(1.0, 0.9, 0.3, 0.85)
	})

func _cast_decoy_swap(center: Vector2, damage: int) -> void:
	var start_pos: Vector2 = skill_owner.global_position
	if start_pos.distance_to(center) > 6.0:
		skill_owner.global_position = center
	_burst(start_pos, 100.0, int(round(float(damage) * 0.62)), "slow", 0.8, 0.36, 280.0, false)
	_burst(skill_owner.global_position, 120.0, int(round(float(damage) * 0.88)), "fear", 0.65, 0.0, 320.0, true)

func _cast_reverse_wind(center: Vector2, radius: float, damage: int) -> void:
	var pull_phase: bool = true
	if skill_owner.has_meta("e_proto_reverse_phase"):
		pull_phase = not bool(skill_owner.get_meta("e_proto_reverse_phase"))
	skill_owner.set_meta("e_proto_reverse_phase", pull_phase)
	_burst(center, radius, int(round(float(damage) * 0.8)), "slow", 0.9, 0.34, 420.0, pull_phase)

func _cast_mark_explode(center: Vector2, radius: float, damage: int) -> void:
	var enemies: Array[Node2D] = _enemies_in_radius(center, radius)
	for enemy: Node2D in enemies:
		var final_damage: int = damage
		if _enemy_has_status(enemy, "marked"):
			final_damage = int(round(float(damage) * 1.45))
		_apply_enemy_damage(enemy, final_damage)
		_apply_enemy_status(enemy, "slow", 0.8, 0.32)

func _cast_phase_swap(search_radius: float, damage: int) -> void:
	var target: Node2D = _nearest_enemy(search_radius)
	if target == null:
		return
	var owner_pos: Vector2 = skill_owner.global_position
	var target_pos: Vector2 = target.global_position
	skill_owner.global_position = target_pos
	target.global_position = owner_pos
	_apply_enemy_damage(target, int(round(float(damage) * 1.05)))
	_apply_enemy_status(target, "freeze", 0.7, 0.0)

func _cast_chain_overload(center: Vector2, radius: float, damage: int) -> void:
	var enemies: Array[Node2D] = _enemies_in_radius(center, radius)
	enemies.sort_custom(func(a: Node2D, b: Node2D) -> bool:
		return a.global_position.distance_to(center) < b.global_position.distance_to(center)
	)
	var max_hits: int = int(min(6, enemies.size()))
	for idx: int in range(max_hits):
		var enemy: Node2D = enemies[idx]
		var scale: float = 1.0 - float(idx) * 0.12
		_apply_enemy_damage(enemy, max(1, int(round(float(damage) * scale))))
		_apply_enemy_status(enemy, "freeze", 0.45, 0.0)

func _spawn_debuff_zone(center: Vector2, radius: float, duration: float, debuff_type: String, debuff_value: float, debuff_duration: float, tick_interval: float, color: Color) -> void:
	SkillEffectManager.create_debuff_zone({
		"polygon": _circle_polygon(center, radius, 20),
		"duration": duration,
		"debuff_type": debuff_type,
		"debuff_value": debuff_value,
		"debuff_duration": debuff_duration,
		"tick_interval": tick_interval,
		"color": color
	})

func _spawn_player_buff_zone(center: Vector2, radius: float, duration: float, buff_type: String, buff_value: float, tick_interval: float, color: Color) -> void:
	SkillEffectManager.create_buff_zone({
		"polygon": _circle_polygon(center, radius, 20),
		"duration": duration,
		"buff_type": buff_type,
		"buff_value": buff_value,
		"tick_interval": tick_interval,
		"target_group": "player",
		"color": color
	})

func _spawn_area_puller(center: Vector2, radius: float, damage: int, duration: float, force: float) -> void:
	SkillEffectManager.create_area_effect({
		"polygon": _circle_polygon(center, radius, 24),
		"damage": max(1, damage),
		"damage_interval": 0.35,
		"duration": duration,
		"pull_to_center": true,
		"pull_force": force,
		"pull_interval": 0.05,
		"color": Color(0.5, 0.9, 1.0, 0.3)
	})

func _cast_blade_reap(center: Vector2, radius: float, damage: int) -> void:
	var enemies: Array[Node2D] = _enemies_in_radius(center, radius)
	for enemy: Node2D in enemies:
		var ratio: float = _enemy_hp_ratio(enemy)
		var final_damage: int = damage
		if ratio <= 0.30:
			final_damage = int(round(float(damage) * 1.85))
		_apply_enemy_damage(enemy, max(1, final_damage))
		_apply_enemy_status(enemy, "slow", 0.7, 0.38)

func _redeploy_baits_to_mouse(search_radius: float, damage: int) -> void:
	var mouse_pos: Vector2 = skill_owner.get_global_mouse_position()
	var refs: Array = _owner_meta_array(META_NODE_BAITS)
	var moved: int = 0
	for ref_obj: Variant in refs:
		if not (ref_obj is WeakRef):
			continue
		var raw: Variant = ref_obj.get_ref()
		if raw == null or not is_instance_valid(raw) or not (raw is Node2D):
			continue
		var node: Node2D = raw
		if node.global_position.distance_to(skill_owner.global_position) > search_radius:
			continue
		node.global_position = mouse_pos + Vector2(randf_range(-40.0, 40.0), randf_range(-40.0, 40.0))
		_burst(node.global_position, 85.0, damage, "slow", 0.8, 0.35, 220.0, true)
		moved += 1
	if moved <= 0:
		_burst(mouse_pos, 95.0, damage, "slow", 0.8, 0.35, 240.0, true)

func _cast_thermal_break(center: Vector2, radius: float, damage: int) -> void:
	var enemies: Array[Node2D] = _enemies_in_radius(center, radius)
	for enemy: Node2D in enemies:
		var final_damage: int = damage
		if _enemy_has_status(enemy, "burn"):
			final_damage = int(round(float(damage) * 1.6))
		_apply_enemy_damage(enemy, final_damage)
		_apply_enemy_status(enemy, "slow", 0.9, 0.34)

func _cast_verdict_trigger(center: Vector2, radius: float, damage: int) -> void:
	var enemies: Array[Node2D] = _enemies_in_radius(center, radius)
	for enemy: Node2D in enemies:
		if not _enemy_has_status(enemy, "marked"):
			continue
		_apply_enemy_damage(enemy, int(round(float(damage) * 1.25)))
		_burst(enemy.global_position, 70.0, int(round(float(damage) * 0.6)), "slow", 0.7, 0.28, 180.0, false)

func _spawn_lure(center: Vector2, duration: float, radius: float) -> void:
	var lure: Node2D = Node2D.new()
	lure.name = "EProtoLure"
	lure.global_position = center
	var scene: Node = get_tree().current_scene if get_tree() else null
	if scene != null:
		scene.add_child(lure)
	else:
		add_child(lure)
	var enemies: Array = get_tree().get_nodes_in_group("enemies")
	for enemy_obj: Variant in enemies:
		if enemy_obj == null or not is_instance_valid(enemy_obj) or not (enemy_obj is Node2D):
			continue
		var enemy: Node2D = enemy_obj
		if enemy.global_position.distance_to(center) > radius:
			continue
		if enemy.has_method("set_taunt_target"):
			enemy.call("set_taunt_target", lure)
	get_tree().create_timer(duration).timeout.connect(func() -> void:
		if is_instance_valid(lure):
			lure.queue_free()
	)

func _set_invincible_window(duration: float) -> void:
	if not is_instance_valid(skill_owner):
		return
	skill_owner.set_meta("buff_invincible", true)
	var owner_ref: WeakRef = weakref(skill_owner)
	get_tree().create_timer(max(0.1, duration)).timeout.connect(func() -> void:
		var raw: Variant = owner_ref.get_ref() if owner_ref != null else null
		if raw != null and is_instance_valid(raw) and raw is Node:
			var node: Node = raw
			node.set_meta("buff_invincible", false)
	)

func _dash_to_mouse(max_distance: float) -> void:
	if not is_instance_valid(skill_owner):
		return
	var start: Vector2 = skill_owner.global_position
	var mouse_pos: Vector2 = skill_owner.get_global_mouse_position()
	var offset: Vector2 = mouse_pos - start
	if offset.length() <= 1.0:
		return
	skill_owner.global_position = start + offset.normalized() * min(max_distance, offset.length())

func _pay_health_cost(ratio: float) -> void:
	if not is_instance_valid(skill_owner):
		return
	if not skill_owner.has_node("HealthComponent"):
		return
	var hc: Node = skill_owner.get_node("HealthComponent")
	if hc == null:
		return
	var max_hp: float = float(hc.get("max_health")) if "max_health" in hc else 100.0
	var cost: int = int(max(1, int(round(max_hp * ratio))))
	if hc.has_method("take_damage"):
		hc.call("take_damage", cost)

func _detonate_owner_nodes(meta_key: String, damage: int, force: float, pull_to_center: bool) -> int:
	var refs: Array = _owner_meta_array(meta_key)
	var detonated: int = 0
	for ref_obj: Variant in refs:
		if not (ref_obj is WeakRef):
			continue
		var raw: Variant = ref_obj.get_ref()
		if raw == null or not is_instance_valid(raw):
			continue
		if not (raw is Node2D):
			continue
		var node: Node2D = raw
		var hits: int = _burst(node.global_position, 90.0, damage, "slow", 0.8, 0.36, force, pull_to_center)
		if hits > 0:
			detonated += 1
		node.queue_free()
	if is_instance_valid(skill_owner):
		skill_owner.set_meta(meta_key, [])
	return detonated

func _owner_meta_array(meta_key: String) -> Array:
	if not is_instance_valid(skill_owner):
		return []
	if not skill_owner.has_meta(meta_key):
		return []
	var raw: Variant = skill_owner.get_meta(meta_key)
	if raw is Array:
		return raw
	return []

func _nearest_enemy(max_distance: float) -> Node2D:
	var enemies: Array = get_tree().get_nodes_in_group("enemies")
	var nearest: Node2D = null
	var nearest_dist: float = max_distance
	for enemy_obj: Variant in enemies:
		if enemy_obj == null or not is_instance_valid(enemy_obj):
			continue
		if not (enemy_obj is Node2D):
			continue
		var enemy: Node2D = enemy_obj
		var dist: float = skill_owner.global_position.distance_to(enemy.global_position)
		if dist <= nearest_dist:
			nearest = enemy
			nearest_dist = dist
	return nearest

func _enemies_in_radius(center: Vector2, radius: float) -> Array[Node2D]:
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

func _enemy_has_status(enemy: Node2D, status_type: String) -> bool:
	if enemy == null or not is_instance_valid(enemy):
		return false
	if enemy.has_method("has_status"):
		return bool(enemy.call("has_status", status_type))
	return false

func _enemy_hp_ratio(enemy: Node2D) -> float:
	if enemy == null or not is_instance_valid(enemy):
		return 1.0
	if not enemy.has_node("HealthComponent"):
		return 1.0
	var hc: Node = enemy.get_node("HealthComponent")
	if hc == null:
		return 1.0
	if not ("current_health" in hc and "max_health" in hc):
		return 1.0
	var max_hp: float = float(max(1.0, float(hc.get("max_health"))))
	return float(hc.get("current_health")) / max_hp

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

func _circle_polygon(center: Vector2, radius: float, segments: int) -> PackedVector2Array:
	var result: PackedVector2Array = PackedVector2Array()
	var seg_count: int = int(max(6, segments))
	for i: int in range(seg_count):
		var angle: float = TAU * float(i) / float(seg_count)
		result.append(center + Vector2(cos(angle), sin(angle)) * radius)
	return result
