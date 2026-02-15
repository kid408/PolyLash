# 武器系统重构 - 需求文档

## 项目概述

**项目名称**: 武器系统重构 - 动态行为与完整扩展  
**创建日期**: 2026-02-08  
**状态**: 进行中  
**优先级**: High

## 背景

我们已完成武器系统的基础重构：
- ✅ CSV 表设计（weapon_config.csv）
- ✅ 示范 36 行数据（9 种武器 × 4 级）
- ✅ WeaponConfigLoader.gd（CSV 解析器）
- ✅ item_weapon.gd 简化
- ✅ Weapon.gd 增强（场景复用系统）

现在需要完成剩余工作，实现完整的动态行为系统，支持所有 30 种武器变体（120 行配置）。

## 核心目标

1. **动态复用 7 个基场景** - 无重复 .tscn，纯 CSV 驱动
2. **支持 30 种武器变体** - Melee 15 种 + Range 15 种，每种 4 级
3. **运行时动态调整** - 根据 CSV 参数调整碰撞/弹道/效果
4. **完全废弃 .tres** - 清理所有资源文件残留
5. **可玩状态** - 加载任意武器 ID → 正确显示/攻击/效果

## 用户故事

### US1: 近战武器动态 Hitbox
**作为** 游戏策划  
**我想要** 通过 CSV 配置不同的近战攻击形状（点/线/扇形/圆形）  
**以便** 无需创建新场景即可设计多样化的近战武器

**验收标准**:
- AC1.1: 加载 shape_type="point" 的武器时，动态创建 CircleShape2D
- AC1.2: 加载 shape_type="line" 的武器时，动态创建 RectangleShape2D
- AC1.3: 加载 shape_type="sector" 的武器时，动态创建 CollisionPolygon2D（扇形）
- AC1.4: 加载 shape_type="circle" 的武器时，动态创建 CircleShape2D（全范围）
- AC1.5: 不同形状的攻击动画不同（扇形旋转，直线前冲）
- AC1.6: 控制台输出形状类型和类名用于调试

### US2: 远程武器动态子弹
**作为** 游戏策划  
**我想要** 通过 CSV 配置不同的子弹发射模式（单发/散射/穿透/魔法）  
**以便** 创建丰富的远程武器体验

**验收标准**:
- AC2.1: bullet_mode="single" 时发射 1 枚直线子弹
- AC2.2: bullet_mode="spread" 时发射 bullet_count 枚散射子弹
- AC2.3: bullet_mode="pierce" 时子弹可穿透 pierce_count 个敌人
- AC2.4: bullet_mode="magic" 时子弹具有重力和追踪效果
- AC2.5: effect_type="heal" 时子弹命中回复玩家生命值
- AC2.6: 子弹从正确的 muzzle_offset 位置发射
- AC2.7: effect_type="buff" 时子弹命中增加队友伤害 buff（param3=持续时间）

### US3: 场景复用系统
**作为** 开发者  
**我想要** 只维护 7 个基础武器场景  
**以便** 减少文件数量和维护成本

**验收标准**:
- AC3.1: 创建 4 个近战基场景（point/thrust/sector/circle）
- AC3.2: 创建 3 个远程基场景（physical/beam/magic）
- AC3.3: 所有场景节点结构一致
- AC3.4: 所有场景可被 base_scene_path 正确引用
- AC3.5: 动态节点（Sprite/Hitbox/Muzzle）可被 CSV 参数覆盖
- AC3.6: 所有场景继承自 weapon_base.tscn（如果存在）
- AC3.7: 场景在编辑器中可正常打开和编辑

### US4: 完整武器库
**作为** 游戏策划  
**我想要** 配置 30 种不同的武器变体  
**以便** 提供丰富的游戏内容

