# Design Document - Weaver Q技能重新设计

## Overview

本设计文档描述了织网者（PlayerWeaver）Q技能的重新设计。新设计将技能分为两个阶段：编织（Weave）和收割（Recall）。玩家通过按住Q键进入子弹时间绘制丝线路径，松开Q键后丝线实体化并滞留8秒，再次按Q键或8秒后自动触发收割效果。

设计目标：
1. 保持与PlayerHerder相同的Q技能操作流程
2. 实现独特的定身+易伤+收割机制
3. 提供清晰的视觉反馈和战术深度
4. 确保性能优化和代码可维护性

## Architecture

### 状态机设计

```
┌─────────────────┐
│   IDLE_MODE     │ (初始状态)
│  (编织模式)      │
└────────┬────────┘
         │ 按住Q键
         ▼
┌─────────────────┐
│  PLANNING_MODE  │ (子弹时间)
│  (规划路径)      │
└────────┬────────┘
         │ 松开Q键
         ▼
┌─────────────────┐
│   WEAVE_MODE    │ (丝线存在)
│  (收割模式)      │
└────────┬────────┘
         │ 按Q键 或 8秒后
         ▼
┌─────────────────┐
│  RECALL_MODE    │ (执行收割)
│  (收割中)        │
└────────┬────────┘
         │ 收割完成
         ▼
     IDLE_MODE
```

### 组件结构

```
PlayerWeaver
├── State Variables
│   ├── skill_state: SkillState (IDLE/PLANNING/WEAVE/RECALL)
│   ├── path_points: Array[Vector2] (路径点集合)
│   ├── web_lines: Array[Line2D] (实体化的丝线)
│   ├── cocooned_enemies: Array[Enemy] (被结茧的敌人)
│   └── web_lifetime_timer: Timer (8秒计时器)
│
├── Visual Components
│   ├── line_2d: Line2D (预览线和路径线)
│   ├── web_container: Node2D (丝线容器)
│   └── cocoon_polygon: Polygon2D (闭合区域视觉)
│
└── Logic Methods
    ├── charge_skill_q() (按住Q - 进入规划)
    ├── release_skill_q() (松开Q - 实体化丝线)
    ├── try_add_path_point() (左键 - 添加路径点)
    ├── undo_last_point() (右键 - 撤销路径点)
    ├── check_path_closed() (判定路径是否闭合)
    ├── apply_cocoon_effect() (应用结茧效果)
    ├── trigger_recall() (触发收割)
    ├── apply_recall_damage() (应用收割伤害)
    └── cleanup_webs() (清理丝线)
```

## Components and Interfaces

### 1. 状态枚举

```gdscript
enum SkillState {
    IDLE,      # 编织模式 - 可以按住Q进入规划
    PLANNING,  # 规划模式 - 子弹时间，绘制路径
    WEAVE,     # 收割模式 - 丝线存在，等待收割
    RECALL     # 收割中 - 正在执行收割动画
}
```

### 2. 核心变量

```gdscript
# 状态管理
var skill_state: SkillState = SkillState.IDLE
var is_planning: bool = false  # 兼容Herder的变量名

# 路径数据
var path_points: Array[Vector2] = []  # 已确认的路径点
var web_lines: Array[Line2D] = []     # 实体化的丝线
var closed_polygon: PackedVector2Array = []  # 闭合路径的多边形

# 敌人标记
var cocooned_enemies: Array[Enemy] = []  # 被结茧的敌人（有易伤标记）
var rooted_enemies: Array[Enemy] = []    # 被定身的敌人

# 计时器
var web_lifetime_timer: Timer = null  # 8秒自动收割计时器

# 配置参数
var web_duration: float = 8.0          # 丝线存活时间
var close_threshold: float = 60.0      # 闭合判定距离
var path_check_width: float = 30.0     # 路径判定宽度
var normal_recall_damage: int = 50     # 普通收割伤害
var cocoon_recall_damage_mult: float = 2.5  # 破茧伤害倍率（250%）
```

### 3. 视觉组件

```gdscript
@onready var line_2d: Line2D = $Line2D  # 复用Herder的Line2D
@onready var web_container: Node2D = Node2D.new()  # 丝线容器
```

## Data Models

### PathPoint 数据结构

```gdscript
# 路径点不需要单独的类，直接使用Vector2数组
# path_points: Array[Vector2]
```

### EnemyMark 数据结构

```gdscript
# 敌人标记通过数组管理
# cocooned_enemies: Array[Enemy]  # 有易伤标记
# rooted_enemies: Array[Enemy]     # 被定身
```

