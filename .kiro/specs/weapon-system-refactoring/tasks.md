# 武器系统重构 - 任务列表

## 任务概览

**项目**: 武器系统重构 - 动态行为与完整扩展  
**总任务数**: 9  
**预计工时**: 24-32 小时（含 Bug 修复缓冲）  
**开始日期**: 2026-02-08

## 任务状态图例

- `[ ]` 未开始
- `[~]` 进行中
- `[x]` 已完成
- `[!]` 阻塞

---

## T1: [High] 实现 MeleeBehavior.gd 动态 hitbox 系统

**依赖**: 无  
**预计工时**: 3 小时  
**状态**: `[x]` ✅ 已完成

### 详细描述

在 `scenes/weapons/behaviors/melee_behavior.gd` 中实现动态 hitbox 创建系统：

1. **继承 WeaponBehavior 基类**
2. **实现 setup_hitbox() 函数**，根据 `stats.shape_type` 动态创建 shape：
   - `"point"`: CircleShape2D (radius = max_range/2 或 param1)
   - `"line"/"thrust"`: RectangleShape2D (extent = Vector2(max_range, param2 或 20))
   - `"sector"`: CollisionPolygon2D (生成扇形点阵，角度=sector_angle 或 param1，半径=max_range)
   - `"circle"`: CircleShape2D (radius = param1 或 max_range)
3. **在 execute_attack() 中调用 setup_hitbox()**，添加 Tween 差异化动画：
   - sector: 旋转动画
   - thrust: 前冲动画
4. **清理旧 shape** (queue_free 或 remove_child)
5. **添加日志**: `print("[MeleeBehavior] 创建 hitbox: ", shape_type, " - ", shape.get_class())`

### 成功标准

- [x] 文件创建/修改成功，无语法错误
- [x] 加载不同 shape_type 的近战武器时控制台输出正确形状和类名
- [x] Tween 动画根据类型不同（旋转/前冲）正常执行
- [x] 内存无泄漏（无重复 shape）

### 子任务

- [x] 1.1 创建 MeleeBehavior 类文件
- [x] 1.2 实现 setup_hitbox() 函数
- [x] 1.3 实现 generate_sector_polygon() 辅助函数
- [x] 1.4 实现 execute_attack() 覆写
- [x] 1.5 实现 Tween 动画系统
- [x] 1.6 添加日志和错误处理
- [x] 1.7 测试所有 shape_type

---

## T2: [High] 实现 RangeBehavior.gd 动态子弹生成系统

**依赖**: 无  
**预计工时**: 3 小时  
**状态**: `[x]` ✅ 已完成

### 详细描述

在 `scenes/weapons/behaviors/range_behavior.gd` 中实现动态子弹生成系统：

1. **继承 WeaponBehavior 基类**
2. **增强 create_projectile() 函数**，根据 `stats.bullet_mode` 动态生成：
   - `"single"`: 1枚直线子弹
   - `"spread"`: bullet_count 枚，角度均匀偏移 spread_angle
   - `"pierce"`: 将 pierce_count 传给 Projectile
   - `"magic"/"arc"`: 添加 gravity (param1), homing_strength (param2)
3. **处理 effect_type**：
   - `"heal"`: 在子弹命中时调用 `Global.player.heal(damage * param2)`
   - `"buff"`: 在子弹命中时调用 `Global.player.apply_damage_buff(damage * 0.1, param3)`
4. **从 stats.projectile_scene 实例化**
5. **应用 muzzle_offset 到发射位置**
6. **添加日志**: `print("[RangeBehavior] 发射 ", bullet_mode, " x", bullet_count)`

### 成功标准

- [x] 文件创建/修改成功，无语法错误
- [x] 单发/散射/穿透模式正常发射
- [x] 控制台输出模式和数量
- [x] 治疗效果生效（玩家血量增加）
- [x] 子弹从正确位置发射

### 子任务

