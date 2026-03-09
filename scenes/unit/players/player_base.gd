extends Unit
class_name PlayerBase

# 对外信号：供 HUD、结算与其他系统同步玩家实时状态。
signal energy_changed(current, max_val)
signal armor_changed(current)
signal xp_changed(current)
signal gold_changed(current)

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
var move_dir: Vector2 = Vector2.ZERO
var external_force: Vector2 = Vector2.ZERO
var external_force_decay: float = 50.0
var knockback_scale: float = 0.3
var reduction_per_armor: float = 0.2
var player_hit_cooldown: float = 0.12
var _player_hit_cooldown_timer: float = 0.0

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

var equipped_item_id: String = "" 

# 危险血线提示阈值（35% / 20% / 10%）
const DANGER_THRESHOLD_LV1: float = 0.35
const DANGER_THRESHOLD_LV2: float = 0.20
const DANGER_THRESHOLD_LV3: float = 0.10
var _danger_warned_lv1: bool = false
var _danger_warned_lv2: bool = false
var _danger_warned_lv3: bool = false

func _ready() -> void:
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
		"speed": speed,
		"energy_regen": energy_regen,
		"pickup_range": pickup_range,
		"damage": damage,
	}
	
	var modified = BondManager.apply_stat_modifiers(stats)
	
	var old_health = health
	health = modified.get("max_health", health)
	speed = modified.get("speed", speed)
	energy_regen = modified.get("energy_regen", energy_regen)
	pickup_range = modified.get("pickup_range", pickup_range)
	damage = modified.get("damage", damage)
	
	if health_component:
		if abs(health - health_component.max_health) > 0.01:
			health_component.setup_with_health(health)
		energy = max_energy
	
	if OS.is_debug_build():
		print("[PlayerBase] Bond stat modifiers applied:")
		print("  HP: %.0f -> %.0f" % [old_health, health])
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
	# 武器来源优先级：本局选中的初始武器 + 局内商店购买武器（避免重复）。
	if player_id.is_empty() or not weapon_container:
		return
	
	var selected_weapon_type: String = ""
	if Global.selected_player_weapons.has(player_id):
		selected_weapon_type = str(Global.selected_player_weapons[player_id])

	if selected_weapon_type.is_empty():
		var fallback_weapon_types: Array[String] = ConfigManager.get_player_available_weapon_types(player_id)
		if not fallback_weapon_types.is_empty():
			selected_weapon_type = fallback_weapon_types[0]
			Global.selected_player_weapons[player_id] = selected_weapon_type
			print("[PlayerBase] fallback weapon assigned for %s: %s" % [player_id, selected_weapon_type])
		else:
			push_warning("[PlayerBase] no available weapon types for player: %s" % player_id)
	
	if selected_weapon_type != "":
		var weapon_id = "%s_1" % selected_weapon_type
		var item_weapon = _create_item_weapon_from_csv(weapon_id)
		if item_weapon:
			_add_weapon(item_weapon)
	
	var purchased_weapon_type = DataManager.get_purchased_weapon(player_id)
	if purchased_weapon_type != "" and purchased_weapon_type != selected_weapon_type:
		var purchased_weapon_id = "%s_1" % purchased_weapon_type
		var purchased_item = _create_item_weapon_from_csv(purchased_weapon_id)
		if purchased_item:
			_add_weapon(purchased_item)
			print("[PlayerBase] loaded purchased weapon: %s" % purchased_weapon_id)
	
	if current_weapons.is_empty():
		print("[PlayerBase] Warning: player %s has no weapons loaded" % player_id)
	else:
		print("[PlayerBase] player %s loaded %d weapons" % [player_id, current_weapons.size()])
	return

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
	
	if energy < max_energy:
		energy += energy_regen * delta
		update_ui_signals()
	
	if external_force.length() > 1.0:
		position += external_force * delta
		external_force = external_force.lerp(Vector2.ZERO, external_force_decay * delta)
	else:
		external_force = Vector2.ZERO
	
	_handle_input(delta)
	_process_subclass(delta)
	update_rotation()

