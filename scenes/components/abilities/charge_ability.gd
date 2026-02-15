extends AbilityBase
class_name ChargeAbility

## 冲锋能力 - 向玩家冲刺攻击
## 配置示例: charge,冲锋,3.0,100,300,0,1,0.8,0.6,3.5,30

@export_group("Charge Settings")
@export var prep_time: float = 0.8  # 预警时间
@export var charge_duration: float = 0.6  # 冲锋持续时间
@export var speed_multiplier: float = 3.5  # 速度倍率
@export var warning_line_width: float = 30.0  # 预警线宽度
@export var warning_color: Color = Color(1, 0.2, 0.2, 0.3)  # 预警颜色

enum ChargeState { IDLE, PREPARING, CHARGING, COOLDOWN }

var charge_state: ChargeState = ChargeState.IDLE
var charge_direction: Vector2 = Vector2.ZERO
var charge_timer: float = 0.0
var warning_line: Line2D = null

# ==============================================================================
# 初始化
# ==============================================================================
func _ready() -> void:
	super._ready()
	ability_id = "charge"
	ability_name = "冲锋"
	set_process(true)
	
	# 创建预警线
	warning_line = Line2D.new()
	warning_line.width = warning_line_width
	warning_line.default_color = Color(1, 0, 0, 0)
	warning_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	warning_line.end_cap_mode = Line2D.LINE_CAP_ROUND
	warning_line.top_level = true
	add_child(warning_line)

func _process(delta: float) -> void:
	super._process(delta)
	
	match charge_state:
		ChargeState.IDLE:
			if auto_activate and can_activate():
				try_activate()
		
		ChargeState.PREPARING:
			_update_preparing(delta)
		
		ChargeState.CHARGING:
			_update_charging(delta)
		
		ChargeState.COOLDOWN:
			charge_timer -= delta
			if charge_timer <= 0:
				charge_state = ChargeState.IDLE

# ==============================================================================
# 能力实现
# ==============================================================================
func activate() -> void:
	"""激活能力 - 开始预警"""
	if not is_instance_valid(owner_enemy) or not is_instance_valid(Global.player):
		return
	
	charge_state = ChargeState.PREPARING
	charge_timer = prep_time
	
	# 锁定冲锋方向（优先嘲讽目标）
	var target_node = Global.player
	if "override_target" in owner_enemy and is_instance_valid(owner_enemy.override_target):
		target_node = owner_enemy.override_target
	charge_direction = owner_enemy.global_position.direction_to(
		target_node.global_position).normalized()
	
	# 敌人变色提示
	if owner_enemy.has_node("Visuals"):
		var visuals = owner_enemy.get_node("Visuals")
		var tween = create_tween()
		tween.tween_property(visuals, "modulate", Color(3.0, 0.5, 0.5, 1.0), 0.2)
	
	# 绘制预警线
	var end_pos = owner_enemy.global_position + (charge_direction * 500.0)
	warning_line.clear_points()
	warning_line.add_point(owner_enemy.global_position)
	warning_line.add_point(end_pos)
	
	var line_tween = create_tween()
	line_tween.tween_property(warning_line, "default_color", warning_color, 0.2)
	line_tween.parallel().tween_property(warning_line, "width", 20.0, prep_time)

func _update_preparing(delta: float) -> void:
	"""更新预警阶段"""
	charge_timer -= delta
	
	# 视觉震动
	if owner_enemy.has_node("Visuals"):
		var visuals = owner_enemy.get_node("Visuals")
		visuals.position = Vector2(randf_range(-2, 2), randf_range(-2, 2))
	
	# 更新预警线起点
	if warning_line.points.size() > 1:
		warning_line.set_point_position(0, owner_enemy.global_position)
	
	if charge_timer <= 0:
		_start_charging()

func _start_charging() -> void:
	"""开始冲锋"""
	charge_state = ChargeState.CHARGING
	charge_timer = charge_duration
	
	# 恢复视觉
	if owner_enemy.has_node("Visuals"):
		var visuals = owner_enemy.get_node("Visuals")
		visuals.position = Vector2.ZERO
		visuals.modulate = Color.WHITE
	
	# 隐藏预警线
	warning_line.default_color = Color(1, 0, 0, 0)
	warning_line.clear_points()
	
	# 禁用普通移动
	if owner_enemy.has("can_move"):
		owner_enemy.can_move = false

func _update_charging(delta: float) -> void:
	"""更新冲锋阶段"""
	charge_timer -= delta
	
	# 沿锁定方向移动
	if is_instance_valid(owner_enemy) and owner_enemy.has("speed"):
		owner_enemy.position += charge_direction * owner_enemy.speed * speed_multiplier * delta
	
	if charge_timer <= 0:
		_end_charging()

func _end_charging() -> void:
	"""结束冲锋"""
	charge_state = ChargeState.COOLDOWN
	charge_timer = cooldown
	
	# 恢复移动
	if owner_enemy.has("can_move"):
		owner_enemy.can_move = true
	
	start_cooldown()
	is_active = false
	ability_finished.emit()

# ==============================================================================
# 配置加载
# ==============================================================================
func setup(enemy: Node2D, config: Dictionary = {}) -> void:
	super.setup(enemy, config)
	
	if config.has("prep_time"):
		prep_time = float(config.prep_time)
	if config.has("charge_duration"):
		charge_duration = float(config.charge_duration)
	if config.has("speed_multiplier"):
		speed_multiplier = float(config.speed_multiplier)
	if config.has("warning_line_width"):
		warning_line_width = float(config.warning_line_width)

func get_config_template() -> Dictionary:
	var base = super.get_config_template()
	base.merge({
		"prep_time": prep_time,
		"charge_duration": charge_duration,
		"speed_multiplier": speed_multiplier,
		"warning_line_width": warning_line_width
	})
	return base