### WebLine 数据结构

```gdscript
# 丝线使用Line2D节点
# 属性：
# - points: PackedVector2Array  # 线段的起点和终点
# - width: float = 3.0
# - default_color: Color = Color.WHITE (开放) / Color.RED (闭合)
```

## Correctness Properties

*属性是关于系统应该满足的特征或行为的正式陈述，这些陈述应该在所有有效执行中保持为真。属性作为人类可读规范和机器可验证正确性保证之间的桥梁。*

### Property 1: 状态转换一致性
*对于任何*技能状态序列，状态转换必须遵循定义的状态机规则（IDLE → PLANNING → WEAVE → RECALL → IDLE）
**Validates: Requirements 1.1, 10.1, 10.2, 10.3, 10.4, 10.5, 10.6**

### Property 2: 子弹时间保持
*对于任何*PLANNING状态，Engine.time_scale必须保持为0.1，不受顿帧系统影响
**Validates: Requirements 1.1, 1.5**

### Property 3: 能量守恒
*对于任何*路径点添加和撤销操作序列，能量变化总和必须等于（添加次数 - 撤销次数）× skill_q_cost
**Validates: Requirements 8.1, 8.2, 8.3**

### Property 4: 路径闭合判定
*对于任何*路径点集合，如果最后一点距离第一点小于close_threshold或存在线段相交，则必须判定为闭合路径
**Validates: Requirements 4.1, 13.1, 13.2, 13.3**

### Property 5: 结茧效果完整性
*对于任何*闭合路径，圈内的所有敌人必须同时被定身且挂上易伤标记
**Validates: Requirements 4.2, 4.3, 4.4, 4.5, 4.6**

### Property 6: 收割伤害计算
*对于任何*敌人，如果有易伤标记则受到250%伤害，否则受到100%伤害
**Validates: Requirements 6.1, 6.2, 6.3, 7.1**

### Property 7: 丝线生命周期
*对于任何*实体化的丝线，必须在8秒后自动触发收割或被手动收割清除
**Validates: Requirements 2.5, 5.2, 12.1**

### Property 8: 输入优先级
*对于任何*输入序列，E键优先级最高，Q键次之，左键最低
**Validates: Requirements 11.1, 11.2, 11.3, 11.4**

### Property 9: 资源清理
*对于任何*技能结束或角色切换，所有丝线、标记、定身效果必须被清除
**Validates: Requirements 12.2, 12.3, 12.4, 12.5**

### Property 10: 路径点唯一性
*对于任何*路径点添加操作，如果能量不足则路径点不被添加
**Validates: Requirements 8.3, 8.4**

## Error Handling

### 1. 能量不足

**场景**: 玩家尝试添加路径点但能量不足

**处理**:
```gdscript
if not consume_energy(skill_q_cost):
    Global.spawn_floating_text(global_position, "No Energy!", Color.RED)
    return false
```

### 2. 无效路径

**场景**: 玩家松开Q键时路径点少于2个

**处理**:
```gdscript
if path_points.size() < 2:
    Global.spawn_floating_text(global_position, "Need More Points!", Color.GRAY)
    path_points.clear()
    return
```

### 3. 敌人已死亡

**场景**: 收割时敌人已经死亡

**处理**:
```gdscript
# 在应用伤害前检查
if not is_instance_valid(enemy) or enemy.is_dead:
    continue
```

### 4. 丝线已清除

**场景**: 8秒计时器触发时丝线已被手动收割

**处理**:
```gdscript
func _on_web_lifetime_timeout() -> void:
    if skill_state != SkillState.WEAVE:
        return  # 已经被手动收割了
    trigger_recall()
```

### 5. 状态冲突

**场景**: 玩家在RECALL状态时尝试进入PLANNING

**处理**:
```gdscript
func charge_skill_q(delta: float) -> void:
    if skill_state == SkillState.RECALL:
        return  # 收割中，忽略输入
    # ...
```

## Testing Strategy

### Unit Tests

#### 测试1: 状态转换
```gdscript
func test_state_transitions():
    # 初始状态
    assert(weaver.skill_state == SkillState.IDLE)
    
    # 按住Q进入规划
    weaver.charge_skill_q(0.1)
    assert(weaver.skill_state == SkillState.PLANNING)
    assert(Engine.time_scale == 0.1)
    
    # 松开Q实体化
    weaver.release_skill_q()
    assert(weaver.skill_state == SkillState.WEAVE)
    assert(Engine.time_scale == 1.0)
    
    # 再次按Q收割
    weaver.release_skill_q()
    assert(weaver.skill_state == SkillState.RECALL)
```

