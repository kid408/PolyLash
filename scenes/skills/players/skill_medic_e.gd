extends SkillBase
class_name SkillMedicE

var station_radius: float = 170.0
var station_duration: float = 5.0
var station_heal_tick: float = 10.0
var station_lifesteal: float = 0.18
var station_cdr: float = 0.18
var station_speed_boost: float = 0.12
var enemy_anti_heal_amp: float = 0.20
var enemy_slow_value: float = 0.26
var energy_burst: float = 16.0

func execute() -> void:
	if not can_execute():
		return
	if not consume_energy():
		if is_instance_valid(skill_owner):
			Global.spawn_floating_text(skill_owner.global_position, "No Energy!", Color.RED)
		return
	if not is_instance_valid(skill_owner):
		return

	var damage_amp: float = get_e_damage_amp(0.18, 0.22)
	var duration_amp: float = get_e_duration_amp(0.4)
	var center: Vector2 = skill_owner.get_global_mouse_position()
	var final_duration: float = station_duration * duration_amp
	var final_radius: float = station_radius * (1.0 + (duration_amp - 1.0) * 0.35)
	var final_heal: float = station_heal_tick * (1.0 + (duration_amp - 1.0) * 0.4)
	var final_cdr: float = min(0.45, station_cdr * (1.0 + (duration_amp - 1.0) * 0.35))
	var final_mark_amp: float = enemy_anti_heal_amp * (1.0 + (damage_amp - 1.0) * 0.45)

	SkillEffectManager.create_buff_zone({
		"polygon": _build_circle_polygon(center, final_radius, 28),
		"duration": final_duration,
		"buff_type": "heal",
		"buff_value": final_heal,
		"tick_interval": 0.45,
		"color": Color(0.38, 1.0, 0.64, 0.42)
	})

	SkillEffectManager.create_buff_zone({
		"polygon": _build_circle_polygon(center, final_radius * 0.9, 24),
		"duration": final_duration,
		"buff_type": "cooldown_reduction",
		"buff_value": final_cdr,
		"tick_interval": 0.5,
		"color": Color(0.58, 1.0, 0.82, 0.24)
	})

	SkillEffectManager.create_buff_zone({
		"polygon": _build_circle_polygon(center, final_radius * 0.75, 20),
		"duration": final_duration,
		"buff_type": "speed_boost",
		"buff_value": station_speed_boost,
		"tick_interval": 0.5,
		"color": Color(0.62, 1.0, 0.9, 0.2)
	})

	SkillEffectManager.create_buff_zone({
		"polygon": _build_circle_polygon(center, final_radius * 0.6, 18),
		"duration": final_duration,
		"buff_type": "lifesteal",
		"buff_value": station_lifesteal,
		"tick_interval": 0.6,
		"color": Color(0.32, 0.95, 0.58, 0.18)
	})

	SkillEffectManager.create_debuff_zone({
		"polygon": _build_circle_polygon(center, final_radius, 28),
		"duration": final_duration,
		"debuff_type": "damage_amp",
		"debuff_value": final_mark_amp,
		"debuff_duration": 1.1,
		"tick_interval": 0.42,
		"color": Color(0.35, 0.82, 0.56, 0.16)
	})

	SkillEffectManager.create_debuff_zone({
		"polygon": _build_circle_polygon(center, final_radius * 0.85, 24),
		"duration": final_duration,
		"debuff_type": "slow",
		"debuff_value": enemy_slow_value,
		"debuff_duration": 0.9,
		"tick_interval": 0.36,
		"color": Color(0.3, 0.72, 0.52, 0.14)
	})

	if skill_owner.has_method("gain_energy"):
		var gain: float = energy_burst * (1.12 if is_f_window_active() else 1.0)
		skill_owner.call("gain_energy", gain)

	Global.spawn_floating_text(center, "MED STATION", Color(0.52, 1.0, 0.72))
	spawn_skill_vfx(center, Color(0.48, 1.0, 0.62, 0.76), 0.72)
	Global.on_camera_shake.emit(5.8, 0.1)
	start_cooldown()

func _build_circle_polygon(center: Vector2, radius: float, steps: int) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	var safe_steps: int = max(8, steps)
	for i: int in range(safe_steps):
		var angle: float = TAU * float(i) / float(safe_steps)
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	return points
