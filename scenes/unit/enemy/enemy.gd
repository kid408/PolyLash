extends Unit
class_name Enemy

const DEBUG_VERBOSE := false
const COMBAT_MODIFIER_COMPONENT := preload("res://scenes/components/combat_modifier_component.gd")
const COMBAT_EVENT_TYPES := preload("res://scenes/components/combat_event_types.gd")
const SILK_LINK_UTILS := preload("res://scenes/effects/silk_link_utils.gd")
const OPEN_LINE_DAMAGE_KINDS := {
	"arc_travel": true,
	"minimalist_slash": true,
	"mirror_draw": true,
	"overtone_sonic_boom": true,
	"wall_contact_damage": true,
}
const CLOSED_SPACE_DAMAGE_KINDS := {
	"area_effect_tick": true,
	"collapse_singularity_tick": true,
	"joule_closed_blast": true,
	"minimalist_true_slash": true,
	"overtone_drum_roll": true,
	"phalanx_pinball_enemy": true,
	"phalanx_pinball_wall": true,
}
const SKILL_E_DAMAGE_KINDS := {
	"arc_drift_blast": true,
	"silk_energy_reflow": true,
}
const SKILL_F_DAMAGE_KINDS := {
	"collapse_event_horizon_final": true,
	"collapse_event_horizon_tick": true,
	"phalanx_rigid_body_boss": true,
}

signal knockback_requested(enemy: Enemy, payload: Dictionary)

# ==============================================================================
# 1. 灞炴€ч厤缃?
# ==============================================================================
enum EnemyType {
	NORMAL,         # 0
	LINE_BREAKER,   # 1
	SHIELDED,       # 2
	SPIKED,         # 3
	MINE_LAYER      # 4 - 鏂板锛氬湴闆锋€紝姝诲悗鐣欐瘨姹?
}

enum AIState {
	CHASE,      # 姝ｅ父杩介€?
	PREPARING,  # 棰勮闃舵 (鍑虹孩绾?
	CHARGING,   # 鍐查攱闃舵
	COOLDOWN    # 浼戞伅
}

@export var enemy_type: EnemyType = EnemyType.NORMAL

# 鏁屼汉ID锛岀敤浜庝粠CSV鍔犺浇閰嶇疆
@export var enemy_id: String = "basic_enemy"

@export_group("Movement")
@export var flock_push: float = 20.0 
@export var stop_distance: float = 60.0 
@export_group("Swarm Encircle")
@export var tangential_slip_enabled: bool = true
@export var tangential_slip_strength: float = 0.75
@export var tangential_front_dot_threshold: float = 0.2
@export var tangential_distance_falloff: float = 90.0
@export var desired_separation: float = 60.0
@export var engagement_radius: float = 120.0
@export var engagement_band: float = 56.0
@export var chase_radial_weight: float = 1.2
@export var chase_separation_weight: float = 1.0
@export var chase_tangent_weight: float = 1.8
@export var ring_tangent_boost: float = 2.2
@export var flank_bias_strength: float = 1.15

@export_group("Charge Settings")
@export var can_charge: bool = false       # 鏄惁寮€鍚啿閿嬫妧鑳?(寤鸿鍦↖nspector缁欏埡鐚?纭３榫熷嬀閫?
@export var charge_prep_time: float = 0.8  # 棰勮鏃堕棿 (绾㈢嚎鏄剧ず鏃堕棿)
@export var charge_duration: float = 0.6   # 鍐查攱鎸佺画鏃堕棿
@export var charge_speed_mult: float = 3.5 # 鍐查攱閫熷害鍊嶇巼
@export var charge_cooldown: float = 3.0   # 鍐峰嵈鏃堕棿

@export_group("Charge Collision")
@export var charge_cage_collision_mask: int = 4
@export var charge_cast_radius: float = 18.0
@export var charge_cast_backoff: float = 0.02
@export var charge_wall_stun_duration: float = 0.45
@export var charge_wall_rebound_distance: float = 12.0
@export var charge_open_line_check_enabled: bool = true
@export var charge_open_line_radius: float = 36.0
@export var charge_open_line_max_age_msec: int = 2500
@export var charge_open_line_hit_interval: float = 0.12
@export var charge_open_line_damage_ratio: float = 0.35
@export var charge_local_hitstop_duration: float = 0.04
@export_group("Parasite")
@export var parasite_duration_max: float = 8.0
@export var parasite_pulse_interval: float = 0.4
@export var parasite_pulse_radius: float = 80.0
@export var parasite_pulse_damage_ratio: float = 0.15
@export var parasite_slow_ratio: float = 0.20
@export var parasite_pull_collision_mask: int = 4
@export var parasite_catalyst_death_window: float = 0.5
@export var parasite_catalyst_spread_radius: float = 300.0
@export var parasite_catalyst_spread_count: int = 3
@export var parasite_catalyst_pull_duration: float = 0.35
@export var parasite_catalyst_pull_speed: float = 450.0
@export var parasite_f_detonation_delay: float = 0.5
@export var parasite_f_detonation_radius: float = 120.0
@export var parasite_f_detonation_damage_ratio: float = 1.80
@export var parasite_pit_damage_taken_bonus: float = 0.15
@export var parasite_pit_slow_ratio: float = 0.15

@export_group("Visual & Effects")
@export var death_vfx_scene: PackedScene 
const DEFAULT_EXPLOSION = preload("uid://dvfjoyutjx5jf") 

# ==============================================================================
# 鐗规畩鑳藉姏鍙傛暟
# ==============================================================================

@export_group("Shooting Behavior (Shielded)")
@export var shoot_cooldown: float = 3.0
@export var projectile_count: int = 3
@export var projectile_arc_angle: float = 45.0
@export var projectile_speed: float = 1800.0

@export_group("Poison Pool (MineLayer)")
@export var pool_radius: float = 60.0
@export var pool_damage: float = 5.0
@export var pool_damage_interval: float = 0.5
@export var pool_lifetime: float = 8.0 

# ==============================================================================
# 2. 鑺傜偣寮曠敤
# ==============================================================================
@onready var vision_area: Area2D = $VisionArea
@onready var knockback_timer: Timer = $KnockbackTimer
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var contact_hitbox: HitboxComponent = $HitboxComponent

# 銆愭柊澧炪€戦璀︾嚎鑺傜偣 (浠ｇ爜鍔ㄦ€佺敓鎴愶紝鍏嶅幓鎵嬪姩娣诲姞)
var warning_line: Line2D 
# 銆愭柊澧炪€戝綋鍓嶆敾鍑荤洰鏍?(榛樿涓?null锛岄€昏緫閲屼細鍥炴粴鍒?Global.player)
var override_target: Node2D = null
# ==============================================================================
# 3. 閫昏緫鍙橀噺
# ==============================================================================
var can_move: bool = true
var is_dead: bool = false
var knockback_dir: Vector2 = Vector2.ZERO
var knockback_power: float = 0.0
var break_radius: float = 40.0

var elite_affix_id: String = ""
var elite_affix_params: Dictionary = {}
var _affix_vamp_tick: float = 0.0

var boss_phase_configs: Array = []
var boss_current_phase: int = 1
var _boss_base_speed: float = 0.0
var _boss_base_damage: float = 0.0

# AI 鐘舵€?
var current_ai_state: AIState = AIState.CHASE
var charge_vector: Vector2 = Vector2.ZERO # 鍐查攱鏂瑰悜
var ai_timer: float = 0.0 # 閫氱敤璁℃椂鍣?
var original_modulate: Color
var local_hitstop_timer: float = 0.0
var _resume_base_anim_after_hitstop: bool = false
var _resume_charge_anim_after_hitstop: bool = false
var _charge_shape_cast: ShapeCast2D = null
var _charge_line_hit_msec_by_asset: Dictionary = {}
var _encircle_side_preference: float = 1.0
var _flank_direction: float = 1.0
var is_parasitized: bool = false
var parasite_timer: float = 0.0
var parasite_pulse_timer: float = 0.0
var parasite_source_attack: float = 0.0
var parasite_pull_timer: float = 0.0
var parasite_pull_speed: float = 0.0
var parasite_pull_target: Vector2 = Vector2.ZERO
var _parasite_visual_active: bool = false
var parasite_catalyst_timer: float = 0.0
var parasite_catalyst_attack: float = 0.0
var parasite_pending_detonation: bool = false
var parasite_detonation_timer: float = 0.0
var parasite_detonation_attack: float = 0.0
var parasite_rooted: bool = false
var _parasite_ring: Line2D = null
var _parasite_visual_pulse: float = 0.0
var _parasite_pit_sources: Dictionary = {}
var _joule_tar_ring: Line2D = null
var _joule_tar_visual_pulse: float = 0.0
var _soul_link_ring: Line2D = null
var _soul_link_tether: Line2D = null
var _soul_link_visual_pulse: float = 0.0
var combat_modifier_component: CombatModifierComponent = null
var phalanx_motion_lock_count: int = 0
var phalanx_ballistic_active: bool = false
var phalanx_ballistic_velocity: Vector2 = Vector2.ZERO
var phalanx_ballistic_remaining_distance: float = 0.0
var phalanx_ballistic_remaining_time: float = 0.0
var phalanx_ballistic_source_attack: float = 0.0
var phalanx_ballistic_collision_damage_ratio: float = 0.0
var phalanx_ballistic_impact_push_distance: float = 0.0
var phalanx_ballistic_source: Variant = null
var phalanx_ballistic_hit_radius: float = 26.0
var phalanx_ballistic_stop_on_hit: bool = true
var phalanx_ballistic_target_hit_cooldowns: Dictionary = {}
var _last_damage_payload: Dictionary = {}
var _last_knockback_payload: Dictionary = {}
var _split_spawned_on_death: bool = false
var _slime_sprite_base_scale: Vector2 = Vector2.ONE
var _slime_visual_time: float = 0.0
var _slime_birth_invul_timer: float = 0.0
var _slime_spawn_pop_timer: float = 0.0
var _closure_dummy_vulnerable_timer: float = 0.0
var _line_dummy_feedback_cooldown: float = 0.0

const ASSIST_BACKEND_KILL_META: String = "assist_backend_kill"
const ASSIST_BACKEND_KILL_OWNER_META: String = "assist_backend_kill_owner"

# ==============================================================================
# P2-3/P2-4: 鐘舵€佺郴缁燂紙Status/Debuff System锛?
# ==============================================================================
## 婵€娲荤殑鐘舵€佹晥鏋滐細{status_name: {duration: float, value: float, stacks: int}}
var active_statuses: Dictionary = {}

## 鐘舵€佹晥鏋滅殑浼ゅ璁℃椂鍣紙鐢ㄤ簬DoT鏁堟灉锛?
var status_damage_timers: Dictionary = {} 
# ==============================================================================
# 4. 鍒濆鍖?
# ==============================================================================
func _ready() -> void:
	_ensure_combat_modifier_component()
	super._ready() 
	if not is_in_group("enemies"):
		add_to_group("enemies")
	if death_vfx_scene == null:
		death_vfx_scene = DEFAULT_EXPLOSION
	health_component.on_unit_died.connect(destroy_enemy)
	
	# 鍋滄鍔ㄧ敾鎾斁锛岄伩鍏嶅嚭鐢熸椂鐨?鍙戝ぇ鍐嶇缉灏?鐗规晥
	if anim_player:
		anim_player.stop()
	
	# 銆愯瑙変紭鍖栥€戦璀︾孩绾?
	warning_line = Line2D.new()
	warning_line.width = 30.0 # 銆愪慨鏀广€戦潪甯稿锛屽儚涓€涓暱鐭╁舰鍖哄煙
	warning_line.default_color = Color(1, 0.2, 0.2, 0.0) # 鍒濆閫忔槑
	warning_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	warning_line.end_cap_mode = Line2D.LINE_CAP_ROUND
	warning_line.top_level = true # 蹇呴』椤剁骇锛屼笉闅忔€墿鏃嬭浆
	add_child(warning_line)
	_setup_charge_shape_cast()
	
	# 鏍规嵁 enemy_id 璁剧疆鏁屼汉绫诲瀷
	_set_enemy_type_from_id()
	
	# 搴旂敤CSV閰嶇疆
	_apply_visual_from_config()  # 搴旂敤瑙嗚閰嶇疆锛堢簿鐏点€佺缉鏀俱€佺鎾炰綋绛夛級
	_apply_color_from_config()   # 搴旂敤棰滆壊閰嶇疆
	_apply_behavior_from_config() # 搴旂敤琛屼负閰嶇疆
	_sync_contact_hitbox_damage()
	
	original_modulate = visuals.modulate
	var initial_flank_direction: float = -1.0 if randf() < 0.5 else 1.0
	_flank_direction = initial_flank_direction
	_encircle_side_preference = initial_flank_direction
	_setup_parasite_ring()
	_setup_soul_link_visuals()
	_refresh_parasite_visual()
	
	_setup_special_nodes()
	_init_boss_phase_template()
	
	if enemy_type == EnemyType.SPIKED:
		can_charge = true

	_apply_split_spawn_profile()
	_setup_fractal_slime_runtime()

# 鏍规嵁 enemy_id 璁剧疆鏁屼汉绫诲瀷
func _set_enemy_type_from_id() -> void:
	match enemy_id:
		"breaker_enemy":
			enemy_type = EnemyType.LINE_BREAKER
		"shielded_enemy":
			enemy_type = EnemyType.SHIELDED
		"spiked_enemy":
			enemy_type = EnemyType.SPIKED
		"mine_layer_enemy":
			enemy_type = EnemyType.MINE_LAYER
		_:
			enemy_type = EnemyType.NORMAL

# 浠嶤SV閰嶇疆搴旂敤棰滆壊
func _apply_color_from_config() -> void:
	var config = ConfigManager.get_enemy_config(enemy_id)
	if config.is_empty():
		return
	
	# 妫€鏌ユ槸鍚﹂厤缃簡棰滆壊锛坈olor_r, color_g, color_b锛?
	if config.has("color_r") and config.has("color_g") and config.has("color_b"):
		var r = config.get("color_r", "")
		var g = config.get("color_g", "")
		var b = config.get("color_b", "")
		
		# 濡傛灉棰滆壊鍊间笉涓虹┖锛屽簲鐢ㄩ鑹?
		if r != null and g != null and b != null:
			#var color = Color(float(r), float(g), float(b), 1)
			var color = Color(float(r), float(g), float(b), 1)
			visuals.modulate = color
			# print("[Enemy] 搴旂敤棰滆壊閰嶇疆: ", enemy_id, " -> ", color)

# 浠嶤SV閰嶇疆搴旂敤瑙嗚灞炴€э紙绮剧伒銆佺缉鏀俱€佺鎾炰綋绛夛級
func _apply_visual_from_config() -> void:
	var visual_config = ConfigManager.get_enemy_visual(enemy_id)
	if visual_config.is_empty():
		#print("[Enemy] 璀﹀憡: 鎵句笉鍒拌瑙夐厤缃?", enemy_id)
		return
	
	#print("[Enemy] 搴旂敤瑙嗚閰嶇疆: ", enemy_id)
	
	# 璁剧疆绮剧伒
	if visual_config.has("sprite_path"):
		var sprite_path: String = str(visual_config.get("sprite_path", ""))
		if not sprite_path.is_empty():
			var resolved_sprite_path: String = sprite_path
			if not FileAccess.file_exists(resolved_sprite_path):
				push_warning("[Enemy] sprite missing for %s: %s, fallback to Enemy_1.png" % [enemy_id, sprite_path])
				resolved_sprite_path = "res://assets/sprites/Enemies/Enemy_1.png"

			var texture: Texture2D = null
			if FileAccess.file_exists(resolved_sprite_path):
				texture = load(resolved_sprite_path) as Texture2D

			if texture != null:
				var sprite_node = null
				if visuals.has_node("Sprite"):
					sprite_node = visuals.get_node("Sprite")
				elif visuals.has_node("Sprite2D"):
					sprite_node = visuals.get_node("Sprite2D")
				
				if sprite_node:
					sprite_node.texture = texture
					#print("[Enemy] 搴旂敤绮剧伒: ", enemy_id, " -> ", sprite_path)
			#else:
				#print("[Enemy] 璀﹀憡: 鏃犳硶鍔犺浇绮剧伒 ", sprite_path)
	
	# 璁剧疆缂╂斁锛堜箻浠ュ熀纭€缂╂斁0.5锛岃€屼笉鏄鐩栵級
	if visual_config.has("scale_x") and visual_config.has("scale_y"):
		var scale_x = visual_config.get("scale_x", 1.0)
		var scale_y = visual_config.get("scale_y", 1.0)
		if scale_x != null and scale_y != null:
			# 淇濇寔鍩虹缂╂斁0.5锛屼箻浠ラ厤缃腑鐨勭缉鏀惧€?
			var base_scale = 0.5
			visuals.scale = Vector2(float(scale_x) * base_scale, float(scale_y) * base_scale)
			# print("[Enemy] 搴旂敤缂╂斁: ", visuals.scale)
	
	# 璁剧疆鍋忕Щ
	if visual_config.has("offset_x") and visual_config.has("offset_y"):
		var offset_x = visual_config.get("offset_x", 0.0)
		var offset_y = visual_config.get("offset_y", 0.0)
		if offset_x != null and offset_y != null:
			# 灏濊瘯鎵惧埌绮剧伒鑺傜偣锛堟敮鎸?Sprite 鍜?Sprite2D锛?
			var sprite_node = null
			if visuals.has_node("Sprite"):
				sprite_node = visuals.get_node("Sprite")
			elif visuals.has_node("Sprite2D"):
				sprite_node = visuals.get_node("Sprite2D")
			
			if sprite_node:
				sprite_node.offset = Vector2(float(offset_x), float(offset_y))
	
	# 璁剧疆纰版挒浣撳崐寰?
	if visual_config.has("collision_radius") and collision_shape:
		var radius = visual_config.get("collision_radius", 20.0)
		if radius != null and collision_shape.shape is CircleShape2D:
			collision_shape.shape.radius = float(radius)
			# print("[Enemy] 搴旂敤纰版挒鍗婂緞: ", radius)
	
	# 璁剧疆鍙楀嚮妗嗗ぇ灏?
	if visual_config.has("hitbox_width") and visual_config.has("hitbox_height"):
		var hitbox_width = visual_config.get("hitbox_width", 40.0)
		var hitbox_height = visual_config.get("hitbox_height", 40.0)
		if hitbox_width != null and hitbox_height != null:
			var hitbox = get_node_or_null("Hitbox")
			if hitbox:
				var hitbox_shape = hitbox.get_node_or_null("CollisionShape2D")
				if hitbox_shape and hitbox_shape.shape is RectangleShape2D:
					hitbox_shape.shape.size = Vector2(float(hitbox_width), float(hitbox_height))
					# print("[Enemy] 搴旂敤鍙楀嚮妗? ", hitbox_shape.shape.size)
	
	# 璁剧疆Z灞傜骇
	if visual_config.has("z_index"):
		var z = visual_config.get("z_index", 0)
		if z != null:
			z_index = int(z)
	
	# 璁剧疆棰滆壊锛堜粠visual_config锛岃鐩杄nemy_config涓殑棰滆壊锛?
	if visual_config.has("color_r") and visual_config.has("color_g") and visual_config.has("color_b"):
		var r = visual_config.get("color_r", 1.0)
		var g = visual_config.get("color_g", 1.0)
		var b = visual_config.get("color_b", 1.0)
		var a = visual_config.get("color_a", 1.0)
		if r != null and g != null and b != null:
			visuals.modulate = Color(float(r), float(g), float(b), float(a) if a != null else 1.0)