**验收标准**:
- AC4.1: CSV 包含 120 行配置（30 种 × 4 级）
- AC4.2: 新增 11 种近战变体（thrust_charged, swing_cleave 等）
- AC4.3: 新增 10 种远程变体（single_arc, spread_fan 等）
- AC4.4: 每种变体 4 级数值渐进合理
- AC4.5: 所有字段填充完整（param1/2/3, effect_type 等）
- AC4.6: WeaponConfigLoader 能解析所有 120 个 weapon_id

### US5: 子弹增强系统
**作为** 开发者  
**我想要** 子弹支持穿透、治疗、重力、追踪等效果  
**以便** 实现复杂的武器机制

**验收标准**:
- AC5.1: Projectile 脚本新增 pierce_count 属性
- AC5.2: Projectile 脚本新增 gravity 属性
- AC5.3: Projectile 脚本新增 homing_strength 属性
- AC5.4: Projectile 脚本新增 effect_type 和 heal_multiplier 属性
- AC5.5: 穿透逻辑正常工作（击中多个敌人）
- AC5.6: 治疗效果正常工作（玩家血量增加）

### US6: 清理遗留系统
**作为** 开发者  
**我想要** 移除所有 .tres 资源文件引用  
**以便** 确保系统完全由 CSV 驱动

**验收标准**:
- AC6.1: 项目中无 .tres 文件引用
- AC6.2: 所有武器通过 ItemWeapon.create_from_csv() 创建
- AC6.3: 旧 .tres 文件移至 _deprecated/ 文件夹
- AC6.4: 游戏运行无 "Resource not found" 错误

### US7: 测试与验证
**作为** QA  
**我想要** 自动化测试脚本验证所有武器  
**以便** 确保系统稳定可靠

**验收标准**:
- AC7.1: 测试脚本能加载所有 120 个 weapon_id
- AC7.2: 测试脚本验证 4 种近战形状
- AC7.3: 测试脚本验证 4 种远程弹道
- AC7.4: 测试脚本验证升级链
- AC7.5: 测试脚本验证特殊效果（治疗/穿透）
- AC7.6: 性能测试（同时 10 个武器实例）

### US8: 文档与集成
**作为** 团队成员  
**我想要** 完整的系统文档和集成测试  
**以便** 理解和使用新系统

**验收标准**:
- AC8.1: 创建 WEAPON_SYSTEM_GUIDE.md
- AC8.2: 文档包含 CSV 字段说明
- AC8.3: 文档包含 30 种武器变体列表
- AC8.4: 文档包含示例代码
- AC8.5: 游戏场景集成测试通过
- AC8.6: 更新 SYSTEM_STATUS.md

### US9: Projectile 脚本扩展支持
**作为** 开发者  
**我想要** 更新 Projectile.gd 支持穿透/重力/追踪/效果  
**以便** 实现高级远程武器变体

**验收标准**:
- AC9.1: pierce_count > 0 时子弹不销毁，可击中多个敌人
- AC9.2: gravity 影响 velocity.y，实现抛物线弹道
- AC9.3: homing_strength > 0 时子弹转向最近敌人
- AC9.4: effect_type="heal" 时回复生命值（damage * heal_multiplier），目标为 Global.player 或附近队友（基于 param3 范围）
- AC9.5: effect_type="buff" 时增加队友伤害 buff（持续时间=param3）
- AC9.6: 子弹记录已击中敌人列表，避免重复伤害

### US10: CSV 扩展支持
**作为** 游戏策划  
**我想要** 扩展 weapon_config.csv 到 120 行，补充 21 种武器变体  
**以便** 覆盖 30 种角色/玩法需求

**验收标准**:
- AC10.1: 新增 Melee 变体 11 种，合理填充 param1~3（蓄力时间/旋转速度/连击次数等）
- AC10.2: 新增 Range 变体 10 种，数值渐进合理（damage/cooldown/pierce_count 等）
- AC10.3: effect_type 多样化（heal/buff/fire/ice/chain/poison/stun 等）
- AC10.4: 所有变体 4 级配置完整，upgrade_to 链正确
- AC10.5: base_scene_path 正确指向 7 个基础场景之一
- AC10.6: CSV 格式正确，无空值（除最后一级 upgrade_to）

