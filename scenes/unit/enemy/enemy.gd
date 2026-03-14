extends Unit
class_name Enemy

const DEBUG_VERBOSE := false

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

@export_group("Charge Settings")
@export var can_charge: bool = false       # 鏄惁寮€鍚啿閿嬫妧鑳?(寤鸿鍦↖nspector缁欏埡鐚?纭３榫熷嬀閫?
@export var charge_prep_time: float = 0.8  # 棰勮鏃堕棿 (绾㈢嚎鏄剧ず鏃堕棿)
@export var charge_duration: float = 0.6   # 鍐查攱鎸佺画鏃堕棿
@export var charge_speed_mult: float = 3.5 # 鍐查攱閫熷害鍊嶇巼
@export var charge_cooldown: float = 3.0   # 鍐峰嵈鏃堕棿

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
	
	# 鏍规嵁 enemy_id 璁剧疆鏁屼汉绫诲瀷
	_set_enemy_type_from_id()
	
	# 搴旂敤CSV閰嶇疆
	_apply_visual_from_config()  # 搴旂敤瑙嗚閰嶇疆锛堢簿鐏点€佺缉鏀俱€佺鎾炰綋绛夛級
	_apply_color_from_config()   # 搴旂敤棰滆壊閰嶇疆
	_apply_behavior_from_config() # 搴旂敤琛屼负閰嶇疆
	_sync_contact_hitbox_damage()
	
	original_modulate = visuals.modulate
	
	_setup_special_nodes()
	_init_boss_phase_template()
	
	if enemy_type == EnemyType.SPIKED:
		can_charge = true

	_apply_split_spawn_profile()

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
	
	_process_status_effects(delta)
	_process_elite_affix(delta)
	_process_boss_phase_template(delta)
	
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
	if enemy_id != "boss_enemy":
		return

	var grouped: Dictionary = ConfigRepository.load_boss_phase_configs()
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
	var move_vec = get_move_direction() + (knockback_dir * knockback_power)
		
	position += move_vec * speed * delta
	update_rotation()
	
	# 5. 鍐查攱鍒ゅ畾
	if can_charge:
		if dist < 300.0 and dist > 100.0: 
			start_charge_sequence()

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
	
	position += charge_vector * speed * charge_speed_mult * delta
	
	# 杩欓噷涓嶆洿鏂版湞鍚戯紝淇濇寔鍐查攱鏃剁殑闇镐綋鎰?
	
	if ai_timer <= 0:
		current_ai_state = AIState.COOLDOWN
		ai_timer = charge_cooldown

# --- 5. 鍐峰嵈闃舵 ---
func _state_cooldown(delta: float) -> void:
	ai_timer -= delta
	
	# 缂撴參绉诲姩
	var move_vec = get_move_direction() * 0.2
	position += move_vec * speed * delta
	update_rotation()
	
	if ai_timer <= 0:
		current_ai_state = AIState.CHASE

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
	var direction := global_position.direction_to(target_node.global_position)
	
	# 3. 缇よ仛閫昏緫 (淇濇寔涓嶅彉)
	for area: Node2D in vision_area.get_overlapping_areas():
		if area != self and area.is_inside_tree():
			var vector := global_position - area.global_position
			if vector.length() > 0:
				direction += flock_push * vector.normalized() / vector.length()
	return direction

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
	if BondManager.has_mechanic("debuff_duration"):
		var original_duration = duration
		duration *= 1.5
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
		health_component.take_damage(damage)
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
	
# ==============================================================================
# 鍑婚€€涓庡彈鍑?(淇濇寔涔嬪墠鐨勪慨澶?
# ==============================================================================
func apply_knockback(knock_dir: Vector2, knock_power: float) -> void:
	# 鍐查攱鏈熼棿鍏嶇柅鍑婚€€ (闇镐綋)
	if current_ai_state == AIState.CHARGING: return
	
	knockback_dir = knock_dir
	knockback_power = knock_power
	if knockback_timer.time_left > 0:
		knockback_timer.stop()
		reset_knockback()
	knockback_timer.start()

func reset_knockback() -> void:
	knockback_dir = Vector2.ZERO
	knockback_power = 0.0

func _on_knockback_timer_timeout() -> void:
	reset_knockback()

