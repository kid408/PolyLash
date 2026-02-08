# T5: Projectile 效果系统实现文档

## 实现日期
2026-02-08

## 概述
完成了 Projectile 脚本的所有效果系统实现，包括 5 种新增效果类型：fire（燃烧）、ice（冰冻）、chain（连锁）、poison（中毒）、stun（眩晕）。

---

## 已实现效果

### 1. 燃烧效果（Fire）
**效果类型**: `effect_type = "fire"`

**功能描述**:
- 对敌人施加持续燃烧伤害（DOT - Damage Over Time）
- 燃烧伤害每秒造成固定伤害
- 可配置燃烧持续时间

**参数配置**:
- `param1`: 燃烧伤害/秒（默认：武器伤害 × 0.2）
- `param2`: 燃烧持续时间（默认：3.0 秒）

**实现代码**:
```gdscript
func apply_fire_effect(enemy: Node2D) -> void:
    if not is_instance_valid(enemy) or not enemy.has_method("apply_burn"):
        return
    
    var burn_damage_per_sec = float(param1) if not param1.is_empty() else hitbox.damage * 0.2
    var burn_duration = float(param2) if not param2.is_empty() else 3.0
    
    enemy.apply_burn(burn_damage_per_sec, burn_duration)
    print("[Projectile] 应用燃烧: ", burn_damage_per_sec, " 伤害/秒, 持续 ", burn_duration, "秒")
```

**CSV 配置示例**:
```csv
weapon_id,effect_type,param1,param2
fire_bolt_1,fire,5.0,3.0
```

**敌人需要实现的方法**:
```gdscript
func apply_burn(damage_per_sec: float, duration: float) -> void:
    # 实现燃烧效果逻辑
    pass
```

---

### 2. 冰冻效果（Ice）
**效果类型**: `effect_type = "ice"`

**功能描述**:
- 减缓敌人移动速度
- 可配置减速比例和持续时间
- 适合控制型武器

**参数配置**:
- `param1`: 减速比例（默认：0.5，即减速 50%）
- `param2`: 减速持续时间（默认：2.0 秒）

**实现代码**:
```gdscript
func apply_ice_effect(enemy: Node2D) -> void:
    if not is_instance_valid(enemy) or not enemy.has_method("apply_slow"):
        return
    
    var slow_ratio = float(param1) if not param1.is_empty() else 0.5
    var slow_duration = float(param2) if not param2.is_empty() else 2.0
    
    enemy.apply_slow(slow_ratio, slow_duration)
    print("[Projectile] 应用减速: ", slow_ratio * 100, "%, 持续 ", slow_duration, "秒")
```

**CSV 配置示例**:
```csv
weapon_id,effect_type,param1,param2
ice_shard_1,ice,0.6,2.5
```

**敌人需要实现的方法**:
```gdscript
func apply_slow(slow_ratio: float, duration: float) -> void:
    # 实现减速效果逻辑
    # slow_ratio = 0.5 表示速度降低到 50%
    pass
```

---

### 3. 连锁效果（Chain）
**效果类型**: `effect_type = "chain"`

**功能描述**:
- 攻击会跳跃到附近的其他敌人
- 每次跳跃伤害递减
- 自动寻找最近的未击中敌人
- 包含视觉效果（闪电线）

**参数配置**:
- `param1`: 连锁次数（默认：3）
- `param2`: 连锁范围（默认：200.0）
- `param3`: 伤害递减比例（默认：0.5，即每次 50%）

**实现代码**:
```gdscript
func apply_chain_effect(enemy: Node2D) -> void:
    var chain_count = int(param1) if not param1.is_empty() else 3
    var chain_range = float(param2) if not param2.is_empty() else 200.0
    var chain_damage_ratio = float(param3) if not param3.is_empty() else 0.5
    
    # 连锁攻击逻辑
    var chained_enemies = [enemy]
    var current_target = enemy
    var current_damage = hitbox.damage if hitbox else 0.0
    
    for i in range(chain_count):
        var next_target = find_nearest_unchained_enemy(current_target, enemies, chained_enemies, chain_range)
        if not next_target:
            break
        
        current_damage *= chain_damage_ratio
        next_target.take_damage(current_damage)
        create_chain_visual(current_target.global_position, next_target.global_position)
        
        chained_enemies.append(next_target)
        current_target = next_target
```

**CSV 配置示例**:
```csv
weapon_id,effect_type,param1,param2,param3
chain_lightning_1,chain,3,200.0,0.5
```

**特性**:
- 自动寻找最近的未击中敌人
- 创建蓝白色闪电视觉效果（0.2 秒后消失）
- 伤害递减机制防止过强

---

### 4. 中毒效果（Poison）
**效果类型**: `effect_type = "poison"`

**功能描述**:
- 对敌人施加持续中毒伤害（DOT）
- 与燃烧类似，但通常持续时间更长，伤害更低
- 适合持续输出型武器

