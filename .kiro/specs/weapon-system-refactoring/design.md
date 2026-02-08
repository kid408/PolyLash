# 武器系统重构 - 设计文档

## 1. 系统架构

### 1.1 整体架构图

```
┌─────────────────────────────────────────────────────────────┐
│                    Weapon System Architecture                │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  ┌──────────────┐         ┌──────────────┐                  │
│  │ weapon_config│────────▶│WeaponConfig  │                  │
│  │    .csv      │  Parse  │   Loader     │                  │
│  └──────────────┘         └──────┬───────┘                  │
│                                   │                          │
│                                   ▼                          │
│                          ┌────────────────┐                 │
│                          │  WeaponStats   │                 │
│                          └────────┬───────┘                 │
│                                   │                          │
│                    ┌──────────────┴──────────────┐          │
│                    ▼                             ▼          │
│           ┌────────────────┐          ┌────────────────┐   │
│           │  ItemWeapon    │          │    Weapon      │   │
│           │   (Data)       │          │   (Scene)      │   │
│           └────────────────┘          └────────┬───────┘   │
│                                                 │           │
│                                ┌────────────────┴────────┐  │
│                                ▼                         ▼  │
│                       ┌─────────────────┐    ┌──────────────┐
│                       │ MeleeBehavior   │    │RangeBehavior │
│                       │  (Dynamic       │    │  (Dynamic    │
│                       │   Hitbox)       │    │   Bullets)   │
│                       └─────────────────┘    └──────────────┘
│                                                               │
└─────────────────────────────────────────────────────────────┘
```

### 1.2 核心组件

#### 1.2.1 WeaponConfigLoader (已完成)
- **职责**: 解析 CSV，创建 WeaponStats
- **位置**: autoloads/weapon_config_loader.gd
- **状态**: ✅ 已实现

#### 1.2.2 MeleeBehavior (待实现)
- **职责**: 动态创建近战 hitbox，执行攻击动画
- **位置**: scenes/weapons/behaviors/melee_behavior.gd
- **状态**: ⏳ 待实现

#### 1.2.3 RangeBehavior (待实现)
- **职责**: 动态生成子弹，处理发射逻辑
- **位置**: scenes/weapons/behaviors/range_behavior.gd
- **状态**: ⏳ 待实现

#### 1.2.4 Projectile (待增强)
- **职责**: 子弹行为（穿透/治疗/追踪）
- **位置**: scenes/projectiles/projectile.gd
- **状态**: ⏳ 待增强

## 2. 详细设计

### 2.1 MeleeBehavior 动态 Hitbox 系统

#### 2.1.1 类结构

```gdscript
extends WeaponBehavior
class_name MeleeBehavior

var hitbox_area: Area2D
var hitbox_shape: CollisionShape2D
var current_shape: Shape2D

func setup_hitbox(stats: WeaponStats) -> void:
    # 动态创建/更新 hitbox shape
    pass

func execute_attack() -> void:
    # 调用 setup_hitbox，执行 Tween 动画
    pass
```

#### 2.1.2 Shape 类型映射

| shape_type | Shape2D 类型 | 参数来源 | 动画类型 |
|-----------|-------------|---------|---------|
| point | CircleShape2D | radius = max_range/2 或 param1 | 无动画 |
| line/thrust | RectangleShape2D | extent = Vector2(max_range, param2 或 20) | 前冲 Tween |
| sector | CollisionPolygon2D | 扇形点阵（sector_angle, max_range） | 旋转 Tween |
| circle | CircleShape2D | radius = param1 或 max_range | 旋转 Tween |

#### 2.1.3 扇形生成算法

```gdscript
func generate_sector_polygon(angle_deg: float, radius: float) -> PackedVector2Array:
    var points = PackedVector2Array()
    points.append(Vector2.ZERO)  # 中心点
    
    var segments = 16
    var start_angle = -angle_deg / 2.0
    var end_angle = angle_deg / 2.0
    
    for i in range(segments + 1):
        var t = float(i) / segments
        var current_angle = lerp(start_angle, end_angle, t)
        var rad = deg_to_rad(current_angle)
        var point = Vector2(cos(rad), sin(rad)) * radius
        points.append(point)
    
    return points
```

### 2.2 RangeBehavior 动态子弹系统

#### 2.2.1 类结构