## 非功能需求

### 性能要求
- NFR1: 同时存在 10+ 武器实例时 FPS > 60
- NFR2: 武器加载时间 < 50ms
- NFR3: 内存占用增加 < 10MB

### 可维护性要求
- NFR4: 所有代码遵循 GDScript 最佳实践
- NFR5: 关键函数添加注释和日志
- NFR6: 错误处理完善（空值检查、资源验证）

### 可扩展性要求
- NFR7: 新增武器变体只需修改 CSV
- NFR8: 新增效果类型只需扩展 effect_type 枚举
- NFR9: 支持未来添加更多 param 字段
- NFR10: 支持 Godot 4.0 ~ 4.3 版本
- NFR11: CSV 解析防注入（load 前验证 ResourceLoader.exists）

## 技术约束

1. **引擎版本**: Godot 4.x（最低 4.0，支持 4.0 ~ 4.3）
2. **语言**: GDScript
3. **数据格式**: CSV（UTF-8 编码）
4. **场景数量**: 最多 7 个基础场景
5. **配置行数**: 120 行（30 种 × 4 级）
6. **基础场景**: weapon_base.tscn 可继承（如果存在）

## 风险与假设

### 风险
- R1: 动态创建 CollisionPolygon2D 可能影响性能
- R2: CSV 解析错误可能导致游戏崩溃
- R3: 旧代码可能存在硬编码的 .tres 引用
- R4: CSV 文件过大（120 行）可能导致加载时间过长
- R5: 动态 Polygon 生成在低端设备上可能存在性能瓶颈
- R6: 30 种武器变体的平衡调优可能耗时超预期

### 假设
- A1: WeaponStats 类已包含所有必要字段
- A2: Global.player 对象可用于治疗效果
- A3: 现有 Projectile 脚本可扩展
- A4: weapon_base.tscn 场景存在且可继承
- A5: Global.player 有 heal() 方法可调用

## 成功指标

1. **功能完整性**: 所有 10 个用户故事的验收标准通过
2. **代码质量**: 无语法错误、无警告、无内存泄漏
3. **性能达标**: FPS > 60，加载时间 < 50ms
4. **文档完善**: 包含使用指南和示例代码
5. **测试覆盖**: 所有关键功能有自动化测试
6. **测试覆盖率**: 核心功能测试覆盖率 > 80%

## 交付物

1. ✅ 需求文档（本文档）
2. ⏳ 设计文档（design.md）
3. ⏳ 任务列表（tasks.md）
4. ⏳ MeleeBehavior.gd
5. ⏳ RangeBehavior.gd
6. ⏳ 7 个基础武器场景
7. ⏳ 扩展的 weapon_config.csv（120 行）
8. ⏳ 更新的 Projectile 脚本
9. ⏳ 测试脚本（test_weapon_system.gd）
10. ⏳ 系统文档（WEAPON_SYSTEM_GUIDE.md）
11. ⏳ 更新的 weapon_config.csv（120 行完整配置）
12. ⏳ Git 分支（feat-weapon-dynamic）
13. ⏳ 更新的 SYSTEM_STATUS.md

## 时间估算

- T1-T2（动态行为）: 6 小时
- T3（场景创建）: 2 小时
- T4（CSV 扩展）: 4 小时
- T5（Projectile 更新）: 2 小时
- T6（迁移清理）: 1 小时
- T7（测试脚本）: 2 小时
- T8（文档集成）: 2 小时
- T9（Bug 修复缓冲）: 4 小时（总缓冲时间）

**总计**: 24-32 小时（含缓冲）

**备注**: T9 为弹性缓冲时间，用于应对 R6（平衡调优）和其他不可预见问题。

## 审批

- **需求提出**: 用户
- **需求审核**: Kiro AI
- **开发负责**: Kiro AI
- **测试负责**: 自动化测试 + 用户验收

---

**文档版本**: 1.2  
**最后更新**: 2026-02-08