# 浠嶤SV閰嶇疆搴旂敤琛屼负鍙傛暟
func _apply_behavior_from_config() -> void:
	var config = ConfigManager.get_enemy_config(enemy_id)
	if config.is_empty():
		return
	
	# 鍔犺浇鍩虹琛屼负鍙傛暟
	if config.has("flock_push"):
		flock_push = float(config.get("flock_push", 20.0))
	if config.has("stop_distance"):
		stop_distance = float(config.get("stop_distance", 60.0))
	if config.has("charge_prep_time"):
		charge_prep_time = float(config.get("charge_prep_time", 0.8))
	if config.has("charge_duration"):
		charge_duration = float(config.get("charge_duration", 0.6))
	if config.has("charge_speed_mult"):
		charge_speed_mult = float(config.get("charge_speed_mult", 3.5))
	if config.has("charge_cooldown"):
		charge_cooldown = float(config.get("charge_cooldown", 3.0))
	if config.has("break_radius"):
		break_radius = float(config.get("break_radius", 40.0))
	if config.has("can_charge"):
		can_charge = int(config.get("can_charge", 0)) == 1
	
	# 鍔犺浇鐗规畩鑳藉姏鍙傛暟
	# ShootingBehavior 鍙傛暟
	if config.has("shoot_cooldown"):
		shoot_cooldown = float(config.get("shoot_cooldown", 3.0))
	if config.has("projectile_count"):
		projectile_count = int(config.get("projectile_count", 3))
	if config.has("projectile_arc_angle"):
		projectile_arc_angle = float(config.get("projectile_arc_angle", 45.0))
	if config.has("projectile_speed"):
		projectile_speed = float(config.get("projectile_speed", 1800.0))
	
	# MineLayer 鍙傛暟
	if config.has("pool_radius"):
		pool_radius = float(config.get("pool_radius", 60.0))
	if config.has("pool_damage"):
		pool_damage = float(config.get("pool_damage", 5.0))
	if config.has("pool_damage_interval"):
		pool_damage_interval = float(config.get("pool_damage_interval", 0.5))
	if config.has("pool_lifetime"):
		pool_lifetime = float(config.get("pool_lifetime", 8.0))
	
	#print("[Enemy] 搴旂敤琛屼负閰嶇疆: ", enemy_id)

# 鍔ㄦ€佺敓鎴愮壒娈婅妭鐐癸紙鏍规嵁鏁屼汉绫诲瀷锛?
func _setup_special_nodes() -> void:
	match enemy_type:
		EnemyType.SHIELDED:
			_setup_shooting_behavior()
		EnemyType.SPIKED:
			_setup_charge_animation()
		EnemyType.MINE_LAYER:
			pass  # 姣掓睜灏嗗湪姝讳骸鏃剁敓鎴?
		_:
			pass

# 涓虹‖澹抽緹鐢熸垚灏勫嚮琛屼负鑺傜偣
func _setup_shooting_behavior() -> void:
	# 妫€鏌ユ槸鍚﹀凡瀛樺湪
	if has_node("ShootingBehavior"):
		return
	
	# 鍒涘缓 FirePos 鏍囪
	var fire_pos = Marker2D.new()
	fire_pos.name = "FirePos"
	fire_pos.position = Vector2(0, -50)
	visuals.add_child(fire_pos)
	
	# 鍒涘缓 ShootingBehavior 鑺傜偣
	var shooting_behavior = Node2D.new()
	shooting_behavior.name = "ShootingBehavior"
	
	# 鍔犺浇鑴氭湰
	var script = load("res://scenes/unit/enemy/shooting_behavior.gd")
	if script == null:
		push_error("[Enemy] 閿欒: 鏃犳硶鍔犺浇 shooting_behavior.gd 鑴氭湰")
		return
	
	shooting_behavior.set_script(script)
	
	# 璁剧疆灞炴€э紙蹇呴』鍦ㄨ剼鏈粦瀹氬悗锛?
	shooting_behavior.enemy = self
	shooting_behavior.fire_pos = fire_pos
	shooting_behavior.projectile_scene = load("res://scenes/projectiles/projectile_enemy.tscn")
	
	# 搴旂敤閰嶇疆鍙傛暟
	shooting_behavior.cooldown = shoot_cooldown
	shooting_behavior.projectile_count = projectile_count
	shooting_behavior.arc_angle = projectile_arc_angle
	shooting_behavior.projectile_speed = projectile_speed
	
	# 娣诲姞鍒板満鏅爲
	add_child(shooting_behavior)
	
	# 鎵嬪姩璋冪敤 _ready()锛屽洜涓鸿剼鏈槸鍔ㄦ€佺粦瀹氱殑
	if shooting_behavior.has_method("_ready"):
		shooting_behavior._ready()
	else:
		push_error("[Enemy] 閿欒: ShootingBehavior 娌℃湁 _ready() 鏂规硶")
	
	# 纭繚 _process 浼氳璋冪敤
	shooting_behavior.set_process(true)

# 涓哄埡鐚敓鎴愬啿閿嬪姩鐢?
func _setup_charge_animation() -> void:
	# 妫€鏌ユ槸鍚﹀凡瀛樺湪
	if has_node("AnimationEffects"):
		return
	
	# 鍒涘缓 AnimationPlayer
	var anim_player = AnimationPlayer.new()
	anim_player.name = "AnimationEffects"
	add_child(anim_player)
	
	# 鍒涘缓鍔ㄧ敾搴?
	var anim_lib = AnimationLibrary.new()
	
	# 鍒涘缓 RESET 鍔ㄧ敾
	var reset_anim = Animation.new()
	reset_anim.length = 0.001
	var track_idx = reset_anim.add_track(Animation.TYPE_VALUE)
	reset_anim.track_set_path(track_idx, "Visuals/Sprite:modulate")
	reset_anim.track_insert_key(track_idx, 0, Color(1, 1, 1, 1))
	anim_lib.add_animation(&"RESET", reset_anim)
	
	# 鍒涘缓 charge 鍔ㄧ敾锛堥棯鐑佺孩鑹诧級
	var charge_anim = Animation.new()
	charge_anim.length = 0.5
	track_idx = charge_anim.add_track(Animation.TYPE_VALUE)
	charge_anim.track_set_path(track_idx, "Visuals/Sprite:modulate")
	charge_anim.track_set_interpolation_type(track_idx, Animation.INTERPOLATION_LINEAR)
	
	var times = PackedFloat32Array([0, 0.1, 0.2, 0.3, 0.4])
	var colors = [
		Color(1, 1, 1, 1),
		Color(0.9529412, 0, 0.36862746, 1),
		Color(1, 1, 1, 1),
		Color(0.9529412, 0, 0.36862746, 1),
		Color(1, 1, 1, 1)
	]
	
	for i in range(times.size()):
		charge_anim.track_insert_key(track_idx, times[i], colors[i])
	
	anim_lib.add_animation(&"charge", charge_anim)
	
	# 璁剧疆鍔ㄧ敾搴?
	anim_player.add_animation_library("", anim_lib)

# ==============================================================================
# 5. 鐗╃悊澶勭悊 (甯︾姸鎬佹満)
# ==============================================================================
func _process(delta: float) -> void:
	if Global.game_paused or is_dead: return
	_closure_dummy_vulnerable_timer = max(0.0, _closure_dummy_vulnerable_timer - delta)
	_line_dummy_feedback_cooldown = max(0.0, _line_dummy_feedback_cooldown - delta)

	_process_status_effects(delta)
	_process_parasite_timers(delta)
	_process_parasite_runtime(delta)
	_process_modifier_visuals(delta)
	_process_fractal_slime_feedback(delta)
	_process_elite_affix(delta)
	_process_boss_phase_template(delta)
	if _process_phalanx_ballistic(delta):
		return
	if local_hitstop_timer > 0.0:
		local_hitstop_timer = max(0.0, local_hitstop_timer - delta)
		if local_hitstop_timer <= 0.0:
			_resume_local_hitstop_visuals()
		return
	if _process_parasite_pull(delta):
		return
	
	# 鍓垁鎵嬪垏绾?
	if enemy_type == EnemyType.LINE_BREAKER:
		_check_line_break()
	
	# 鐘舵€佹満閫昏緫
	match current_ai_state:
		AIState.CHASE:
			_state_chase(delta)
		AIState.PREPARING:
			_state_preparing(delta)
		AIState.CHARGING:
			_state_charging(delta)
		AIState.COOLDOWN:
			_state_cooldown(delta)

func apply_elite_affix(affix_id: String, params: Dictionary = {}) -> void:
	elite_affix_id = affix_id
	elite_affix_params = params.duplicate(true)
	if elite_affix_id.is_empty():
		return
	
	var visual_node: Node2D = visuals
	if not is_instance_valid(visual_node):
		visual_node = get_node_or_null("Visuals") as Node2D

	match elite_affix_id.to_lower():
		"swift":
			var speed_mult := float(params.get("speed_mult", 1.35))
			speed *= speed_mult
			if is_instance_valid(visual_node):
				visual_node.modulate = visual_node.modulate.lerp(Color(0.7, 1.4, 2.0, 1.0), 0.35)
		"titan":
			var hp_mult := float(params.get("hp_mult", 1.6))
			var dmg_mult := float(params.get("dmg_mult", 1.25))
			damage *= dmg_mult
			if health_component:
				health_component.max_health *= hp_mult
				health_component.current_health = health_component.max_health
			health *= hp_mult
			if is_instance_valid(visual_node):
				visual_node.scale *= 1.15
				visual_node.modulate = visual_node.modulate.lerp(Color(1.6, 1.2, 0.8, 1.0), 0.35)
		"vamp":
			_affix_vamp_tick = 0.0
			if is_instance_valid(visual_node):
				visual_node.modulate = visual_node.modulate.lerp(Color(1.5, 0.5, 0.6, 1.0), 0.30)
		"split":
			if is_instance_valid(visual_node):
				visual_node.modulate = visual_node.modulate.lerp(Color(1.0, 1.0, 1.8, 1.0), 0.30)
		_:
			pass

	Global.spawn_floating_text(global_position, affix_id.to_upper(), Color(1.4, 1.6, 2.0))
	_sync_contact_hitbox_damage()

func _process_elite_affix(delta: float) -> void:
	if elite_affix_id.to_lower() != "vamp":
		return
	if not health_component:
		return
	_affix_vamp_tick += delta
	if _affix_vamp_tick < 1.0:
		return
	_affix_vamp_tick = 0.0
	var heal_amount: float = max(1.0, float(health_component.max_health) * 0.01)
	health_component.heal(heal_amount)

func _init_boss_phase_template() -> void:
	var grouped: Dictionary = ConfigRepository.load_boss_phase_configs()
	if not grouped.has(enemy_id):
		return
	boss_phase_configs = grouped.get(enemy_id, [])
	if boss_phase_configs.is_empty():
		return

	_boss_base_speed = speed
	_boss_base_damage = damage
	boss_current_phase = int(boss_phase_configs[0].get("phase", 1))
	_apply_boss_phase(boss_current_phase, true)

func _process_boss_phase_template(_delta: float) -> void:
	if boss_phase_configs.is_empty():
		return
	if not health_component:
		return
	if health_component.max_health <= 0:
		return

	var hp_ratio := float(health_component.current_health) / float(health_component.max_health)
	var target_phase := boss_current_phase
	for phase_cfg in boss_phase_configs:
		var threshold := float(phase_cfg.get("trigger_hp_ratio", 1.0))
		var phase_no := int(phase_cfg.get("phase", 1))
		if hp_ratio <= threshold:
			target_phase = max(target_phase, phase_no)

	if target_phase > boss_current_phase:
		_apply_boss_phase(target_phase, false)

func _apply_boss_phase(phase_no: int, is_initial: bool) -> void:
	var phase_cfg := _get_boss_phase_config(phase_no)
	if phase_cfg.is_empty():
		return

	var speed_mul := float(phase_cfg.get("speed_multiplier", 1.0))
	var damage_mul := float(phase_cfg.get("damage_multiplier", 1.0))
	var budget_mul := float(phase_cfg.get("spawn_budget_multiplier", 1.0))
	var event_tag := str(phase_cfg.get("event_tag", ""))

	speed = _boss_base_speed * speed_mul
	damage = _boss_base_damage * damage_mul
	_sync_contact_hitbox_damage()
	boss_current_phase = phase_no
	set_meta("boss_phase_budget_multiplier", budget_mul)
	set_meta("boss_phase_event_tag", event_tag)
	if has_method("on_boss_phase_changed"):
		call("on_boss_phase_changed", phase_no, is_initial, event_tag)

	if not is_initial:
		Global.spawn_floating_text(global_position, "BOSS P%d" % phase_no, Color(1.6, 0.8, 0.2))
		SoundManager.play("enemy_charge_warning")

	if DEBUG_VERBOSE: print("[Enemy][BossPhase] enemy=%s phase=%d speed_mul=%.2f damage_mul=%.2f budget_mul=%.2f event=%s" % [
		enemy_id, phase_no, speed_mul, damage_mul, budget_mul, event_tag
	])

func _get_boss_phase_config(phase_no: int) -> Dictionary:
	for phase_cfg in boss_phase_configs:
		if int(phase_cfg.get("phase", 0)) == phase_no:
			return phase_cfg
	return {}

func _sync_contact_hitbox_damage() -> void:
	if not contact_hitbox:
		return
	var final_damage: float = max(1.0, damage)
	contact_hitbox.setup(final_damage, false, 0.0, self)

# --- 鐘舵€侊細杩介€?(榛樿) ---
func _state_chase(delta: float) -> void:
	# 1. 妫€鏌ヨ兘涓嶈兘鍔?
	if not can_move: 
		return
	
	# 2. 妫€鏌ョ帺瀹舵槸鍚﹀瓨鍦?
	if not is_instance_valid(Global.player):
		return

	# 3. 妫€鏌ヨ窛绂?
	var dist = global_position.distance_to(Global.player.global_position)

	# 濡傛灉璺濈灏忎簬鍋滄璺濈 (渚嬪璐磋劯浜?锛屽氨涓嶇Щ鍔ㄤ簡
	if dist <= stop_distance:
		return
	
	# 4. 鎵ц绉诲姩
	var move_vec: Vector2 = _get_chase_steering(Global.player)
	move_vec += knockback_dir * knockback_power
	move_vec = move_vec.limit_length(1.0)
	if _is_movement_locked():
		return
	var motion: Vector2 = move_vec * _current_move_speed() * delta
	if knockback_power > 0.0:
		var wall_hit: Dictionary = _detect_knockback_wall_hit(motion)
		if not wall_hit.is_empty():
			if BondManager != null and BondManager.has_method("on_enemy_knockback_wall_impact"):
				BondManager.on_enemy_knockback_wall_impact(self, _last_knockback_payload.duplicate(true), wall_hit)
			reset_knockback()
			return
	position += motion
	update_rotation()
	
	# 5. 鍐查攱鍒ゅ畾
	if can_charge:
		if dist < 300.0 and dist > 100.0: 
			start_charge_sequence()