```gdscript
extends WeaponBehavior
class_name RangeBehavior

func execute_attack() -> void:
    create_projectiles()

func create_projectiles() -> void:
    var stats = weapon.data.stats
    match stats.bullet_mode:
        "single":
            spawn_single_bullet()
        "spread":
            spawn_spread_bullets()
        "pierce":
            spawn_pierce_bullet()
        "magic", "arc":
            spawn_magic_bullet()
```

#### 2.2.2 子弹模式映射

| bullet_mode | 子弹数量 | 角度偏移 | 特殊属性 |
|------------|---------|---------|---------|
| single | 1 | 0 | 无 |
| spread | bullet_count | spread_angle 均分 | 无 |
| pierce | 1 | 0 | pierce_count |
| magic/arc | 1 | 0 | gravity, homing_strength |

#### 2.2.3 效果类型映射

| effect_type | 效果描述 | 参数来源 |
|------------|---------|---------|
| heal | 回复玩家生命值 | damage * heal_multiplier (param2) |
| buff | 增加队友伤害 buff | 持续时间 = param3 |
| fire | 燃烧 DOT（预留） | param1 = 伤害/秒 |
| ice | 减速效果（预留） | param1 = 减速比例 |

#### 2.2.4 治疗与 Buff 代码示例

```gdscript
# RangeBehavior.gd - 治疗效果示例
func spawn_heal_bullet() -> void:
    var projectile = projectile_scene.instantiate()
    projectile.setup({
        "damage": stats.damage,
        "effect_type": "heal",
        "heal_multiplier": float(stats.param2) if not stats.param2.is_empty() else 0.5,
        "param3": stats.param3  # 治疗范围
    })
    get_tree().current_scene.add_child(projectile)
    print("[RangeBehavior] 发射治疗弹: 倍率=", projectile.heal_multiplier)

# RangeBehavior.gd - Buff 效果示例
func spawn_buff_bullet() -> void:
    var projectile = projectile_scene.instantiate()
    projectile.setup({
        "damage": stats.damage,
        "effect_type": "buff",
        "buff_duration": float(stats.param3) if not stats.param3.is_empty() else 5.0
    })
    get_tree().current_scene.add_child(projectile)
    print("[RangeBehavior] 发射增益弹: 持续=", projectile.buff_duration, "秒")
```

#### 2.2.5 散射角度计算

```gdscript
func spawn_spread_bullets() -> void:
    var stats = weapon.data.stats
    var count = stats.bullet_count
    var spread = stats.spread_angle
    
    for i in range(count):
        var angle_offset = 0.0
        if count > 1:
            var t = float(i) / (count - 1)
            angle_offset = lerp(-spread / 2.0, spread / 2.0, t)
        
        spawn_bullet_at_angle(angle_offset)
```

### 2.3 Projectile 增强系统

#### 2.3.1 新增属性

```gdscript
class_name Projectile
extends Area2D

# 新增属性
var pierce_count: int = 0
var gravity: float = 0.0
var homing_strength: float = 0.0
var effect_type: String = ""
var heal_multiplier: float = 0.0
var param3: String = ""  # 用于范围治疗/buff 持续时间

# 已击中的敌人列表（用于穿透）
var hit_enemies: Array[Enemy] = []
```

#### 2.3.2 穿透逻辑

```gdscript
func _on_area_entered(area: Area2D) -> void:
    if area is Enemy:
        if area in hit_enemies:
            return  # 已击中过，跳过
        
        hit_enemies.append(area)
        apply_damage(area)
        
        pierce_count -= 1
        if pierce_count < 0:
            queue_free()
```

#### 2.3.3 治疗与 Buff 效果

```gdscript
func apply_damage(enemy: Enemy) -> void:
    enemy.take_damage(damage)
    
    # 治疗效果（支持范围治疗）
    if effect_type == "heal":
        apply_heal_effect()
    
    # Buff 效果
    if effect_type == "buff" and is_instance_valid(Global.player):
        var buff_duration = float(param3) if not param3.is_empty() else 5.0
        Global.player.apply_damage_buff(damage * 0.1, buff_duration)
        print("[Projectile] 应用伤害 buff: +", damage * 0.1, " 持续 ", buff_duration, "秒")

func apply_heal_effect() -> void:
    var heal_amount = damage * heal_multiplier
    var heal_range = float(param3) if not param3.is_empty() else 0.0
    
    # 治疗玩家
    if is_instance_valid(Global.player):
        Global.player.heal(heal_amount)
        print("[Projectile] 治疗玩家: ", heal_amount)
    
    # 范围治疗队友
    if heal_range > 0:
        var allies = get_tree().get_nodes_in_group("allies")
        for ally in allies:
            if global_position.distance_to(ally.global_position) <= heal_range:
                ally.heal(heal_amount)
                print("[Projectile] 治疗队友: ", ally.name, " +", heal_amount)
```

