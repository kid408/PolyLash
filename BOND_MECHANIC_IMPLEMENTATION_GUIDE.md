# 羁绊机制实现指南 - Bond Mechanic Implementation Guide

## 📋 概述

本文档详细说明如何实现新羁绊系统中的所有 `mechanic` 类型效果。这些机制需要在游戏代码中实现，而不仅仅是数值加成。

## 🎯 实现优先级

### P0 - 核心画图机制（必须实现）
1. `closed_shape_dmg` - 闭合图形伤害加成
2. `line_duration` - 线条持续时间
3. `shape_tolerance` - 图形闭合容错率

### P1 - 重要玩法机制
4. `kill_regen` - 击杀回能
5. `super_armor` - 霸体
6. `speed_to_damage` - 速度转伤害
7. `gold_trail` - 金币轨迹

### P2 - 进阶机制
8. `secondary_explode` - 二次爆炸
9. `thorns_wall` - 反伤墙
10. `debuff_duration` - Debuff延长
11. `curse_stack` - 诅咒叠加

### P3 - 高级机制
12. `chain_reaction` - 连锁反应
13. `permanent_cage` - 永久牢笼
14. `death_brush` - 画笔真伤
15. `small_shape_crit` - 小图形暴击
16. `polygon_effect` - 多边形特效

### P4 - 战术机制
17. `bench_cd_reduce` - 后台冷却减少
18. `mirror_draw` - 镜像作画
19. `switch_cd_reduce` - 切换冷却减少
20. `ink_inherit` - 图形继承
21. `soul_attach` - 灵魂附着

## 🔧 实现方案

### 1. closed_shape_dmg - 闭合图形伤害加成

**羁绊**: 爆破师 Lv.1  
**效果值**: 0.2 (20%)  
**实现位置**: `skill_drawing_base.gd` 或各个画图技能

```gdscript
# 在闭合图形伤害计算时
func calculate_closed_shape_damage(base_damage: float) -> float:
    var damage = base_damage
    
    # 检查爆破师羁绊
    if BondManager.has_mechanic("closed_shape_dmg"):
        var bonus = BondManager.get_mechanic_value("closed_shape_dmg")
        damage *= (1.0 + bonus)
        print("[DrawingSkill] 闭合图形伤害加成: +%.0f%%" % (bonus * 100))
    
    return damage
```

### 2. line_duration - 线条持续时间

**羁绊**: 筑墙者 Lv.1  
**效果值**: 3.0 (秒)  
**实现位置**: `skill_drawing_base.gd`

```gdscript
# 在创建线条时
func create_line_segment(start: Vector2, end: Vector2) -> void:
    var line = Line2D.new()
    # ... 设置线条属性
    
    # 基础持续时间
    var duration = base_line_duration
    
    # 检查筑墙者羁绊
    if BondManager.has_mechanic("line_duration"):
        var bonus = BondManager.get_mechanic_value("line_duration")
        duration += bonus
        print("[DrawingSkill] 线条持续时间: %.1f秒" % duration)
    
    # 设置定时器
    var timer = get_tree().create_timer(duration)
    timer.timeout.connect(func(): line.queue_free())
```

### 3. shape_tolerance - 图形闭合容错率

**羁绊**: 几何学家 Lv.1  
**效果值**: 1 (提升等级)  
**实现位置**: `skill_drawing_base.gd`

```gdscript
# 在检测闭合时
func check_if_closed() -> bool:
    if drawn_points.size() < 3:
        return false
    
    var first_point = drawn_points[0]
    var last_point = drawn_points[-1]
    
    # 基础容错距离
    var tolerance = 30.0
    
    # 检查几何学家羁绊
    if BondManager.has_mechanic("shape_tolerance"):
        var level = BondManager.get_mechanic_value("shape_tolerance")
        tolerance += level * 15.0  # 每级+15像素
        print("[DrawingSkill] 闭合容错: %.0f像素" % tolerance)
    
    return first_point.distance_to(last_point) <= tolerance
```

### 4. kill_regen - 击杀回能

**羁绊**: 墨灵 Lv.2  
**效果值**: 5 (能量点数)  
**实现位置**: `player_base.gd` 或 `health_component.gd`

