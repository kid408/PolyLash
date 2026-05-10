extends Unit
class_name PlayerBase

const COMBAT_MODIFIER_COMPONENT := preload("res://scenes/components/combat_modifier_component.gd")
const COMBAT_EVENT_TYPES := preload("res://scenes/components/combat_event_types.gd")

# 对外信号：供 HUD、结算与其他系统同步玩家实时状态。
signal energy_changed(current, max_val)
signal armor_changed(current)
signal xp_changed(current)
signal gold_changed(current)
signal dash_started(player_id: String, start_pos: Vector2, direction: Vector2)
signal dash_active(player_id: String, current_pos: Vector2, direction: Vector2, normalized_time: float)
signal dash_finished(player_id: String, end_pos: Vector2, direction: Vector2)
signal pre_hit_veto_requested(payload: Dictionary)
signal on_skill_e_cast(player: Node2D)
signal on_skill_f_cast(player: Node2D)

@export var player_id: String = ""

@export_group("Common Settings")
@export var dash_vfx_scene: PackedScene 

# 角色配置缓存。装备生效前会先回读该配置，避免叠加污染。
var config: Dictionary = {}

# 基础属性（角色表 + 局外成长）
var max_energy: float = 100.0
var energy_regen: float = 0.5
var max_armor: int = 3
var base_speed: float = 300.0
var pickup_range: float = 150.0

# 主动技能资源消耗
var skill_q_cost: float = 50.0
var skill_e_cost: float = 30.0

# 划线闭合容差
var close_threshold: float = 60.0

# 运行时战斗状态
var energy: float = 0.0
var armor: int = 0
var xp: int = 0
var gold: int = 0
var blood_shield: float = 0.0
var max_blood_shield: float = 0.0
var move_dir: Vector2 = Vector2.ZERO
var external_force: Vector2 = Vector2.ZERO
var external_force_decay: float = 50.0
var knockback_scale: float = 0.3
var reduction_per_armor: float = 0.2
var player_hit_cooldown: float = 0.12
var _player_hit_cooldown_timer: float = 0.0
var _temporary_armor_stacks: Array[float] = []
var _control_lock_timer: float = 0.0

@export_group("Tactical Reject")
@export var tactical_reject_enabled: bool = true
@export var tactical_reject_energy_cost: float = 15.0
@export var tactical_reject_cooldown: float = 4.0
@export var tactical_reject_radius: float = 150.0
@export var tactical_reject_push_distance: float = 150.0
@export var tactical_reject_stun_duration: float = 0.5
@export var tactical_reject_visual_duration: float = 0.18

var _tactical_reject_cooldown_remaining: float = 0.0

# 核心节点引用
@onready var collision: CollisionShape2D = $CollisionShape2D
@onready var weapon_container: WeaponContainer = $WeaponContainer if has_node("WeaponContainer") else null

# 武器/技能运行时引用
var current_weapons: Array[Weapon] = []

var ultimate_skill: SkillUltimate = null

var energy_bar_ui: Control = null

# 角色切换后恢复技能冷却用的暂存快照
var _pending_skill_cooldowns: Dictionary = {}
var _pending_bench_elapsed: float = 0.0
var _pending_bench_multiplier: float = 1.0


# 装备词条与当前已装备道具
var modifier_manager: Node = null
var combat_modifier_component: CombatModifierComponent = null

var equipped_item_id: String = "" 

# 危险血线提示阈值（35% / 20% / 10%）
const DANGER_THRESHOLD_LV1: float = 0.35
const DANGER_THRESHOLD_LV2: float = 0.20
const DANGER_THRESHOLD_LV3: float = 0.10
var _danger_warned_lv1: bool = false
var _danger_warned_lv2: bool = false
var _danger_warned_lv3: bool = false

func _ready() -> void:
	_ensure_combat_modifier_component()
	# 初始化顺序：基础配置 -> 外观 -> 父类构建 -> 道具/武器 -> 信号 -> UI -> 大招 -> 技能管理器

	_load_config_from_csv()
	

	_load_sprite_from_csv()
	
	super._ready()
	

	modifier_manager = ModifierManager
	if not modifier_manager:
		printerr("[PlayerBase] Error: ModifierManager autoload missing")
		return
	

	_load_and_equip_item()
	

	_load_weapons_from_config()
	
	if not is_in_group("player"):
		add_to_group("player")
	

	Global.player = self
	
	if health_component:
		if not health_component.on_unit_died.is_connected(_on_death):
			health_component.on_unit_died.connect(_on_death)
			print("[PlayerBase] death signal connected")
		else:
			print("[PlayerBase] death signal already connected")
		if not health_component.on_health_changed.is_connected(_on_health_changed_for_danger):
			health_component.on_health_changed.connect(_on_health_changed_for_danger)
	else:
		printerr("[PlayerBase] Error: health_component missing")
	

	energy = max_energy
	armor = max_armor
	_reset_danger_warning_flags()
	update_ui_signals()
	

	_create_energy_bar_ui()
	

	_load_ultimate_skill()
	


	call_deferred("_auto_create_skill_manager")

func _exit_tree() -> void:
	_force_deactivate_ultimate_on_exit()

	_cancel_active_planning_skills(false)
	Engine.time_scale = 1.0


func _force_deactivate_ultimate_on_exit() -> void:
	if has_meta("preserve_f_runtime_on_exit") and bool(get_meta("preserve_f_runtime_on_exit")):
		return
	if not ultimate_skill or not is_instance_valid(ultimate_skill):
		return
	if ultimate_skill.has_method("deactivate"):
		ultimate_skill.deactivate()

func _load_config_from_csv() -> void:
	# 从角色 CSV 与全局配置读取基础数值，并叠加局外成长属性。
	if player_id.is_empty():
		printerr("[PlayerBase] Warning: player_id is empty, using defaults")
		return
	
	config = ConfigManager.get_player_config(player_id)
	
	if config.is_empty():
		printerr("[PlayerBase] Warning: config '%s' not found, using defaults" % player_id)
		return
	

	max_energy = config.get("max_energy", 100.0)
	energy_regen = config.get("energy_regen", 0.5)
	max_armor = config.get("max_armor", 3)
	base_speed = config.get("base_speed", 300.0)
	

	skill_q_cost = config.get("skill_q_cost", 50.0)
	skill_e_cost = config.get("skill_e_cost", 30.0)
	

	close_threshold = config.get("close_threshold", 60.0)
	external_force_decay = config.get("external_force_decay", 50.0)
	knockback_scale = config.get("knockback_scale", 0.3)
	

	reduction_per_armor = ConfigManager.get_game_setting("armor_reduction_per_level", 0.2)
	player_hit_cooldown = ConfigManager.get_game_setting("player_hit_cooldown", 0.12)
	
	var initial_energy = config.get("initial_energy", max_energy)
	energy = initial_energy
	
	var csv_health = config.get("health", 100.0)
	var csv_speed = config.get("base_speed", 300.0)
	
	health = csv_health
	speed = csv_speed
	base_speed = csv_speed

	var player_speed_scale: float = ConfigManager.get_game_setting("player_speed_scale", 1.0)
	if player_speed_scale > 0.0:
		speed *= player_speed_scale
		base_speed *= player_speed_scale
	
	if DataManager:
		var hp_bonus = DataManager.get_attribute_bonus(player_id, "hp")
		var energy_bonus = DataManager.get_attribute_bonus(player_id, "max_energy")
		var regen_bonus = DataManager.get_attribute_bonus(player_id, "energy_regen")
		var speed_bonus = DataManager.get_attribute_bonus(player_id, "base_speed")
		var armor_bonus = DataManager.get_attribute_bonus(player_id, "max_armor")
		
		if hp_bonus > 0:
			health += hp_bonus
			print("[PlayerBase] Upgrade HP: +%.0f -> %.0f" % [hp_bonus, health])
		if energy_bonus > 0:
			max_energy += energy_bonus
			print("[PlayerBase] Upgrade MaxEnergy: +%.0f -> %.0f" % [energy_bonus, max_energy])
		if regen_bonus > 0:
			energy_regen += regen_bonus
			print("[PlayerBase] Upgrade EnergyRegen: +%.1f -> %.1f" % [regen_bonus, energy_regen])
		if speed_bonus > 0:
			speed += speed_bonus
			base_speed += speed_bonus
			print("[PlayerBase] Upgrade Speed: +%.0f -> %.0f" % [speed_bonus, speed])
		if armor_bonus > 0:
			max_armor += int(armor_bonus)
			print("[PlayerBase] Upgrade Armor: +%d -> %d" % [int(armor_bonus), max_armor])
	

	block_chance = 0.0