### 2.4 场景复用系统

#### 2.4.1 7 个基础场景

| 场景文件 | 用途 | WeaponBehavior | 特殊节点 |
|---------|------|---------------|---------|
| weapon_melee_point.tscn | 拳头类 | MeleeBehavior | 无 |
| weapon_melee_thrust.tscn | 长矛类 | MeleeBehavior | 无 |
| weapon_melee_sector.tscn | 斧头类 | MeleeBehavior | 无 |
| weapon_melee_circle.tscn | 弯刀类 | MeleeBehavior | 无 |
| weapon_range_physical.tscn | 手枪/霰弹枪 | RangeBehavior | Muzzle |
| weapon_range_beam.tscn | 激光类 | RangeBehavior | Muzzle |
| weapon_range_magic.tscn | 魔法棒类 | RangeBehavior | Muzzle |

#### 2.4.2 统一节点结构

```
Weapon (Node2D)
├─ Sprite2D
├─ HitboxComponent (Area2D)
│  └─ CollisionShape2D (动态 shape)
├─ CooldownTimer (Timer)
└─ WeaponBehavior (MeleeBehavior 或 RangeBehavior)
   └─ Muzzle (Marker2D, 仅远程武器)
```

## 3. 数据流设计

### 3.1 武器加载流程

```
1. ItemWeapon.create_from_csv(weapon_id)
   ↓
2. WeaponConfigLoader.get_weapon_stats(weapon_id)
   ↓
3. 解析 CSV 行，创建 WeaponStats
   ↓
4. 根据 base_scene_path 实例化场景
   ↓
5. Weapon.setup_weapon(ItemWeapon)
   ↓
6. 应用 sprite_texture, hitbox_offset, muzzle_offset
   ↓
7. WeaponBehavior.setup_hitbox() 或 create_projectiles()
```

### 3.2 攻击执行流程

#### 3.2.1 近战攻击

```
1. Weapon.use_weapon()
   ↓
2. MeleeBehavior.execute_attack()
   ↓
3. setup_hitbox(stats) - 动态创建 shape
   ↓
4. 创建 Tween 动画（旋转/前冲）
   ↓
5. HitboxComponent 检测碰撞
   ↓
6. 应用伤害和效果
```

#### 3.2.2 远程攻击

```
1. Weapon.use_weapon()
   ↓
2. RangeBehavior.execute_attack()
   ↓
3. create_projectiles() - 根据 bullet_mode
   ↓
4. 实例化 Projectile 场景
   ↓
5. 设置 pierce_count, gravity, effect_type
   ↓
6. 从 Muzzle 位置发射
   ↓
7. Projectile 检测碰撞，应用效果
```

## 4. CSV 扩展设计

### 4.1 新增武器变体分类

#### 4.1.1 近战变体（11 种新增）

| weapon_id | 显示名 | shape_type | 特殊参数 | 描述 |
|-----------|-------|-----------|---------|------|
| thrust_charged_1~4 | 蓄力突刺 | line | param1=蓄力时间 | 蓄力后前冲 |
| swing_cleave_1~4 | 横扫斩击 | sector | sector_angle=120 | 大范围横扫 |
| swing_heavy_1~4 | 重型挥砍 | sector | sector_angle=60 | 高伤害窄角度 |
| circular_vortex_1~4 | 旋风斩 | circle | param1=旋转速度 | 持续旋转 |
| circular_dual_1~4 | 双刀旋舞 | circle | param1=攻击次数 | 多段攻击 |
| hammer_smash_1~4 | 战锤重击 | point | param1=震荡范围 | AOE 伤害 |
| whip_lash_1~4 | 鞭击 | line | max_range=300 | 超长距离 |
| spear_spin_1~4 | 长矛旋转 | circle | param1=旋转角度 | 360度攻击 |
| dagger_flurry_1~4 | 匕首连击 | point | param1=连击次数 | 快速多次 |
| scythe_reap_1~4 | 镰刀收割 | sector | sector_angle=180 | 半圆攻击 |
| chain_whip_1~4 | 链鞭 | line | param1=链节数 | 多段判定 |