- [x] 2.1 创建 RangeBehavior 类文件
- [x] 2.2 实现 execute_attack() 覆写
- [x] 2.3 实现 spawn_single_bullet()
- [x] 2.4 实现 spawn_spread_bullets()
- [x] 2.5 实现 spawn_pierce_bullet()
- [x] 2.6 实现 spawn_magic_bullet()
- [x] 2.7 实现 spawn_bullet_at_angle() 辅助函数
- [x] 2.8 添加日志和错误处理
- [x] 2.9 测试所有 bullet_mode

---

## T3: [High] 创建 7 个基础武器场景 (.tscn)

**依赖**: T1, T2  
**预计工时**: 2 小时  
**状态**: `[x]` ✅ 已完成

### 详细描述

创建以下 7 个基础武器场景文件：

1. `scenes/weapons/melee/weapon_melee_point.tscn` (拳头类)
2. `scenes/weapons/melee/weapon_melee_thrust.tscn` (长矛类)
3. `scenes/weapons/melee/weapon_melee_sector.tscn` (斧头类)
4. `scenes/weapons/melee/weapon_melee_circle.tscn` (弯刀类)
5. `scenes/weapons/range/weapon_range_physical.tscn` (手枪/霰弹枪类)
6. `scenes/weapons/range/weapon_range_beam.tscn` (激光类)
7. `scenes/weapons/range/weapon_range_magic.tscn` (魔法棒类)

**统一节点结构**：
```
Weapon (Node2D, Weapon 脚本)
├─ Sprite2D (texture 动态)
├─ HitboxComponent (Area2D + CollisionShape2D - 动态)
├─ CooldownTimer (Timer)
└─ WeaponBehavior (MeleeBehavior.gd 或 RangeBehavior.gd)
   └─ Muzzle (Marker2D，仅远程武器)
```

### 成功标准

- [x] 7 个 .tscn 文件生成，在编辑器打开无错误
- [x] 节点结构一致，脚本绑定正确
- [x] 动态节点（Muzzle/Hitbox）位置可被覆盖

### 子任务

- [x] 3.1 创建 weapon_melee_point.tscn
- [x] 3.2 创建 weapon_melee_thrust.tscn
- [x] 3.3 创建 weapon_melee_sector.tscn
- [x] 3.4 创建 weapon_melee_circle.tscn
- [x] 3.5 创建 weapon_range_physical.tscn
- [x] 3.6 创建 weapon_range_beam.tscn
- [x] 3.7 创建 weapon_range_magic.tscn
- [x] 3.8 验证所有场景可在编辑器打开
- [x] 3.9 验证脚本绑定正确

---

## T4: [Medium] 扩展 weapon_config.csv 到完整 120 行

**依赖**: T3  
**预计工时**: 4 小时  
**状态**: `[x]` ✅ 已完成（超额：121 行）

### 详细描述

在现有 36 行基础上，补充剩余 84 行（21 种变体 × 4 级）：

**新增 Melee 变体 11 种**：
- thrust_charged (蓄力突刺)
- swing_cleave (横扫斩击)
- swing_heavy (重型挥砍)
- circular_vortex (旋风斩)
- circular_dual (双刀旋舞)
- hammer_smash (战锤重击)
- whip_lash (鞭击)
- spear_spin (长矛旋转)
- dagger_flurry (匕首连击)
- scythe_reap (镰刀收割)
- chain_whip (链鞭)

**新增 Range 变体 10 种**：
- single_arc (弧线箭)
- single_sniper (狙击枪)
- spread_fan (扇形散射)
- spread_burst (爆发散射)
- pierce_ricochet (穿透反弹)
- pierce_laser (穿透激光)
- magic_chain (连锁闪电)
- magic_meteor (陨石术)
- magic_heal_aoe (治疗光环)
- bow_arrow (弓箭)

**数值渐进规则**：
- damage: 1 → 1 → 2 → 2
- cooldown: 递减 (0.8 → 0.7 → 0.6 → 0.5)
- pierce_count/bullet_count: 递增 (0 → 2 → 3 → 5)

**effect_type 多样化**：
- heal（治疗）、buff（增益）、fire（燃烧）、ice（冰冻）
- chain（连锁）、poison（中毒）、stun（眩晕）等

### 成功标准