func apply_bond_stat_modifiers() -> void:
	"""Apply BondManager stat modifiers to this player's runtime stats."""
	if not BondManager:
		return
	
	var stats = {
		"max_health": health,
		"max_energy": max_energy,
		"speed": speed,
		"energy_regen": energy_regen,
		"pickup_range": pickup_range,
		"damage": damage,
		"max_armor": max_armor,
	}
	
	var modified = BondManager.apply_stat_modifiers(stats)
	
	var old_health = health
	var old_max_energy = max_energy
	health = modified.get("max_health", health)
	max_energy = modified.get("max_energy", max_energy)
	speed = modified.get("speed", speed)
	energy_regen = modified.get("energy_regen", energy_regen)
	pickup_range = modified.get("pickup_range", pickup_range)
	damage = modified.get("damage", damage)
	max_armor = int(round(modified.get("max_armor", max_armor)))
	
	if health_component:
		if abs(health - health_component.max_health) > 0.01:
			health_component.setup_with_health(health)
	if old_max_energy != max_energy:
		energy = min(energy, max_energy)
		max_blood_shield = max(max_blood_shield, health * 0.5)
	armor = min(armor, max_armor)
	
	if OS.is_debug_build():
		print("[PlayerBase] Bond stat modifiers applied:")
		print("  HP: %.0f -> %.0f" % [old_health, health])
		print("  MaxEnergy: %.0f -> %.0f" % [old_max_energy, max_energy])
		print("  Speed: %.0f" % speed)
		print("  EnergyRegen: %.1f" % energy_regen)
		print("  PickupRange: %.0f" % pickup_range)
		print("  Damage: %.0f" % damage)

func _load_sprite_from_csv() -> void:
	"""Load sprite from player visual config and override scene default texture."""
	if player_id.is_empty():
		return
	
	var visual_config = ConfigManager.get_player_visual(player_id)
	if visual_config.is_empty():
		return
	
	var sprite_path = visual_config.get("sprite_path", "")
	if sprite_path == "":
		return
	
	var sprite_node = null
	if has_node("Visuals/Sprite"):
		sprite_node = get_node("Visuals/Sprite")
	elif visuals and visuals.has_node("Sprite"):
		sprite_node = visuals.get_node("Sprite")
	
	if not sprite_node:
		return
	
	var texture = load(sprite_path) as Texture2D
	if texture:
		sprite_node.texture = texture
	else:
		printerr("[PlayerBase] Error: failed to load sprite texture: %s" % sprite_path)

func _load_weapons_from_config() -> void:
	for weapon in current_weapons:
		if is_instance_valid(weapon):
			weapon.queue_free()
	current_weapons.clear()

	if player_id.strip_edges().is_empty():
		push_warning("[PlayerBase] skip weapon load: empty player_id")
		return

	var weapon_type: String = ""
	if Global != null:
		weapon_type = str(Global.selected_player_weapons.get(player_id, "")).strip_edges()

	if weapon_type.is_empty():
		var available_weapon_types: Array[String] = ConfigManager.get_player_available_weapon_types(player_id)
		if not available_weapon_types.is_empty():
			weapon_type = available_weapon_types[0]

	if weapon_type.is_empty():
		push_warning("[PlayerBase] no weapon configured for player: %s" % player_id)
		return

	var weapon_id: String = "%s_1" % weapon_type
	var weapon_data: ItemWeapon = _create_item_weapon_from_csv(weapon_id)
	if weapon_data == null:
		printerr("[PlayerBase] failed to create weapon from csv: %s" % weapon_id)
		return

	_add_weapon(weapon_data)
	print("[PlayerBase] equipped runtime weapon: %s -> %s" % [player_id, weapon_id])

func _create_item_weapon_from_csv(weapon_id: String) -> ItemWeapon:
	"""Create ItemWeapon instance from CSV config."""
	return ItemWeapon.create_from_csv(weapon_id)

func _add_weapon(data: ItemWeapon) -> void:
	"""Add weapon to player."""
	if not data:
		printerr("[Player] Error: weapon data is null")
		return
	
	if not data.scene:
		printerr("[Player] Error: weapon scene is null - weapon_id: ", data.weapon_id)
		printerr("[Player] Scene path: ", data.stats.base_scene_path if data.stats else "stats is null")
		return
	
	var weapon := data.scene.instantiate() as Weapon
	if not weapon:
		printerr("[Player] Error: failed to instantiate weapon scene - weapon_id: ", data.weapon_id)
		return
	
	print("[Player] weapon added: ", data.item_name, " (", data.weapon_id, ")")
	
	add_child(weapon)
	
	print("[Player] weapon node added to scene")
	print("[Player] weapon position: ", weapon.position)
	print("[Player] weapon global position: ", weapon.global_position)
	print("[Player] weapon visible: ", weapon.visible)
	print("[Player] weapon z_index: ", weapon.z_index)
	

	weapon.setup_weapon(data)
	current_weapons.append(weapon)
	
	if weapon_container:
		weapon_container.update_weapons_position(current_weapons)
		print("[Player] weapon position after layout: ", weapon.position)
		print("[Player] weapon global position after layout: ", weapon.global_position)


func _load_and_equip_item() -> void:
	# 按 EquipmentManager 的装备记录，在角色生成时恢复道具效果。
	if not EquipmentManager:
		return
	
	var item_type = EquipmentManager.get_equipped_item(player_id)
	if item_type <= 0:
		if OS.is_debug_build():
			print("[PlayerBase] player %s has no equipped item" % player_id)
		return
	
	var item_id = WarehouseManager.get_item_id_from_type(item_type)
	if item_id != "":
		equip_item(item_id)

