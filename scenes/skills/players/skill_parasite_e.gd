extends SkillBase
class_name SkillParasiteE

@export var catalyst_damage_ratio: float = 1.20
@export var parasite_duration: float = 8.0
@export var spread_radius: float = 300.0
@export var spread_count: int = 3
@export var pull_duration: float = 0.35
@export var pull_speed: float = 450.0
@export var catalyst_death_window: float = 0.5

func _ready() -> void:
	skill_id = "skill_parasite_e"
	set_skill_tags_from_value("e,active,burst,parasite")

func execute() -> void:
	if is_on_cooldown or not is_instance_valid(skill_owner):
		return

	if not consume_energy():
		return

	var hosts: Array[Enemy] = []
	for enemy_node in get_tree().get_nodes_in_group("enemies"):
		if not (enemy_node is Enemy):
			continue
		var enemy := enemy_node as Enemy
		if not is_instance_valid(enemy) or enemy.is_dead or not enemy.is_parasitized:
			continue
		hosts.append(enemy)

	if hosts.is_empty():
		Global.spawn_floating_text(skill_owner.global_position, "MISS", Color(1.0, 0.45, 0.45))
		start_cooldown()
		return

	var source_attack: float = float(skill_owner.get("damage")) if "damage" in skill_owner else 0.0
	var catalyst_damage: int = max(1, int(round(max(1.0, source_attack) * catalyst_damage_ratio)))
	Global.spawn_floating_text(skill_owner.global_position, "Catalyze!", Color(1.0, 0.36, 0.36))
	var hit_enemies: Array = []

	for enemy in hosts:
		if not is_instance_valid(enemy) or enemy.is_dead or enemy.health_component == null:
			continue
		enemy.mark_parasite_catalyst_window(source_attack, catalyst_death_window)
		enemy.health_component.take_damage(catalyst_damage)
		hit_enemies.append(enemy)

	if skill_owner.has_method("notify_front_skill_damage") and not hit_enemies.is_empty():
		skill_owner.notify_front_skill_damage("e", hit_enemies, {
			"skill_id": "e_parasite",
			"source": "parasite_catalyze",
		})

	start_cooldown()