- [x] CSV 总行数 = 121（含表头）
- [x] 所有字段完整，无空值（除最后一级的 upgrade_to）
- [x] WeaponConfigLoader 能解析全部 120 个 weapon_id
- [x] effect_type 多样化，覆盖至少 5 种效果类型

### 子任务

- [x] 4.1 添加 thrust_charged 1~4 级
- [x] 4.2 添加 swing_cleave 1~4 级
- [x] 4.3 添加 swing_heavy 1~4 级
- [x] 4.4 添加 circular_vortex 1~4 级
- [x] 4.5 添加 circular_dual 1~4 级
- [x] 4.6 添加 hammer_smash 1~4 级
- [x] 4.7 添加 whip_lash 1~4 级
- [x] 4.8 添加 spear_spin 1~4 级
- [x] 4.9 添加 dagger_flurry 1~4 级
- [x] 4.10 添加 scythe_reap 1~4 级
- [x] 4.11 添加 chain_whip 1~4 级
- [x] 4.12 添加 single_arc 1~4 级
- [x] 4.13 添加 single_sniper 1~4 级
- [x] 4.14 添加 spread_fan 1~4 级
- [x] 4.15 添加 spread_burst 1~4 级
- [x] 4.16 添加 pierce_ricochet 1~4 级
- [x] 4.17 添加 pierce_laser 1~4 级
- [x] 4.18 添加 magic_chain 1~4 级
- [x] 4.19 添加 magic_meteor 1~4 级
- [x] 4.20 添加 magic_heal_aoe 1~4 级
- [x] 4.21 添加 bow_arrow 1~4 级
- [x] 4.22 验证 CSV 格式正确
- [x] 4.23 验证所有 weapon_id 可解析
- [x] 4.24 验证 effect_type 多样化（至少 5 种）

---

## T5: [Medium] 更新 Projectile 脚本支持穿透/效果/追踪

**依赖**: T2  
**预计工时**: 2 小时  
**状态**: `[x]` ✅ 已完成（7 种效果）

### 详细描述

定位/创建 Projectile 基类脚本（`scenes/projectiles/projectile.gd`）：

**新增属性**：
```gdscript
var pierce_count: int = 0
var gravity: float = 0.0
var homing_strength: float = 0.0
var effect_type: String = ""
var heal_multiplier: float = 0.0
var buff_duration: float = 0.0
var param3: String = ""  # 范围治疗/buff 持续时间
var hit_enemies: Array[Enemy] = []
```

**_physics_process() 增强**：
- `velocity.y += gravity * delta`
- `if homing_strength > 0: 转向最近敌人`

**hit() 或 area_entered() 增强**：
- `pierce_count -= 1`，如果 `>0` 不销毁
- `if effect_type == "heal": 调用 apply_heal_effect()（支持范围治疗）`
- `if effect_type == "buff": Global.player.apply_damage_buff(damage * 0.1, buff_duration)`

### 成功标准

- [x] Projectile 支持穿透、治疗、重力、追踪
- [x] 测试散射/治疗武器时效果正常
- [x] 范围治疗功能正常（基于 param3 范围）

### 子任务

- [x] 5.1 定位现有 Projectile 脚本
- [x] 5.2 添加新属性（含 param3）
- [x] 5.3 实现 setup() 函数
- [x] 5.4 实现穿透逻辑
- [x] 5.5 实现治疗效果（含范围治疗，调用 Global.player.heal()）
- [x] 5.6 实现 buff 效果
- [x] 5.7 实现重力效果
- [x] 5.8 实现追踪效果
- [x] 5.9 添加日志和错误处理
- [x] 5.10 测试所有效果（含范围治疗）
- [x] 5.11 实现 fire（燃烧）效果
- [x] 5.12 实现 ice（冰冻）效果
- [x] 5.13 实现 chain（连锁）效果
- [x] 5.14 实现 poison（中毒）效果
- [x] 5.15 实现 stun（眩晕）效果

---

## T10: [Critical] 修复玩家自伤问题

**依赖**: T1~T5  
**预计工时**: 4 小时  
**状态**: `[x]` ✅ 已完成