func equip_item(item_id: String) -> void:
	# 装备前重置到角色基线配置，再按道具 tier 应用，避免重复叠加。
	if item_id.is_empty():
		return
	
	var item_data = ConfigManager.get_item_config_by_id(item_id)
	if item_data.is_empty():
		printerr("[PlayerBase] Error: item config not found '%s'" % item_id)
		return
	
	var tier = int(item_data.get("tier", 1))
	
	if OS.is_debug_build():
		print("[PlayerBase] equip item: %s (Tier %d)" % [item_data.get("name", item_id), tier])
	

	_load_config_from_csv()
	
	match tier:
		1:
			_apply_tier1_item(item_data)
		2:
			_apply_tier2_item(item_data)
		3:
			_apply_tier3_item(item_data)
		_:
			printerr("[PlayerBase] Error: unknown item tier %d" % tier)
	

	equipped_item_id = item_id

func _apply_tier1_item(item_data: Dictionary) -> void:
	var stat_name = str(item_data.get("base_stat", "")).strip_edges()
	var value = float(item_data.get("base_value", 0.0))
	
	if stat_name.is_empty() or value == 0.0:
		printerr("[PlayerBase] Error: Tier 1 item missing base_stat or base_value")
		return
	
	_apply_base_stat(stat_name, value)

func _apply_tier2_item(item_data: Dictionary) -> void:
	var stat_name = str(item_data.get("base_stat", "")).strip_edges()
	var base_value = float(item_data.get("base_value", 0.0))
	if not stat_name.is_empty() and base_value != 0.0:
		_apply_base_stat(stat_name, base_value)
	
	if not modifier_manager:
		printerr("[PlayerBase] Error: ModifierManager not initialized")
		return
	
	var modifiers = item_data.get("modifiers", [])
	for mod in modifiers:
		var mod_type = str(mod.get("type", ""))
		var mod_value = float(mod.get("value", 0.0))
		if not mod_type.is_empty():
			modifier_manager.add_modifier([mod_type], "percent", mod_value)
			if OS.is_debug_build():
				print("[PlayerBase] add modifier: type=%s, value=%.2f" % [mod_type, mod_value])

func _apply_tier3_item(item_data: Dictionary) -> void:
	var stat_name = str(item_data.get("base_stat", "")).strip_edges()
	var base_value = float(item_data.get("base_value", 0.0))
	if not stat_name.is_empty() and base_value != 0.0:
		_apply_base_stat(stat_name, base_value)
	
	if modifier_manager:
		var modifiers = item_data.get("modifiers", [])
		for mod in modifiers:
			var mod_type = str(mod.get("type", ""))
			var mod_value = float(mod.get("value", 0.0))
			if not mod_type.is_empty():
				modifier_manager.add_modifier([mod_type], "percent", mod_value)
				if OS.is_debug_build():
					print("[PlayerBase] T3 modifier: type=%s, value=%.2f" % [mod_type, mod_value])
	
	var bond_grant = str(item_data.get("bond_grant", "")).strip_edges()
	if not bond_grant.is_empty():
		if OS.is_debug_build():
			print("[PlayerBase] T3 register bond_grant tag: '%s'" % bond_grant)

func get_equipped_relic_tags() -> Dictionary:
	if equipped_item_id.is_empty():
		return {}
	
	var item_data = ConfigManager.get_item_config_by_id(equipped_item_id)
	if item_data.is_empty():
		return {}
	
	var tier = int(item_data.get("tier", 1))
	if tier != 3:
		return {}
	
	var bond_grant = str(item_data.get("bond_grant", "")).strip_edges()
	if bond_grant.is_empty():
		return {}
	
	return {bond_grant: 1}

func _apply_base_stat(stat_name: String, value: float) -> void:
	match stat_name:
		"hp", "health":
			health += value
			if OS.is_debug_build():
				print("[PlayerBase] HP +%.0f -> %.0f" % [value, health])
		"speed":
			speed += value
			if OS.is_debug_build():
				print("[PlayerBase] Speed +%.0f -> %.0f" % [value, speed])
		"attack", "damage":
			damage += value
			if OS.is_debug_build():
				print("[PlayerBase] Damage +%.0f -> %.0f" % [value, damage])
		"energy":
			energy = min(energy + value, max_energy)
			if OS.is_debug_build():
				print("[PlayerBase] Energy +%.0f -> %.0f" % [value, energy])
		_:
			printerr("[PlayerBase] Warning: unknown stat name '%s'" % stat_name)

func apply_consumable_effect(config: Dictionary) -> void:
	var stat_name = str(config.get("base_stat", "")).strip_edges()
	var value = float(config.get("base_value", 0.0))
	
	if stat_name.is_empty() or value == 0.0:
		printerr("[PlayerBase] Invalid consumable config: missing base_stat or base_value")
		return
	
	match stat_name:
		"hp", "health":
			if health_component:
				health_component.heal(value)
				Global.spawn_floating_text(global_position, "+%d HP" % int(value), Color.GREEN)
				if OS.is_debug_build():
					print("[PlayerBase] consumable: heal %.0f HP" % value)
		"energy":
			energy = min(energy + value, max_energy)
			update_ui_signals()
			Global.spawn_floating_text(global_position, "+%d Energy" % int(value), Color.CYAN)
			if OS.is_debug_build():
				print("[PlayerBase] consumable: restore %.0f Energy" % value)
		_:

			_apply_base_stat(stat_name, value)
			Global.spawn_floating_text(global_position, "+%d %s" % [int(value), stat_name], Color.WHITE)

func get_skill_param(base_value: float, tags: Array) -> float:
	if not modifier_manager:
		return base_value
	
	return modifier_manager.get_modified_value(base_value, tags)

func _process(delta: float) -> void:
	if Global.game_paused: return

	if _player_hit_cooldown_timer > 0.0:
		_player_hit_cooldown_timer = max(0.0, _player_hit_cooldown_timer - delta)
	if _tactical_reject_cooldown_remaining > 0.0:
		_tactical_reject_cooldown_remaining = max(0.0, _tactical_reject_cooldown_remaining - delta)	
	if _control_lock_timer > 0.0:
		_control_lock_timer = max(0.0, _control_lock_timer - delta)
	if energy < max_energy:
		energy += energy_regen * delta
		update_ui_signals()
	_process_temporary_armor_stacks(delta)
	
	if external_force.length() > 1.0:
		position += external_force * delta
		external_force = external_force.lerp(Vector2.ZERO, external_force_decay * delta)
	else:
		external_force = Vector2.ZERO
	
	_handle_input(delta)
	_process_subclass(delta)
	update_rotation()

func _handle_input(delta: float) -> void:
	# 输入优先级：移动 -> 通用保命Q -> E瞬发 -> Space蓄力/释放 -> 普攻 -> F大招。

	move_dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if can_move():
		var current_speed: float = get_effective_move_speed()
		position += move_dir * current_speed * delta

	if Input.is_action_just_pressed("tactical_reject"):
		_try_activate_tactical_reject()

	if has_node("SkillManager"):
		var skill_manager = get_node("SkillManager")
		
		if Input.is_action_just_pressed("skill_e"):
			print("[PlayerBase] E pressed -> execute_skill('e')")
			skill_manager.execute_skill("e")
			notify_front_skill_cast("e", {"source": "base_input"})
			return
		
		if Input.is_action_pressed("click_right"):
			skill_manager.charge_skill("q", delta)
			return
		elif Input.is_action_just_released("click_right"):
			print("[PlayerBase] Q released -> release_skill('q')")
			skill_manager.release_skill("q")
			return
		
		if Input.is_action_just_pressed("click_left"):
			skill_manager.execute_skill("lmb")
			return
	
	if Input.is_action_just_pressed("skill_f"):
		print("[PlayerBase] F pressed, ultimate_skill = %s" % str(ultimate_skill))
		if ultimate_skill:
			print("[PlayerBase] try activate ultimate, energy: %.1f%%" % get_energy_percent())
			ultimate_skill.try_activate()
			notify_front_skill_cast("f", {"source": "base_input"})
		else:
			print("[PlayerBase] ultimate is not loaded")

			Global.spawn_floating_text(global_position, "Ultimate not ready", Color.GRAY)