func _get_chase_steering(target_node: Node2D) -> Vector2:
	if not is_instance_valid(target_node):
		return Vector2.ZERO

	var to_player: Vector2 = target_node.global_position - global_position
	var distance_to_player: float = to_player.length()
	if distance_to_player <= 0.001:
		return Vector2.ZERO

	var dir_to_player: Vector2 = to_player / distance_to_player
	var tangent: Vector2 = Vector2(-dir_to_player.y, dir_to_player.x)
	var ring_offset: float = distance_to_player - engagement_radius
	var safe_band: float = max(1.0, engagement_band)
	var radial_weight: float = clamp(ring_offset / safe_band, -1.0, 1.0)
	var ring_closeness: float = 1.0 - clamp(abs(ring_offset) / safe_band, 0.0, 1.0)
	var safe_separation: float = max(1.0, desired_separation)

	var separation_force := Vector2.ZERO
	var tangent_force := Vector2.ZERO
	var flank_force := Vector2.ZERO

	if ring_closeness > 0.0:
		flank_force = tangent * _flank_direction * flank_bias_strength * ring_closeness

	for area: Node2D in vision_area.get_overlapping_areas():
		if area == self or not area.is_inside_tree():
			continue
		if not area.is_in_group("enemies"):
			continue

		var to_other: Vector2 = area.global_position - global_position
		var distance: float = to_other.length()
		if distance <= 0.001:
			continue

		var away_from_other: Vector2 = -to_other / distance
		var push_strength: float = clamp(1.0 - (distance / safe_separation), 0.0, 1.0)
		if push_strength <= 0.0:
			continue
		separation_force += away_from_other * push_strength

		if not tangential_slip_enabled:
			continue

		var forward_dot: float = dir_to_player.dot(to_other / distance)
		if forward_dot <= tangential_front_dot_threshold:
			continue

		var side_sign: float = -sign(dir_to_player.cross(to_other))
		if is_zero_approx(side_sign):
			side_sign = _encircle_side_preference

		var distance_weight: float = clamp(1.0 - (distance / max(1.0, tangential_distance_falloff)), 0.0, 1.0)
		var slip_strength: float = push_strength * forward_dot * distance_weight
		tangent_force += tangent * side_sign * slip_strength

	if separation_force.length_squared() > 0.0:
		separation_force = separation_force.normalized()
	if tangent_force.length_squared() > 0.0:
		tangent_force = tangent_force.normalized()

	var tangent_weight: float = chase_tangent_weight
	if ring_closeness > 0.0:
		tangent_weight *= lerp(1.0, ring_tangent_boost, ring_closeness)

	var blocker_tangent_force: Vector2 = tangent_force * tangential_slip_strength
	if flank_force.length_squared() > 0.0 and blocker_tangent_force.length_squared() > 0.0:
		var tangent_alignment: float = flank_force.normalized().dot(blocker_tangent_force.normalized())
		var flank_blend: float = lerp(0.2, 0.65, (tangent_alignment + 1.0) * 0.5)
		flank_force *= flank_blend

	var steering := dir_to_player * (radial_weight * chase_radial_weight)
	steering += separation_force * chase_separation_weight
	steering += flank_force * tangent_weight
	steering += blocker_tangent_force * tangent_weight
	return steering

# --- 1. 瑙﹀彂鍐查攱搴忓垪 (鐢熸垚绾㈢嚎) ---
func start_charge_sequence() -> void:
	current_ai_state = AIState.PREPARING
	ai_timer = charge_prep_time
	SoundManager.play("enemy_charge_warning")
	
	# 閿佸畾鍐查攱鏂瑰悜 (褰掍竴鍖栵紒)
	charge_vector = global_position.direction_to(Global.player.global_position).normalized()
	
	# 鏁屼汉鍙樿壊鎻愮ず
	var tween = create_tween()
	tween.tween_property(visuals, "modulate", Color(3.0, 0.5, 0.5, 1.0), 0.2) 
	
	# 缁樺埗棰勮鍖哄煙 (鍥哄畾闀垮害锛屼緥濡?500px)
	var end_pos = global_position + (charge_vector * 500.0)
	
	warning_line.clear_points()
	warning_line.add_point(global_position)
	warning_line.add_point(end_pos)
	
	# 绾㈢嚎鍔ㄧ敾锛氬崐閫忔槑娣″叆 -> 鍙樼粏涓€鐐圭偣
	warning_line.default_color = Color(1, 0, 0, 0)
	warning_line.width = 40.0
	
	var line_tween = create_tween()
	# 0.2绉掓贰鍏ュ埌鍗婇€忔槑 (0.3 alpha)
	line_tween.tween_property(warning_line, "default_color", Color(1, 0, 0, 0.3), 0.2)
	# 鍚屾椂瀹藉害绋嶅井鏀剁缉锛屽鍔犺仛鐒︽劅
	line_tween.parallel().tween_property(warning_line, "width", 20.0, charge_prep_time)

# --- 2. 棰勮闃舵 (鍋滃湪鍘熷湴锛岄ⅳ鎶? ---
func _state_preparing(delta: float) -> void:
	ai_timer -= delta
	
	# 瑙嗚闇囧姩
	if _is_movement_locked():
		visuals.position = Vector2.ZERO
	else:
		visuals.position = Vector2(randf_range(-2, 2), randf_range(-2, 2))
	
	# 鏇存柊绾㈢嚎璧风偣 (璺熼殢鎬墿)锛岀粓鐐瑰浐瀹?(涓嶈拷韪帺瀹朵簡锛岃繖灏辨槸缁欑帺瀹惰翰閬跨殑鏈轰細)
	if warning_line.points.size() > 1:
		warning_line.set_point_position(0, global_position)
	
	if ai_timer <= 0:
		enter_charge_state()

# --- 3. 杩涘叆鍐查攱 (鍔ㄤ綔鍒囨崲) ---
func enter_charge_state() -> void:
	current_ai_state = AIState.CHARGING
	ai_timer = charge_duration
	SoundManager.play("enemy_charge")
	
	# 鎭㈠瑙嗚
	visuals.position = Vector2.ZERO
	visuals.modulate = original_modulate
	
	# 闅愯棌绾㈢嚎
	warning_line.default_color = Color(1, 0, 0, 0)
	warning_line.clear_points()
	
	# 鎾斁鍐查攱鍔ㄧ敾锛堝鏋滄槸鍒虹尙锛?
	if enemy_type == EnemyType.SPIKED and has_node("AnimationEffects"):
		var anim_player = get_node("AnimationEffects") as AnimationPlayer
		if anim_player:
			anim_player.play("charge")
	
	# 鎾斁鍐查攱闊虫晥
	# Global.play_sfx(...)
	
# --- 4. 鍐查攱闃舵 (娌跨洿绾夸綅绉? ---
func _state_charging(delta: float) -> void:
	ai_timer -= delta
	
	# 銆愭牳蹇冧慨澶嶃€戝彧娌跨潃閿佸畾鐨?charge_vector 绉诲姩锛屼笉杩涜浠讳綍瀵昏矾璁＄畻
	# 涓嶄娇鐢?move_and_slide锛岀洿鎺ヤ慨鏀?position锛岄伩鍏嶇墿鐞嗙鎾炲鑷寸殑濂囨€粦姝ワ紙濡傛灉鏄疉rea2D绫诲瀷鐨勫崟浣嶏級
	# 濡傛灉鏄?CharacterBody2D锛岃鐢?velocity = ... move_and_slide()
	
	if _is_movement_locked():
		if ai_timer <= 0:
			current_ai_state = AIState.COOLDOWN
			ai_timer = charge_cooldown
		return
	var motion: Vector2 = charge_vector * _current_move_speed() * charge_speed_mult * delta
	var start_pos: Vector2 = global_position
	if _handle_charge_cage_collision(motion):
		return
	var next_pos: Vector2 = start_pos + motion
	var hit_result := _charge_hits_open_assets(start_pos, next_pos)
	if bool(hit_result.get("hit", false)):
		_apply_charge_open_line_hit(hit_result)
		return
	position = next_pos
	
	# 杩欓噷涓嶆洿鏂版湞鍚戯紝淇濇寔鍐查攱鏃剁殑闇镐綋鎰?
	
	if ai_timer <= 0:
		current_ai_state = AIState.COOLDOWN
		ai_timer = charge_cooldown

# --- 5. 鍐峰嵈闃舵 ---
func _state_cooldown(delta: float) -> void:
	ai_timer -= delta
	
	# 缂撴參绉诲姩
	if _is_movement_locked():
		if ai_timer <= 0:
			current_ai_state = AIState.CHASE
		return
	var move_vec = get_move_direction() * 0.2
	position += move_vec * _current_move_speed() * delta
	update_rotation()
	
	if ai_timer <= 0:
		current_ai_state = AIState.CHASE

func is_tactical_reject_elite_immune() -> bool:
	return self is EnemyElites or not elite_affix_id.is_empty() or is_boss_enemy()

func is_boss_enemy() -> bool:
	if not boss_phase_configs.is_empty():
		return true
	var config: Dictionary = ConfigManager.get_enemy_config(enemy_id)
	return str(config.get("role", "")).strip_edges().to_lower() == "boss"

func apply_tactical_reject(origin: Vector2, push_distance: float, stun_duration: float) -> Dictionary:
	var result: Dictionary = {
		"pushed": false,
		"interrupted": false,
		"immune": false,
	}
	if is_dead:
		return result

	var push_dir: Vector2 = global_position - origin
	if push_dir.length_squared() <= 0.0001:
		push_dir = Vector2.RIGHT.rotated(randf() * TAU)
	else:
		push_dir = push_dir.normalized()

	var immune_to_push: bool = is_tactical_reject_elite_immune()
	result["immune"] = immune_to_push
	var can_interrupt: bool = _can_be_interrupted_by_tactical_reject()
	if can_interrupt:
		_interrupt_for_tactical_reject(stun_duration, immune_to_push)
		result["interrupted"] = true

	if immune_to_push:
		return result

	global_position = _resolve_tactical_reject_target(push_dir, push_distance)
	if not can_interrupt:
		apply_status("stun", stun_duration, 0.0, 1, 1.0)
		_play_charge_hit_feedback("PUSH!", Color(0.82, 0.96, 1.0), false)
	result["pushed"] = true
	return result

func _can_be_interrupted_by_tactical_reject() -> bool:
	return current_ai_state == AIState.PREPARING or current_ai_state == AIState.CHARGING

func _interrupt_for_tactical_reject(stun_duration: float, show_break_feedback: bool = true) -> void:
	current_ai_state = AIState.COOLDOWN
	ai_timer = max(max(stun_duration, 0.2), charge_cooldown * 0.35)
	charge_vector = Vector2.ZERO
	visuals.position = Vector2.ZERO
	visuals.modulate = original_modulate
	if warning_line:
		warning_line.default_color = Color(1, 0, 0, 0)
		warning_line.clear_points()
	apply_status("stun", stun_duration, 0.0, 1, 1.0)
	if show_break_feedback:
		_play_charge_hit_feedback("BREAK!", Color(0.92, 0.98, 1.0), false)

func _resolve_tactical_reject_target(push_dir: Vector2, push_distance: float) -> Vector2:
	var start_pos: Vector2 = global_position
	var target_pos: Vector2 = start_pos + push_dir * push_distance
	var world := get_world_2d()
	if world == null:
		return target_pos
	var space_state := world.direct_space_state
	var query := PhysicsRayQueryParameters2D.create(start_pos, target_pos)
	query.collide_with_bodies = true
	query.collide_with_areas = false
	var hit: Dictionary = space_state.intersect_ray(query)
	if hit.is_empty():
		return target_pos
	var hit_position: Vector2 = hit.get("position", target_pos)
	return hit_position - push_dir * 8.0

func _setup_charge_shape_cast() -> void:
	if is_instance_valid(_charge_shape_cast):
		return
	_charge_shape_cast = ShapeCast2D.new()
	_charge_shape_cast.name = "ChargeShapeCast"
	_charge_shape_cast.enabled = true
	_charge_shape_cast.collide_with_areas = false
	_charge_shape_cast.collide_with_bodies = true
	_charge_shape_cast.collision_mask = charge_cage_collision_mask
	var cast_shape := CircleShape2D.new()
	cast_shape.radius = max(1.0, charge_cast_radius)
	_charge_shape_cast.shape = cast_shape
	add_child(_charge_shape_cast)

func _handle_charge_cage_collision(motion: Vector2) -> bool:
	if not is_instance_valid(_charge_shape_cast):
		return false
	if motion.length_squared() <= 0.0001:
		return false
	_charge_shape_cast.global_position = global_position
	_charge_shape_cast.target_position = motion
	_charge_shape_cast.force_shapecast_update()
	if not _charge_shape_cast.is_colliding():
		return false
	var safe_fraction: float = _charge_shape_cast.get_closest_collision_safe_fraction()
	var clamped_fraction: float = clamp(safe_fraction - charge_cast_backoff, 0.0, 1.0)
	global_position += motion * clamped_fraction
	var collision_normal: Vector2 = _charge_shape_cast.get_collision_normal(0)
	_on_charge_cage_crash(collision_normal)
	return true

func _on_charge_cage_crash(collision_normal: Vector2) -> void:
	current_ai_state = AIState.COOLDOWN
	ai_timer = max(ai_timer, charge_cooldown)
	if collision_normal.length_squared() > 0.0001:
		global_position += collision_normal.normalized() * charge_wall_rebound_distance
	apply_status("stun", charge_wall_stun_duration, 0.0, 1, 1.0)
	_play_charge_hit_feedback("THUD!", Color(1.0, 0.82, 0.72), true)

func _charge_hits_open_assets(from_pos: Vector2, to_pos: Vector2) -> Dictionary:
	var result: Dictionary = {"hit": false}
	if not charge_open_line_check_enabled:
		return result
	var sweep_rect: Rect2 = _build_rect_between_points(from_pos, to_pos, charge_open_line_radius)
	var assets: Array[Dictionary] = SkillAssetRegistry.list_scene_assets(self, "", "", charge_open_line_max_age_msec)
	var now_msec: int = Time.get_ticks_msec()
	var min_interval_msec: int = int(round(charge_open_line_hit_interval * 1000.0))
	for asset: Dictionary in assets:
		var asset_id: String = str(asset.get("asset_id", ""))
		if not asset_id.is_empty():
			var last_hit_msec: int = int(_charge_line_hit_msec_by_asset.get(asset_id, -999999))
			if now_msec - last_hit_msec < min_interval_msec:
				continue
		var payload_var: Variant = asset.get("payload", {})
		if not (payload_var is Dictionary):
			continue
		var payload: Dictionary = payload_var
		if bool(payload.get("is_closed", false)):
			continue
		var asset_rect: Rect2 = payload.get("aabb", Rect2())
		if asset_rect == Rect2() or not asset_rect.intersects(sweep_rect):
			continue
		var segments_var: Variant = payload.get("segments", [])
		if not (segments_var is Array):
			continue
		for seg_var: Variant in segments_var:
			if not (seg_var is Dictionary):
				continue
			var seg: Dictionary = seg_var
			var seg_rect: Rect2 = seg.get("aabb", Rect2())
			if seg_rect != Rect2() and not seg_rect.intersects(sweep_rect):
				continue
			var start: Vector2 = seg.get("start", Vector2.ZERO)
			var end_pos: Vector2 = seg.get("end", Vector2.ZERO)
			if _segment_distance(from_pos, to_pos, start, end_pos) > charge_open_line_radius:
				continue
			result["hit"] = true
			result["asset"] = asset
			result["segment"] = seg
			return result
	return result

func _apply_charge_open_line_hit(hit_result: Dictionary) -> void:
	var asset: Dictionary = hit_result.get("asset", {})
	var damage_amount: int = _resolve_charge_open_line_damage(asset)
	if damage_amount > 0 and health_component:
		health_component.take_damage(damage_amount, {
			"source": asset.get("owner", null),
			"kind": "charge_open_line_hit",
			"damage_type": "DMG_DIRECT",
		})
	var asset_id: String = str(asset.get("asset_id", ""))
	if not asset_id.is_empty():
		_charge_line_hit_msec_by_asset[asset_id] = Time.get_ticks_msec()
	_play_charge_hit_feedback("CUT!", Color(1.0, 1.0, 1.0), false)

func _resolve_charge_open_line_damage(asset: Dictionary) -> int:
	var owner_instance_id: int = int(asset.get("owner_instance_id", 0))
	if owner_instance_id > 0:
		var owner_obj: Object = instance_from_id(owner_instance_id)
		if owner_obj != null and is_instance_valid(owner_obj) and owner_obj is Node:
			var owner_node: Node = owner_obj
			if "damage" in owner_node:
				return max(1, int(round(float(owner_node.get("damage")) * charge_open_line_damage_ratio)))
	return max(1, int(round(damage * charge_open_line_damage_ratio)))

func _play_charge_hit_feedback(label: String, flash_color: Color, heavy_hit: bool) -> void:
	set_flash_material()
	local_hitstop_timer = max(local_hitstop_timer, charge_local_hitstop_duration)
	_pause_local_hitstop_visuals()
	var tween = create_tween()
	tween.tween_property(visuals, "modulate", flash_color, 0.02)
	tween.tween_property(visuals, "modulate", original_modulate, 0.08 if heavy_hit else 0.06)
	Global.spawn_floating_text(global_position, label, flash_color)
	if heavy_hit:
		Global.on_camera_shake.emit(4.0, 0.08)