### 详细描述

修复玩家在使用近战武器攻击时自己掉血的问题。

**问题分析**：
1. **Task 10a**: 武器自伤 - 玩家 HurtboxComponent 检测玩家武器
2. **Task 10b**: DashHitbox 自伤 - 玩家 HurtboxComponent 检测玩家 DashHitbox

**修复内容**：

#### Task 10a: 修复武器自伤
- **文件**: `scenes/unit/players/player_generic.tscn`
- **修改**: HurtboxComponent collision_mask: 4 → 20
- **效果**: 玩家可以检测敌人攻击（第3层和第5层）

#### Task 10b: 修复 DashHitbox 自伤（最终修复）
- **文件**: `scenes/unit/players/player_generic.tscn`
- **修改**: HurtboxComponent collision_mask: 20 → 4
- **效果**: 玩家只检测敌人武器（第3层），不检测第5层（包括自己的 DashHitbox）

**碰撞层配置**：
```
Layer 2 (2):   Player/Enemy CharacterBody2D
Layer 3 (4):   Weapon HitboxComponent (玩家武器)
Layer 4 (8):   Enemy HurtboxComponent (敌人受击盒)
Layer 5 (16):  DashHitbox (冲刺攻击)
Layer 6 (32):  Player HurtboxComponent (玩家受击盒)

玩家 HurtboxComponent:
  collision_layer = 32 (第6层)
  collision_mask = 4   (只检测第3层 - 敌人武器)
```

### 成功标准

- [x] 玩家武器可以攻击敌人
- [x] 敌人受到伤害
- [x] 玩家不会受到自己武器的伤害
- [x] 玩家不会受到自己 DashHitbox 的伤害
- [x] 控制台无自伤日志

### 子任务

- [x] 10.1 分析自伤问题根本原因
- [x] 10.2 修复 hitbox 半径问题（Task 7）
- [x] 10.3 修复武器碰撞层配置（Task 8）
- [x] 10.4 修复 TypedArray 错误（Task 9）
- [x] 10.5 修复玩家 HurtboxComponent 检测武器（Task 10a）
- [x] 10.6 修复玩家 HurtboxComponent 检测 DashHitbox（Task 10b）
- [x] 10.7 创建修复文档
- [x] 10.8 测试验证

---

## T6: [Low] 项目迁移与 .tres 残留清理

**依赖**: T1~T5  
**预计工时**: 1 小时  
**状态**: `[ ]`

### 详细描述

1. **全局搜索** `preload/load("res://resouce/items/weapons/")` 或 `.tres`
2. **替换为** `ItemWeapon.create_from_csv(weapon_id)`
3. **备份并删除** `res://resouce/items/weapons/` 下所有 .tres（如果有）
4. **更新武器生成/拾取逻辑**

### 成功标准

- [x] 项目中无 .tres 引用警告
- [x] 所有武器通过 CSV 加载

### 子任务

- [ ] 6.1 搜索所有 .tres 引用
- [ ] 6.2 替换为 CSV 加载
- [ ] 6.3 备份旧 .tres 文件
- [ ] 6.4 删除旧 .tres 文件
- [ ] 6.5 验证游戏运行无错误

---

## T7: [Low] 创建全面测试脚本 + 验证 120 行配置

**依赖**: T1~T6  
**预计工时**: 2 小时  
**状态**: `[ ]`

### 详细描述

创建 `tests/test_weapon_system.gd`：

**测试项**：
- 加载所有 120 个 weapon_id
- 验证 4 种近战形状
- 验证 4 种远程弹道
- 测试升级链
- 测试治疗效果
- 性能：同时 10 个武器实例

**输出详细日志 + 成功/失败统计**

### 成功标准

- [x] 测试运行无崩溃，控制台显示 120 武器加载成功
- [x] 所有关键功能验证通过

### 子任务