#### 4.1.2 远程变体（10 种新增）

| weapon_id | 显示名 | bullet_mode | 特殊参数 | 描述 |
|-----------|-------|------------|---------|------|
| single_arc_1~4 | 弧线箭 | magic | gravity=200 | 抛物线弹道 |
| single_sniper_1~4 | 狙击枪 | single | projectile_speed=3000 | 超高速 |
| spread_fan_1~4 | 扇形散射 | spread | bullet_count=7 | 扇形覆盖 |
| spread_burst_1~4 | 爆发散射 | spread | bullet_count=12 | 大量子弹 |
| pierce_ricochet_1~4 | 穿透反弹 | pierce | pierce_count=5 | 多次穿透 |
| pierce_laser_1~4 | 穿透激光 | pierce | pierce_count=-1 | 无限穿透 |
| magic_chain_1~4 | 连锁闪电 | magic | param1=跳跃次数, effect_type=chain | 链式攻击 |
| magic_meteor_1~4 | 陨石术 | magic | gravity=500, effect_type=fire | 高伤害AOE |
| magic_heal_aoe_1~4 | 治疗光环 | magic | effect_type=heal, param3=范围 | 范围治疗 |
| bow_arrow_1~4 | 弓箭 | single | gravity=100 | 物理弓箭 |

### 4.2 数值渐进规则

#### 4.2.1 基础数值

| 属性 | 1级 | 2级 | 3级 | 4级 |
|-----|-----|-----|-----|-----|
| damage | 1.0 | 1.0 | 2.0 | 2.0 |
| cooldown | 0.8 | 0.7 | 0.6 | 0.5 |
| crit_chance | 0.05 | 0.06 | 0.07 | 0.08 |

#### 4.2.2 特殊数值

| 属性 | 1级 | 2级 | 3级 | 4级 |
|-----|-----|-----|-----|-----|
| pierce_count | 0 | 2 | 3 | 5 |
| bullet_count | 3 | 5 | 7 | 9 |
| sector_angle | 60 | 75 | 90 | 105 |

## 5. 正确性属性（Property-Based Testing）

### 5.1 近战武器属性

**Property 1.1: Shape 创建正确性**
```
对于所有 shape_type ∈ {point, line, sector, circle}:
  setup_hitbox(stats) 后，hitbox_shape.shape 类型正确
```

**Property 1.2: Shape 参数正确性**
```
对于 shape_type = "point":
  hitbox_shape.shape.radius == max_range/2 或 param1
```

**Property 1.3: 动画执行完整性**
```
对于所有近战武器:
  execute_attack() 后，Tween 动画完成且 hitbox 恢复初始状态
```

### 5.2 远程武器属性

**Property 2.1: 子弹数量正确性**
```
对于 bullet_mode = "spread":
  create_projectiles() 生成的子弹数 == bullet_count
```

**Property 2.2: 散射角度正确性**
```
对于 bullet_mode = "spread":
  所有子弹角度在 [-spread_angle/2, spread_angle/2] 范围内
```

**Property 2.3: 穿透逻辑正确性**
```
对于 pierce_count = N:
  子弹最多击中 N+1 个敌人后销毁
```

### 5.3 效果系统属性

**Property 3.1: 治疗效果正确性**
```
对于 effect_type = "heal":
  子弹命中后，玩家生命值增加 == damage * heal_multiplier
```

**Property 3.2: 重力效果正确性**
```
对于 gravity > 0:
  子弹 velocity.y 随时间递增
```

## 6. 接口设计

### 6.1 MeleeBehavior 接口

```gdscript
class_name MeleeBehavior
extends WeaponBehavior

## 设置 hitbox 形状
## @param stats: 武器统计数据
func setup_hitbox(stats: WeaponStats) -> void

## 执行攻击（覆写）
func execute_attack() -> void

## 清理旧 shape
func cleanup_old_shape() -> void

## 创建 Tween 动画
## @param shape_type: 形状类型
## @return Tween 对象
func create_attack_tween(shape_type: String) -> Tween
```