func _pause_local_hitstop_visuals() -> void:
	if anim_player and anim_player.is_playing():
		anim_player.pause()
		_resume_base_anim_after_hitstop = true
	var charge_anim := get_node_or_null("AnimationEffects") as AnimationPlayer
	if charge_anim and charge_anim.is_playing():
		charge_anim.pause()
		_resume_charge_anim_after_hitstop = true

func _resume_local_hitstop_visuals() -> void:
	if _resume_base_anim_after_hitstop and anim_player:
		anim_player.play()
	_resume_base_anim_after_hitstop = false
	var charge_anim := get_node_or_null("AnimationEffects") as AnimationPlayer
	if _resume_charge_anim_after_hitstop and charge_anim:
		charge_anim.play()
	_resume_charge_anim_after_hitstop = false

func _build_rect_between_points(from_pos: Vector2, to_pos: Vector2, padding: float = 0.0) -> Rect2:
	var min_x: float = min(from_pos.x, to_pos.x)
	var min_y: float = min(from_pos.y, to_pos.y)
	var max_x: float = max(from_pos.x, to_pos.x)
	var max_y: float = max(from_pos.y, to_pos.y)
	var rect := Rect2(Vector2(min_x, min_y), Vector2(max_x - min_x, max_y - min_y))
	return rect.grow(max(0.0, padding))

func _segment_distance(a_start: Vector2, a_end: Vector2, b_start: Vector2, b_end: Vector2) -> float:
	if Geometry2D.segment_intersects_segment(a_start, a_end, b_start, b_end) != null:
		return 0.0
	var min_distance: float = INF
	min_distance = min(min_distance, a_start.distance_to(Geometry2D.get_closest_point_to_segment(a_start, b_start, b_end)))
	min_distance = min(min_distance, a_end.distance_to(Geometry2D.get_closest_point_to_segment(a_end, b_start, b_end)))
	min_distance = min(min_distance, b_start.distance_to(Geometry2D.get_closest_point_to_segment(b_start, a_start, a_end)))
	min_distance = min(min_distance, b_end.distance_to(Geometry2D.get_closest_point_to_segment(b_end, a_start, a_end)))
	return min_distance

func apply_parasite_state(duration: float = 8.0, source_attack: float = 0.0) -> void:
	if is_dead:
		return
	var was_parasitized: bool = is_parasitized
	is_parasitized = true
	parasite_timer = max(0.01, duration)
	parasite_pulse_timer = max(0.05, parasite_pulse_interval)
	if source_attack > 0.0:
		parasite_source_attack = max(parasite_source_attack, source_attack)
	apply_tag_marker("parasite_marker", "parasite", parasite_timer, CombatModifierComponent.STACK_REFRESH, Global.player)
	_refresh_parasite_visual()
	_share_parasite_state_to_linked(duration, source_attack)
	if not was_parasitized:
		Global.spawn_floating_text(global_position, "PARASITE", Color(0.62, 1.45, 0.62))

func clear_parasite_state(reset_pull: bool = true) -> void:
	is_parasitized = false
	parasite_timer = 0.0
	parasite_pulse_timer = 0.0
	parasite_source_attack = 0.0
	parasite_catalyst_timer = 0.0
	parasite_catalyst_attack = 0.0
	parasite_pending_detonation = false
	parasite_detonation_timer = 0.0
	parasite_detonation_attack = 0.0
	parasite_rooted = false
	if combat_modifier_component:
		combat_modifier_component.clear_tag_marker("parasite")
		combat_modifier_component.remove_modifier("parasite_pulse_slow")
	_refresh_parasite_visual()
	if reset_pull:
		parasite_pull_timer = 0.0
		parasite_pull_speed = 0.0
		parasite_pull_target = global_position

func start_parasite_pull(target_position: Vector2, duration: float = 0.35, speed_value: float = 450.0) -> void:
	if is_dead:
		return
	parasite_pull_target = target_position
	parasite_pull_timer = max(0.0, duration)
	parasite_pull_speed = max(0.0, speed_value)

func mark_parasite_catalyst_window(source_attack: float, duration: float = 0.5) -> void:
	if is_dead or not is_parasitized:
		return
	parasite_catalyst_timer = max(parasite_catalyst_timer, duration)
	parasite_catalyst_attack = max(parasite_catalyst_attack, source_attack)

func trigger_parasite_detonation(source_attack: float, delay: float = 0.5) -> void:
	if is_dead or not is_parasitized:
		return
	parasite_pending_detonation = true
	parasite_rooted = true
	parasite_detonation_timer = max(delay, parasite_f_detonation_delay)
	parasite_detonation_attack = max(parasite_detonation_attack, source_attack)
	parasite_pull_timer = 0.0
	parasite_pull_speed = 0.0
	Global.spawn_floating_text(global_position + Vector2(0, -18), "ARMED", Color(1.0, 0.38, 0.32))
	_refresh_parasite_visual()

func set_parasite_pit_presence(source_key: String, inside: bool, damage_bonus: float = 0.15, slow_ratio: float = 0.15) -> void:
	if source_key.is_empty():
		return
	if inside:
		_parasite_pit_sources[source_key] = {
			"damage_bonus": damage_bonus,
			"slow_ratio": slow_ratio,
		}
	else:
		_parasite_pit_sources.erase(source_key)

func get_incoming_damage_multiplier() -> float:
	var multiplier: float = 1.0
	if not _parasite_pit_sources.is_empty():
		var max_bonus: float = 0.0
		for source_data_var: Variant in _parasite_pit_sources.values():
			if source_data_var is Dictionary:
				var source_data: Dictionary = source_data_var
				max_bonus = max(max_bonus, float(source_data.get("damage_bonus", parasite_pit_damage_taken_bonus)))
		multiplier += max_bonus
	if combat_modifier_component:
		multiplier *= combat_modifier_component.get_damage_taken_multiplier()
	return multiplier

func preprocess_incoming_damage(raw_damage: float, payload: Dictionary = {}) -> Dictionary:
	var processed_payload: Dictionary = payload.duplicate(true)
	var damage_value: float = raw_damage
	if enemy_id == "line_dummy":
		return _preprocess_line_dummy_damage(damage_value, processed_payload)
	if enemy_id == "closure_dummy":
		return _preprocess_closure_dummy_damage(damage_value, processed_payload)
	if enemy_id != "phalanx_enforcer":
		return {
			"damage": damage_value,
			"payload": processed_payload,
		}

	var damage_type: int = COMBAT_EVENT_TYPES.normalize_damage_type(
		processed_payload.get("damage_type", COMBAT_EVENT_TYPES.DamageType.DIRECT)
	)
	processed_payload["damage_type"] = damage_type
	if damage_type != COMBAT_EVENT_TYPES.DamageType.DIRECT:
		return {
			"damage": damage_value,
			"payload": processed_payload,
		}

	var is_blocked: bool = _should_block_front_guard_payload(processed_payload)
	if not is_blocked:
		return {
			"damage": damage_value,
			"payload": processed_payload,
		}

	damage_value = 0.0
	processed_payload["blocked_by_front_guard"] = true
	Global.spawn_floating_text(global_position + Vector2(0, -18), "GUARD!", Color(0.66, 0.92, 1.0))
	if has_method("set_flash_material"):
		set_flash_material()
	if SoundManager != null and SoundManager.has_method("play"):
		SoundManager.play("enemy_charge_warning")
	return {
		"damage": damage_value,
		"payload": processed_payload,
	}

func _preprocess_line_dummy_damage(raw_damage: float, payload: Dictionary) -> Dictionary:
	var damage_value: float = raw_damage
	if _is_open_line_damage_payload(payload):
		damage_value *= 3.0
		if _line_dummy_feedback_cooldown <= 0.0:
			_line_dummy_feedback_cooldown = 0.18
			Global.spawn_floating_text(global_position + Vector2(0, -18), "LINE x3", Color(0.48, 0.92, 1.0))
	else:
		damage_value *= 0.2
		if _line_dummy_feedback_cooldown <= 0.0:
			_line_dummy_feedback_cooldown = 0.18
			Global.spawn_floating_text(global_position + Vector2(0, -18), "RESIST", Color(1.0, 0.84, 0.44))
	return {
		"damage": damage_value,
		"payload": payload,
	}

func _preprocess_closure_dummy_damage(raw_damage: float, payload: Dictionary) -> Dictionary:
	if _closure_dummy_vulnerable_timer > 0.0:
		return {
			"damage": raw_damage,
			"payload": payload,
		}
	if not bool(payload.get("allow_closure_dummy_damage", false)):
		payload["blocked_by_closure_dummy"] = true
		Global.spawn_floating_text(global_position + Vector2(0, -18), "SEALED", Color(1.0, 0.72, 0.36))
		return {
			"damage": 0.0,
			"payload": payload,
		}
	return {
		"damage": raw_damage,
		"payload": payload,
	}

func _should_block_front_guard_payload(payload: Dictionary) -> bool:
	if enemy_id != "phalanx_enforcer":
		return false
	var source_position: Vector2 = _extract_damage_source_position(payload)
	if source_position == Vector2.INF:
		return false
	var front_direction: Vector2 = _get_front_guard_direction()
	if front_direction.length_squared() <= 0.0001:
		return false
	var to_source: Vector2 = source_position - global_position
	if to_source.length_squared() <= 0.0001:
		return false
	return front_direction.normalized().dot(to_source.normalized()) >= 0.5

func _extract_damage_source_position(payload: Dictionary) -> Vector2:
	var source_position_variant: Variant = payload.get("source_position", Vector2.INF)
	if source_position_variant is Vector2:
		return source_position_variant
	var source_variant: Variant = payload.get("source", null)
	if typeof(source_variant) == TYPE_OBJECT:
		var source_object: Object = source_variant as Object
		if source_object != null and is_instance_valid(source_object) and source_object is Node2D:
			return (source_object as Node2D).global_position
	return Vector2.INF

func _get_front_guard_direction() -> Vector2:
	var target_node: Node2D = override_target
	if not is_instance_valid(target_node):
		target_node = Global.player
	if is_instance_valid(target_node):
		var to_target: Vector2 = target_node.global_position - global_position
		if to_target.length_squared() > 0.0001:
			return to_target.normalized()
	if is_instance_valid(visuals):
		return Vector2.RIGHT if visuals.scale.x < 0.0 else Vector2.LEFT
	return Vector2.LEFT

func _is_open_line_damage_payload(payload: Dictionary) -> bool:
	var explicit_mode: String = str(payload.get("space_skill_mode", "")).strip_edges().to_lower()
	if explicit_mode == "open":
		return true
	var kind: String = str(payload.get("kind", "")).strip_edges().to_lower()
	return OPEN_LINE_DAMAGE_KINDS.has(kind)

func _is_closed_space_damage_payload(payload: Dictionary) -> bool:
	var explicit_mode: String = str(payload.get("space_skill_mode", "")).strip_edges().to_lower()
	if explicit_mode == "closed":
		return true
	var kind: String = str(payload.get("kind", "")).strip_edges().to_lower()
	return CLOSED_SPACE_DAMAGE_KINDS.has(kind)

func _is_skill_slot_damage(payload: Dictionary, skill_slot: String) -> bool:
	var normalized_slot: String = skill_slot.strip_edges().to_lower()
	if normalized_slot.is_empty():
		return false
	var explicit_slot: String = str(payload.get("skill_slot", payload.get("source_slot", ""))).strip_edges().to_lower()
	if explicit_slot == normalized_slot:
		return true
	var kind: String = str(payload.get("kind", "")).strip_edges().to_lower()
	match normalized_slot:
		"e":
			return SKILL_E_DAMAGE_KINDS.has(kind)
		"f":
			return SKILL_F_DAMAGE_KINDS.has(kind)
		_:
			return false

func on_player_draw_release(_player: PlayerBase, release_data: Dictionary) -> void:
	if enemy_id != "closure_dummy":
		return
	if not bool(release_data.get("is_closed", false)):
		return
	var points_variant: Variant = release_data.get("points", PackedVector2Array())
	var polygon: PackedVector2Array = PackedVector2Array()
	if points_variant is PackedVector2Array:
		polygon = points_variant
	elif points_variant is Array:
		for point_variant: Variant in points_variant:
			if point_variant is Vector2:
				polygon.append(point_variant)
	if polygon.size() < 3:
		return
	if not Geometry2D.is_point_in_polygon(global_position, polygon):
		return
	_closure_dummy_vulnerable_timer = 2.0
	Global.spawn_floating_text(global_position + Vector2(0, -20), "OPEN 2.0s", Color(1.0, 0.66, 0.34))

func _process_parasite_timers(delta: float) -> void:
	if not is_parasitized:
		return

	if not parasite_pending_detonation:
		parasite_timer -= delta
		if parasite_timer <= 0.0:
			clear_parasite_state(false)
			return

	parasite_pulse_timer -= delta
	var pulse_interval: float = max(0.05, parasite_pulse_interval)
	while parasite_pulse_timer <= 0.0:
		parasite_pulse_timer += pulse_interval
		_emit_parasite_pulse()

func _emit_parasite_pulse() -> void:
	if not is_parasitized or is_dead:
		return

	var source_attack: float = parasite_source_attack if parasite_source_attack > 0.0 else damage
	var pulse_damage: int = max(1, int(round(max(1.0, source_attack) * parasite_pulse_damage_ratio)))
	Global.spawn_floating_text(global_position + Vector2(0, -14), "Pulse", Color(0.72, 1.18, 0.72))
	for enemy_node in get_tree().get_nodes_in_group("enemies"):
		if enemy_node == self:
			continue
		if not (enemy_node is Enemy):
			continue
		var enemy := enemy_node as Enemy
		if not is_instance_valid(enemy) or enemy.is_dead:
			continue
		if global_position.distance_to(enemy.global_position) > parasite_pulse_radius:
			continue
		enemy.apply_modifier_damage(pulse_damage, self, {
			"kind": "parasite_pulse",
			"damage_type": "DMG_DOT",
		})
		enemy.apply_move_speed_modifier(
			"parasite_pulse_slow",
			max(0.0, 1.0 - parasite_slow_ratio),
			parasite_pulse_interval,
			CombatModifierComponent.STACK_REPLACE_STRONGER,
			self,
			{"kind": "parasite_pulse"}
		)

func _process_parasite_pull(delta: float) -> bool:
	if parasite_rooted:
		parasite_pull_timer = 0.0
		parasite_pull_speed = 0.0
		return false
	if parasite_pull_timer <= 0.0 or parasite_pull_speed <= 0.0:
		return false

	var to_target: Vector2 = parasite_pull_target - global_position
	var distance_to_target: float = to_target.length()
	parasite_pull_timer = max(0.0, parasite_pull_timer - delta)

	if distance_to_target <= 2.0 or parasite_pull_timer <= 0.0:
		parasite_pull_timer = 0.0
		parasite_pull_speed = 0.0
		return true

	var motion: Vector2 = to_target.normalized() * min(distance_to_target, parasite_pull_speed * delta)
	if _is_parasite_pull_blocked(motion):
		parasite_pull_timer = 0.0
		parasite_pull_speed = 0.0
		return true

	global_position += motion
	update_rotation()
	return true

func _refresh_parasite_visual() -> void:
	if not is_instance_valid(visuals):
		return
	_refresh_modifier_visual_tint()
	if is_instance_valid(_parasite_ring):
		_parasite_ring.visible = is_parasitized or parasite_pending_detonation

func _process_parasite_runtime(delta: float) -> void:
	if parasite_catalyst_timer > 0.0:
		parasite_catalyst_timer = max(0.0, parasite_catalyst_timer - delta)
	if parasite_pending_detonation:
		parasite_detonation_timer = max(0.0, parasite_detonation_timer - delta)
		if parasite_detonation_timer <= 0.0:
			_execute_parasite_detonation()
			return
	_update_parasite_visual_fx(delta)

func _setup_parasite_ring() -> void:
	if is_instance_valid(_parasite_ring):
		return
	_parasite_ring = Line2D.new()
	_parasite_ring.name = "ParasiteRing"
	_parasite_ring.closed = true
	_parasite_ring.width = 5.0
	_parasite_ring.default_color = Color(0.58, 1.2, 0.52, 0.9)
	_parasite_ring.z_index = 3
	var ring_points := PackedVector2Array()
	var ring_segments: int = 24
	var ring_center: Vector2 = collision_shape.position if is_instance_valid(collision_shape) else Vector2.ZERO
	var ring_radius: float = 34.0
	if is_instance_valid(collision_shape) and collision_shape.shape is CircleShape2D:
		ring_radius = float((collision_shape.shape as CircleShape2D).radius) + 12.0
	for i in range(ring_segments + 1):
		var angle := (float(i) / float(ring_segments)) * TAU
		ring_points.append(ring_center + Vector2.RIGHT.rotated(angle) * ring_radius)
	_parasite_ring.points = ring_points
	_parasite_ring.visible = false
	add_child(_parasite_ring)
	_setup_joule_tar_ring()