func _handle_input(delta: float) -> void:
	# 输入优先级：移动 -> E瞬发 -> Q蓄力/释放 -> 普攻 -> F大招。

	move_dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if can_move():
		var current_speed = speed
		if has_meta("buff_speed_boost"):
			current_speed *= (1.0 + get_meta("buff_speed_boost"))
		position += move_dir * current_speed * delta

	if has_node("SkillManager"):
		var skill_manager = get_node("SkillManager")
		
		if Input.is_action_just_pressed("skill_e"):
			print("[PlayerBase] E pressed -> execute_skill('e')")
			skill_manager.execute_skill("e")
			return
		
		if Input.is_action_pressed("skill_q"):
			skill_manager.charge_skill("q", delta)
			return
		elif Input.is_action_just_released("skill_q"):
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
		else:
			print("[PlayerBase] ultimate is not loaded")

			Global.spawn_floating_text(global_position, "Ultimate not ready", Color.GRAY)

func can_move() -> bool: 
	return true

func _process_subclass(delta: float) -> void: 
	pass

func _on_hurtbox_component_on_damaged(hitbox: HitboxComponent) -> void:
	if not health_component or health_component.current_health <= 0:
		return
	if not hitbox:
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

	set_flash_material()
	take_damage(hitbox.damage)
	_player_hit_cooldown_timer = player_hit_cooldown

	if hitbox.knockback_power > 0.0 and hitbox.source and is_instance_valid(hitbox.source):
		var knock_dir := hitbox.source.global_position.direction_to(global_position)
		apply_knockback_self(knock_dir * hitbox.knockback_power)

func take_damage(raw_amount: float) -> void:
	# 伤害流程：护甲减伤 -> 护甲层消耗/破甲反馈 -> 扣血 -> 被动反制触发。
	var damage_multiplier = 1.0 - (clamp(armor, 0, max_armor) * reduction_per_armor)
	var final_damage = max(1, raw_amount * damage_multiplier)
	
	print("[PlayerBase] take_damage: raw=%d, final=%d, current_hp=%d" % [raw_amount, final_damage, health_component.current_health])
	

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
	
	health_component.take_damage(final_damage)
	
	if BondManager.has_mechanic("soul_attach") or BondManager.has_mechanic("dual_order"):
		_trigger_soul_attach_on_hit()
	
	print("[PlayerBase] hp after damage=%d" % health_component.current_health)

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
				enemy.get_node("HealthComponent").take_damage(attach_damage)
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
	if _is_drawing_active() and BondManager.has_mechanic("super_armor"):
		print("[PlayerBase] [P1-2] super armor triggered, knockback ignored (damage still applied)")
		SoundManager.play("super_armor_trigger")
		Global.spawn_floating_text(global_position, "SUPER ARMOR!", Color.ORANGE)

		Global.on_camera_shake.emit(3.0, 0.08)
		return
	

	external_force = force * knockback_scale
	Global.on_camera_shake.emit(5.0, 0.1)

func consume_energy(amount: float) -> bool:
	if energy >= amount:
		energy -= amount
		update_ui_signals()
		return true
	else:
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
	
	if skill_manager.has_method("get_all_skills"):
		for skill in skill_manager.get_all_skills():
			if skill is SkillDrawingBase:
				if skill.is_planning or skill.is_drawing:
					return true
	
	return false

func get_speed_damage_bonus() -> float:
	
	
	if not BondManager.has_mechanic("speed_to_damage"):
		return 0.0
	
	var conversion_rate = BondManager.get_mechanic_value("speed_to_damage")
	
	var current_speed = speed
	var speed_diff = current_speed - base_speed
	
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
	"""按角色读取大招配置并挂载统一的大招脚本实例。"""
	print("[PlayerBase] start loading ultimate, player_id = %s" % player_id)
	
	if player_id.is_empty():
		print("[PlayerBase] player_id is empty, skip ultimate load")
		return
	
	var ult_config = _load_ult_config_from_csv(player_id)
	if ult_config.is_empty():
		print("[PlayerBase] player %s has no ultimate config" % player_id)
		return
	
	print("[PlayerBase] ultimate config loaded: %s" % str(ult_config))
	
	var ult_script = _get_ultimate_script_for_player(player_id)
	if not ult_script:
		print("[PlayerBase] player %s has no ultimate script" % player_id)
		return
	
	print("[PlayerBase] ultimate script loaded: %s" % str(ult_script))
	

	ultimate_skill = ult_script.new()
	ultimate_skill.name = "UltimateSkill"
	add_child(ultimate_skill)
	
	print("[PlayerBase] ultimate node created")
	

	ultimate_skill.initialize(ult_config, self)
	
	print("[PlayerBase] ultimate load complete: %s" % ult_config.get("name", "Unknown"))