func _try_activate_tactical_reject() -> bool:
	if not tactical_reject_enabled:
		return false
	if has_meta("buff_invincible"):
		return false
	if _tactical_reject_cooldown_remaining > 0.0:
		Global.spawn_floating_text(global_position, "CD", Color(0.9, 0.8, 0.4))
		SoundManager.play("ui_error")
		return false
	if not consume_energy(tactical_reject_energy_cost):
		return false
	_tactical_reject_cooldown_remaining = tactical_reject_cooldown
	_execute_tactical_reject()
	return true

func _execute_tactical_reject() -> void:
	var pushed_enemy_count: int = 0
	var interrupted_enemy_count: int = 0
	var destroyed_projectile_count: int = 0

	for enemy_node in get_tree().get_nodes_in_group("enemies"):
		if not (enemy_node is Enemy):
			continue
		var enemy: Enemy = enemy_node as Enemy
		if not is_instance_valid(enemy) or enemy.is_dead:
			continue
		if enemy.global_position.distance_to(global_position) > tactical_reject_radius:
			continue
		if enemy.has_method("apply_tactical_reject"):
			var raw_result: Variant = enemy.call("apply_tactical_reject", global_position, tactical_reject_push_distance, tactical_reject_stun_duration)
			if raw_result is Dictionary:
				var result: Dictionary = raw_result
				if bool(result.get("pushed", false)):
					pushed_enemy_count += 1
				if bool(result.get("interrupted", false)):
					interrupted_enemy_count += 1

	var cleared_projectile_ids: Dictionary = {}
	for group_name: String in ["elite_projectiles", "projectiles"]:
		for projectile_node in get_tree().get_nodes_in_group(group_name):
			if not is_instance_valid(projectile_node) or projectile_node.is_queued_for_deletion():
				continue
			var projectile_id: int = projectile_node.get_instance_id()
			if cleared_projectile_ids.has(projectile_id):
				continue
			if not _is_enemy_projectile(projectile_node):
				continue
			if projectile_node is Node2D and (projectile_node as Node2D).global_position.distance_to(global_position) <= tactical_reject_radius:
				cleared_projectile_ids[projectile_id] = true
				projectile_node.queue_free()
				destroyed_projectile_count += 1

	_spawn_tactical_reject_vfx()
	Global.on_camera_shake.emit(4.0, 0.08)
	SoundManager.play("skill_e_instant")
	var label: String = "DENY"
	if destroyed_projectile_count > 0:
		label = "DENY x%d" % destroyed_projectile_count
	Global.spawn_floating_text(global_position, label, Color(0.72, 0.95, 1.0))
	if interrupted_enemy_count > 0 and interrupted_enemy_count >= pushed_enemy_count:
		Global.spawn_floating_text(global_position + Vector2(0, -24), "BREAK", Color(1.0, 0.9, 0.72))

func _is_enemy_projectile(node: Node) -> bool:
	if node.is_in_group("elite_projectiles"):
		return true
	if node is Projectile:
		var projectile: Projectile = node as Projectile
		if is_instance_valid(projectile.owner_unit) and projectile.owner_unit.is_in_group("enemies"):
			return true
		if projectile.hitbox != null and int(projectile.hitbox.collision_layer) == 64:
			return true
	return false

func _spawn_tactical_reject_vfx() -> void:
	var root: Node2D = Node2D.new()
	root.top_level = true
	root.global_position = global_position
	root.z_index = 90
	get_tree().current_scene.add_child(root)

	var outer_ring: Line2D = Line2D.new()
	outer_ring.top_level = true
	outer_ring.closed = true
	outer_ring.width = 14.0
	outer_ring.default_color = Color(0.58, 0.92, 1.0, 0.95)
	outer_ring.antialiased = true
	outer_ring.z_index = 90
	root.add_child(outer_ring)

	var inner_ring: Line2D = Line2D.new()
	inner_ring.top_level = true
	inner_ring.closed = true
	inner_ring.width = 34.0
	inner_ring.default_color = Color(0.72, 0.95, 1.0, 0.22)
	inner_ring.antialiased = true
	inner_ring.z_index = 89
	root.add_child(inner_ring)

	var points: PackedVector2Array = PackedVector2Array()
	for i in range(25):
		var angle: float = (float(i) / 24.0) * TAU
		points.append(global_position + Vector2.RIGHT.rotated(angle) * tactical_reject_radius)
	outer_ring.points = points
	inner_ring.points = points
	outer_ring.scale = Vector2(0.25, 0.25)
	inner_ring.scale = Vector2(0.2, 0.2)

	var tween: Tween = root.create_tween()
	tween.set_parallel(true)
	tween.tween_property(outer_ring, "scale", Vector2.ONE, tactical_reject_visual_duration)
	tween.tween_property(inner_ring, "scale", Vector2.ONE, tactical_reject_visual_duration)
	tween.tween_property(outer_ring, "modulate:a", 0.0, tactical_reject_visual_duration)
	tween.tween_property(inner_ring, "modulate:a", 0.0, tactical_reject_visual_duration)
	tween.finished.connect(root.queue_free)

func can_move() -> bool:
	return _control_lock_timer <= 0.0

func apply_control_lock(duration: float, feedback_text: String = "") -> void:
	if duration <= 0.0:
		return
	_control_lock_timer = max(_control_lock_timer, duration)
	external_force = Vector2.ZERO
	if not feedback_text.is_empty():
		Global.spawn_floating_text(global_position, feedback_text, Color(1.0, 0.74, 0.38))

func get_modified_dash_direction(requested_direction: Vector2) -> Vector2:
	var final_direction: Vector2 = requested_direction.normalized()
	if final_direction.length_squared() <= 0.0001:
		final_direction = Vector2.RIGHT if is_facing_right() else Vector2.LEFT
	for enemy_node: Node in get_tree().get_nodes_in_group("enemies"):
		if enemy_node == null or not is_instance_valid(enemy_node):
			continue
		if not enemy_node.has_method("modify_player_dash_direction"):
			continue
		var result: Variant = enemy_node.call("modify_player_dash_direction", self, final_direction)
		if not (result is Dictionary):
			continue
		var result_dict: Dictionary = result
		var direction_variant: Variant = result_dict.get("direction", final_direction)
		if direction_variant is Vector2:
			var new_direction: Vector2 = (direction_variant as Vector2).normalized()
			if new_direction.length_squared() > 0.0001:
				final_direction = new_direction
	return final_direction

func _ensure_combat_modifier_component() -> void:
	if combat_modifier_component and is_instance_valid(combat_modifier_component):
		return
	combat_modifier_component = get_node_or_null("CombatModifierComponent") as CombatModifierComponent
	if combat_modifier_component == null:
		combat_modifier_component = COMBAT_MODIFIER_COMPONENT.new()
		combat_modifier_component.name = "CombatModifierComponent"
		add_child(combat_modifier_component)