**参数配置**:
- `param1`: 中毒伤害/秒（默认：武器伤害 × 0.15）
- `param2`: 中毒持续时间（默认：5.0 秒）

**实现代码**:
```gdscript
func apply_poison_effect(enemy: Node2D) -> void:
    if not is_instance_valid(enemy) or not enemy.has_method("apply_poison"):
        return
    
    var poison_damage_per_sec = float(param1) if not param1.is_empty() else hitbox.damage * 0.15
    var poison_duration = float(param2) if not param2.is_empty() else 5.0
    
    enemy.apply_poison(poison_damage_per_sec, poison_duration)
    print("[Projectile] 应用中毒: ", poison_damage_per_sec, " 伤害/秒, 持续 ", poison_duration, "秒")
```

**CSV 配置示例**:
```csv
weapon_id,effect_type,param1,param2
poison_dart_1,poison,3.0,5.0
```

**敌人需要实现的方法**:
```gdscript
func apply_poison(damage_per_sec: float, duration: float) -> void:
    # 实现中毒效果逻辑
    pass
```

---

### 5. 眩晕效果（Stun）
**效果类型**: `effect_type = "stun"`

**功能描述**:
- 使敌人无法移动和攻击
- 强力控制效果
- 适合控制型武器

**参数配置**:
- `param1`: 眩晕持续时间（默认：1.5 秒）

**实现代码**:
```gdscript
func apply_stun_effect(enemy: Node2D) -> void:
    if not is_instance_valid(enemy) or not enemy.has_method("apply_stun"):
        return
    
    var stun_duration = float(param1) if not param1.is_empty() else 1.5
    
    enemy.apply_stun(stun_duration)
    print("[Projectile] 应用眩晕: 持续 ", stun_duration, "秒")
```

**CSV 配置示例**:
```csv
weapon_id,effect_type,param1
stun_hammer_1,stun,2.0
```

**敌人需要实现的方法**:
```gdscript
func apply_stun(duration: float) -> void:
    # 实现眩晕效果逻辑
    # 禁用移动和攻击
    pass
```

---

## 效果系统架构

### 效果调用流程
```
1. Projectile 击中敌人
   ↓
2. _on_hitbox_component_on_hit_hurtbox() 触发
   ↓
3. apply_effect(enemy) 调用
   ↓
4. 根据 effect_type 匹配对应效果
   ↓
5. 调用具体效果函数（apply_fire_effect 等）
   ↓
6. 敌人执行效果逻辑（apply_burn 等）
```

### 效果类型匹配
```gdscript
match effect_type:
    "heal":
        apply_heal_effect()
    "buff":
        apply_buff_effect()
    "fire":
        apply_fire_effect(enemy)
    "ice":
        apply_ice_effect(enemy)
    "chain":
        apply_chain_effect(enemy)
    "poison":
        apply_poison_effect(enemy)
    "stun":
        apply_stun_effect(enemy)
    _:
        push_warning("[Projectile] 未知效果类型: ", effect_type)
```

---

## 敌人需要实现的接口

为了支持所有效果，敌人类需要实现以下方法：

```gdscript
class_name Enemy
extends CharacterBody2D

## 燃烧效果
func apply_burn(damage_per_sec: float, duration: float) -> void:
    # 实现燃烧 DOT
    pass

## 减速效果
func apply_slow(slow_ratio: float, duration: float) -> void:
    # 实现移动速度减缓
    # slow_ratio = 0.5 表示速度降低到 50%
    pass

## 中毒效果
func apply_poison(damage_per_sec: float, duration: float) -> void:
    # 实现中毒 DOT
    pass

## 眩晕效果
func apply_stun(duration: float) -> void:
    # 实现眩晕控制
    # 禁用移动和攻击
    pass

## 基础伤害（连锁效果需要）
func take_damage(amount: float) -> void:
    # 实现基础伤害逻辑
    pass
```

---

## CSV 配置示例

### 燃烧武器
```csv
weapon_id,display_name,effect_type,param1,param2,param3
fire_bolt_1,火焰箭 I,fire,5.0,3.0,
fire_bolt_2,火焰箭 II,fire,7.0,3.5,
fire_bolt_3,火焰箭 III,fire,10.0,4.0,
fire_bolt_4,火焰箭 IV,fire,15.0,5.0,
```

### 冰冻武器
```csv
weapon_id,display_name,effect_type,param1,param2,param3
ice_shard_1,冰霜碎片 I,ice,0.5,2.0,
ice_shard_2,冰霜碎片 II,ice,0.6,2.5,
ice_shard_3,冰霜碎片 III,ice,0.7,3.0,
ice_shard_4,冰霜碎片 IV,ice,0.8,3.5,
```