#### 测试2: 能量消耗
```gdscript
func test_energy_consumption():
    var initial_energy = weaver.energy
    
    # 添加路径点
    weaver.try_add_path_point()
    assert(weaver.energy == initial_energy - weaver.skill_q_cost)
    
    # 撤销路径点
    weaver.undo_last_point()
    assert(weaver.energy == initial_energy)
```

#### 测试3: 闭合路径判定
```gdscript
func test_path_closure():
    # 开放路径
    weaver.path_points = [Vector2(0, 0), Vector2(100, 0), Vector2(100, 100)]
    assert(not weaver.check_path_closed())
    
    # 闭合路径（距离判定）
    weaver.path_points = [Vector2(0, 0), Vector2(100, 0), Vector2(100, 100), Vector2(50, 50)]
    assert(weaver.check_path_closed())
```

#### 测试4: 结茧效果
```gdscript
func test_cocoon_effect():
    # 创建闭合路径
    weaver.path_points = [Vector2(0, 0), Vector2(200, 0), Vector2(200, 200), Vector2(0, 200)]
    weaver.closed_polygon = PackedVector2Array(weaver.path_points)
    
    # 创建敌人在圈内
    var enemy = create_test_enemy(Vector2(100, 100))
    
    # 应用结茧效果
    weaver.apply_cocoon_effect()
    
    # 验证
    assert(not enemy.can_move)  # 被定身
    assert(enemy in weaver.cocooned_enemies)  # 有易伤标记
```

#### 测试5: 收割伤害
```gdscript
func test_recall_damage():
    # 普通敌人
    var normal_enemy = create_test_enemy(Vector2(50, 0))
    var initial_health = normal_enemy.health_component.current_health
    
    weaver.apply_recall_damage_to_enemy(normal_enemy)
    assert(normal_enemy.health_component.current_health == initial_health - weaver.normal_recall_damage)
    
    # 结茧敌人
    var cocooned_enemy = create_test_enemy(Vector2(100, 0))
    weaver.cocooned_enemies.append(cocooned_enemy)
    initial_health = cocooned_enemy.health_component.current_health
    
    weaver.apply_recall_damage_to_enemy(cocooned_enemy)
    var expected_damage = weaver.normal_recall_damage * weaver.cocoon_recall_damage_mult
    assert(cocooned_enemy.health_component.current_health == initial_health - expected_damage)
```

### Property-Based Tests

#### 属性测试1: 状态转换一致性
```gdscript
func property_test_state_transitions():
    # 生成随机输入序列
    for i in range(100):
        var weaver = create_test_weaver()
        var actions = generate_random_actions()
        
        for action in actions:
            execute_action(weaver, action)
            
            # 验证状态转换合法
            assert(is_valid_state_transition(weaver.previous_state, weaver.skill_state))
```

#### 属性测试2: 能量守恒
```gdscript
func property_test_energy_conservation():
    for i in range(100):
        var weaver = create_test_weaver()
        var initial_energy = weaver.energy
        
        # 随机添加和撤销路径点
        var add_count = randi() % 10
        var undo_count = randi() % add_count
        
        for j in range(add_count):
            weaver.try_add_path_point()
        
        for j in range(undo_count):
            weaver.undo_last_point()
        
        # 验证能量变化
        var expected_energy = initial_energy - (add_count - undo_count) * weaver.skill_q_cost
        assert(weaver.energy == expected_energy)
```

#### 属性测试3: 路径闭合判定
```gdscript
func property_test_path_closure():
    for i in range(100):
        var weaver = create_test_weaver()
        
        # 生成随机路径
        var point_count = randi() % 10 + 3
        var points = generate_random_points(point_count)
        weaver.path_points = points
        
        # 手动判定是否闭合
        var manually_closed = is_manually_closed(points, weaver.close_threshold)
        
        # 验证算法判定结果
        assert(weaver.check_path_closed() == manually_closed)
```

#### 属性测试4: 收割伤害计算
```gdscript
func property_test_recall_damage():
    for i in range(100):
        var weaver = create_test_weaver()
        var enemy = create_test_enemy(Vector2.ZERO)
        
        # 随机决定是否结茧
        var is_cocooned = randf() > 0.5
        if is_cocooned:
            weaver.cocooned_enemies.append(enemy)
        
        var initial_health = enemy.health_component.current_health
        weaver.apply_recall_damage_to_enemy(enemy)
        
        # 验证伤害计算
        var expected_damage = weaver.normal_recall_damage
        if is_cocooned:
            expected_damage *= weaver.cocoon_recall_damage_mult
        
        assert(enemy.health_component.current_health == initial_health - expected_damage)
```