func get_effective_move_speed() -> float:
	var current_speed: float = speed
	if has_meta("buff_speed_boost"):
		current_speed *= (1.0 + float(get_meta("buff_speed_boost")))
	if combat_modifier_component:
		current_speed *= combat_modifier_component.get_move_speed_multiplier()
	return current_speed

func get_incoming_damage_multiplier() -> float:
	if combat_modifier_component:
		return combat_modifier_component.get_damage_taken_multiplier()
	return 1.0

func apply_modifier_damage(raw_amount: float, _source: Variant = null, _payload: Dictionary = {}) -> void:
	var payload: Dictionary = _payload.duplicate(true)
	if _source != null and not payload.has("source"):
		payload["source"] = _source
	take_damage(raw_amount, payload)

func apply_move_speed_modifier(modifier_id: String, multiplier: float, duration: float, stacking_rule: String = CombatModifierComponent.STACK_REFRESH, source: Variant = null, payload: Dictionary = {}) -> String:
	_ensure_combat_modifier_component()
	return combat_modifier_component.apply_move_speed_multiplier(modifier_id, multiplier, duration, stacking_rule, source, payload)

func apply_damage_over_time_modifier(modifier_id: String, damage_per_tick: float, duration: float, tick_interval: float, stacking_rule: String = CombatModifierComponent.STACK_REFRESH, source: Variant = null, payload: Dictionary = {}) -> String:
	_ensure_combat_modifier_component()
	return combat_modifier_component.apply_damage_over_time(modifier_id, damage_per_tick, duration, tick_interval, stacking_rule, source, payload)

func apply_vulnerable_modifier(modifier_id: String, multiplier: float, duration: float, stacking_rule: String = CombatModifierComponent.STACK_REFRESH, source: Variant = null, payload: Dictionary = {}) -> String:
	_ensure_combat_modifier_component()
	return combat_modifier_component.apply_vulnerable(modifier_id, multiplier, duration, stacking_rule, source, payload)

func apply_tag_marker(modifier_id: String, tag_name: String, duration: float, stacking_rule: String = CombatModifierComponent.STACK_REFRESH, source: Variant = null, payload: Dictionary = {}) -> String:
	_ensure_combat_modifier_component()
	return combat_modifier_component.apply_tag_marker(modifier_id, tag_name, duration, stacking_rule, source, payload)

func get_abnormal_state_count() -> int:
	var abnormal_states: Dictionary = {}
	if combat_modifier_component != null:
		for marker_name: String in combat_modifier_component.get_tag_markers():
			if marker_name == "joule_tar" or marker_name == "joule_tar_max":
				abnormal_states["tar_debuff"] = true
		for modifier_data: Dictionary in combat_modifier_component.get_modifiers_by_type("move_speed_multiplier"):
			if float(modifier_data.get("value", 1.0)) < 1.0:
				abnormal_states["slow"] = true
		if not combat_modifier_component.get_modifiers_by_type("vulnerable").is_empty():
			abnormal_states["vulnerable"] = true
		for modifier_data: Dictionary in combat_modifier_component.get_modifiers_by_type("damage_over_time"):
			var modifier_payload: Dictionary = modifier_data.get("payload", {})
			var abnormal_key: String = str(modifier_payload.get("abnormal_state", modifier_payload.get("status_name", ""))).strip_edges().to_lower()
			if abnormal_key in ["poison", "bleed"]:
				abnormal_states[abnormal_key] = true
	return abnormal_states.size()

func has_mechanic_mark(mark_name: String) -> bool:
	var normalized_mark: String = mark_name.strip_edges().to_lower()
	if normalized_mark.is_empty() or combat_modifier_component == null:
		return false
	if normalized_mark == "mark":
		return combat_modifier_component.has_tag_marker("mark") or combat_modifier_component.has_tag_marker("overtone_echo")
	if normalized_mark == "soul_link":
		return combat_modifier_component.has_tag_marker("soul_link") or combat_modifier_component.has_tag_marker("soul_link_empowered")
	return combat_modifier_component.has_tag_marker(normalized_mark)

func _process_subclass(delta: float) -> void: 
	pass

func _on_hurtbox_component_on_damaged(hitbox: HitboxComponent) -> void:
	if not health_component or health_component.current_health <= 0:
		return
	if not hitbox:
		return
	if Global.has_meta("skill_synergy_test_no_damage") and bool(Global.get_meta("skill_synergy_test_no_damage")):
		return

	if has_meta("buff_invincible"):
		Global.on_create_block_text.emit(self)
		return

	if _player_hit_cooldown_timer > 0.0:
		return

	var blocked := Global.get_chance_sucess(block_chance / 100.0)
	if blocked:
		Global.on_create_block_text.emit(self)
		return

	var pre_hit_payload: Dictionary = {
		"damage": float(hitbox.damage),
		"source": hitbox.source,
		"hitbox": hitbox,
		"kind": "hurtbox",
		"knockback_power": float(hitbox.knockback_power),
		"damage_type": int(hitbox.damage_type),
		"is_shared_damage": bool(hitbox.is_shared_damage),
	}
	var pre_hit_result: Dictionary = _evaluate_pre_hit_veto(pre_hit_payload)
	if bool(pre_hit_result.get("cancel", false)):
		Global.on_create_block_text.emit(self)
		return

	set_flash_material()
	var damage_applied: bool = take_damage(hitbox.damage, {
		"skip_pre_hit_veto": true,
		"source": hitbox.source,
		"kind": "hurtbox",
		"hitbox": hitbox,
		"damage_type": int(hitbox.damage_type),
		"is_shared_damage": bool(hitbox.is_shared_damage),
	})
	if not damage_applied:
		return
	_player_hit_cooldown_timer = player_hit_cooldown

	if hitbox.knockback_power > 0.0 and hitbox.source and is_instance_valid(hitbox.source):
		var knock_dir := hitbox.source.global_position.direction_to(global_position)
		apply_knockback_self(knock_dir * hitbox.knockback_power)

func take_damage(raw_amount: float, payload: Dictionary = {}) -> bool:
	if Global.has_meta("skill_synergy_test_no_damage") and bool(Global.get_meta("skill_synergy_test_no_damage")):
		return false
	if not bool(payload.get("skip_pre_hit_veto", false)):
		var pre_hit_payload: Dictionary = payload.duplicate(true)
		pre_hit_payload["damage"] = float(raw_amount)
		var pre_hit_result: Dictionary = _evaluate_pre_hit_veto(pre_hit_payload)
		if bool(pre_hit_result.get("cancel", false)):
			Global.on_create_block_text.emit(self)
			return false
	# 伤害流程：护甲减伤 -> 护甲层消耗/破甲反馈 -> 扣血 -> 被动反制触发。
	var incoming_multiplier: float = get_incoming_damage_multiplier()
	var damage_multiplier: float = 1.0 - (clamp(armor, 0, max_armor) * reduction_per_armor)
	var final_damage: float = max(1.0, raw_amount * incoming_multiplier * damage_multiplier)
	
	print("[PlayerBase] take_damage: raw=%d, final=%d, current_hp=%d" % [int(round(raw_amount)), int(round(final_damage)), health_component.current_health])
	

	SoundManager.play("player_hurt")
	
	if armor > 0:
		armor -= 1
		if armor == 0:
			SoundManager.play("player_armor_break")
		Global.spawn_floating_text(global_position, "Armor Crack!", Color.YELLOW)
		armor_changed.emit(armor)

		Global.on_camera_shake.emit(4.0, 0.1)
		Global.frame_freeze(0.03, 0.2)
	else:
		Global.spawn_floating_text(global_position, "-%d" % final_damage, Color.RED)

		Global.on_camera_shake.emit(10.0, 0.25)
		Global.frame_freeze(0.08, 0.15)
	
	var health_payload: Dictionary = payload.duplicate(true)
	health_payload["damage_type"] = COMBAT_EVENT_TYPES.normalize_damage_type(
		health_payload.get("damage_type", COMBAT_EVENT_TYPES.DamageType.DIRECT)
	)
	health_payload["is_shared_damage"] = bool(health_payload.get("is_shared_damage", false))
	health_component.take_damage(final_damage, health_payload)
	if BondManager != null and BondManager.has_method("on_player_took_damage"):
		BondManager.on_player_took_damage(self, final_damage, health_payload)
	
	if BondManager.has_mechanic("soul_attach") or BondManager.has_mechanic("dual_order"):
		_trigger_soul_attach_on_hit()
	
	print("[PlayerBase] hp after damage=%d" % health_component.current_health)
	return true