```gdscript
# 在敌人死亡时
func _on_enemy_killed(enemy: Node2D) -> void:
    # 检查墨灵羁绊
    if BondManager.has_mechanic("kill_regen"):
        var regen_amount = BondManager.get_mechanic_value("kill_regen")
        current_energy = min(current_energy + regen_amount, max_energy)
        print("[Player] 击杀回能: +%.0f (当前: %.0f/%.0f)" % [regen_amount, current_energy, max_energy])
        
        # 触发UI更新
        energy_changed.emit(current_energy, max_energy)
```

### 5. super_armor - 霸体

**羁绊**: 巨擘 Lv.2  
**效果值**: 1 (布尔标记)  
**实现位置**: `skill_drawing_base.gd`

```gdscript
# 在画闭合图形时
var is_drawing_closed_shape: bool = false

func start_drawing() -> void:
    is_drawing_closed_shape = true
    
    # 检查巨擘羁绊
    if BondManager.has_mechanic("super_armor"):
        player.set_super_armor(true)
        print("[DrawingSkill] 霸体激活")

func finish_drawing() -> void:
    is_drawing_closed_shape = false
    
    # 移除霸体
    if BondManager.has_mechanic("super_armor"):
        player.set_super_armor(false)
        print("[DrawingSkill] 霸体解除")

# 在 player_base.gd 中
var has_super_armor: bool = false

func set_super_armor(enabled: bool) -> void:
    has_super_armor = enabled

func take_damage(amount: float, source: Node2D = null) -> void:
    # 霸体时不会被打断
    if has_super_armor:
        # 仍然受到伤害，但不会被击退或打断
        health_component.take_damage(amount, false)  # 不触发击退
    else:
        health_component.take_damage(amount, true)
```

### 6. speed_to_damage - 速度转伤害

**羁绊**: 风行者 Lv.2  
**效果值**: 1 (转化比例标记)  
**实现位置**: `player_base.gd`

```gdscript
# 在计算伤害时
func calculate_final_damage(base_damage: float) -> float:
    var damage = base_damage
    
    # 检查风行者羁绊
    if BondManager.has_mechanic("speed_to_damage"):
        # 移动速度加成转化为攻击力
        # 假设基础速度为500，每超过100速度增加10%伤害
        var speed_bonus = (current_speed - 500) / 100.0 * 0.1
        if speed_bonus > 0:
            damage *= (1.0 + speed_bonus)
            print("[Player] 速度转伤害: +%.0f%% (速度: %.0f)" % [speed_bonus * 100, current_speed])
    
    return damage
```

### 7. gold_trail - 金币轨迹

**羁绊**: 炼金术士 Lv.2  
**效果值**: 1 (布尔标记)  
**实现位置**: `skill_drawing_base.gd`

```gdscript
# 在画线时
func update_drawing(new_point: Vector2) -> void:
    drawn_points.append(new_point)
    
    # 检查炼金术士羁绊
    if BondManager.has_mechanic("gold_trail"):
        # 每隔一定距离生成金币
        if drawn_points.size() % 10 == 0:  # 每10个点生成1个金币
            spawn_gold_coin(new_point)

func spawn_gold_coin(position: Vector2) -> void:
    # 生成小额金币（1-3金币）
    var gold_amount = randi_range(1, 3)
    # 调用金币生成系统
    # GoldSpawner.spawn_coin(position, gold_amount)
    print("[DrawingSkill] 生成金币: %d at %v" % [gold_amount, position])
```

### 8. secondary_explode - 二次爆炸

**羁绊**: 爆破师 Lv.2  
**效果值**: 1 (布尔标记)  
**实现位置**: 各个画图技能的爆炸逻辑

```gdscript
# 在闭合图形爆炸时
func trigger_explosion(center: Vector2, radius: float, damage: float) -> void:
    # 主爆炸
    deal_area_damage(center, radius, damage)
    
    # 检查爆破师羁绊
    if BondManager.has_mechanic("secondary_explode"):
        # 延迟0.3秒后触发二次余波
        await get_tree().create_timer(0.3).timeout
        
        # 二次爆炸：范围更大，伤害减半
        var secondary_radius = radius * 1.5
        var secondary_damage = damage * 0.5
        deal_area_damage(center, secondary_radius, secondary_damage)
        
        print("[DrawingSkill] 二次爆炸: 半径=%.0f 伤害=%.0f" % [secondary_radius, secondary_damage])
```

