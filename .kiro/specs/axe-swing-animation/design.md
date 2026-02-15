# 斧头挥舞动画设计文档

## 1. 设计概述

### 1.1 设计目标
为扇形近战武器（斧头、狼牙棒等）实现明显的挥砍动画效果，让玩家能清楚看到武器从后上方举起，沿弧形轨迹向前下方挥砍的过程。

### 1.2 设计原则
1. **视觉明显性**: 动画变化必须足够大，让玩家能清楚看到
2. **流畅性**: 动画过渡自然流畅，无卡顿
3. **同步性**: 动画与碰撞检测、伤害计算同步
4. **可配置性**: 关键参数可通过CSV配置调整
5. **兼容性**: 不影响其他武器类型的动画

## 2. 架构设计

### 2.1 系统架构

```
MeleeBehavior (近战行为)
├── execute_attack() - 攻击执行
│   ├── 武器类型判断
│   │   ├── sector (扇形) → 挥砍动画
│   │   ├── circle (圆形) → 横扫动画
│   │   └── 其他 → 传统动画
│   ├── Tween动画创建
│   │   ├── 起始状态设置
│   │   ├── 攻击阶段动画
│   │   └── 收回阶段动画
│   └── Hitbox管理
│       ├── 启用时机
│       └── 禁用时机
└── setup_hitbox() - 碰撞体设置
    └── _create_sector_shape() - 扇形碰撞体
```

### 2.2 动画流程设计

#### 扇形武器动画流程

```
阶段1: 准备阶段 (立即执行)
├── 设置起始位置: (x-20, y-40)
├── 设置起始旋转: -60°
└── 武器处于"举起"状态

阶段2: 停顿阶段 (recoil_duration)
├── 保持举起状态
└── 替代传统后坐力动画

阶段3: 挥砍阶段 (attack_duration)
├── 启用Hitbox (开始时)
├── 位置动画: (x-20, y-40) → (x+range*0.5, y+30)
├── 旋转动画: -60° → +60° (并行)
├── 缓动: EASE_IN (加速挥下)
└── 禁用Hitbox (结束时)

阶段4: 收回阶段 (back_duration)
├── 位置动画: 当前位置 → atk_start_pos
├── 旋转动画: 当前旋转 → 0° (并行)
└── 缓动: EASE_OUT (减速收回)
```

## 3. 详细设计

### 3.1 动画参数设计

#### 起始状态参数
```gdscript
# 位置偏移
start_offset_x = atk_start_pos.x - 20  # 向后偏移
start_offset_y = atk_start_pos.y - 40  # 向上偏移
start_rotation = -60°  # 向后旋转

# 设计理由:
# - 向后偏移20像素: 营造"蓄力"感
# - 向上偏移40像素: 营造"举起"感
# - 旋转-60°: 武器朝向后上方
```

#### 结束状态参数
```gdscript
# 位置偏移
end_offset_x = atk_start_pos.x + max_range * 0.5  # 向前偏移
end_offset_y = atk_start_pos.y + 30  # 向下偏移
end_rotation = +60°  # 向前旋转

# 设计理由:
# - 向前偏移: 根据武器攻击范围动态计算
# - 向下偏移30像素: 营造"挥下"感
# - 旋转+60°: 武器朝向前下方
# - 总旋转角度120°: 足够明显的视觉变化
```

#### 时间参数
```gdscript
# 从CSV读取
recoil_duration = stats.recoil_duration  # 停顿时间 (默认0.12s)
attack_duration = stats.attack_duration  # 挥砍时间 (默认0.3s)
back_duration = stats.back_duration      # 收回时间 (默认0.15s)

# 总时长 = 0.12 + 0.3 + 0.15 = 0.57s
```

### 3.2 Tween动画设计

#### 动画链设计
```gdscript
var tween = create_tween()

# 1. 立即设置起始状态 (无动画)
weapon.sprite.position = start_offset
weapon.sprite.rotation = start_rotation

# 2. 停顿阶段 (替代后坐力)
tween.tween_interval(recoil_duration)

# 3. 启用Hitbox回调
tween.tween_callback(enable_hitbox_func)

# 4. 挥砍动画 (位置 + 旋转并行)
tween.tween_property(sprite, "position", end_offset, attack_duration)
    .set_ease(Tween.EASE_IN)
tween.parallel()
    .tween_property(sprite, "rotation", end_rotation, attack_duration)
    .set_ease(Tween.EASE_IN)

# 5. 禁用Hitbox回调
tween.tween_callback(disable_hitbox_func)

# 6. 收回动画 (位置 + 旋转并行)
tween.tween_property(sprite, "position", atk_start_pos, back_duration)
    .set_ease(Tween.EASE_OUT)
tween.parallel()
    .tween_property(sprite, "rotation", 0.0, back_duration)
    .set_ease(Tween.EASE_OUT)

# 7. 完成回调
tween.finished.connect(on_attack_finished)
```