func _update_parasite_visual_fx(delta: float) -> void:
	if not is_instance_valid(_parasite_ring):
		return
	if not (is_parasitized or parasite_pending_detonation):
		_parasite_ring.visible = false
		return
	_parasite_ring.visible = true
	_parasite_visual_pulse += delta * (8.0 if parasite_pending_detonation else 4.0)
	var pulse: float = 0.5 + 0.5 * sin(_parasite_visual_pulse)
	if parasite_pending_detonation:
		_parasite_ring.default_color = Color(1.0, 0.28, 0.22, lerp(0.35, 0.95, pulse))
		_parasite_ring.width = lerp(4.0, 8.0, pulse)
	else:
		_parasite_ring.default_color = Color(0.52, 1.0, 0.48, lerp(0.55, 0.92, pulse))
		_parasite_ring.width = lerp(4.0, 6.0, pulse)

func _get_parasite_visual_tint() -> Color:
	if parasite_pending_detonation:
		return Color(1.0, 0.42, 0.38, 1.0)
	return Color(0.58, 1.2, 0.52, 1.0)

func _setup_joule_tar_ring() -> void:
	if is_instance_valid(_joule_tar_ring):
		return
	_joule_tar_ring = Line2D.new()
	_joule_tar_ring.name = "JouleTarRing"
	_joule_tar_ring.closed = true
	_joule_tar_ring.width = 4.0
	_joule_tar_ring.default_color = Color(1.0, 0.58, 0.14, 0.92)
	_joule_tar_ring.z_index = 2
	var ring_points: PackedVector2Array = PackedVector2Array()
	var ring_segments: int = 24
	var ring_center: Vector2 = collision_shape.position if is_instance_valid(collision_shape) else Vector2.ZERO
	var ring_radius: float = 30.0
	if is_instance_valid(collision_shape) and collision_shape.shape is CircleShape2D:
		ring_radius = float((collision_shape.shape as CircleShape2D).radius) + 8.0
	for i: int in range(ring_segments + 1):
		var angle: float = (float(i) / float(ring_segments)) * TAU
		ring_points.append(ring_center + Vector2.RIGHT.rotated(angle) * ring_radius)
	_joule_tar_ring.points = ring_points
	_joule_tar_ring.visible = false
	add_child(_joule_tar_ring)

func _setup_soul_link_visuals() -> void:
	if not is_instance_valid(_soul_link_ring):
		_soul_link_ring = Line2D.new()
		_soul_link_ring.name = "SoulLinkRing"
		_soul_link_ring.closed = true
		_soul_link_ring.width = 4.0
		_soul_link_ring.default_color = Color(1.0, 0.22, 0.30, 0.90)
		_soul_link_ring.z_index = 4
		var ring_points: PackedVector2Array = PackedVector2Array()
		var ring_segments: int = 24
		var ring_center: Vector2 = collision_shape.position if is_instance_valid(collision_shape) else Vector2.ZERO
		var ring_radius: float = 28.0
		if is_instance_valid(collision_shape) and collision_shape.shape is CircleShape2D:
			ring_radius = float((collision_shape.shape as CircleShape2D).radius) + 10.0
		for i: int in range(ring_segments + 1):
			var angle: float = (float(i) / float(ring_segments)) * TAU
			ring_points.append(ring_center + Vector2.RIGHT.rotated(angle) * ring_radius)
		_soul_link_ring.points = ring_points
		_soul_link_ring.visible = false
		add_child(_soul_link_ring)
	if not is_instance_valid(_soul_link_tether):
		_soul_link_tether = Line2D.new()
		_soul_link_tether.name = "SoulLinkTether"
		_soul_link_tether.top_level = true
		_soul_link_tether.width = 3.0
		_soul_link_tether.default_color = Color(1.0, 0.30, 0.38, 0.72)
		_soul_link_tether.begin_cap_mode = Line2D.LINE_CAP_ROUND
		_soul_link_tether.end_cap_mode = Line2D.LINE_CAP_ROUND
		_soul_link_tether.antialiased = true
		_soul_link_tether.z_index = 58
		_soul_link_tether.visible = false
		add_child(_soul_link_tether)

func _process_modifier_visuals(delta: float) -> void:
	_update_joule_tar_visual_fx(delta)
	_update_soul_link_visual_fx(delta)
	if current_ai_state != AIState.PREPARING and local_hitstop_timer <= 0.0:
		_refresh_modifier_visual_tint()

func _refresh_modifier_visual_tint() -> void:
	if not is_instance_valid(visuals):
		return
	var tint_target: Color = original_modulate
	var has_tar: bool = _has_joule_tar()
	var has_tar_max: bool = _has_joule_tar_max()
	var has_soul_link: bool = _has_soul_link()
	var has_soul_link_empowered: bool = _has_empowered_soul_link()
	if has_tar:
		tint_target = tint_target.lerp(_get_joule_tar_visual_tint(has_tar_max), 0.48 if not has_tar_max else 0.66)
	if has_soul_link:
		tint_target = tint_target.lerp(_get_soul_link_visual_tint(has_soul_link_empowered), 0.42 if not has_soul_link_empowered else 0.62)
	if is_parasitized or parasite_pending_detonation:
		tint_target = tint_target.lerp(_get_parasite_visual_tint(), 0.58)
		_parasite_visual_active = true
	else:
		_parasite_visual_active = false
	visuals.modulate = tint_target

func _update_joule_tar_visual_fx(delta: float) -> void:
	if not is_instance_valid(_joule_tar_ring):
		return
	var has_tar: bool = _has_joule_tar()
	var has_tar_max: bool = _has_joule_tar_max()
	if not has_tar:
		_joule_tar_ring.visible = false
		return
	_joule_tar_ring.visible = true
	_joule_tar_visual_pulse += delta * (7.5 if has_tar_max else 4.5)
	var pulse: float = 0.5 + 0.5 * sin(_joule_tar_visual_pulse)
	if has_tar_max:
		_joule_tar_ring.default_color = Color(1.0, 0.34, 0.08, lerp(0.58, 0.98, pulse))
		_joule_tar_ring.width = lerp(4.0, 7.5, pulse)
	else:
		_joule_tar_ring.default_color = Color(1.0, 0.58, 0.12, lerp(0.46, 0.88, pulse))
		_joule_tar_ring.width = lerp(3.0, 5.5, pulse)

func _get_joule_tar_visual_tint(is_empowered: bool) -> Color:
	if is_empowered:
		return Color(1.0, 0.46, 0.16, 1.0)
	return Color(1.0, 0.66, 0.20, 1.0)

func _update_soul_link_visual_fx(delta: float) -> void:
	if not is_instance_valid(_soul_link_ring) or not is_instance_valid(_soul_link_tether):
		return
	var has_link: bool = _has_soul_link()
	var has_empowered_link: bool = _has_empowered_soul_link()
	if not has_link:
		_soul_link_ring.visible = false
		_soul_link_tether.visible = false
		return
	_soul_link_ring.visible = true
	_soul_link_visual_pulse += delta * (8.0 if has_empowered_link else 5.0)
	var pulse: float = 0.5 + 0.5 * sin(_soul_link_visual_pulse)
	if has_empowered_link:
		_soul_link_ring.default_color = Color(1.0, 0.14, 0.20, lerp(0.56, 0.98, pulse))
		_soul_link_ring.width = lerp(4.0, 7.0, pulse)
	else:
		_soul_link_ring.default_color = Color(1.0, 0.26, 0.34, lerp(0.42, 0.86, pulse))
		_soul_link_ring.width = lerp(3.0, 5.0, pulse)
	var nearest_linked_enemy: Enemy = _find_nearest_soul_linked_enemy()
	if nearest_linked_enemy == null:
		_soul_link_tether.visible = false
		return
	_soul_link_tether.visible = true
	_soul_link_tether.default_color = Color(1.0, 0.30, 0.38, lerp(0.28, 0.82, pulse))
	_soul_link_tether.width = lerp(2.0, 4.5, pulse)
	_soul_link_tether.points = PackedVector2Array([global_position, nearest_linked_enemy.global_position])

func _get_soul_link_visual_tint(is_empowered: bool) -> Color:
	if is_empowered:
		return Color(1.0, 0.32, 0.38, 1.0)
	return Color(1.0, 0.46, 0.52, 1.0)

func _has_joule_tar() -> bool:
	return combat_modifier_component != null and combat_modifier_component.has_tag_marker("joule_tar")

func _has_joule_tar_max() -> bool:
	return combat_modifier_component != null and combat_modifier_component.has_tag_marker("joule_tar_max")

func _has_soul_link() -> bool:
	return SILK_LINK_UTILS.has_link(self)

func _has_empowered_soul_link() -> bool:
	return SILK_LINK_UTILS.has_empowered_link(self)

func _ensure_combat_modifier_component() -> void:
	if combat_modifier_component and is_instance_valid(combat_modifier_component):
		return
	combat_modifier_component = get_node_or_null("CombatModifierComponent") as CombatModifierComponent
	if combat_modifier_component == null:
		combat_modifier_component = COMBAT_MODIFIER_COMPONENT.new()
		combat_modifier_component.name = "CombatModifierComponent"
		add_child(combat_modifier_component)

func apply_modifier_damage(raw_amount: float, _source: Variant = null, _payload: Dictionary = {}) -> void:
	if is_dead or health_component == null:
		return
	var final_damage: float = raw_amount
	var payload: Dictionary = _payload.duplicate(true)
	if _source != null and not payload.has("source"):
		payload["source"] = _source
	var damage_type: int = COMBAT_EVENT_TYPES.normalize_damage_type(
		payload.get(
			"damage_type",
			COMBAT_EVENT_TYPES.DamageType.TRUE_DAMAGE if bool(payload.get("true_damage", false)) else COMBAT_EVENT_TYPES.DamageType.DIRECT
		)
	)
	payload["damage_type"] = damage_type
	payload["is_shared_damage"] = bool(payload.get("is_shared_damage", false))
	var is_true_damage: bool = damage_type == COMBAT_EVENT_TYPES.DamageType.TRUE_DAMAGE or bool(payload.get("true_damage", false))
	if not is_true_damage:
		final_damage *= get_incoming_damage_multiplier()
	if is_true_damage:
		set_meta("ignore_incoming_damage_multiplier_once", true)
	if bool(payload.get("soul_link_propagated", false)):
		set_meta("soul_link_silent_damage", true)
	health_component.take_damage(final_damage, payload)
	if has_meta("ignore_incoming_damage_multiplier_once"):
		remove_meta("ignore_incoming_damage_multiplier_once")
	if has_meta("soul_link_silent_damage"):
		remove_meta("soul_link_silent_damage")

func apply_move_speed_modifier(modifier_id: String, multiplier: float, duration: float, stacking_rule: String = CombatModifierComponent.STACK_REFRESH, source: Variant = null, payload: Dictionary = {}) -> String:
	_ensure_combat_modifier_component()
	var applied_id: String = combat_modifier_component.apply_move_speed_multiplier(modifier_id, multiplier, duration, stacking_rule, source, payload)
	if _should_share_modifier_to_linked(modifier_id, payload, ""):
		for linked_enemy: Enemy in _get_other_soul_linked_enemies():
			var linked_payload: Dictionary = payload.duplicate(true)
			linked_payload["soul_link_skip_share"] = true
			linked_enemy.apply_move_speed_modifier(modifier_id, multiplier, duration, stacking_rule, source, linked_payload)
	return applied_id

func apply_damage_over_time_modifier(modifier_id: String, damage_per_tick: float, duration: float, tick_interval: float, stacking_rule: String = CombatModifierComponent.STACK_REFRESH, source: Variant = null, payload: Dictionary = {}) -> String:
	_ensure_combat_modifier_component()
	var applied_id: String = combat_modifier_component.apply_damage_over_time(modifier_id, damage_per_tick, duration, tick_interval, stacking_rule, source, payload)
	if _should_share_modifier_to_linked(modifier_id, payload, ""):
		for linked_enemy: Enemy in _get_other_soul_linked_enemies():
			var linked_payload: Dictionary = payload.duplicate(true)
			linked_payload["soul_link_skip_share"] = true
			linked_enemy.apply_damage_over_time_modifier(modifier_id, damage_per_tick, duration, tick_interval, stacking_rule, source, linked_payload)
	return applied_id

func apply_vulnerable_modifier(modifier_id: String, multiplier: float, duration: float, stacking_rule: String = CombatModifierComponent.STACK_REFRESH, source: Variant = null, payload: Dictionary = {}) -> String:
	_ensure_combat_modifier_component()
	var applied_id: String = combat_modifier_component.apply_vulnerable(modifier_id, multiplier, duration, stacking_rule, source, payload)
	if _should_share_modifier_to_linked(modifier_id, payload, ""):
		for linked_enemy: Enemy in _get_other_soul_linked_enemies():
			var linked_payload: Dictionary = payload.duplicate(true)
			linked_payload["soul_link_skip_share"] = true
			linked_enemy.apply_vulnerable_modifier(modifier_id, multiplier, duration, stacking_rule, source, linked_payload)
	return applied_id

func apply_tag_marker(modifier_id: String, tag_name: String, duration: float, stacking_rule: String = CombatModifierComponent.STACK_REFRESH, source: Variant = null, payload: Dictionary = {}) -> String:
	_ensure_combat_modifier_component()
	var applied_id: String = combat_modifier_component.apply_tag_marker(modifier_id, tag_name, duration, stacking_rule, source, payload)
	if _should_share_modifier_to_linked(modifier_id, payload, tag_name):
		for linked_enemy: Enemy in _get_other_soul_linked_enemies():
			var linked_payload: Dictionary = payload.duplicate(true)
			linked_payload["soul_link_skip_share"] = true
			linked_enemy.apply_tag_marker(modifier_id, tag_name, duration, stacking_rule, source, linked_payload)
	return applied_id

func on_health_component_damage_applied(applied_damage: float, payload: Dictionary = {}) -> void:
	if applied_damage <= 0.0:
		return
	_last_damage_payload = payload.duplicate(true)
	if has_meta("soul_link_silent_damage"):
		return
	if bool(payload.get("is_shared_damage", false)):
		return
	if bool(payload.get("soul_link_skip_share", false)):
		return
	if not _has_soul_link():
		return
	var transmission_ratio: float = SILK_LINK_UTILS.get_transmission_ratio(_has_empowered_soul_link())
	var shared_damage: float = applied_damage * transmission_ratio
	if shared_damage <= 0.0:
		return
	for linked_enemy: Enemy in _get_other_soul_linked_enemies():
		linked_enemy.apply_modifier_damage(shared_damage, self, {
			"true_damage": true,
			"damage_type": COMBAT_EVENT_TYPES.DamageType.TRUE_DAMAGE,
			"is_shared_damage": true,
			"soul_link_propagated": true,
			"kind": "soul_link_damage",
		})
		if linked_enemy.has_method("set_flash_material"):
			linked_enemy.set_flash_material()
		Global.spawn_floating_text(linked_enemy.global_position + Vector2(0, -14), "LINK", Color(1.0, 0.42, 0.50))

func _should_share_modifier_to_linked(modifier_id: String, payload: Dictionary, tag_name: String) -> bool:
	if not _has_soul_link():
		return false
	if bool(payload.get("soul_link_skip_share", false)):
		return false
	if modifier_id.begins_with("soul_link"):
		return false
	if tag_name == SILK_LINK_UTILS.LINK_TAG or tag_name == SILK_LINK_UTILS.LINK_EMPOWERED_TAG:
		return false
	return true

func _get_other_soul_linked_enemies() -> Array[Enemy]:
	var linked_enemies: Array[Enemy] = []
	for enemy_node: Node in get_tree().get_nodes_in_group("enemies"):
		if not (enemy_node is Enemy):
			continue
		var enemy: Enemy = enemy_node as Enemy
		if enemy == self or not is_instance_valid(enemy) or enemy.is_dead:
			continue
		if not SILK_LINK_UTILS.has_link(enemy):
			continue
		linked_enemies.append(enemy)
	return linked_enemies

func _find_nearest_soul_linked_enemy() -> Enemy:
	var nearest_enemy: Enemy = null
	var nearest_distance_sq: float = INF
	for linked_enemy: Enemy in _get_other_soul_linked_enemies():
		var distance_sq: float = global_position.distance_squared_to(linked_enemy.global_position)
		if distance_sq < nearest_distance_sq:
			nearest_distance_sq = distance_sq
			nearest_enemy = linked_enemy
	return nearest_enemy

func _share_parasite_state_to_linked(duration: float, source_attack: float) -> void:
	if not _has_soul_link():
		return
	if has_meta("soul_link_parasite_share"):
		return
	for linked_enemy: Enemy in _get_other_soul_linked_enemies():
		linked_enemy.set_meta("soul_link_parasite_share", true)
		linked_enemy.apply_parasite_state(duration, source_attack)
		if linked_enemy.has_meta("soul_link_parasite_share"):
			linked_enemy.remove_meta("soul_link_parasite_share")

func _current_move_speed() -> float:
	var pit_slow: float = 0.0
	for source_data_var: Variant in _parasite_pit_sources.values():
		if source_data_var is Dictionary:
			var source_data: Dictionary = source_data_var
			pit_slow = max(pit_slow, float(source_data.get("slow_ratio", parasite_pit_slow_ratio)))
	var move_speed: float = speed * max(0.0, 1.0 - pit_slow)
	if combat_modifier_component:
		move_speed *= combat_modifier_component.get_move_speed_multiplier()
	return move_speed

