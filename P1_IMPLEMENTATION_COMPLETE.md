# P1 重要玩法机制实现完成报告

## 概述

本文档记录了 P1 级（重要玩法机制）的完整实现过程。这四个机制决定了游戏四大流派的核心体验：
- **法师续航流**：击杀回能
- **坦克硬抗流**：霸体防打断
- **跑酷输出流**：速度转伤害
- **经济发育流**：金币轨迹

## 实现状态

| 机制ID | 机制名称 | 关联羁绊 | 状态 | 实现位置 |
|--------|---------|---------|------|---------|
| P1-1 | kill_regen | 墨灵 Lv.2 | ✅ 完成 | `enemy.gd` |
| P1-2 | super_armor | 巨擘 Lv.2 | ✅ 完成 | `player_base.gd` |
| P1-3 | speed_to_damage | 风行者 Lv.2 | ✅ 完成 | `player_base.gd`, `skill_drawing_base.gd` |
| P1-4 | gold_trail | 炼金术士 Lv.2 | ✅ 完成 | `skill_drawing_base.gd` |

---

## P1-1: 击杀回能 (kill_regen)

### 功能描述
击杀敌人时，额外获得能量奖励。

### 关联羁绊
- **墨灵 (Inkborn) Lv.2**
- 效果值：5（额外能量）

### 实现位置
`scenes/unit/enemy/enemy.gd` - `destroy_enemy()` 函数

### 实现逻辑
```gdscript
# 给玩家奖励（能量、经验、金币）
if is_instance_valid(Global.player):
    var enemy_config = ConfigManager.get_enemy_config(enemy_id)
    
    # P1-1: 击杀回能（墨灵羁绊）
    if Global.player.has_method("gain_energy"):
        var energy_drop = enemy_config.get("energy_drop", 5)
        
        # 检查墨灵羁绊 - 击杀回能
        if BondManager.has_mechanic("kill_regen"):
            var bonus_energy = BondManager.get_mechanic_value("kill_regen")
            energy_drop += bonus_energy
            print("[Enemy] [P1-1] 击杀回能触发: 基础%d + 墨灵%d = %d" % [
                enemy_config.get("energy_drop", 5),
                bonus_energy,
                energy_drop
            ])
        
        Global.player.gain_energy(energy_drop)
```

### 测试方法
1. 选择墨灵角色（或装备墨灵圣物）
2. 激活墨灵 Lv.2 羁绊（需要2个墨灵标签）
3. 击杀敌人
4. 观察能量条增加量（应为基础值 + 5）
5. 查看控制台日志确认触发

---

## P1-2: 霸体 (super_armor)

### 功能描述
画图时免疫击退效果（仍然受到伤害，但不会被打断）。

### 关联羁绊
- **巨擘 (Colossus) Lv.2**
- 效果值：1（开关型机制）

### 实现位置
`scenes/unit/players/player_base.gd`

### 实现逻辑

#### 1. 画图状态检测
```gdscript
## P1-2: 检查是否正在画图（用于霸体判定）
func _is_drawing_active() -> bool:
    """检查玩家是否正在画图
    
    Returns:
        是否正在画图
    """
    # 检查是否有SkillManager
    if not has_node("SkillManager"):
        return false
    
    var skill_manager = get_node("SkillManager")
    
    # 遍历所有技能，检查是否有正在画图的技能
    if skill_manager.has_method("get_all_skills"):
        for skill in skill_manager.get_all_skills():
            # 检查是否是画图技能
            if skill is SkillDrawingBase:
                # 检查是否处于规划模式或正在画图
                if skill.is_planning or skill.is_drawing:
                    return true
    
    return false
```

#### 2. 击退免疫逻辑
```gdscript
func apply_knockback_self(force: Vector2) -> void:
    # P1-2: 霸体机制 - 画图时免疫击退
    if _is_drawing_active() and BondManager.has_mechanic("super_armor"):
        print("[PlayerBase] [P1-2] 触发霸体，免疫击退（仍然受到伤害）")
        Global.spawn_floating_text(global_position, "SUPER ARMOR!", Color.ORANGE)
        # 仍然播放受击反馈，但不应用击退
        Global.on_camera_shake.emit(3.0, 0.08)
        return
    
    # 应用击退力缩放系数，减少击退效果（从CSV加载）
    external_force = force * knockback_scale
    Global.on_camera_shake.emit(5.0, 0.1)
```

### 测试方法
1. 选择巨擘角色（或装备巨擘圣物）
2. 激活巨擘 Lv.2 羁绊（需要2个巨擘标签）
3. 按住Q键进入画图模式
4. 让敌人攻击你
5. 观察：
   - 仍然扣血
   - 不会被击退
   - 画图不会中断
   - 屏幕显示 "SUPER ARMOR!" 飘字

---

## P1-3: 速度转伤害 (speed_to_damage)

### 功能描述
当前移动速度超过基础速度时，额外的速度会转化为伤害加成。

### 关联羁绊
- **风行者 (Nomad) Lv.2**
- 效果值：0.01（转换系数，每点速度增加1%伤害）

