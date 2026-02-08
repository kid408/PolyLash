# 霰弹枪子弹场景文件名修复 - 需求文档

## 问题描述

游戏运行时出现霰弹枪武器错误：
```
ERROR: [Weapon] 错误: 远程武器缺少 projectile_scene - 霰弹枪1级
ERROR: [RangeBehavior] 错误: projectile_scene 为空 - 武器: 霰弹枪1级
```

## 根本原因

**文件名冲突**：项目中同时存在两个文件：
- `scenes/projectiles/projectile_shootgun.tscn` (拼写错误 - 多了 "o")
- `scenes/projectiles/projectile_shotgun.tscn` (正确拼写)

**CSV 配置**使用正确的文件名：`res://scenes/projectiles/projectile_shotgun.tscn`

但是某些场景文件或引用可能仍然指向旧的错误文件名，导致资源加载混乱。

## 用户故事

### 1. 作为玩家
**我想要**：使用霰弹枪武器正常攻击敌人  
**以便**：游戏体验流畅，没有错误提示

**验收标准**：
- 选择装备霰弹枪的角色（屠夫、战士、坦克手）
- 进入游戏后攻击敌人
- 霰弹枪正常发射 7 颗子弹
- 子弹呈 45° 扇形散射
- 控制台无错误信息

### 2. 作为开发者
**我想要**：项目中只有正确命名的文件  
**以便**：避免文件名混乱和引用错误

**验收标准**：
- 项目中只存在 `projectile_shotgun.tscn`（正确拼写）
- 不存在 `projectile_shootgun.tscn`（错误拼写）
- 所有引用都指向正确的文件名
- CSV 配置正确
- 武器加载器能正确加载子弹场景

## 影响范围

### 受影响的角色
- 屠夫 (butcher) - 默认武器：霰弹枪
- 战士 (warrior) - 可选武器：霰弹枪
- 坦克手 (tankman) - 可选武器：霰弹枪

### 受影响的系统
- 武器配置加载系统 (`weapon_config_loader.gd`)
- 远程武器行为系统 (`range_behavior.gd`)
- 子弹生成系统

## 技术约束

1. **Godot 资源系统**：
   - 文件重命名后，Godot 会自动更新 `.uid` 文件
   - 但场景内部的引用需要手动检查

2. **向后兼容性**：
   - 删除旧文件不会影响现有功能
   - 因为 CSV 已经使用正确的文件名

3. **测试要求**：
   - 必须测试所有使用霰弹枪的角色
   - 必须验证其他武器不受影响

## 优先级

**高优先级** - 影响核心游戏功能，导致多个角色无法正常战斗

## 相关文档

- 武器系统重构文档：`docs/WEAPON_SYSTEM_REFACTORING_GUIDE.md`
- 武器配置清理指南：`docs/WEAPON_CONFIG_CLEANUP_GUIDE.md`
- 之前的分析：`霰弹枪问题分析.md`
- 调试日志：`霰弹枪调试日志.md`

---

**创建时间**：2026-02-09  
**状态**：待修复  
**预计工作量**：30 分钟