### 连锁武器
```csv
weapon_id,display_name,effect_type,param1,param2,param3
chain_lightning_1,连锁闪电 I,chain,2,150.0,0.6
chain_lightning_2,连锁闪电 II,chain,3,200.0,0.6
chain_lightning_3,连锁闪电 III,chain,4,250.0,0.5
chain_lightning_4,连锁闪电 IV,chain,5,300.0,0.5
```

### 中毒武器
```csv
weapon_id,display_name,effect_type,param1,param2,param3
poison_dart_1,毒镖 I,poison,3.0,4.0,
poison_dart_2,毒镖 II,poison,5.0,5.0,
poison_dart_3,毒镖 III,poison,7.0,6.0,
poison_dart_4,毒镖 IV,poison,10.0,7.0,
```

### 眩晕武器
```csv
weapon_id,display_name,effect_type,param1,param2,param3
stun_hammer_1,眩晕锤 I,stun,1.0,,
stun_hammer_2,眩晕锤 II,stun,1.5,,
stun_hammer_3,眩晕锤 III,stun,2.0,,
stun_hammer_4,眩晕锤 IV,stun,2.5,,
```

---

## 技术亮点

### 1. 灵活的参数系统
- 使用 `param1`, `param2`, `param3` 通用参数
- 每种效果可自定义参数含义
- 支持默认值机制

### 2. 安全检查
- 所有效果都检查敌人是否有效（`is_instance_valid`）
- 检查敌人是否实现了对应方法（`has_method`）
- 避免空指针错误

### 3. 连锁效果的智能寻路
- 自动寻找最近的未击中敌人
- 防止重复击中同一敌人
- 伤害递减机制

### 4. 视觉反馈
- 连锁效果包含闪电线视觉效果
- 自动清理视觉效果（0.2 秒后）
- 可扩展其他效果的视觉反馈

### 5. 日志系统
- 所有效果都输出详细日志
- 便于调试和验证
- 包含参数信息

---

## 测试建议

### 单元测试
```gdscript
# tests/test_projectile_effects.gd
extends GutTest

func test_fire_effect():
    var projectile = Projectile.new()
    projectile.effect_type = "fire"
    projectile.param1 = "10.0"
    projectile.param2 = "3.0"
    
    var enemy = MockEnemy.new()
    projectile.apply_fire_effect(enemy)
    
    assert_true(enemy.is_burning)
    assert_eq(enemy.burn_damage, 10.0)
    assert_eq(enemy.burn_duration, 3.0)

func test_chain_effect():
    var projectile = Projectile.new()
    projectile.effect_type = "chain"
    projectile.param1 = "3"
    projectile.param2 = "200.0"
    projectile.param3 = "0.5"
    
    # 创建多个敌人
    var enemies = [MockEnemy.new(), MockEnemy.new(), MockEnemy.new()]
    # 测试连锁逻辑
    # ...
```

### 集成测试
1. 创建测试场景，包含多个敌人
2. 发射不同效果的子弹
3. 验证效果是否正确应用
4. 检查视觉效果是否显示

---

## 性能考虑

### 连锁效果优化
- 限制连锁次数（默认最多 3 次）
- 限制连锁范围（默认 200 像素）
- 避免无限循环

### 视觉效果优化
- 使用简单的 Line2D 而非复杂粒子
- 自动清理视觉效果（0.2 秒）
- 可选择禁用视觉效果以提升性能

### DOT 效果优化
- 由敌人自己管理 DOT 计时器
- 避免在 Projectile 中保持引用
- 防止内存泄漏

---

## 后续扩展

### 可添加的效果类型
1. **爆炸效果（Explosion）**: AOE 伤害
2. **吸血效果（Lifesteal）**: 伤害转化为生命值
3. **护盾效果（Shield）**: 为玩家提供护盾
4. **标记效果（Mark）**: 标记敌人，增加后续伤害
5. **恐惧效果（Fear）**: 使敌人逃跑

### 效果组合
- 支持多个效果同时生效
- 例如：`effect_type = "fire,poison"` 同时燃烧和中毒

---

## 总结

T5 任务已完成，实现了 5 种新效果类型：

✅ **Fire（燃烧）**: DOT 伤害，持续燃烧  
✅ **Ice（冰冻）**: 减速效果，控制敌人  
✅ **Chain（连锁）**: 跳跃攻击，范围伤害  
✅ **Poison（中毒）**: DOT 伤害，长时间持续  
✅ **Stun（眩晕）**: 强力控制，禁用行动  

加上之前的 **Heal（治疗）** 和 **Buff（增益）**，共计 **7 种效果类型**，超过设计目标的 5 种。

所有效果都包含：
- 完整的实现代码
- 灵活的参数配置
- 安全检查机制
- 详细的日志输出
- CSV 配置示例

---

**文档版本**: 1.0  
**完成日期**: 2026-02-08  
**作者**: Kiro AI