func _is_movement_locked() -> bool:
	return not can_move or parasite_rooted or phalanx_motion_lock_count > 0

func _execute_parasite_detonation() -> void:
	if is_dead:
		return
	parasite_pending_detonation = false
	parasite_rooted = false
	var detonation_center: Vector2 = global_position
	var source_attack: float = parasite_detonation_attack if parasite_detonation_attack > 0.0 else parasite_source_attack
	var detonation_damage: int = max(1, int(round(max(1.0, source_attack) * parasite_f_detonation_damage_ratio)))
	clear_parasite_state(false)
	Global.spawn_floating_text(detonation_center, "BURST!", Color(1.0, 0.46, 0.34))
	for enemy_node in get_tree().get_nodes_in_group("enemies"):
		if not (enemy_node is Enemy):
			continue
		var enemy := enemy_node as Enemy
		if not is_instance_valid(enemy) or enemy.is_dead or enemy == self:
			continue
		if detonation_center.distance_to(enemy.global_position) > parasite_f_detonation_radius:
			continue
		if enemy.health_component:
			enemy.health_component.take_damage(detonation_damage, {
				"source": self,
				"kind": "parasite_f_detonation",
				"damage_type": "DMG_AOE",
			})

func _trigger_parasite_catalyst_spread_on_death() -> void:
	if parasite_catalyst_timer <= 0.0:
		return
	var spread_origin: Vector2 = global_position
	var source_attack: float = parasite_catalyst_attack if parasite_catalyst_attack > 0.0 else parasite_source_attack
	var candidates: Array[Enemy] = []
	for enemy_node in get_tree().get_nodes_in_group("enemies"):
		if not (enemy_node is Enemy):
			continue
		var enemy := enemy_node as Enemy
		if not is_instance_valid(enemy) or enemy.is_dead or enemy == self or enemy.is_parasitized:
			continue
		if spread_origin.distance_to(enemy.global_position) > parasite_catalyst_spread_radius:
			continue
		candidates.append(enemy)
	var infected_count: int = 0
	for _i in range(min(parasite_catalyst_spread_count, candidates.size())):
		var closest_enemy: Enemy = null
		var closest_distance: float = INF
		for candidate in candidates:
			if not is_instance_valid(candidate):
				continue
			var candidate_distance: float = spread_origin.distance_to(candidate.global_position)
			if candidate_distance < closest_distance:
				closest_distance = candidate_distance
				closest_enemy = candidate
		if closest_enemy == null:
			break
		closest_enemy.apply_parasite_state(parasite_duration_max, source_attack)
		closest_enemy.start_parasite_pull(spread_origin, parasite_catalyst_pull_duration, parasite_catalyst_pull_speed)
		_spawn_parasite_tentacle(spread_origin, closest_enemy.global_position)
		candidates.erase(closest_enemy)
		infected_count += 1
	if infected_count > 0:
		Global.spawn_floating_text(spread_origin + Vector2(0, -24), "SPREAD x%d" % infected_count, Color(0.86, 1.0, 0.52))
	parasite_catalyst_timer = 0.0
	parasite_catalyst_attack = 0.0

func _spawn_parasite_tentacle(from_pos: Vector2, to_pos: Vector2) -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var line := Line2D.new()
	line.top_level = true
	line.z_index = 60
	line.width = 10.0
	line.default_color = Color(0.72, 1.0, 0.52, 0.92)
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	line.points = PackedVector2Array([from_pos, to_pos])
	scene.add_child(line)
	var tween := line.create_tween()
	tween.set_parallel(true)
	tween.tween_property(line, "width", 2.0, 0.22)
	tween.tween_property(line, "default_color:a", 0.0, 0.22)
	tween.chain().tween_callback(line.queue_free)

func _is_parasite_pull_blocked(motion: Vector2) -> bool:
	if motion.length_squared() <= 0.0001:
		return false
	var world_2d := get_world_2d()
	if world_2d == null:
		return false
	var params := PhysicsRayQueryParameters2D.create(global_position, global_position + motion)
	params.collide_with_areas = false
	params.collide_with_bodies = true
	params.collision_mask = parasite_pull_collision_mask
	var hit: Dictionary = world_2d.direct_space_state.intersect_ray(params)
	return not hit.is_empty()

# ==============================================================================
# 鍘熸湁杈呭姪鍑芥暟
# ==============================================================================
func _check_line_break() -> void:
	if not is_instance_valid(Global.player):
		return
	
	# 妫€鏌ョ帺瀹舵槸鍚︽湁杩欎釜鍔熻兘锛屽啀璋冪敤
	if Global.player.has_method("try_break_line"):
		Global.player.try_break_line(global_position, break_radius)

func update_rotation() -> void:
	if not is_instance_valid(Global.player): return
	var player_pos := Global.player.global_position
	var moving_right := global_position.x < player_pos.x
	# 鍙敼鍙?X 杞寸殑缂╂斁锛堢敤浜庣炕杞簿鐏碉級锛屼繚鎸?Y 杞寸殑缂╂斁涓嶅彉
	# 淇濇寔 X 杞寸缉鏀剧殑缁濆鍊间笌 Y 杞寸浉鍚岋紝鍙敼鍙樼鍙?
	var scale_magnitude = abs(visuals.scale.y)
	visuals.scale.x = -scale_magnitude if moving_right else scale_magnitude

func get_move_direction() -> Vector2:
	# 1. 纭畾鐩爣锛氬鏋滄湁鍢茶鐩爣涓斿瓨娲伙紝灏辫拷鍢茶鐩爣锛涘惁鍒欒拷鐜╁
	var target_node = Global.player
	if is_instance_valid(override_target):
		target_node = override_target
	
	if not is_instance_valid(target_node): return Vector2.ZERO
	
	# 2. 璁＄畻鏂瑰悜
	var dir_to_player := global_position.direction_to(target_node.global_position)
	var direction := dir_to_player
	var tangent := Vector2(-dir_to_player.y, dir_to_player.x)
	
	# 3. 缇よ仛閫昏緫 (淇濇寔涓嶅彉)
	for area: Node2D in vision_area.get_overlapping_areas():
		if area == self or not area.is_inside_tree():
			continue
		var to_other := area.global_position - global_position
		var distance := to_other.length()
		if distance <= 0.001:
			continue
		var away_from_other := -to_other / distance
		direction += flock_push * away_from_other / distance
		
		if not tangential_slip_enabled:
			continue
		
		var forward_dot: float = dir_to_player.dot(to_other / distance)
		if forward_dot <= tangential_front_dot_threshold:
			continue
		
		var side_sign: float = -sign(dir_to_player.cross(to_other))
		if is_zero_approx(side_sign):
			side_sign = _encircle_side_preference
		
		var distance_weight: float = clamp(1.0 - (distance / max(1.0, tangential_distance_falloff)), 0.0, 1.0)
		var slip_strength: float = tangential_slip_strength * forward_dot * distance_weight
		direction += tangent * side_sign * slip_strength
	
	if direction.length_squared() <= 0.0001:
		return Vector2.ZERO
	return direction.normalized()

func can_move_towards_player() -> bool:
	var target_node = Global.player
	if is_instance_valid(override_target):
		target_node = override_target
		
	# 銆愪慨澶嶃€戝皢 stop_distance_distance 鏀逛负 stop_distance
	return is_instance_valid(target_node) and \
		   global_position.distance_to(target_node.global_position) > stop_distance

# 銆愭柊澧炪€戣缃己鍒剁洰鏍?(鍢茶鎺ュ彛)
func set_taunt_target(target: Node2D) -> void:
	override_target = target
	# 瑙嗚鍙嶉锛氬彉涓鑹茶〃绀鸿鍢茶浜?
	var tween = create_tween()
	tween.tween_property(visuals, "modulate", Color.MAGENTA, 0.2)
	tween.tween_property(visuals, "modulate", Color.WHITE, 0.2)

# ==============================================================================
# P2-3/P2-4: 鐘舵€佺郴缁熷疄鐜?
# ==============================================================================

## P2-3: 搴旂敤鐘舵€佹晥鏋滐紙鏀寔Debuff寤堕暱锛?
## @param type: 鐘舵€佺被鍨嬶紙"burn", "slow", "curse", "freeze"绛夛級
## @param duration: 鎸佺画鏃堕棿锛堢锛?
## @param value: 鏁堟灉鍊硷紙浼ゅ銆佸噺閫熸瘮渚嬬瓑锛?
## @param stacks: 鍙犲姞灞傛暟锛堝彲閫夛紝榛樿1锛?
## @param tick_interval: DoT鏁堟灉鐨勮Е鍙戦棿闅旓紙鍙€夛紝榛樿1.0绉掞級
func apply_status(type: String, duration: float, value: float = 0, stacks: int = 1, tick_interval: float = 1.0) -> void:
	if is_dead:
		return
	
	# P2-3: Debuff寤堕暱鏈哄埗锛堝拻鏈笀 Lv.1锛?
	if BondManager.has_mechanic("abnormal_duration_scale") or BondManager.has_mechanic("debuff_duration"):
		var original_duration = duration
		var duration_scale: float = BondManager.get_mechanic_value("abnormal_duration_scale")
		if duration_scale <= 0.0:
			duration_scale = 1.0 + max(0.0, BondManager.get_mechanic_value("debuff_duration"))
		duration *= duration_scale
		if DEBUG_VERBOSE: print("[Enemy] [P2-3] Debuff寤堕暱瑙﹀彂: %s 鎸佺画鏃堕棿 %.1f绉?-> %.1f绉?(x1.5)" % [
			type,
			original_duration,
			duration
		])
		# 瑙嗚鍙嶉
		Global.spawn_floating_text(global_position, "EXTENDED!", Color(0.8, 0.0, 0.8))
	
	# 濡傛灉鐘舵€佸凡瀛樺湪锛屽埛鏂版寔缁椂闂村苟鍙犲姞灞傛暟
	if active_statuses.has(type):
		var status = active_statuses[type]
		status.duration = max(status.duration, duration)  # 鍙栨洿闀跨殑鎸佺画鏃堕棿
		
		# 璇呭拻鍜屼腑姣掑彲浠ュ彔鍔犲眰鏁?
		if type in ["curse", "poison"]:
			status.stacks += stacks
			if DEBUG_VERBOSE: print("[Enemy] %s鍙犲姞: %s 灞傛暟 %d -> %d" % [
				type,
				name,
				status.stacks - stacks,
				status.stacks
			])
		
		status.value = value  # 鏇存柊鏁堟灉鍊?
		status.tick_interval = tick_interval
	else:
		# 鍒濆鍖栨柊鐘舵€?
		active_statuses[type] = {
			"duration": duration,
			"value": value,
			"stacks": stacks,
			"tick_interval": tick_interval,
			"tick_timer": 0.0  # DoT璁℃椂鍣?
		}
		
		if DEBUG_VERBOSE: print("[Enemy] 搴旂敤鐘舵€? %s 鎸佺画%.1f绉? 鍊?%.1f, 灞傛暟=%d" % [
			type,
			duration,
			value,
			stacks
		])
		
		# 鎾斁寮傚父鐘舵€侀煶鏁?
		if type in ["burn", "curse", "poison", "slow", "freeze", "stun"]:
			SoundManager.play("debuff_" + type)
		
		# 搴旂敤鍒濆鏁堟灉
		_apply_status_initial_effect(type, value)

## 搴旂敤鐘舵€佺殑鍒濆鏁堟灉锛堜緥濡傚噺閫燂級
func _apply_status_initial_effect(type: String, value: float) -> void:
	match type:
		"slow":
			# 鍑忛€熸晥鏋滐細闄嶄綆绉诲姩閫熷害
			speed *= (1.0 - value)
			if DEBUG_VERBOSE: print("[Enemy] 鍑忛€熸晥鏋? 閫熷害闄嶄綆 %.0f%%" % (value * 100))
		
		"freeze":
			# 鍐板喕鏁堟灉锛氬畬鍏ㄥ仠姝㈢Щ鍔?
			can_move = false
			if DEBUG_VERBOSE: print("[Enemy] 鍐板喕鏁堟灉: 鏃犳硶绉诲姩")
		
		"stun":
			# 鐪╂檿鏁堟灉锛氬畬鍏ㄥ仠姝㈢Щ鍔紙绫讳技鍐板喕锛?
			can_move = false
			if DEBUG_VERBOSE:
				var stun_data: Dictionary = active_statuses.get("stun", {})
				var stun_duration: float = float(stun_data.get("duration", 0.0))
				print("[Enemy] stun applied, duration=%.1f" % stun_duration)
		
		"marked":
			# 鏍囪鏁堟灉锛氬彈鍒扮殑浼ゅ澧炲姞锛堝湪 HealthComponent.take_damage 涓鏌ワ級
			if DEBUG_VERBOSE: print("[Enemy] 鏍囪鏁堟灉: 鍙椾激澧炲姞 %.0f%%" % (value * 100))
		
		"burn", "curse", "poison":
			# DoT鏁堟灉锛氬湪 _process_status_effects 涓鐞?
			pass

## 澶勭悊鐘舵€佹晥鏋滐紙姣忓抚璋冪敤锛?
func _process_status_effects(delta: float) -> void:
	if active_statuses.is_empty():
		return
	
	var statuses_to_remove = []
	
	for status_type in active_statuses.keys():
		var status = active_statuses[status_type]
		
		# 鍑忓皯鎸佺画鏃堕棿
		status.duration -= delta
		
		# 澶勭悊DoT鏁堟灉锛堢噧鐑с€佽瘏鍜掋€佷腑姣掞級
		if status_type in ["burn", "curse", "poison"]:
			status.tick_timer += delta
			
			if status.tick_timer >= status.tick_interval:
				status.tick_timer = 0.0
				_apply_dot_damage(status_type, status.value, status.stacks)
		
		# 妫€鏌ユ槸鍚﹁繃鏈?
		if status.duration <= 0:
			statuses_to_remove.append(status_type)
	
	# 绉婚櫎杩囨湡鐘舵€?
	for status_type in statuses_to_remove:
		_remove_status(status_type)

## 搴旂敤DoT浼ゅ锛堢噧鐑с€佽瘏鍜掋€佷腑姣掞級
func _apply_dot_damage(status_type: String, value: float, stacks: int) -> void:
	if not health_component:
		return
	
	var damage = 0
	
	match status_type:
		"burn":
			# 鐕冪儳锛氬浐瀹氫激瀹?
			damage = int(value)
			Global.spawn_floating_text(global_position, "BURN!", Color(2.0, 0.5, 0.0))
		
		"curse":
			# 璇呭拻锛氭瘡灞傞€犳垚浼ゅ
			damage = int(value * stacks)
			Global.spawn_floating_text(global_position, "CURSE x%d!" % stacks, Color(0.8, 0.0, 0.8))
		
		"poison":
			# 涓瘨锛氭瘡灞傞€犳垚浼ゅ
			damage = int(value * stacks)
			Global.spawn_floating_text(global_position, "POISON x%d!" % stacks, Color(0.4, 0.7, 0.1))
	
	if damage > 0:
		health_component.take_damage(damage, {
			"source": self,
			"kind": "%s_status_tick" % status_type,
			"damage_type": "DMG_DOT",
		})
		if DEBUG_VERBOSE: print("[Enemy] %s DoT浼ゅ: %d (灞傛暟: %d)" % [status_type.to_upper(), damage, stacks])

## 绉婚櫎鐘舵€佹晥鏋?
func _remove_status(type: String) -> void:
	if not active_statuses.has(type):
		return
	
	if DEBUG_VERBOSE: print("[Enemy] 绉婚櫎鐘舵€? %s" % type)
	
	# 鎭㈠鐘舵€佹晥鏋?
	match type:
		"slow":
			# 鎭㈠绉诲姩閫熷害锛堥噸鏂颁粠閰嶇疆鍔犺浇锛?
			var config = ConfigManager.get_enemy_config(enemy_id)
			if not config.is_empty():
				speed = float(config.get("speed", 100))
		
		"freeze":
			# 鎭㈠绉诲姩鑳藉姏
			can_move = true
		
		"stun":
			# 鎭㈠绉诲姩鑳藉姏
			can_move = true
	
	# 浠庡瓧鍏镐腑绉婚櫎
	active_statuses.erase(type)

## 妫€鏌ユ槸鍚︽湁鎸囧畾鐘舵€?
func has_status(type: String) -> bool:
	return active_statuses.has(type)

## 鑾峰彇鐘舵€佺殑灞傛暟
func get_status_stacks(type: String) -> int:
	if active_statuses.has(type):
		return active_statuses[type].stacks
	return 0

## 娓呴櫎鎵€鏈夌姸鎬侊紙鐢ㄤ簬姝讳骸鎴栫壒娈婃儏鍐碉級
func clear_all_statuses() -> void:
	for status_type in active_statuses.keys():
		_remove_status(status_type)
	
	active_statuses.clear()