#### 属性测试5: 资源清理
```gdscript
func property_test_resource_cleanup():
    for i in range(100):
        var weaver = create_test_weaver()
        
        # 创建随机数量的丝线和标记
        var web_count = randi() % 10
        var enemy_count = randi() % 20
        
        for j in range(web_count):
            weaver.web_lines.append(create_test_line())
        
        for j in range(enemy_count):
            var enemy = create_test_enemy(Vector2.ZERO)
            weaver.cocooned_enemies.append(enemy)
            weaver.rooted_enemies.append(enemy)
        
        # 清理
        weaver.cleanup_webs()
        
        # 验证所有资源被清理
        assert(weaver.web_lines.size() == 0)
        assert(weaver.cocooned_enemies.size() == 0)
        assert(weaver.rooted_enemies.size() == 0)
        assert(weaver.path_points.size() == 0)
```

### Integration Tests

#### 集成测试1: 完整技能流程
```gdscript
func integration_test_full_skill_flow():
    var weaver = create_test_weaver()
    var enemies = create_test_enemies(10)
    
    # 1. 进入规划模式
    weaver.charge_skill_q(0.1)
    assert(weaver.skill_state == SkillState.PLANNING)
    
    # 2. 添加路径点形成闭合路径
    weaver.try_add_path_point()  # 点1
    weaver.try_add_path_point()  # 点2
    weaver.try_add_path_point()  # 点3
    weaver.try_add_path_point()  # 点4（接近点1）
    
    # 3. 松开Q实体化
    weaver.release_skill_q()
    assert(weaver.skill_state == SkillState.WEAVE)
    assert(weaver.web_lines.size() > 0)
    
    # 4. 验证结茧效果
    var cocooned_count = 0
    for enemy in enemies:
        if enemy in weaver.cocooned_enemies:
            cocooned_count += 1
            assert(not enemy.can_move)
    assert(cocooned_count > 0)
    
    # 5. 触发收割
    weaver.release_skill_q()
    assert(weaver.skill_state == SkillState.RECALL)
    
    # 6. 等待收割完成
    await get_tree().create_timer(0.5).timeout
    assert(weaver.skill_state == SkillState.IDLE)
    assert(weaver.web_lines.size() == 0)
```

#### 集成测试2: 与其他技能交互
```gdscript
func integration_test_skill_interaction():
    var weaver = create_test_weaver()
    
    # 1. 进入规划模式
    weaver.charge_skill_q(0.1)
    assert(weaver.skill_state == SkillState.PLANNING)
    
    # 2. 按E键（应该优先触发E技能）
    weaver.use_skill_e()
    assert(weaver.skill_state == SkillState.IDLE)  # 退出规划模式
    assert(Engine.time_scale == 1.0)
    
    # 3. 在规划模式中点击左键（应该添加路径点，不触发冲刺）
    weaver.charge_skill_q(0.1)
    var initial_pos = weaver.global_position
    weaver.try_add_path_point()
    assert(weaver.global_position == initial_pos)  # 没有移动
    assert(weaver.path_points.size() == 1)  # 添加了路径点
```

## Implementation Notes

### 1. 复用Herder的代码

从PlayerHerder复用以下方法（修改变量名以适应Weaver）：

```gdscript
# 子弹时间管理
func enter_planning_mode() -> void:
    is_planning = true
    skill_state = SkillState.PLANNING
    Engine.time_scale = 0.1

func exit_planning_mode() -> void:
    is_planning = false
    Engine.time_scale = 1.0

# 路径点管理
func try_add_path_point() -> bool:
    if consume_energy(skill_q_cost):
        add_path_point(get_global_mouse_position())
        return true
    return false

func add_path_point(mouse_pos: Vector2) -> void:
    path_points.append(mouse_pos)

func undo_last_point() -> void:
    if path_points.size() > 0:
        path_points.pop_back()
        energy += skill_q_cost
        update_ui_signals()

# 子弹时间保持（防止顿帧重置）
func _process_subclass(delta: float) -> void:
    if is_planning:
        if Engine.time_scale > 0.2:
            Engine.time_scale = 0.1
    # ...
```

### 2. 复用Butcher的代码

从PlayerButcher复用以下方法（修改以适应静态路径）：