func _evaluate_pre_hit_veto(payload: Dictionary) -> Dictionary:
	var normalized_payload: Dictionary = payload.duplicate(true)
	pre_hit_veto_requested.emit(normalized_payload)
	var local_result: Dictionary = on_pre_hit_check(normalized_payload)
	if bool(local_result.get("cancel", false)):
		return local_result
	var assist_service: Node = get_node_or_null("/root/AssistRuntimeService")
	if assist_service != null and assist_service.has_method("on_front_pre_hit"):
		var assist_result: Variant = assist_service.call("on_front_pre_hit", self, normalized_payload)
		if assist_result is Dictionary and bool((assist_result as Dictionary).get("cancel", false)):
			return assist_result
	return {"cancel": false}

func on_pre_hit_check(_payload: Dictionary) -> Dictionary:
	return {"cancel": false}

func _cancel_active_planning_skills(refund_energy: bool = false) -> void:
	var sm = get_node_or_null("SkillManager")
	if sm and sm.has_method("force_cancel_planning_skills"):
		sm.call("force_cancel_planning_skills", refund_energy)

func _on_health_changed_for_danger(current: float, max_val: float) -> void:
	"""Low HP warning at 35% / 20% / 10%, trigger once per threshold."""
	if Global.is_game_over:
		return
	if max_val <= 0:
		return

	if current <= 0:
		return

	var ratio := current / max_val
	_refresh_danger_warning_reset(ratio)

	if ratio <= DANGER_THRESHOLD_LV3 and not _danger_warned_lv3:
		_trigger_health_danger_warning(3, ratio, current, max_val)
	elif ratio <= DANGER_THRESHOLD_LV2 and not _danger_warned_lv2:
		_trigger_health_danger_warning(2, ratio, current, max_val)
	elif ratio <= DANGER_THRESHOLD_LV1 and not _danger_warned_lv1:
		_trigger_health_danger_warning(1, ratio, current, max_val)

func _refresh_danger_warning_reset(ratio: float) -> void:
	"""Reset warning flags when HP recovers above thresholds."""
	if ratio > DANGER_THRESHOLD_LV1:
		if _danger_warned_lv1 or _danger_warned_lv2 or _danger_warned_lv3:
			_notify_hud_health_safe()
		_reset_danger_warning_flags()
		return

	if ratio > DANGER_THRESHOLD_LV2:
		_danger_warned_lv2 = false
		_danger_warned_lv3 = false
		return

	if ratio > DANGER_THRESHOLD_LV3:
		_danger_warned_lv3 = false

func _reset_danger_warning_flags() -> void:
	_danger_warned_lv1 = false
	_danger_warned_lv2 = false
	_danger_warned_lv3 = false

func _trigger_health_danger_warning(level: int, ratio: float, current: float, max_val: float) -> void:
	"""Trigger low HP feedback chain (sfx, shake, freeze, text, HUD)."""
	match level:
		1:
			_danger_warned_lv1 = true
			SoundManager.play("player_energy_low")
			Global.on_camera_shake.emit(6.0, 0.10)
			Global.frame_freeze(0.02, 0.20)
			Global.spawn_floating_text(global_position, "Warning: HP low 35%", Color(1.2, 0.8, 0.2))
			_play_danger_flash(Color(1.15, 0.75, 0.75))
		2:
			_danger_warned_lv2 = true
			SoundManager.play("player_energy_low")
			SoundManager.play("ui_error")
			Global.on_camera_shake.emit(8.0, 0.14)
			Global.frame_freeze(0.03, 0.18)
			Global.spawn_floating_text(global_position, "Danger: HP very low 20%", Color(1.4, 0.45, 0.2))
			_play_danger_flash(Color(1.30, 0.60, 0.60))
		3:
			_danger_warned_lv3 = true
			SoundManager.play("ui_error")
			Global.on_camera_shake.emit(10.0, 0.20)
			Global.frame_freeze(0.05, 0.15)
			Global.spawn_floating_text(global_position, "Critical: HP only 10%", Color(1.8, 0.20, 0.20))
			_play_danger_flash(Color(1.55, 0.45, 0.45))

	_notify_hud_health_danger(level, current, max_val, ratio)

func _play_danger_flash(tint: Color) -> void:
	if not visuals:
		return
	var original = visuals.modulate
	var tween = create_tween()
	tween.tween_property(visuals, "modulate", tint, 0.06)
	tween.tween_property(visuals, "modulate", original, 0.16)

func _notify_hud_health_danger(level: int, current: float, max_val: float, ratio: float) -> void:
	var arena = get_tree().get_first_node_in_group("arena")
	if not arena or not (arena is Arena):
		return
	var hud = (arena as Arena).global_hud
	if hud and hud.has_method("show_health_danger"):
		hud.show_health_danger(level, current, max_val, ratio)

func _notify_hud_health_safe() -> void:
	var arena = get_tree().get_first_node_in_group("arena")
	if not arena or not (arena is Arena):
		return
	var hud = (arena as Arena).global_hud
	if hud and hud.has_method("clear_health_danger"):
		hud.clear_health_danger()

func _trigger_soul_attach_on_hit() -> void:
	"""Trigger soul-attach counter effect when player takes damage."""
	var attach_damage_scale: float = BondManager.get_mechanic_value("soul_attach")
	var dual_order_level: float = 0.0
	if BondManager.has_mechanic("dual_order"):
		dual_order_level = max(0.0, BondManager.get_mechanic_value("dual_order"))

	if attach_damage_scale <= 0.0 and dual_order_level > 0.0:

		attach_damage_scale = 0.25

		attach_damage_scale *= (1.0 + 0.5 * dual_order_level)
	if attach_damage_scale <= 0:
		return
	
	var attach_damage = int(damage * attach_damage_scale)
	
	print("[PlayerBase] [P4-4] soul_attach triggered: counter_damage=%d (%.0f%% ATK)" % [
		attach_damage,
		attach_damage_scale * 100
	])
	
	var attach_radius: float = 150.0 + (30.0 * dual_order_level)
	var enemies = get_tree().get_nodes_in_group("enemies")
	var hit_count = 0
	
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		
		var distance = global_position.distance_to(enemy.global_position)
		if distance <= attach_radius:
			if enemy.has_node("HealthComponent"):
				enemy.get_node("HealthComponent").take_damage(attach_damage, {
					"source": self,
					"kind": "bond_soul_attach",
					"damage_type": "DMG_AOE",
				})
				hit_count += 1
			

			Global.spawn_floating_text(enemy.global_position, "SOUL!", Color(1.5, 0.5, 1.5))
	
	if hit_count > 0:

		SoundManager.play("bond_soul_attach")
		Global.on_camera_shake.emit(5.0, 0.15)
		if dual_order_level > 0.0:
			Global.spawn_floating_text(global_position, "DUAL ORDER!", Color(2.0, 1.0, 0.3))
		else:
			Global.spawn_floating_text(global_position, "SOUL ATTACH!", Color(2.0, 0.5, 2.0))
		print("[PlayerBase] [P4-4] soul attach hit %d enemies" % hit_count)