func get_abnormal_state_count() -> int:
	var abnormal_states: Dictionary = {}
	for state_name_variant: Variant in active_statuses.keys():
		var state_name: String = str(state_name_variant).strip_edges().to_lower()
		if state_name in ["poison", "vulnerable", "slow", "bleed", "tar_debuff"]:
			abnormal_states[state_name] = true
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
	if normalized_mark.is_empty():
		return false
	if normalized_mark == "mark" and active_statuses.has("marked"):
		return true
	if combat_modifier_component == null:
		return false
	if normalized_mark == "mark":
		return combat_modifier_component.has_tag_marker("mark") or combat_modifier_component.has_tag_marker("overtone_echo")
	if normalized_mark == "soul_link":
		return combat_modifier_component.has_tag_marker("soul_link") or combat_modifier_component.has_tag_marker("soul_link_empowered")
	return combat_modifier_component.has_tag_marker(normalized_mark)
	
# ==============================================================================
# 鍑婚€€涓庡彈鍑?(淇濇寔涔嬪墠鐨勪慨澶?
# ==============================================================================
func apply_knockback(knock_dir: Vector2, knock_power: float, source: Variant = null, extra_payload: Dictionary = {}) -> void:
	# 鍐查攱鏈熼棿鍏嶇柅鍑婚€€ (闇镐綋)
	if current_ai_state == AIState.CHARGING: return

	var payload: Dictionary = {
		"direction": knock_dir,
		"power": knock_power,
		"source": source,
	}
	for key_variant: Variant in extra_payload.keys():
		payload[key_variant] = extra_payload[key_variant]
	if BondManager != null and BondManager.has_method("process_enemy_knockback"):
		payload = BondManager.process_enemy_knockback(self, payload)
	knockback_requested.emit(self, payload)
	var final_direction: Vector2 = payload.get("direction", knock_dir)
	var final_power: float = float(payload.get("power", knock_power))
	if final_direction.length_squared() <= 0.0001 or final_power <= 0.0:
		return

	knockback_dir = final_direction.normalized()
	knockback_power = final_power
	_last_knockback_payload = payload.duplicate(true)
	if knockback_timer.time_left > 0:
		knockback_timer.stop()
		reset_knockback()
	knockback_timer.start()

func reset_knockback() -> void:
	knockback_dir = Vector2.ZERO
	knockback_power = 0.0
	_last_knockback_payload.clear()

func _resolve_source_attack_value(source: Variant) -> float:
	if source == null:
		return max(1.0, damage)
	if source is PlayerBase:
		return max(1.0, float((source as PlayerBase).damage))
	if source is Node and (source as Node).has_method("get_owner_player"):
		var owner_variant: Variant = (source as Node).call("get_owner_player")
		if owner_variant is PlayerBase and is_instance_valid(owner_variant):
			return max(1.0, float((owner_variant as PlayerBase).damage))
	return max(1.0, damage)

func _detect_knockback_wall_hit(motion: Vector2) -> Dictionary:
	if motion.length_squared() <= 0.0001:
		return {}
	var world_2d := get_world_2d()
	if world_2d == null:
		return {}
	var query := PhysicsRayQueryParameters2D.create(global_position, global_position + motion)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	query.collision_mask = charge_cage_collision_mask
	return world_2d.direct_space_state.intersect_ray(query)

func _on_knockback_timer_timeout() -> void:
	reset_knockback()

func set_phalanx_motion_locked(active: bool) -> void:
	if active:
		phalanx_motion_lock_count += 1
	else:
		phalanx_motion_lock_count = max(0, phalanx_motion_lock_count - 1)

func apply_phalanx_ballistic(direction: Vector2, speed_value: float, max_distance: float, max_duration: float, source_attack: float, collision_damage_ratio: float, source: Variant = null, impact_push_distance: float = 10.0, stop_on_hit: bool = true) -> void:
	var ballistic_direction: Vector2 = direction.normalized()
	if ballistic_direction.length_squared() <= 0.0001:
		return
	phalanx_ballistic_active = true
	phalanx_ballistic_velocity = ballistic_direction * max(0.0, speed_value)
	phalanx_ballistic_remaining_distance = max(0.0, max_distance)
	phalanx_ballistic_remaining_time = max(0.0, max_duration)
	phalanx_ballistic_source_attack = max(0.0, source_attack)
	phalanx_ballistic_collision_damage_ratio = max(0.0, collision_damage_ratio)
	phalanx_ballistic_impact_push_distance = max(0.0, impact_push_distance)
	phalanx_ballistic_source = source
	phalanx_ballistic_stop_on_hit = stop_on_hit
	phalanx_ballistic_target_hit_cooldowns.clear()

func clear_phalanx_ballistic() -> void:
	phalanx_ballistic_active = false
	phalanx_ballistic_velocity = Vector2.ZERO
	phalanx_ballistic_remaining_distance = 0.0
	phalanx_ballistic_remaining_time = 0.0
	phalanx_ballistic_source_attack = 0.0
	phalanx_ballistic_collision_damage_ratio = 0.0
	phalanx_ballistic_impact_push_distance = 0.0
	phalanx_ballistic_source = null
	phalanx_ballistic_stop_on_hit = true
	phalanx_ballistic_target_hit_cooldowns.clear()

func _process_phalanx_ballistic(delta: float) -> bool:
	if not phalanx_ballistic_active or is_dead:
		return false
	_decay_phalanx_ballistic_hit_cooldowns(delta)
	var speed_value: float = phalanx_ballistic_velocity.length()
	if speed_value <= 0.001:
		clear_phalanx_ballistic()
		return false
	var direction: Vector2 = phalanx_ballistic_velocity / speed_value
	var step_distance: float = min(phalanx_ballistic_remaining_distance, speed_value * delta)
	var start_pos: Vector2 = global_position
	var end_pos: Vector2 = start_pos + direction * step_distance
	var collided_enemies: Array[Enemy] = _find_phalanx_ballistic_enemy_hits(start_pos, end_pos)
	if not collided_enemies.is_empty():
		var damage_amount: float = max(1.0, phalanx_ballistic_source_attack * phalanx_ballistic_collision_damage_ratio)
		for collided_enemy: Enemy in collided_enemies:
			if collided_enemy == null or not is_instance_valid(collided_enemy) or collided_enemy.is_dead:
				continue
			apply_modifier_damage(damage_amount, phalanx_ballistic_source, {
				"kind": "phalanx_ballistic_collision",
				"damage_type": "DMG_DIRECT",
			})
			collided_enemy.apply_modifier_damage(damage_amount, phalanx_ballistic_source, {
				"kind": "phalanx_ballistic_collision",
				"damage_type": "DMG_DIRECT",
			})
			collided_enemy.global_position += direction * phalanx_ballistic_impact_push_distance
			phalanx_ballistic_target_hit_cooldowns[collided_enemy.get_instance_id()] = 0.08
			if has_method("set_flash_material"):
				set_flash_material()
			if collided_enemy.has_method("set_flash_material"):
				collided_enemy.set_flash_material()
			if phalanx_ballistic_stop_on_hit:
				clear_phalanx_ballistic()
				return true
	global_position = end_pos
	phalanx_ballistic_remaining_distance = max(0.0, phalanx_ballistic_remaining_distance - step_distance)
	phalanx_ballistic_remaining_time = max(0.0, phalanx_ballistic_remaining_time - delta)
	if phalanx_ballistic_remaining_distance <= 0.0 or phalanx_ballistic_remaining_time <= 0.0:
		clear_phalanx_ballistic()
	return true

func _find_phalanx_ballistic_enemy_hits(from_pos: Vector2, to_pos: Vector2) -> Array[Enemy]:
	var hits: Array[Dictionary] = []
	for enemy_node in get_tree().get_nodes_in_group("enemies"):
		if not (enemy_node is Enemy):
			continue
		var other_enemy: Enemy = enemy_node as Enemy
		if other_enemy == self or not is_instance_valid(other_enemy) or other_enemy.is_dead:
			continue
		if float(phalanx_ballistic_target_hit_cooldowns.get(other_enemy.get_instance_id(), 0.0)) > 0.0:
			continue
		var closest_point: Vector2 = Geometry2D.get_closest_point_to_segment(other_enemy.global_position, from_pos, to_pos)
		if other_enemy.global_position.distance_to(closest_point) <= phalanx_ballistic_hit_radius:
			hits.append({
				"enemy": other_enemy,
				"distance": from_pos.distance_squared_to(closest_point),
			})
	hits.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("distance", 0.0)) < float(b.get("distance", 0.0))
	)
	var result: Array[Enemy] = []
	for hit_entry: Dictionary in hits:
		var hit_enemy_variant: Variant = hit_entry.get("enemy", null)
		if hit_enemy_variant is Enemy:
			result.append(hit_enemy_variant as Enemy)
	return result

func _decay_phalanx_ballistic_hit_cooldowns(delta: float) -> void:
	if phalanx_ballistic_target_hit_cooldowns.is_empty():
		return
	var expired_ids: Array[int] = []
	for enemy_id_variant: Variant in phalanx_ballistic_target_hit_cooldowns.keys():
		var enemy_id: int = int(enemy_id_variant)
		var remaining: float = max(0.0, float(phalanx_ballistic_target_hit_cooldowns.get(enemy_id, 0.0)) - delta)
		if remaining <= 0.0:
			expired_ids.append(enemy_id)
		else:
			phalanx_ballistic_target_hit_cooldowns[enemy_id] = remaining
	for enemy_id: int in expired_ids:
		phalanx_ballistic_target_hit_cooldowns.erase(enemy_id)

func _on_hurtbox_component_on_damaged(hitbox: HitboxComponent) -> void:
	if is_dead: return
	var original_damage: float = hitbox.damage
	var front_guard_blocked: bool = false
	if enemy_id == "phalanx_enforcer":
		var preview_payload: Dictionary = hitbox.build_damage_payload()
		var preview_damage_type: int = COMBAT_EVENT_TYPES.normalize_damage_type(
			preview_payload.get("damage_type", COMBAT_EVENT_TYPES.DamageType.DIRECT)
		)
		front_guard_blocked = preview_damage_type == COMBAT_EVENT_TYPES.DamageType.DIRECT and _should_block_front_guard_payload(preview_payload)
	hitbox.damage = original_damage * get_incoming_damage_multiplier()

	# 1. 纭３榫熷弽浼ら€昏緫 (淇敼涓哄噺浼よ€屼笉鏄畬鍏ㄦ牸鎸?
	if enemy_type == EnemyType.SHIELDED and hitbox.source == Global.player:
		Global.spawn_floating_text(global_position, "SHIELD!", Color.CYAN)
		
		# 鍑忓皯浼ゅ鍒?30%
		hitbox.damage *= 0.3
		
		# 杞诲井鍙嶄激鐜╁
		if Global.player.has_method("take_damage"):
			Global.player.take_damage(1, {
				"source": self,
				"kind": "shielded_reflect",
				"damage_type": "DMG_DIRECT",
			})
		
		# 涓嶅啀 return锛岀户缁墽琛屾甯镐激瀹抽€昏緫

	# 2. 姝ｅ父浼ゅ
	super._on_hurtbox_component_on_damaged(hitbox)
	hitbox.damage = original_damage
	if current_ai_state == AIState.CHARGING:
		_play_charge_hit_feedback("CUT!", Color(1.0, 1.0, 1.0), false)
	
	if hitbox.knockback_power > 0 and not front_guard_blocked:
		# 瀹夊叏妫€鏌ワ細纭繚 source 浠嶇劧鏈夋晥
		if hitbox.source and is_instance_valid(hitbox.source):
			var dir := hitbox.source.global_position.direction_to(global_position)
			apply_knockback(dir, hitbox.knockback_power, hitbox.source, {
				"source_attack": _resolve_source_attack_value(hitbox.source),
				"damage_type": int(hitbox.damage_type),
				"knockback_generation": 0,
			})
	
	# 澧炲己鎵撳嚮鎰燂細鏁屼汉鍙楀嚮鏃剁殑鍙嶉
	# 瀹夊叏妫€鏌ワ細纭繚 source 鍜?Global.player 浠嶇劧鏈夋晥
	if hitbox.source and is_instance_valid(hitbox.source) and hitbox.source == Global.player and not front_guard_blocked:
		var is_elite_target: bool = self is EnemyElites
		if Global.has_method("apply_enemy_hit_feedback"):
			Global.apply_enemy_hit_feedback(hitbox.damage, hitbox.critical, is_elite_target)

func despawn_for_wave_end() -> void:
	# Force-remove enemy for wave settlement without rewards, drops, split, or poison pool.
	if is_dead:
		return
	is_dead = true
	can_move = false
	clear_parasite_state()

	if warning_line and is_instance_valid(warning_line):
		warning_line.queue_free()

	if collision_shape:
		collision_shape.set_deferred("disabled", true)

	if contact_hitbox:
		contact_hitbox.monitoring = false
		contact_hitbox.monitorable = false

	clear_all_statuses()
	queue_free()

func mark_backend_kill(source_role_id: String = "") -> void:
	set_meta(ASSIST_BACKEND_KILL_META, true)
	if source_role_id.is_empty():
		if has_meta(ASSIST_BACKEND_KILL_OWNER_META):
			remove_meta(ASSIST_BACKEND_KILL_OWNER_META)
	else:
		set_meta(ASSIST_BACKEND_KILL_OWNER_META, source_role_id)

func is_backend_kill() -> bool:
	return has_meta(ASSIST_BACKEND_KILL_META) and bool(get_meta(ASSIST_BACKEND_KILL_META))

func destroy_enemy() -> void:
	if is_dead: return
	is_dead = true
	can_move = false
	_try_spawn_split_on_death()
	_try_trigger_explode_on_death()
	_trigger_parasite_catalyst_spread_on_death()
	clear_parasite_state()
	var backend_kill: bool = is_backend_kill()
	var assist_service: Node = get_node_or_null("/root/AssistRuntimeService")
	
	# 姝讳骸鏃舵竻鐞嗙孩绾?
	if warning_line:
		warning_line.queue_free()
	
	if collision_shape:
		collision_shape.set_deferred("disabled", true)
	
	# 鍦伴浄鎬壒娈婃晥鏋滐細姝诲悗鐣欐瘨姹?
	if enemy_type == EnemyType.MINE_LAYER:
		call_deferred("_spawn_poison_pool", global_position)
	
	# 缁欑帺瀹跺鍔憋紙鑳介噺銆佺粡楠屻€侀噾甯侊級
	if is_instance_valid(Global.player):
		var enemy_config = ConfigManager.get_enemy_config(enemy_id)
		
		# P1-1: 击杀掉落能量球
		var energy_drop: float = float(enemy_config.get("energy_drop", 5))
		if BondManager.has_mechanic("kill_regen"):
			var bonus_energy: float = float(BondManager.get_mechanic_value("kill_regen"))
			energy_drop += bonus_energy
			if DEBUG_VERBOSE:
				print("[Enemy] [P1-1] kill energy orb boosted: base=%.1f bonus=%.1f total=%.1f" % [
					float(enemy_config.get("energy_drop", 5)),
					bonus_energy,
					energy_drop
				])
			if bonus_energy > 0.0:
				Global.spawn_floating_text(global_position + Vector2(0, -18), "+%.0f ORB" % bonus_energy, Color(0.5, 1.5, 2.0))
		if energy_drop > 0.0 and not backend_kill:
			if Global.has_method("spawn_energy_orb"):
				Global.spawn_energy_orb(global_position, energy_drop)
			elif Global.player.has_method("gain_energy"):
				Global.player.gain_energy(energy_drop)
		
		# 缁忛獙濂栧姳
		if Global.player.has_method("add_xp"):
			var xp_value = int(enemy_config.get("xp_value", 10))
			Global.player.add_xp(xp_value)
		
		# 閲戝竵濂栧姳 - 鏀逛负鐢熸垚閲戝竵瀹炰綋
		var gold_value = int(enemy_config.get("gold_value", 5))
		if gold_value > 0 and not backend_kill:
			Global.spawn_coin(global_position, gold_value)
	
	Global.add_session_kill()

	var arena = get_tree().get_first_node_in_group("arena")
	if arena and arena.has_method("record_enemy_wave_loot_drop"):
		arena.record_enemy_wave_loot_drop(enemy_id, self is EnemyElites)
	
	if not backend_kill and Global.player and Global.player.has_method("on_enemy_killed"):
		Global.player.on_enemy_killed(self)
	if not backend_kill and assist_service != null and assist_service.has_method("on_front_enemy_killed"):
		assist_service.call("on_front_enemy_killed", self)
	if BondManager != null and BondManager.has_method("on_enemy_killed"):
		BondManager.on_enemy_killed(self, _last_damage_payload.duplicate(true))
	
	var is_elite_target: bool = self is EnemyElites
	if Global.has_method("apply_enemy_kill_feedback"):
		Global.apply_enemy_kill_feedback(is_elite_target)
	spawn_explosion_safe()
	if elite_affix_id.to_lower() == "split":
		call_deferred("_spawn_split_children")
	
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(visuals, "modulate", Color.RED, 0.1)
	tween.tween_property(visuals, "modulate:a", 0.0, 0.3)
	tween.tween_property(visuals, "scale", Vector2.ZERO, 0.3)
	
	tween.chain().tween_callback(queue_free)

func spawn_explosion_safe() -> void:
	if not death_vfx_scene: return
	var vfx = death_vfx_scene.instantiate()
	vfx.global_position = global_position
	vfx.z_index = 100 
	get_tree().current_scene.call_deferred("add_child", vfx)
	var vfx_tween = vfx.create_tween()
	vfx_tween.tween_interval(2.0)
	vfx_tween.tween_callback(vfx.queue_free)