### 实现位置
- `scenes/unit/players/player_base.gd` - 速度加成计算
- `scenes/skills/skill_drawing_base.gd` - 伤害应用

### 实现逻辑

#### 1. 速度加成计算（player_base.gd）
```gdscript
## P1-3: 计算速度转伤害加成（风行者羁绊）
func get_speed_damage_bonus() -> float:
    """计算基于速度的伤害加成
    
    Returns:
        伤害加成倍率（例如 0.15 表示 +15% 伤害）
    """
    # 检查风行者羁绊 - 速度转伤害
    if not BondManager.has_mechanic("speed_to_damage"):
        return 0.0
    
    # 获取转换系数（从配置中读取，例如 0.01 = 每点速度增加1%伤害）
    var conversion_rate = BondManager.get_mechanic_value("speed_to_damage")
    
    # 计算速度差值
    var current_speed = speed  # 当前速度（可能被buff影响）
    var speed_diff = current_speed - base_speed
    
    # 只有速度高于基础速度时才有加成
    if speed_diff <= 0:
        return 0.0
    
    # 计算加成
    var bonus = speed_diff * conversion_rate
    
    print("[PlayerBase] [P1-3] 速度转伤害: 当前速度%.0f, 基础速度%.0f, 差值%.0f, 转换率%.4f, 伤害加成+%.1f%%" % [
        current_speed,
        base_speed,
        speed_diff,
        conversion_rate,
        bonus * 100
    ])
    
    return bonus
```

#### 2. 伤害应用（skill_drawing_base.gd）
```gdscript
## P1-3: 应用速度转伤害加成（风行者羁绊）
## @param base_damage: 基础伤害值
## @return: 应用速度加成后的伤害值
func _apply_speed_damage_bonus(base_damage: float) -> float:
    if not skill_owner or not skill_owner.has_method("get_speed_damage_bonus"):
        return base_damage
    
    var speed_bonus = skill_owner.get_speed_damage_bonus()
    if speed_bonus <= 0:
        return base_damage
    
    var final_damage = base_damage * (1.0 + speed_bonus)
    
    print("[%s] [P1-3] 速度转伤害应用: %.0f -> %.0f (+%.1f%%)" % [
        skill_id,
        base_damage,
        final_damage,
        speed_bonus * 100
    ])
    
    return final_damage
```

### 使用方法
子类技能在计算伤害时调用：
```gdscript
# 在技能的伤害计算中
var base_damage = 100.0
var final_damage = _apply_speed_damage_bonus(base_damage)
```

### 测试方法
1. 选择风行者角色（或装备风行者圣物）
2. 激活风行者 Lv.2 羁绊（需要2个风行者标签）
3. 获得速度buff（例如装备速度道具）
4. 使用技能攻击敌人
5. 观察控制台日志：
   - 速度差值计算
   - 伤害加成百分比
   - 最终伤害值

### 计算示例
- 基础速度：300
- 当前速度：400（+100）
- 转换系数：0.01
- 速度加成：100 × 0.01 = 1.0 = +100% 伤害
- 基础伤害：100
- 最终伤害：100 × (1 + 1.0) = 200

---

## P1-4: 金币轨迹 (gold_trail)

### 功能描述
画图时，每隔一定距离自动生成金币。

### 关联羁绊
- **炼金术士 (Alchemist) Lv.2**
- 效果值：1（每次生成的金币数量）

### 实现位置
`scenes/skills/skill_drawing_base.gd`

### 实现逻辑

#### 1. 变量定义
```gdscript
## P1-4: 上一次生成金币的位置（用于金币轨迹）
var last_gold_spawn_pos: Vector2 = Vector2.ZERO

## P1-4: 金币生成距离阈值（像素）
const GOLD_SPAWN_DISTANCE: float = 100.0
```

#### 2. 初始化
```gdscript
func _start_drawing() -> void:
    is_drawing = true
    var mouse_pos = skill_owner.get_global_mouse_position()
    
    # ... 其他初始化代码 ...
    
    # P1-4: 重置金币生成位置
    last_gold_spawn_pos = mouse_pos
```

#### 3. 金币生成逻辑
```gdscript
func _continue_drawing() -> void:
    # ... 画线逻辑 ...
    
    # P1-4: 金币轨迹机制
    _check_and_spawn_gold_trail(new_point)
    
    # ... 其他逻辑 ...

## P1-4: 检查并生成金币轨迹（炼金术士羁绊）
## @param current_pos: 当前位置
func _check_and_spawn_gold_trail(current_pos: Vector2) -> void:
    # 检查炼金术士羁绊 - 金币轨迹
    if not BondManager.has_mechanic("gold_trail"):
        return
    
    # 检查距离阈值（防止生成过多金币）
    var distance_from_last = current_pos.distance_to(last_gold_spawn_pos)
    if distance_from_last < GOLD_SPAWN_DISTANCE:
        return
    
    # 生成金币
    var gold_amount = int(BondManager.get_mechanic_value("gold_trail"))
    if gold_amount <= 0:
        gold_amount = 1  # 默认1金币
    
    # 调用DataManager添加金币
    if skill_owner and skill_owner.has_method("add_gold"):
        skill_owner.add_gold(gold_amount)
        print("[%s] [P1-4] 金币轨迹触发: 生成%d金币 at (%.0f, %.0f)" % [
            skill_id,
            gold_amount,
            current_pos.x,
            current_pos.y
        ])
    
    # 更新上次生成位置
    last_gold_spawn_pos = current_pos
```