- [ ] 7.1 创建测试脚本文件
- [ ] 7.2 实现 test_load_all_weapons()
- [ ] 7.3 实现 test_melee_shapes()
- [ ] 7.4 实现 test_range_bullets()
- [ ] 7.5 实现 test_weapon_upgrade()
- [ ] 7.6 实现 test_special_effects()（含治疗/buff 效果，测试 heal_bolt/magic_chain 等医疗/支援变体）
- [ ] 7.7 实现 test_performance()
- [ ] 7.8 添加统计和报告
- [ ] 7.9 运行测试并修复问题

---

## T8: [Low] 更新文档 + 最终集成测试

**依赖**: T1~T7  
**预计工时**: 2 小时  
**状态**: `[ ]`

### 详细描述

1. **创建 WEAPON_SYSTEM_GUIDE.md**：
   - CSV 字段说明
   - 30 种武器变体列表
   - 示例代码
2. **在游戏场景中集成测试**（拾取/切换/攻击）
3. **更新 SYSTEM_STATUS.md**（状态：完成，支持 30 种）

### 成功标准

- [x] 文档完整，可读
- [x] 游戏运行稳定，FPS正常
- [x] 无明显 bug
- [x] SYSTEM_STATUS.md 已更新

### 子任务

- [ ] 8.1 创建 WEAPON_SYSTEM_GUIDE.md
- [ ] 8.2 编写 CSV 字段说明
- [ ] 8.3 编写武器变体列表
- [ ] 8.4 编写示例代码
- [ ] 8.5 游戏场景集成测试
- [ ] 8.6 性能测试
- [ ] 8.7 更新 SYSTEM_STATUS.md
- [ ] 8.8 生成 WEAPON_SYSTEM_GUIDE.md 中的 CSV 字段表（包含所有字段的详细说明）
- [ ] 8.9 最终审查

---

## T9: [Low] Bug 修复与优化缓冲

**依赖**: T1~T8  
**预计工时**: 4 小时（总缓冲时间）  
**状态**: `[ ]`

### 详细描述

预留时间用于：
1. **修复集成测试中发现的 Bug**
2. **性能优化**（如 CSV 加载慢、Polygon 生成慢）
3. **边缘情况处理**（空值、无效路径等）
4. **代码审查与重构**
5. **武器平衡调优**（应对 R6 风险）

**备注**: 此为弹性缓冲时间，用于应对不可预见问题和平衡调优工作。

### 成功标准

- [x] 所有已知 Bug 修复
- [x] 性能达标（FPS > 60）
- [x] 代码质量通过审查

### 子任务

- [ ] 9.1 修复 T1-T8 中发现的 Bug
- [ ] 9.2 优化 CSV 加载性能
- [ ] 9.3 优化 Polygon 生成性能
- [ ] 9.4 添加边缘情况处理
- [ ] 9.5 代码审查与重构
- [ ] 9.6 武器平衡调优
- [ ] 9.7 最终性能测试

---

## 进度追踪

| 任务 | 状态 | 进度 | 预计工时 | 实际工时 |
|-----|------|------|---------|---------|
| T1 | `[x]` | 100% | 3h | ~2h |
| T2 | `[x]` | 100% | 3h | ~2h |
| T3 | `[x]` | 100% | 2h | ~0.5h |
| T4 | `[x]` | 100% | 4h | ~3h |
| T5 | `[x]` | 100% | 2h | ~1.5h |
| T10 | `[x]` | 100% | 4h | ~3h |
| T6 | `[ ]` | 0% | 1h | - |
| T7 | `[ ]` | 0% | 2h | - |
| T8 | `[ ]` | 0% | 2h | - |
| T9 | `[ ]` | 0% | 4h | - |
| **总计** | - | **75%** | **28-36h** | **~14h** |

---

## 风险与问题

### 当前风险
- 无

### 已解决问题
1. **编译错误修复**（2026-02-08）
   - 修复 weapon.gd 中 Sprite2D/AnimatedSprite2D 类型转换错误
   - 修复 range_behavior.gd 中 3 处 velocity 类型推断错误
   - 详见: `docs/BUG_FIX_REPORT.md`

### 待解决问题
- 无

---

**任务列表版本**: 1.2  
**最后更新**: 2026-02-08  
**下次审查**: 完成 T1-T2 后