func apply_knockback_self(force: Vector2) -> void:
	if BondManager != null and BondManager.has_method("is_player_immune_to_knockback") and BondManager.is_player_immune_to_knockback(self):
		Global.spawn_floating_text(global_position, "IMMUNE", Color(0.72, 0.95, 1.0))
		return
	if _is_drawing_active() and BondManager.has_mechanic("super_armor"):
		print("[PlayerBase] [P1-2] super armor triggered, knockback ignored (damage still applied)")
		SoundManager.play("super_armor_trigger")
		Global.spawn_floating_text(global_position, "SUPER ARMOR!", Color.ORANGE)

		Global.on_camera_shake.emit(3.0, 0.08)
		return
	

	external_force = force * knockback_scale
	Global.on_camera_shake.emit(5.0, 0.1)

func consume_energy(amount: float) -> bool:
	if _is_skill_synergy_test_no_cost_mode():
		return true

	if BondManager != null and BondManager.has_method("consume_player_energy"):
		var result: Variant = BondManager.consume_player_energy(self, amount)
		if result is bool and bool(result):
			update_ui_signals()
			return true
	if energy >= amount:
		energy -= amount
		update_ui_signals()
		return true
	SoundManager.play("player_energy_low")
	Global.spawn_floating_text(global_position, "No Energy!", Color.RED)
	return false

func gain_energy(amount: float) -> void:
	energy = min(energy + amount, max_energy)
	update_ui_signals()
	SoundManager.play("player_energy_gain")
	Global.spawn_floating_text(global_position, "+%d Energy" % amount, Color.CYAN)

func add_xp(amount: int) -> void:
	var applied_xp := amount
	var progression: Node = get_node_or_null("/root/ProgressionManager")
	if progression and progression.has_method("add_xp"):
		var raw_result: Variant = progression.call("add_xp", amount)
		var result: Dictionary = raw_result if raw_result is Dictionary else {}
		applied_xp = int(result.get("applied_xp", amount))
		xp = int(result.get("total_xp", RunStateService.get_run_xp()))
	else:
		applied_xp = RunStateService.add_run_xp(amount)
		xp = RunStateService.get_run_xp()
	xp_changed.emit(xp)
	if applied_xp > 0:
		Global.spawn_floating_text(global_position + Vector2(20, -10), "+%d XP" % applied_xp, Color.MEDIUM_PURPLE)

func add_gold(amount: int) -> void:
	RunStateService.add_run_gold(amount, true)
	gold = RunStateService.get_run_gold()
	gold_changed.emit(gold)
	Global.spawn_floating_text(global_position + Vector2(-20, -10), "+%d Gold" % amount, Color.GOLD)

func update_ui_signals() -> void:
	energy_changed.emit(energy, max_energy)
	armor_changed.emit(armor)
	
	if energy_bar_ui and energy_bar_ui.has_method("update_bar"):
		var value = energy / max_energy if max_energy > 0 else 0
		energy_bar_ui.update_bar(value, energy)

func _create_energy_bar_ui() -> void:
	pass

func _on_energy_changed_for_ui(current: float, max_val: float) -> void:
	if energy_bar_ui and energy_bar_ui.has_method("_on_player_energy_changed"):
		energy_bar_ui._on_player_energy_changed(current, max_val)

func update_rotation() -> void:
	var facing_dir = get_global_mouse_position() - global_position
	if facing_dir.x != 0:
		visuals.scale.x = -0.5 if facing_dir.x > 0 else 0.5

func is_facing_right() -> bool:
	return visuals.scale.x < 0

func _is_drawing_active() -> bool:
	if not has_node("SkillManager"):
		return false
	
	var skill_manager = get_node("SkillManager")

	if skill_manager.has_method("get_skill"):
		var q_skill = skill_manager.get_skill("q")
		if q_skill and is_instance_valid(q_skill):
			for flag in ["is_planning", "is_drawing", "is_charging"]:
				if flag in q_skill and bool(q_skill.get(flag)):
					return true

	if skill_manager.has_method("get_all_skills"):
		for skill in skill_manager.get_all_skills():
			if skill == null or not is_instance_valid(skill):
				continue
			for flag in ["is_planning", "is_drawing", "is_charging"]:
				if flag in skill and bool(skill.get(flag)):
					return true
	
	return false

func get_speed_damage_bonus() -> float:
	
	
	if not BondManager.has_mechanic("speed_to_damage"):
		return 0.0
	
	var conversion_rate = BondManager.get_mechanic_value("speed_to_damage")
	
	var current_speed: float = get_effective_move_speed()
	var speed_diff: float = current_speed - base_speed
	
	if speed_diff <= 0:
		return 0.0
	
	var bonus = speed_diff * conversion_rate
	
	print("[PlayerBase] [P1-3] speed_to_damage: current=%.0f, base=%.0f, diff=%.0f, ratio=%.4f, bonus=+%.1f%%" % [
		current_speed,
		base_speed,
		speed_diff,
		conversion_rate,
		bonus * 100
	])
	
	return bonus

func _on_death() -> void:
	print("[PlayerBase] ========== PLAYER DIED ==========")
	print("[PlayerBase] current_hp = %d" % health_component.current_health)
	
	SoundManager.play("player_death")
	visuals.visible = false
	var emitter = CPUParticles2D.new()
	emitter.emitting = true
	emitter.one_shot = true
	emitter.amount = 30
	emitter.explosiveness = 1.0
	emitter.gravity = Vector2(0, 800)
	emitter.color = Color.WHITE
	emitter.global_position = global_position
	get_tree().current_scene.add_child(emitter)
	
	collision.set_deferred("disabled", true)
	set_process(false)
	set_physics_process(false)
	
	print("[PlayerBase] set Global.is_game_over = true")
	Global.is_game_over = true
	print("[PlayerBase] requesting pause from PauseService (source=player_death)")
	PauseService.request_pause("player_death", get_tree())
	
	print("[PlayerBase] ========== PLAYER DEATH HANDLED ==========")

func _cleanup_skill_effects() -> void:
	if "skill_manager" in self and self.skill_manager:
		var sm = self.skill_manager as SkillManager
		if sm:
			for skill in sm.get_all_skills():
				if skill and skill.has_method("cleanup"):
					skill.cleanup()


func _load_ultimate_skill() -> void:
	ultimate_skill = null
	print("[PlayerBase] Stage 1 cleanup: legacy ultimate loading disabled")

func _load_ult_config_from_csv(pid: String) -> Dictionary:
	
	return ConfigRepository.get_ult_config_for_player(pid)