### 性能保护
- **距离阈值**：100像素（`GOLD_SPAWN_DISTANCE`）
- **触发频率**：每画100像素生成1次金币
- **防止爆炸**：通过距离检测确保不会在短时间内生成大量金币

### 测试方法
1. 选择炼金术士角色（或装备炼金术士圣物）
2. 激活炼金术士 Lv.2 羁绊（需要2个炼金术士标签）
3. 按住Q键进入画图模式
4. 按住鼠标左键画一条长线（至少200像素）
5. 观察：
   - 每隔100像素生成1金币
   - 金币数量增加
   - 控制台显示生成日志

---

## 修改文件清单

### 1. `scenes/unit/enemy/enemy.gd`
- **修改内容**：P1-1 击杀回能
- **修改位置**：`destroy_enemy()` 函数
- **代码行数**：+12 行

### 2. `scenes/unit/players/player_base.gd`
- **修改内容**：
  - P1-2 霸体机制（击退免疫）
  - P1-3 速度转伤害计算
- **修改位置**：
  - `apply_knockback_self()` 函数
  - 新增 `_is_drawing_active()` 函数
  - 新增 `get_speed_damage_bonus()` 函数
- **代码行数**：+70 行

### 3. `scenes/skills/skill_drawing_base.gd`
- **修改内容**：
  - P1-3 速度转伤害应用
  - P1-4 金币轨迹
- **修改位置**：
  - 新增变量 `last_gold_spawn_pos`, `GOLD_SPAWN_DISTANCE`
  - `_start_drawing()` 函数（初始化金币位置）
  - `_continue_drawing()` 函数（调用金币生成）
  - 新增 `_apply_speed_damage_bonus()` 函数
  - 新增 `_check_and_spawn_gold_trail()` 函数
- **代码行数**：+80 行

---

## 测试清单

### P1-1: 击杀回能
- [ ] 激活墨灵 Lv.2 羁绊
- [ ] 击杀敌人
- [ ] 验证能量增加量（基础 + 5）
- [ ] 检查控制台日志

### P1-2: 霸体
- [ ] 激活巨擘 Lv.2 羁绊
- [ ] 进入画图模式
- [ ] 被敌人攻击
- [ ] 验证不被击退
- [ ] 验证仍然扣血
- [ ] 验证画图不中断
- [ ] 检查飘字提示

### P1-3: 速度转伤害
- [ ] 激活风行者 Lv.2 羁绊
- [ ] 获得速度buff
- [ ] 使用技能攻击
- [ ] 验证伤害增加
- [ ] 检查控制台日志（速度差值、加成百分比）

### P1-4: 金币轨迹
- [ ] 激活炼金术士 Lv.2 羁绊
- [ ] 画一条长线（>200像素）
- [ ] 验证金币生成（每100像素1个）
- [ ] 验证金币数量增加
- [ ] 检查控制台日志

---

## 后续工作

### P2 级机制（次要玩法）
- P2-1: `dash_invincible` - 冲刺无敌
- P2-2: `reflect_damage` - 反伤
- P2-3: `aoe_expand` - AOE扩大
- P2-4: `cooldown_reduction` - 冷却缩减

### P3 级机制（高级玩法）
- P3-1: `chain_lightning` - 连锁闪电
- P3-2: `summon_clone` - 召唤分身
- P3-3: `time_slow` - 时间减速
- P3-4: `resource_conversion` - 资源转换

---

## 注意事项

1. **性能优化**：
   - 金币轨迹使用距离阈值防止过度生成
   - 所有机制都有明确的触发条件检查

2. **调试日志**：
   - 所有机制都包含详细的 `print` 日志
   - 日志格式统一：`[类名] [机制ID] 描述: 数据`

3. **代码规范**：
   - 使用 `##` 注释标记机制相关代码
   - 函数命名清晰（`_check_and_spawn_gold_trail`）
   - 变量命名语义化（`last_gold_spawn_pos`）

4. **扩展性**：
   - 所有机制通过 `BondManager` 统一管理
   - 子类技能可以轻松调用基类提供的加成函数
   - 配置驱动，易于调整数值

---

## 总结

P1 级四个核心机制已全部实现完成，覆盖了四大流派的核心玩法：

1. **击杀回能**：支持法师续航流，通过击杀敌人快速恢复能量
2. **霸体**：支持坦克硬抗流，画图时不会被打断
3. **速度转伤害**：支持跑酷输出流，速度越快伤害越高
4. **金币轨迹**：支持经济发育流，画图时自动生成金币

所有机制都经过详细的代码注释和日志输出，便于调试和测试。下一步可以继续实现 P2 级和 P3 级机制，进一步丰富游戏玩法。

---

**实现日期**：2026-01-31  
**实现者**：Kiro AI Assistant  
**版本**：v1.0