func _load_ult_config_from_csv(pid: String) -> Dictionary:
	
	return ConfigRepository.get_ult_config_for_player(pid)

func _get_ultimate_script_for_player(pid: String) -> Script:

	var script_path := "res://scenes/skills/players/skill_ultimate_qef_v3.gd"
	if not FileAccess.file_exists(script_path):
		script_path = "res://scenes/skills/skill_ultimate_base.gd"
		print("[PlayerBase] QEF V3 script missing, fallback to base ultimate: %s" % pid)
	
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

func _auto_create_skill_manager() -> void:
	# 若场景未预置 SkillManager，则按角色技能绑定表自动创建。
	for child in get_children():
		if child is SkillManager:
			var sm = child as SkillManager
			print("[PlayerBase] SkillManager already exists (created by child: %s), loaded=%d, skip auto create" % [child.name, sm.get_loaded_skill_count()])
			if child.name != "SkillManager":
				child.name = "SkillManager"

			sm.print_skills_info()
			return
	
	var bindings = ConfigManager.get_player_skill_bindings(player_id)
	if bindings.is_empty():
		print("[PlayerBase] player %s has no skill bindings, skip SkillManager auto create" % player_id)
		return
	
	var has_any_skill = false
	for slot in ["q", "e", "lmb", "rmb"]:
		var skill_id = bindings.get("slot_%s" % slot, "")
		if not skill_id.is_empty():
			has_any_skill = true
			break
	
	if not has_any_skill:
		print("[PlayerBase] player %s has no skills configured, skip SkillManager auto create" % player_id)
		return
	
	var skill_manager = SkillManager.new(self)
	skill_manager.name = "SkillManager"
	skill_manager.debug_mode = false
	add_child(skill_manager)
	
	var success = skill_manager.load_skills_from_config(player_id)
	
	if success:
		print("[PlayerBase] SkillManager auto-created: %s (loaded %d skills)" % [
			player_id, 
			skill_manager.get_loaded_skill_count()
		])
	else:
		print("[PlayerBase] SkillManager created, but skill loading failed: %s" % player_id)

func get_skill_cooldowns_snapshot() -> Dictionary:
	if not has_node("SkillManager"):
		return {}
	var sm = get_node("SkillManager")
	if sm and sm.has_method("export_cooldown_state"):
		return sm.export_cooldown_state()
	return {}

func queue_restore_skill_cooldowns(snapshot: Dictionary, elapsed_time: float = 0.0, bench_speed_multiplier: float = 1.0) -> void:
	_pending_skill_cooldowns = snapshot.duplicate(true)
	_pending_bench_elapsed = max(0.0, elapsed_time)
	_pending_bench_multiplier = max(0.0, bench_speed_multiplier)
	call_deferred("_apply_queued_skill_cooldowns")

func _apply_queued_skill_cooldowns() -> void:
	if _pending_skill_cooldowns.is_empty():
		return

	var retry_frames := 5
	while not has_node("SkillManager") and retry_frames > 0:
		retry_frames -= 1
		await get_tree().process_frame

	if not has_node("SkillManager"):
		return

	var sm = get_node("SkillManager")
	if sm and sm.has_method("import_cooldown_state"):
		sm.import_cooldown_state(_pending_skill_cooldowns, _pending_bench_elapsed, _pending_bench_multiplier)

	_pending_skill_cooldowns.clear()
	_pending_bench_elapsed = 0.0
	_pending_bench_multiplier = 1.0

func get_energy_percent() -> float:
	
	if max_energy <= 0:
		return 0.0
	return (energy / max_energy) * 100.0

func consume_energy_percent(percent: float) -> bool:
	
	var amount = (percent / 100.0) * max_energy
	return consume_energy(amount)

func try_break_line(enemy_pos: Vector2, radius: float) -> void:
	pass

func _cleanup_all_skills() -> void:
	if has_node("SkillManager"):
		var skill_manager = get_node("SkillManager")
		if skill_manager.has_method("cleanup_all_skills"):
			skill_manager.cleanup_all_skills()
	
	for child in get_children():
		if child.has_method("cleanup"):
			child.cleanup()


