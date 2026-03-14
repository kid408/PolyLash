extends SkillBase
class_name SkillMeatStake

var chain_radius: float = 250.0
var stake_throw_speed: float = 1200.0
var stake_impact_damage: int = 20
var stake_duration: float = 6.0
var max_throw_distance: float = 800.0
var chain_color: Color = Color(0.3, 0.1, 0.1, 0.8)

var active_stake: Node2D = null

func execute() -> void:
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

	if is_instance_valid(active_stake):
		active_stake.queue_free()
		active_stake = null

	var target_pos: Vector2 = skill_owner.get_global_mouse_position()
	var dir: Vector2 = (target_pos - skill_owner.global_position).normalized()
	var dist: float = min(skill_owner.global_position.distance_to(target_pos), max_throw_distance)
	var final_pos: Vector2 = skill_owner.global_position + dir * dist

	_push_runtime_params_to_owner()

	var stake: MeatStake = MeatStake.new()
	stake.setup(final_pos, skill_owner)
	skill_owner.get_parent().add_child(stake)
	stake.global_position = skill_owner.global_position

	active_stake = stake
	Global.on_camera_shake.emit(6.0, 0.12)
	start_cooldown()

func _push_runtime_params_to_owner() -> void:
	if not is_instance_valid(skill_owner):
		return
	skill_owner.set("chain_radius", chain_radius)
	skill_owner.set("stake_throw_speed", stake_throw_speed)
	skill_owner.set("stake_impact_damage", stake_impact_damage)
	skill_owner.set("stake_duration", stake_duration)
	skill_owner.set("chain_color", chain_color)

func cleanup() -> void:
	if is_instance_valid(active_stake):
		active_stake.queue_free()
	active_stake = null

func get_active_stake() -> Node2D:
	return active_stake

func has_active_stake() -> bool:
	return is_instance_valid(active_stake)