#### 缓动函数选择
- **EASE_IN**: 攻击阶段使用，模拟加速挥下的感觉
- **EASE_OUT**: 收回阶段使用，模拟减速收回的感觉

### 3.3 Hitbox同步设计

#### 启用时机
```gdscript
# 在挥砍动画开始时启用
tween.tween_callback(func():
    hitbox.enable()
    var damage_value = get_damage()
    hitbox.setup(damage_value, critical, knockback, owner)
    print("[MeleeBehavior] Hitbox启用 - 挥砍开始")
)
```

#### 禁用时机
```gdscript
# 在挥砍动画结束时立即禁用
tween.tween_callback(func():
    hitbox.disable()
    print("[MeleeBehavior] Hitbox禁用 - 挥砍结束")
)
```

#### 设计理由
- **启用时机**: 挥砍动画开始时，武器开始向前移动
- **禁用时机**: 挥砍动画结束时，武器到达最前方
- **避免延迟伤害**: 确保伤害在挥砍过程中造成，而非收回时

### 3.4 武器类型判断设计

```gdscript
var shape_type = weapon.data.stats.shape_type

match shape_type:
    "sector":
        # 扇形武器: 挥砍动画
        create_swing_animation()
    
    "circle":
        # 圆形武器: 横扫动画
        create_sweep_animation()
    
    _:
        # 其他武器: 传统动画
        create_traditional_animation()
```

## 4. 数据设计

### 4.1 CSV配置

#### 斧头配置示例
```csv
weapon_base_id,shape_type,base_sector_angle,base_max_range,base_recoil_duration,base_attack_duration,base_back_duration
axe,sector,120,150,0.12,0.3,0.15
```

#### 参数说明
- `shape_type`: "sector" - 触发挥砍动画
- `base_sector_angle`: 120° - 扇形碰撞角度
- `base_max_range`: 150 - 影响挥砍幅度
- `base_recoil_duration`: 0.12s - 停顿时间
- `base_attack_duration`: 0.3s - 挥砍时间
- `base_back_duration`: 0.15s - 收回时间

### 4.2 运行时数据

#### WeaponStats结构
```gdscript
class WeaponStats:
    var shape_type: String        # 武器形状类型
    var sector_angle: float        # 扇形角度
    var max_range: float           # 最大攻击范围
    var recoil_duration: float     # 后坐力时长
    var attack_duration: float     # 攻击时长
    var back_duration: float       # 返回时长
```

## 5. 接口设计

### 5.1 公共接口

#### execute_attack()
```gdscript
func execute_attack() -> void:
    """
    执行近战攻击
    
    功能:
    - 根据武器类型创建不同的攻击动画
    - 管理Hitbox的启用/禁用
    - 处理攻击完成回调
    
    参数: 无
    返回: 无
    """
```

### 5.2 内部接口

#### _create_swing_animation()
```gdscript
func _create_swing_animation(tween: Tween) -> void:
    """
    创建挥砍动画（扇形武器）
    
    功能:
    - 设置起始状态（举起）
    - 创建挥砍动画（位置+旋转）
    - 创建收回动画（位置+旋转）
    
    参数:
    - tween: Tween对象
    
    返回: 无
    """
```

## 6. 算法设计

### 6.1 弧形轨迹计算

#### 位置计算
```gdscript
# 起始位置 (后上方)
start_x = base_x - 20
start_y = base_y - 40

# 结束位置 (前下方)
end_x = base_x + max_range * 0.5
end_y = base_y + 30

# 轨迹: 从(start_x, start_y)到(end_x, end_y)
# 配合旋转动画，形成弧形轨迹
```

#### 旋转计算
```gdscript
# 起始旋转 (向后)
start_rotation = deg_to_rad(-60)

# 结束旋转 (向前)
end_rotation = deg_to_rad(60)

# 总旋转角度: 120°
# 旋转方向: 顺时针
```

### 6.2 并行动画算法

```gdscript
# 位置动画
tween.tween_property(sprite, "position", end_pos, duration)

# 旋转动画 (并行执行)
tween.parallel().tween_property(sprite, "rotation", end_rot, duration)

# 效果: 位置和旋转同时变化，形成弧形轨迹
```

## 7. 性能设计

### 7.1 Tween优化
- 使用单个Tween对象管理整个攻击动画
- 使用`parallel()`实现并行动画，避免创建多个Tween
- 攻击完成后自动清理Tween

### 7.2 内存管理
- Tween对象由Godot自动管理
- 无需手动释放
- 使用`finished`信号确保清理

## 8. 错误处理

### 8.1 数据验证
```gdscript
# 验证武器数据
if not weapon or not weapon.data or not weapon.data.stats:
    printerr("[MeleeBehavior] 错误: 武器数据无效")
    return

# 验证shape_type
var shape_type = weapon.data.stats.shape_type
if shape_type.is_empty():
    shape_type = "point"  # 默认值
```