func _spawn_split_children() -> void:
	var split_count: int = _get_split_child_count()
	if split_count <= 0:
		return
	_spawn_split_children_for_enemy("fractal_slime_mini", split_count)

func _get_split_child_count() -> int:
	var split_ability: Dictionary = _get_enemy_ability_config("split_on_death")
	if split_ability.is_empty():
		return 0
	return max(0, int(split_ability.get("param1", 0)))

func _get_enemy_ability_config(target_ability_id: String) -> Dictionary:
	if AbilityManager == null:
		return {}
	var abilities: Array = AbilityManager.get_enemy_abilities(enemy_id)
	for ability_variant in abilities:
		if not (ability_variant is Dictionary):
			continue
		var ability_config: Dictionary = ability_variant
		if str(ability_config.get("ability_id", "")) == target_ability_id:
			return ability_config
	return {}

func _try_trigger_explode_on_death() -> void:
	var explode_ability: Dictionary = _get_enemy_ability_config("explode_on_death")
	if explode_ability.is_empty():
		return
	var damage_value: float = max(0.0, float(explode_ability.get("param1", 20.0)))
	var radius_value: float = max(8.0, float(explode_ability.get("param2", 80.0)))
	if damage_value <= 0.0:
		return
	_spawn_death_explosion_area(damage_value, radius_value)

func _spawn_death_explosion_area(explosion_damage: float, explosion_radius: float) -> void:
	var current_scene: Node = get_tree().current_scene
	if current_scene == null:
		return

	var explosion_area := Area2D.new()
	explosion_area.name = "VolatileSparkExplosion"
	explosion_area.global_position = global_position
	explosion_area.collision_layer = 0
	explosion_area.collision_mask = 8 | 32
	explosion_area.monitoring = true
	explosion_area.monitorable = false
	explosion_area.z_index = 95

	var collision := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = explosion_radius
	collision.shape = circle
	explosion_area.add_child(collision)

	var ring := Line2D.new()
	ring.width = 7.0
	ring.default_color = Color(1.0, 0.92, 0.42, 0.85)
	ring.closed = true
	ring.z_index = 96
	var ring_points := PackedVector2Array()
	for i in range(20):
		var angle: float = TAU * float(i) / 20.0
		ring_points.append(Vector2.RIGHT.rotated(angle) * explosion_radius)
	ring.points = ring_points
	explosion_area.add_child(ring)

	var fill := Polygon2D.new()
	fill.color = Color(1.0, 0.56, 0.16, 0.24)
	fill.polygon = ring_points
	explosion_area.add_child(fill)

	current_scene.add_child(explosion_area)
	_apply_death_explosion_damage(explosion_damage, explosion_radius)
	if SoundManager != null and SoundManager.has_method("play"):
		SoundManager.play("player_explosion")
	Global.on_camera_shake.emit(5.5, 0.12)

	var tween: Tween = explosion_area.create_tween()
	tween.set_parallel(true)
	tween.tween_property(explosion_area, "scale", Vector2.ONE * 1.18, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(ring, "modulate:a", 0.0, 0.18)
	tween.tween_property(fill, "color:a", 0.0, 0.18)
	tween.chain().tween_callback(explosion_area.queue_free)

func _apply_death_explosion_damage(explosion_damage: float, explosion_radius: float) -> void:
	for hurtbox_variant in get_tree().get_nodes_in_group("hurtbox"):
		if not (hurtbox_variant is HurtboxComponent):
			continue
		var hurtbox: HurtboxComponent = hurtbox_variant
		if not is_instance_valid(hurtbox):
			continue
		var target_node: Node = hurtbox.get_parent()
		if target_node == null or not is_instance_valid(target_node) or target_node == self:
			continue
		if not (target_node is Node2D):
			continue
		var target_2d: Node2D = target_node as Node2D
		if target_2d.global_position.distance_to(global_position) > explosion_radius:
			continue
		if target_node is Enemy:
			var target_enemy: Enemy = target_node as Enemy
			if target_enemy.is_dead:
				continue
			target_enemy.apply_modifier_damage(explosion_damage, self, {
				"kind": "volatile_spark_explosion",
				"damage_type": COMBAT_EVENT_TYPES.DamageType.AOE,
				"source_position": global_position,
			})
		elif target_node is PlayerBase:
			var target_player: PlayerBase = target_node as PlayerBase
			target_player.take_damage(explosion_damage, {
				"source": self,
				"kind": "volatile_spark_explosion",
				"damage_type": COMBAT_EVENT_TYPES.DamageType.AOE,
				"source_position": global_position,
			})

func _try_spawn_split_on_death() -> void:
	if _split_spawned_on_death:
		return
	var split_ability: Dictionary = _get_enemy_ability_config("split_on_death")
	if split_ability.is_empty():
		return
	if _should_block_split_on_death():
		return
	var split_count: int = max(0, int(split_ability.get("param1", 0)))
	if split_count <= 0:
		return
	_split_spawned_on_death = true
	_spawn_fractal_split_burst(Color(0.38, 1.0, 0.42, 1.0), 1.1)
	_spawn_fractal_split_residue()
	_spawn_split_children_for_enemy("fractal_slime_mini", split_count)

func _should_block_split_on_death() -> bool:
	var damage_type: int = COMBAT_EVENT_TYPES.normalize_damage_type(
		_last_damage_payload.get("damage_type", COMBAT_EVENT_TYPES.DamageType.DIRECT)
	)
	if damage_type == COMBAT_EVENT_TYPES.DamageType.TRUE_DAMAGE or bool(_last_damage_payload.get("true_damage", false)):
		return true
	return _has_split_blocking_cc()

func _has_split_blocking_cc() -> bool:
	for status_name in ["stun", "freeze", "petrify"]:
		if has_status(status_name):
			return true
	return false

func _spawn_split_children_for_enemy(child_enemy_id: String, child_count: int) -> void:
	var scene_path: String = scene_file_path
	if scene_path.is_empty():
		scene_path = "res://scenes/unit/enemy/enemy_generic.tscn"
	var scene := load(scene_path) as PackedScene
	if scene == null:
		return

	for i in range(child_count):
		var child_enemy = scene.instantiate() as Enemy
		if child_enemy == null:
			continue
		var launch_dir: Vector2 = Vector2.RIGHT.rotated(randf_range(0.0, TAU))
		var launch_power: float = randf_range(90.0, 145.0)
		child_enemy.enemy_id = child_enemy_id
		child_enemy.global_position = global_position + launch_dir * randf_range(12.0, 30.0)
		child_enemy.elite_affix_id = ""
		child_enemy.set_meta("split_spawn_profile", {
			"speed_mult": 1.0,
			"damage_mult": 1.0,
			"hp_mult": 1.0,
			"disable_split": true,
			"knockback_dir": launch_dir,
			"knockback_power": launch_power
		})
		get_tree().current_scene.call_deferred("add_child", child_enemy)

func _apply_split_spawn_profile() -> void:
	if not has_meta("split_spawn_profile"):
		return
	var raw_profile: Variant = get_meta("split_spawn_profile")
	remove_meta("split_spawn_profile")
	if not (raw_profile is Dictionary):
		return

	var profile: Dictionary = raw_profile
	var speed_mult: float = float(profile.get("speed_mult", 1.0))
	var damage_mult: float = float(profile.get("damage_mult", 1.0))
	var hp_mult: float = float(profile.get("hp_mult", 1.0))
	var disable_split: bool = bool(profile.get("disable_split", false))

	speed *= speed_mult
	damage *= damage_mult
	health *= hp_mult
	if health_component:
		health_component.max_health *= hp_mult
		health_component.current_health = health_component.max_health
	_sync_contact_hitbox_damage()
	if disable_split:
		_split_spawned_on_death = true
	if profile.has("knockback_dir") and profile.has("knockback_power"):
		var knock_dir: Vector2 = profile.get("knockback_dir", Vector2.ZERO)
		var knock_power: float = float(profile.get("knockback_power", 0.0))
		if knock_dir.length_squared() > 0.0001 and knock_power > 0.0:
			call_deferred("apply_knockback", knock_dir, knock_power)

# 鍦伴浄鎬鍚庣敓鎴愭瘨姹?
func _setup_fractal_slime_runtime() -> void:
	if not _is_fractal_slime_family():
		return
	if is_instance_valid(sprite):
		_slime_sprite_base_scale = sprite.scale
		if is_zero_approx(_slime_sprite_base_scale.length_squared()):
			_slime_sprite_base_scale = Vector2.ONE
	_slime_visual_time = randf() * TAU
	if _is_fractal_slime_mini() and health_component != null:
		health_component.is_invincible = true
		_slime_birth_invul_timer = 0.15
		_slime_spawn_pop_timer = 0.22

func _process_fractal_slime_feedback(delta: float) -> void:
	if not _is_fractal_slime_family():
		return
	if is_instance_valid(sprite):
		_slime_visual_time += delta * (5.2 if _is_fractal_slime_mini() else 3.1)
		var base_speed: float = max(speed, 1.0)
		var move_bias: float = clamp(abs(knockback_power) / base_speed, 0.0, 1.0)
		if current_ai_state == AIState.CHARGING:
			move_bias = max(move_bias, 0.6)
		var stretch_amp: float = (0.08 if _is_fractal_slime_mini() else 0.12) + move_bias * 0.04
		var stretch_wave: float = sin(_slime_visual_time)
		var settle_wave: float = cos(_slime_visual_time * 0.5)
		var x_scale: float = 1.0 + stretch_wave * stretch_amp
		var y_scale: float = 1.0 - stretch_wave * stretch_amp * 0.75 + settle_wave * 0.04
		if _slime_spawn_pop_timer > 0.0:
			var pop_progress: float = 1.0 - (_slime_spawn_pop_timer / 0.22)
			var pop_pulse: float = sin(clamp(pop_progress, 0.0, 1.0) * PI)
			x_scale *= 1.0 - pop_pulse * 0.18
			y_scale *= 1.0 + pop_pulse * 0.24
		sprite.scale = Vector2(_slime_sprite_base_scale.x * x_scale, _slime_sprite_base_scale.y * y_scale)
		if _slime_birth_invul_timer > 0.0:
			var flash: float = 0.5 + 0.5 * sin(_slime_visual_time * 16.0)
			sprite.modulate = Color(0.72 + 0.28 * flash, 1.0, 0.72 + 0.18 * flash, 1.0)
		else:
			sprite.modulate = Color.WHITE
	if _slime_birth_invul_timer <= 0.0:
		if _slime_spawn_pop_timer > 0.0:
			_slime_spawn_pop_timer = max(0.0, _slime_spawn_pop_timer - delta)
		return
	_slime_birth_invul_timer = max(0.0, _slime_birth_invul_timer - delta)
	if _slime_spawn_pop_timer > 0.0:
		_slime_spawn_pop_timer = max(0.0, _slime_spawn_pop_timer - delta)
	if _slime_birth_invul_timer <= 0.0 and health_component != null:
		health_component.is_invincible = false

func _spawn_fractal_split_burst(tint: Color, scale_mult: float = 1.0) -> void:
	if death_vfx_scene == null:
		return
	var vfx := death_vfx_scene.instantiate()
	if vfx == null:
		return
	vfx.global_position = global_position
	vfx.z_index = 105
	if vfx is CanvasItem:
		(vfx as CanvasItem).modulate = tint
	if vfx is Node2D:
		(vfx as Node2D).scale = Vector2.ONE * scale_mult
	get_tree().current_scene.call_deferred("add_child", vfx)
	var vfx_tween = vfx.create_tween()
	vfx_tween.tween_interval(1.2)
	vfx_tween.tween_callback(vfx.queue_free)

func _spawn_fractal_split_residue() -> void:
	var current_scene: Node = get_tree().current_scene
	if current_scene == null:
		return
	var root := Node2D.new()
	root.name = "FractalSplitResidue"
	root.global_position = global_position
	root.z_index = 12
	root.scale = Vector2(1.05, 0.78)

	var fill := Polygon2D.new()
	var outline := Line2D.new()
	var points := PackedVector2Array()
	var base_radius: float = 24.0
	for i in range(14):
		var angle: float = (TAU * float(i)) / 14.0
		var wobble: float = 1.0 + 0.14 * sin(angle * 3.0 + randf() * 0.6)
		points.append(Vector2.RIGHT.rotated(angle) * base_radius * wobble)
	fill.polygon = points
	fill.color = Color(0.20, 0.78, 0.22, 0.30)
	root.add_child(fill)

	outline.points = points
	outline.closed = true
	outline.width = 3.0
	outline.default_color = Color(0.55, 1.0, 0.58, 0.55)
	root.add_child(outline)

	current_scene.add_child(root)
	var tween: Tween = root.create_tween()
	tween.set_parallel(true)
	tween.tween_property(root, "scale", Vector2(1.42, 0.94), 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(fill, "color:a", 0.0, 0.55)
	tween.tween_property(outline, "modulate:a", 0.0, 0.45)
	tween.chain().tween_callback(root.queue_free)

func _is_fractal_slime() -> bool:
	return enemy_id == "fractal_slime"

func _is_fractal_slime_mini() -> bool:
	return enemy_id == "fractal_slime_mini"

func _is_fractal_slime_family() -> bool:
	return _is_fractal_slime() or _is_fractal_slime_mini()

func _spawn_poison_pool(pos: Vector2) -> void:
	# 瀹夊叏妫€鏌ワ細纭繚鍦烘櫙鏍戝彲鐢?
	var tree = Engine.get_main_loop() as SceneTree
	if tree == null or tree.current_scene == null:
		push_error("[MineLayer] 閿欒: 鏃犳硶鑾峰彇鍦烘櫙鏍?")
		return
	
	var poison = Area2D.new()
	poison.name = "PoisonPool_" + str(Time.get_ticks_msec())
	poison.add_to_group("enemy_effects")
	poison.collision_layer = 0
	poison.collision_mask = 1
	poison.monitorable = false
	poison.monitoring = true
	
	# 纰版挒浣?
	var col = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = pool_radius
	col.shape = shape
	poison.add_child(col)
	
	# 瑙嗚鏁堟灉锛氬畬鏁寸殑鍦嗗舰姣掓睜
	var vis = Polygon2D.new()
	vis.name = "PoisonVisual"
	var points = PackedVector2Array()
	var segments = 32
	
	# 鐢熸垚鍦嗗舰澶氳竟褰㈢偣
	for i in range(segments):
		var angle = float(i) * TAU / float(segments)
		var point = Vector2(cos(angle), sin(angle)) * pool_radius
		points.append(point)
	
	# 璁剧疆澶氳竟褰?
	vis.polygon = points
	vis.color = Color(0.2, 1.0, 0.2, 0.5)
	vis.z_index = -1
	poison.add_child(vis)
	
	# 鍏堟坊鍔犲埌鍦烘櫙鏍?
	tree.current_scene.add_child(poison)
	
	# 璁剧疆浣嶇疆锛堝湪娣诲姞鍒板満鏅悗璁剧疆锛?
	poison.global_position = pos
	
	# 浼ゅ璁℃椂鍣細鎸夐厤缃棿闅斾激瀹充竴娆?
	var dmg_timer = Timer.new()
	dmg_timer.name = "DamageTimer"
	dmg_timer.wait_time = pool_damage_interval
	dmg_timer.one_shot = false
	poison.add_child(dmg_timer)
	
	# 浣跨敤lambda鍑芥暟锛岄伩鍏嶄緷璧朎nemy瀹炰緥
	dmg_timer.timeout.connect(func():
		if not is_instance_valid(poison) or poison.is_queued_for_deletion():
			dmg_timer.stop()
			return
		
		# 妫€娴嬫墍鏈夊湪姣掓睜鑼冨洿鍐呯殑鐜╁
		var bodies = poison.get_overlapping_bodies()
		var areas = poison.get_overlapping_areas()
		var all_targets = bodies + areas
		
		for target in all_targets:
			var player_node = null
			
			if target.is_in_group("player"):
				player_node = target
			elif target.owner and target.owner.is_in_group("player"):
				player_node = target.owner
			
			if is_instance_valid(player_node) and player_node.has_method("take_damage"):
				player_node.take_damage(int(pool_damage), {
					"source": self,
					"kind": "enemy_poison_pool",
					"damage_type": "DMG_DOT",
				})
				Global.spawn_floating_text(player_node.global_position, "-" + str(int(pool_damage)), Color(0.5, 1.0, 0.5))
	)
	
	dmg_timer.start()
	
	# 鐢熷懡璁℃椂鍣細鎸夐厤缃椂闂村悗娑堝け
	var life_timer = Timer.new()
	life_timer.name = "LifeTimer"
	life_timer.wait_time = pool_lifetime
	life_timer.one_shot = true
	poison.add_child(life_timer)
	
	life_timer.timeout.connect(func():
		if is_instance_valid(poison):
			if is_instance_valid(vis):
				var fade_tween = poison.create_tween()
				fade_tween.tween_property(vis, "color:a", 0.0, 0.5)
				fade_tween.finished.connect(func():
					if is_instance_valid(poison):
						poison.queue_free()
				)
			else:
				poison.queue_free()
	)
	
	life_timer.start()
	
	SoundManager.play("poison_pool_spawn")
	Global.spawn_floating_text(pos, "TOXIC!", Color(0.5, 1.0, 0.5))