```gdscript
# 路径扫描（检测路径上的敌人）
func scan_enemies_on_path(start: Vector2, end: Vector2) -> Array[Enemy]:
    var result: Array[Enemy] = []
    var enemies = get_tree().get_nodes_in_group("enemies")
    
    for enemy in enemies:
        if not is_instance_valid(enemy): continue
        var closest = Geometry2D.get_closest_point_to_segment(enemy.global_position, start, end)
        if enemy.global_position.distance_to(closest) < path_check_width:
            result.append(enemy)
    
    return result

# 辅助线绘制（从丝线到玩家的连线）
func _update_web_chains() -> void:
    # 清理旧的辅助线
    for c in chain_container.get_children(): 
        c.queue_free()
    
    # 绘制新的辅助线
    if web_lines.is_empty(): return
    
    for web_line in web_lines:
        if is_instance_valid(web_line):
            var line = Line2D.new()
            line.width = 2.0
            line.default_color = Color(0.5, 0.5, 0.5, 0.5)
            line.add_point(global_position)
            line.add_point(web_line.global_position)
            chain_container.add_child(line)
```

### 3. 闭合路径判定

复用Herder的find_closing_polygon方法：

```gdscript
func check_path_closed() -> bool:
    if path_points.size() < 3:
        return false
    
    # 方法1: 距离判定
    var first_point = path_points[0]
    var last_point = path_points.back()
    if first_point.distance_to(last_point) < close_threshold:
        closed_polygon = PackedVector2Array(path_points)
        return true
    
    # 方法2: 线段相交判定
    var last_segment_start = path_points[path_points.size() - 2]
    for i in range(path_points.size() - 2):
        var old_pos = path_points[i]
        var old_next = path_points[i + 1]
        
        var intersection = Geometry2D.segment_intersects_segment(
            last_segment_start, last_point, old_pos, old_next
        )
        
        if intersection:
            # 构建闭合多边形
            closed_polygon = PackedVector2Array()
            closed_polygon.append(intersection)
            for j in range(i + 1, path_points.size() - 1):
                closed_polygon.append(path_points[j])
            closed_polygon.append(intersection)
            return true
    
    return false
```

### 4. 视觉更新

复用Herder的_update_visuals方法：

```gdscript
func _update_visuals() -> void:
    # 清理
    line_2d.clear_points()
    
    # 如果不在规划模式且没有路径点，不绘制
    if not is_planning and path_points.is_empty():
        return
    
    # 绘制已确认的路径点
    for p in path_points:
        line_2d.add_point(p)
    
    # 绘制预览线段（规划模式）
    if is_planning:
        var start = global_position
        if path_points.size() > 0:
            start = path_points.back()
        line_2d.add_point(get_global_mouse_position())
    
    # 设置颜色
    if check_path_closed():
        line_2d.default_color = Color(1.0, 0.2, 0.2, 1.0)  # 红色
    elif energy < skill_q_cost:
        line_2d.default_color = Color(0.5, 0.5, 0.5, 0.5)  # 灰色
    else:
        line_2d.default_color = Color.WHITE  # 白色
```

### 5. 性能优化

- 使用对象池管理Line2D节点
- 缓存闭合多边形，避免重复计算
- 使用Timer而不是每帧检查时间
- 及时清理无效的敌人引用

```gdscript
# 清理无效敌人引用
func _clean_invalid_enemies() -> void:
    cocooned_enemies = cocooned_enemies.filter(func(e): return is_instance_valid(e))
    rooted_enemies = rooted_enemies.filter(func(e): return is_instance_valid(e))
```

### 6. 调试辅助

添加调试信息：

```gdscript
func _print_debug_info() -> void:
    if OS.is_debug_build():
        print("[Weaver] State: %s, Points: %d, Webs: %d, Cocooned: %d" % [
            SkillState.keys()[skill_state],
            path_points.size(),
            web_lines.size(),
            cocooned_enemies.size()
        ])
```

## Migration Plan

### 阶段1: 准备工作
1. 备份当前的player_weaver.gd
2. 创建新的状态枚举和变量
3. 添加必要的节点引用

### 阶段2: 实现核心逻辑
1. 实现状态机转换
2. 复用Herder的子弹时间逻辑
3. 实现路径点添加/撤销
4. 实现闭合路径判定

### 阶段3: 实现结茧效果
1. 实现敌人定身逻辑
2. 实现易伤标记系统
3. 实现视觉反馈

### 阶段4: 实现收割系统
1. 实现收割触发逻辑
2. 复用Butcher的路径扫描
3. 实现伤害计算
4. 实现收缩动画

### 阶段5: 测试和优化
1. 单元测试
2. 属性测试
3. 集成测试
4. 性能优化
5. 调试和修复

### 阶段6: 清理和文档
1. 移除旧代码
2. 更新注释
3. 更新PLAYERS.md文档