func _get_ultimate_script_for_player(pid: String) -> Script:

	var script_path: String = ""
	var role_script_path: String = "res://scenes/skills/players/f_roles/skill_%s_f.gd" % pid
	if FileAccess.file_exists(role_script_path):
		script_path = role_script_path

	if script_path.is_empty():
		script_path = "res://scenes/skills/skill_ultimate_base.gd"
		print("[PlayerBase] role ultimate wrapper missing, fallback to base ultimate: %s" % pid)

	if not FileAccess.file_exists(script_path):
		script_path = "res://scenes/skills/skill_ultimate_base.gd"
		print("[PlayerBase] ultimate script missing, fallback to base ultimate: %s" % pid)
	
	if not FileAccess.file_exists(script_path):
		printerr("[PlayerBase] ultimate script not found: %s" % script_path)
		return null
	
	return load(script_path) as Script

func notify_q_path_executed(is_closed: bool, segment_count: int, polygon_count: int) -> void:
	"""Forward Q path execution events to active ultimate."""
	if not ultimate_skill or not is_instance_valid(ultimate_skill):
		return
	if not ultimate_skill.has_method("on_q_path_executed"):
		return
	ultimate_skill.call("on_q_path_executed", is_closed, segment_count, polygon_count)

func notify_space_draw_release(release_data: Dictionary) -> void:
	if BondManager != null and BondManager.has_method("on_space_draw_release"):
		BondManager.on_space_draw_release(self, release_data.duplicate(true))
	for enemy_node: Node in get_tree().get_nodes_in_group("enemies"):
		if enemy_node == null or not is_instance_valid(enemy_node):
			continue
		if not enemy_node.has_method("on_player_draw_release"):
			continue
		enemy_node.call("on_player_draw_release", self, release_data.duplicate(true))
	var assist_service: Node = get_node_or_null("/root/AssistRuntimeService")
	if assist_service == null or not assist_service.has_method("on_front_draw_release"):
		return
	assist_service.call("on_front_draw_release", self, release_data.duplicate(true))

func notify_front_dash_used(dash_data: Dictionary) -> void:
	if BondManager != null and BondManager.has_method("on_dash_started"):
		BondManager.on_dash_started(self, dash_data.duplicate(true))
	for enemy_node: Node in get_tree().get_nodes_in_group("enemies"):
		if enemy_node == null or not is_instance_valid(enemy_node):
			continue
		if not enemy_node.has_method("on_player_dash_used"):
			continue
		enemy_node.call("on_player_dash_used", self, dash_data.duplicate(true))
	var assist_service: Node = get_node_or_null("/root/AssistRuntimeService")
	if assist_service == null or not assist_service.has_method("on_front_dash"):
		return
	assist_service.call("on_front_dash", self, dash_data.duplicate(true))

func notify_front_skill_cast(skill_slot: String, payload: Dictionary = {}) -> void:
	match skill_slot:
		"e":
			on_skill_e_cast.emit(self)
		"f":
			on_skill_f_cast.emit(self)
	if BondManager != null and BondManager.has_method("on_front_skill_cast"):
		BondManager.on_front_skill_cast(self, skill_slot, payload.duplicate(true))

func notify_front_skill_damage(skill_slot: String, hit_enemies: Array, payload: Dictionary = {}) -> void:
	var assist_service: Node = get_node_or_null("/root/AssistRuntimeService")
	if assist_service == null or not assist_service.has_method("on_front_skill_damage"):
		return
	assist_service.call(
		"on_front_skill_damage",
		self,
		skill_slot,
		hit_enemies.duplicate(),
		payload.duplicate(true)
	)

func reset_dash_cooldown() -> void:
	pass

func reset_skill_e_cooldown() -> void:
	for property_name: String in [
		"_e_cooldown_remaining",
		"_gravity_well_cooldown_remaining"
	]:
		if property_name in self:
			set(property_name, 0.0)
	var skill_manager := get_node_or_null("SkillManager")
	if skill_manager != null and skill_manager.has_method("get_skill"):
		var skill_e: Variant = skill_manager.get_skill("e")
		if skill_e != null and is_instance_valid(skill_e):
			for cooldown_property: String in ["cooldown_remaining", "_cooldown_remaining", "current_cooldown", "cooldown_timer"]:
				if cooldown_property in skill_e:
					skill_e.set(cooldown_property, 0.0)

func get_blood_shield() -> float:
	return max(0.0, blood_shield)

func add_blood_shield(amount: float, cap_value: float = -1.0) -> float:
	if amount <= 0.0:
		return blood_shield
	var final_cap: float = cap_value if cap_value >= 0.0 else max(max_blood_shield, health * 0.5)
	max_blood_shield = max(max_blood_shield, final_cap)
	blood_shield = clamp(blood_shield + amount, 0.0, final_cap)
	return blood_shield

func spend_blood_shield(amount: float) -> float:
	var spent: float = min(max(0.0, amount), blood_shield)
	blood_shield = max(0.0, blood_shield - spent)
	return spent

func add_temporary_armor_stack(duration: float, max_stacks: int = 10) -> void:
	if duration <= 0.0:
		return
	while _temporary_armor_stacks.size() >= max_stacks:
		_temporary_armor_stacks.pop_front()
	_temporary_armor_stacks.append(duration)

func get_temporary_armor_bonus() -> float:
	return float(_temporary_armor_stacks.size()) * 2.0

func _process_temporary_armor_stacks(delta: float) -> void:
	if _temporary_armor_stacks.is_empty():
		return
	var kept: Array[float] = []
	for remaining_time: float in _temporary_armor_stacks:
		var next_time: float = max(0.0, remaining_time - delta)
		if next_time > 0.0:
			kept.append(next_time)
	_temporary_armor_stacks = kept

func _auto_create_skill_manager() -> void:
	print("[PlayerBase] Stage 1 cleanup: legacy skill manager auto-create disabled")
	return
func get_energy_percent() -> float:
	if max_energy <= 0.0:
		return 0.0
	return (energy / max_energy) * 100.0

func get_skill_context_snapshot() -> Dictionary:
	return SkillContextBridge.snapshot_owner(self)

func get_skill_asset_snapshot(kind_filter: String = "") -> Array[Dictionary]:
	if kind_filter.strip_edges().is_empty():
		return SkillAssetRegistry.snapshot_for_owner(self)
	return SkillAssetRegistry.list_assets(self, kind_filter)

func get_skill_runtime_snapshot() -> Dictionary:
	return {
		"player_id": player_id,
		"energy": energy,
		"max_energy": max_energy,
		"armor": armor,
		"current_weapons": current_weapons.size(),
		"ultimate_loaded": ultimate_skill != null and is_instance_valid(ultimate_skill)
	}

func _is_skill_synergy_test_no_cost_mode() -> bool:
	if Global == null:
		return false
	return Global.has_meta("skill_synergy_test_mode_active") and bool(Global.get_meta("skill_synergy_test_mode_active"))

func try_break_line(enemy_pos: Vector2, radius: float) -> void:
	pass

func _cleanup_all_skills() -> void:
	if has_node("SkillManager"):
		var skill_manager := get_node("SkillManager")
		if skill_manager.has_method("cleanup_all_skills"):
			skill_manager.cleanup_all_skills()

	for child in get_children():
		if child and child.has_method("cleanup"):
			child.cleanup()