### 8.2 异常处理
```gdscript
# Tween创建失败
if not tween:
    printerr("[MeleeBehavior] 错误: 无法创建Tween")
    weapon.is_attacking = false
    return
```

## 9. 测试设计

### 9.1 单元测试

#### 测试用例1: 动画参数计算
```gdscript
func test_swing_animation_parameters():
    # 给定
    var max_range = 150
    var atk_start_pos = Vector2(50, 0)
    
    # 计算
    var start_offset = Vector2(atk_start_pos.x - 20, atk_start_pos.y - 40)
    var end_offset = Vector2(atk_start_pos.x + max_range * 0.5, atk_start_pos.y + 30)
    
    # 验证
    assert(start_offset == Vector2(30, -40))
    assert(end_offset == Vector2(125, 30))
```

#### 测试用例2: Hitbox同步
```gdscript
func test_hitbox_timing():
    # 验证Hitbox在挥砍阶段启用
    # 验证Hitbox在挥砍结束时禁用
    # 验证伤害在正确时机造成
```

### 9.2 集成测试

#### 测试场景1: 斧头攻击
```
前置条件:
- 角色装备斧头
- 有敌人在攻击范围内

测试步骤:
1. 触发攻击
2. 观察动画
3. 验证伤害

预期结果:
- 斧头从后上方举起
- 沿弧形轨迹挥砍
- 敌人受到伤害
- 动画流畅
```

## 10. 可扩展性设计

### 10.1 新武器类型支持
```gdscript
# 添加新的武器类型动画
match shape_type:
    "sector":
        create_swing_animation()
    "circle":
        create_sweep_animation()
    "new_type":  # 新类型
        create_new_type_animation()
```

### 10.2 参数可配置
```csv
# 可通过CSV添加新参数
weapon_base_id,swing_start_angle,swing_end_angle,swing_arc_height
axe,-60,60,40
```

## 11. 正确性属性

### 属性1: 动画可见性
**描述**: 挥砍动画必须足够明显，让玩家能清楚看到

**形式化**:
```
∀ frame ∈ [attack_start, attack_end]:
    |position(frame) - position(frame-1)| > threshold_position
    OR |rotation(frame) - rotation(frame-1)| > threshold_rotation
```

**验证方法**: 视觉测试 + 位置/旋转变化量测试

### 属性2: 动画同步性
**描述**: Hitbox启用/禁用必须与动画阶段同步

**形式化**:
```
hitbox.enabled == true  ⟺  animation_phase == "attack"
hitbox.enabled == false ⟺  animation_phase ∈ {"prepare", "retract"}
```

**验证方法**: 时序日志分析

### 属性3: 动画流畅性
**描述**: 动画过渡必须连续，无跳跃

**形式化**:
```
∀ frame ∈ [0, total_frames]:
    |position(frame) - position(frame-1)| < max_delta_position
    |rotation(frame) - rotation(frame-1)| < max_delta_rotation
```

**验证方法**: 帧间差值测试

### 属性4: 参数一致性
**描述**: 动画时长必须与CSV配置一致

**形式化**:
```
actual_duration = recoil_duration + attack_duration + back_duration
actual_duration == expected_duration (from CSV)
```

**验证方法**: 时长测量测试

## 12. 实现注意事项

### 12.1 关键点
1. **立即设置起始状态**: 不要用动画过渡到起始状态
2. **并行执行**: 位置和旋转必须同时变化
3. **Hitbox时机**: 在挥砍阶段启用，结束时立即禁用
4. **缓动函数**: 攻击用EASE_IN，收回用EASE_OUT

### 12.2 常见错误
1. ❌ 顺序执行位置和旋转动画 → 动画时长加倍
2. ❌ Hitbox启用过早或禁用过晚 → 伤害时机错误
3. ❌ 起始状态用动画过渡 → 看不到举起动作
4. ❌ 位置偏移太小 → 动画不明显

### 12.3 调试建议
```gdscript
# 添加详细日志
print("[MeleeBehavior] 起始位置: ", start_offset)
print("[MeleeBehavior] 结束位置: ", end_offset)
print("[MeleeBehavior] 起始旋转: ", rad_to_deg(start_rotation), "°")
print("[MeleeBehavior] 结束旋转: ", rad_to_deg(end_rotation), "°")
print("[MeleeBehavior] Hitbox启用")
print("[MeleeBehavior] Hitbox禁用")
```

## 13. 相关文档

- `requirements.md` - 需求文档
- `tasks.md` - 实现任务列表
- `docs/MELEE_BEHAVIOR_IMPLEMENTATION.md` - 近战行为实现文档

---

**文档版本**: 1.0  
**创建日期**: 2026-02-09  
**最后更新**: 2026-02-09