### 9. thorns_wall - 反伤墙

**羁绊**: 筑墙者 Lv.2  
**效果值**: 1 (布尔标记)  
**实现位置**: `skill_drawing_base.gd`

```gdscript
# 在创建线条时
func create_line_segment(start: Vector2, end: Vector2) -> void:
    var line = Line2D.new()
    # ... 设置线条属性
    
    # 检查筑墙者羁绊
    if BondManager.has_mechanic("thorns_wall"):
        # 为线条添加碰撞检测
        var area = Area2D.new()
        var collision = CollisionShape2D.new()
        # ... 设置碰撞形状
        
        area.body_entered.connect(func(body):
            if body.is_in_group("enemies"):
                # 反伤：对接触线条的敌人造成伤害
                var thorns_damage = player.get_stat("attack_damage") * 0.3
                body.take_damage(thorns_damage)
                print("[DrawingSkill] 反伤墙触发: %.0f伤害" % thorns_damage)
        )
        
        line.add_child(area)
```

### 10. debuff_duration - Debuff延长

**羁绊**: 咒术师 Lv.1  
**效果值**: 0.5 (50%延长)  
**实现位置**: 各个Debuff应用逻辑

```gdscript
# 在应用Debuff时
func apply_debuff(target: Node2D, debuff_type: String, base_duration: float) -> void:
    var duration = base_duration
    
    # 检查咒术师羁绊
    if BondManager.has_mechanic("debuff_duration"):
        var extension = BondManager.get_mechanic_value("debuff_duration")
        duration *= (1.0 + extension)
        print("[DrawingSkill] Debuff延长: %.1f秒 -> %.1f秒" % [base_duration, duration])
    
    # 应用Debuff
    target.add_debuff(debuff_type, duration)
```

## 📝 实现检查清单

### 画图相关机制
- [ ] closed_shape_dmg - 闭合图形伤害加成
- [ ] line_duration - 线条持续时间
- [ ] shape_tolerance - 图形闭合容错率
- [ ] secondary_explode - 二次爆炸
- [ ] thorns_wall - 反伤墙
- [ ] permanent_cage - 永久牢笼
- [ ] small_shape_crit - 小图形暴击
- [ ] polygon_effect - 多边形特效

### 能量/资源机制
- [ ] kill_regen - 击杀回能
- [ ] gold_trail - 金币轨迹

### 战斗机制
- [ ] super_armor - 霸体
- [ ] speed_to_damage - 速度转伤害
- [ ] death_brush - 画笔真伤
- [ ] debuff_duration - Debuff延长
- [ ] curse_stack - 诅咒叠加
- [ ] chain_reaction - 连锁反应

### 战术机制
- [ ] bench_cd_reduce - 后台冷却减少
- [ ] mirror_draw - 镜像作画
- [ ] switch_cd_reduce - 切换冷却减少
- [ ] ink_inherit - 图形继承
- [ ] soul_attach - 灵魂附着

## 🧪 测试建议

### 单元测试
1. 创建测试场景，只激活一个羁绊
2. 验证机制是否正确触发
3. 检查数值计算是否准确

### 组合测试
1. 测试多个羁绊同时激活
2. 验证效果是否正确叠加
3. 检查是否有冲突或bug

### 性能测试
1. 测试大量线条/图形时的性能
2. 检查内存泄漏
3. 优化频繁触发的机制

## 📚 相关文件

- `autoloads/bond_manager.gd` - 羁绊管理器
- `scenes/skills/skill_drawing_base.gd` - 画图技能基类
- `scenes/unit/players/player_base.gd` - 玩家基类
- `config/player/bond_config.csv` - 羁绊配置

## ⚠️ 注意事项

1. **性能优化**: 频繁触发的机制（如gold_trail）需要优化
2. **网络同步**: 如果是多人游戏，需要考虑同步问题
3. **保存/加载**: 确保机制状态可以正确保存和恢复
4. **UI反馈**: 重要机制触发时应有视觉/音效反馈
5. **平衡性**: 实现后需要大量测试和调整数值

---

**创建日期**: 2026-01-31  
**作者**: Kiro AI Assistant  
**状态**: 📝 待实现
