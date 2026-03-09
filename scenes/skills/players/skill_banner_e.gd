extends SkillBase
class_name SkillBannerE

## ==============================================================================
## 旗手E技能 - 全队移速爆发
## ==============================================================================
## 
## 功能说明:
## - 按E键吹响号角，为全队提供短暂的移速爆发加成
## - 通过 set_meta("buff_speed_boost") 为所有队友添加移速加成
## 
## ==============================================================================

# ==============================================================================
# 旗手E技能专属参数（从CSV加载）
# ==============================================================================

## 移速加成值（50%）
var speed_boost_value: float = 0.5

## 移速加成持续时间
var speed_boost_duration: float = 4.0

# ==============================================================================
# 技能执行
# ==============================================================================

## 执行技能
func execute() -> void:
	if not consume_energy():
		if skill_owner:
			Global.spawn_floating_text(skill_owner.global_position, "No Energy!", Color.RED)
		return
	if not skill_owner:
		return

	var duration_amp: float = get_e_duration_amp(0.35)
	var damage_amp: float = get_e_damage_amp(0.2, 0.25)
	var final_speed_boost: float = speed_boost_value * (1.0 + (damage_amp - 1.0) * 0.6)
	var final_duration: float = speed_boost_duration * duration_amp
	var extra_attack_boost: float = 0.0
	if is_f_window_active():
		extra_attack_boost = 0.12 + (damage_amp - 1.0) * 0.35

	# 为全队添加移速加成
	var players = get_tree().get_nodes_in_group("player")
	for player in players:
		if not is_instance_valid(player):
			continue
		var had_speed_meta: bool = player.has_meta("buff_speed_boost")
		var old_speed_meta: float = float(player.get_meta("buff_speed_boost")) if had_speed_meta else 0.0
		player.set_meta("buff_speed_boost", final_speed_boost)

		var had_attack_meta: bool = player.has_meta("attack_boost")
		var old_attack_meta: float = float(player.get_meta("attack_boost")) if had_attack_meta else 0.0
		if extra_attack_boost > 0.0:
			player.set_meta("attack_boost", old_attack_meta + extra_attack_boost)

		var player_ref: WeakRef = weakref(player)
		var timer: SceneTreeTimer = get_tree().create_timer(final_duration)
		timer.timeout.connect(
			_on_banner_buff_timeout.bind(
				player_ref,
				had_speed_meta,
				old_speed_meta,
				extra_attack_boost,
				had_attack_meta,
				old_attack_meta
			)
		)

	Global.on_camera_shake.emit(5.0, 0.15)
	if extra_attack_boost > 0.0:
		Global.spawn_floating_text(skill_owner.global_position, "CHARGE++!", Color(1.05, 0.35, 0.25))
	else:
		Global.spawn_floating_text(skill_owner.global_position, "CHARGE!", Color(0.9, 0.2, 0.2))
	start_cooldown()

func _on_banner_buff_timeout(
	player_ref: WeakRef,
	had_speed_meta: bool,
	old_speed_meta: float,
	extra_attack_boost: float,
	had_attack_meta: bool,
	old_attack_meta: float
) -> void:
	var player = player_ref.get_ref() if player_ref != null else null
	if player == null or not is_instance_valid(player):
		return
	if had_speed_meta:
		player.set_meta("buff_speed_boost", old_speed_meta)
	elif player.has_meta("buff_speed_boost"):
		player.remove_meta("buff_speed_boost")
	if extra_attack_boost > 0.0:
		if had_attack_meta:
			player.set_meta("attack_boost", old_attack_meta)
		elif player.has_meta("attack_boost"):
			player.remove_meta("attack_boost")