### 6.2 RangeBehavior 接口

```gdscript
class_name RangeBehavior
extends WeaponBehavior

## 执行攻击（覆写）
func execute_attack() -> void

## 创建子弹
func create_projectiles() -> void

## 生成单发子弹
func spawn_single_bullet() -> void

## 生成散射子弹
func spawn_spread_bullets() -> void

## 生成穿透子弹
func spawn_pierce_bullet() -> void

## 生成魔法子弹
func spawn_magic_bullet() -> void

## 在指定角度生成子弹
## @param angle_offset: 角度偏移（度）
func spawn_bullet_at_angle(angle_offset: float) -> void
```

### 6.3 Projectile 接口

```gdscript
class_name Projectile
extends Area2D

## 设置子弹参数
## @param data: 包含 pierce_count, gravity 等的字典
func setup(data: Dictionary) -> void

## 应用伤害
## @param enemy: 敌人对象
func apply_damage(enemy: Enemy) -> void

## 应用效果
func apply_effect() -> void

## 追踪最近敌人
func track_nearest_enemy(delta: float) -> void
```

## 7. 错误处理

### 7.1 CSV 解析错误

```gdscript
if not _raw_data.has(weapon_id):
    printerr("[WeaponConfigLoader] 错误: 未找到武器 ID - ", weapon_id)
    return null
```

### 7.2 资源加载错误

```gdscript
if not ResourceLoader.exists(projectile_path):
    printerr("[RangeBehavior] 错误: 子弹场景不存在 - ", projectile_path)
    return

# CSV 解析防注入
if not ResourceLoader.exists(texture_path):
    push_warning("[Weapon] 警告: 贴图路径不存在，跳过加载 - ", texture_path)
    return
```

### 7.3 空值检查

```gdscript
if not is_instance_valid(Global.player):
    push_warning("[Projectile] 警告: 玩家对象无效，跳过治疗")
    return
```

## 8. 性能优化

### 8.1 对象池

```gdscript
# 子弹对象池（可选）
var projectile_pool: Array[Projectile] = []

func get_projectile() -> Projectile:
    if projectile_pool.size() > 0:
        return projectile_pool.pop_back()
    else:
        return projectile_scene.instantiate()
```

### 8.2 Shape 缓存

```gdscript
# 缓存常用 shape（可选）
var shape_cache: Dictionary = {}

func get_cached_shape(shape_type: String, params: Dictionary) -> Shape2D:
    var key = shape_type + str(params)
    if shape_cache.has(key):
        return shape_cache[key].duplicate()
    # ...
```

## 9. 测试策略

### 9.1 单元测试

- 测试 MeleeBehavior.setup_hitbox() 所有 shape_type
- 测试 RangeBehavior.create_projectiles() 所有 bullet_mode
- 测试 Projectile 穿透/治疗/追踪逻辑

### 9.2 集成测试

- 测试 30 种武器变体加载
- 测试升级链（1级→2级→3级→4级）
- 测试特殊效果组合

### 9.3 性能测试

- 同时 10 个武器实例
- 同时 50 个子弹实例
- 监控 FPS 和内存占用

## 10. 迁移计划

### 10.1 阶段 1: 动态行为实现（T1-T2）
- 实现 MeleeBehavior
- 实现 RangeBehavior
- 单元测试通过

### 10.2 阶段 2: 场景创建（T3）
- 创建 7 个基础场景
- 验证节点结构
- 编辑器测试通过

### 10.3 阶段 3: CSV 扩展（T4）
- 补充 84 行配置
- 验证数值渐进
- 解析测试通过

### 10.4 阶段 4: 子弹增强（T5）
- 更新 Projectile 脚本
- 实现穿透/治疗/追踪
- 功能测试通过

### 10.5 阶段 5: 清理与测试（T6-T8）
- 清理 .tres 残留
- 创建测试脚本
- 更新文档
- 集成测试通过

### 10.6 风险缓解措施
- **R4 (CSV 加载慢)**: 实现懒加载，仅在需要时解析
- **R5 (Polygon 性能)**: 限制扇形分段数（最多 16 段），缓存常用形状
- **R6 (平衡调优超时)**: 预留 T9 缓冲时间（4 小时），优先实现核心功能

---

**设计版本**: 1.2  
**最后更新**: 2026-02-08  
**审批状态**: 待审批