func _on_hurtbox_component_on_damaged(hitbox: HitboxComponent) -> void:
	if is_dead: return

	# 1. 纭３榫熷弽浼ら€昏緫 (淇敼涓哄噺浼よ€屼笉鏄畬鍏ㄦ牸鎸?
	if enemy_type == EnemyType.SHIELDED and hitbox.source == Global.player:
		Global.spawn_floating_text(global_position, "SHIELD!", Color.CYAN)
		
		# 鍑忓皯浼ゅ鍒?30%
		hitbox.damage *= 0.3
		
		# 杞诲井鍙嶄激鐜╁
		if Global.player.has_method("take_damage"):
			Global.player.take_damage(1) 
		
		# 涓嶅啀 return锛岀户缁墽琛屾甯镐激瀹抽€昏緫

	# 2. 姝ｅ父浼ゅ
	super._on_hurtbox_component_on_damaged(hitbox)
	
	if hitbox.knockback_power > 0:
		# 瀹夊叏妫€鏌ワ細纭繚 source 浠嶇劧鏈夋晥
		if hitbox.source and is_instance_valid(hitbox.source):
			var dir := hitbox.source.global_position.direction_to(global_position)
			apply_knockback(dir, hitbox.knockback_power)
	
	# 澧炲己鎵撳嚮鎰燂細鏁屼汉鍙楀嚮鏃剁殑鍙嶉
	# 瀹夊叏妫€鏌ワ細纭繚 source 鍜?Global.player 浠嶇劧鏈夋晥
	if hitbox.source and is_instance_valid(hitbox.source) and hitbox.source == Global.player: 
		var is_elite_target: bool = self is EnemyElites
		if Global.has_method("apply_enemy_hit_feedback"):
			Global.apply_enemy_hit_feedback(hitbox.damage, hitbox.critical, is_elite_target)

func despawn_for_wave_end() -> void:
	# Force-remove enemy for wave settlement without rewards, drops, split, or poison pool.
	if is_dead:
		return
	is_dead = true
	can_move = false

	if warning_line and is_instance_valid(warning_line):
		warning_line.queue_free()

	if collision_shape:
		collision_shape.set_deferred("disabled", true)

	if contact_hitbox:
		contact_hitbox.monitoring = false
		contact_hitbox.monitorable = false

	clear_all_statuses()
	queue_free()

func destroy_enemy() -> void:
	if is_dead: return
	is_dead = true
	can_move = false
	
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
		
		# P1-1: 鍑绘潃鍥炶兘锛堝ⅷ鐏电緛缁婏級
		if Global.player.has_method("gain_energy"):
			var energy_drop = enemy_config.get("energy_drop", 5)
			
			# 妫€鏌ュⅷ鐏电緛缁?- 鍑绘潃鍥炶兘
			if BondManager.has_mechanic("kill_regen"):
				var bonus_energy = BondManager.get_mechanic_value("kill_regen")
				energy_drop += bonus_energy
				if DEBUG_VERBOSE: print("[Enemy] [P1-1] 鍑绘潃鍥炶兘瑙﹀彂: 鍩虹%d + 澧ㄧ伒%d = %d" % [
					enemy_config.get("energy_drop", 5),
					bonus_energy,
					energy_drop
				])
				# 瑙嗚鍙嶉锛堝湪鐜╁浣嶇疆鏄剧ず锛?
				Global.spawn_floating_text(Global.player.global_position, "+%d ENERGY" % bonus_energy, Color(0.5, 1.5, 2.0))
			
			Global.player.gain_energy(energy_drop)
		
		# 缁忛獙濂栧姳
		if Global.player.has_method("add_xp"):
			var xp_value = int(enemy_config.get("xp_value", 10))
			Global.player.add_xp(xp_value)
		
		# 閲戝竵濂栧姳 - 鏀逛负鐢熸垚閲戝竵瀹炰綋
		var gold_value = int(enemy_config.get("gold_value", 5))
		if gold_value > 0:
			Global.spawn_coin(global_position, gold_value)
	
	Global.add_session_kill()

	var arena = get_tree().get_first_node_in_group("arena")
	if arena and arena.has_method("record_enemy_wave_loot_drop"):
		arena.record_enemy_wave_loot_drop(enemy_id, self is EnemyElites)
	
	if Global.player and Global.player.has_method("on_enemy_killed"):
		Global.player.on_enemy_killed(self)
	
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
	var scene_path: String = scene_file_path
	if scene_path.is_empty():
		scene_path = "res://scenes/unit/enemy/enemy_generic.tscn"
	var scene := load(scene_path) as PackedScene
	if scene == null:
		return

	for i in range(2):
		var child_enemy = scene.instantiate() as Enemy
		if child_enemy == null:
			continue
		child_enemy.enemy_id = enemy_id
		child_enemy.global_position = global_position + Vector2(randf_range(-36, 36), randf_range(-24, 24))
		child_enemy.elite_affix_id = ""
		child_enemy.set_meta("split_spawn_profile", {
			"speed_mult": 1.12,
			"damage_mult": 0.60,
			"hp_mult": 0.45
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

	speed *= speed_mult
	damage *= damage_mult
	health *= hp_mult
	if health_component:
		health_component.max_health *= hp_mult
		health_component.current_health = health_component.max_health
	_sync_contact_hitbox_damage()

# 鍦伴浄鎬鍚庣敓鎴愭瘨姹?
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
				player_node.take_damage(int(pool_damage))
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
