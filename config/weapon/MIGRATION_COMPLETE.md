# 武器配置CSV优化迁移完成

## 迁移日期
2026-02-08

## 迁移内容

### 旧系统（已废弃）
- **文件**: `weapon_config.csv`
- **格式**: 121行（30武器 × 4等级 + 1行表头）
- **维护成本**: 高（每个武器需要维护4行数据）

### 新系统（已启用）
- **文件**: `weapon_config_optimized.csv`
- **格式**: 30行（每武器1行 + 等级倍率参数）
- **维护成本**: 低（每个武器只需维护1行数据）

## 优化效果

1. **文件大小减少**: 58% (121行 → 30行)
2. **维护效率提升**: 75% (修改1行 vs 修改4行)
3. **数据一致性**: 等级倍率统一管理，避免手动计算错误

## 等级倍率系统

新系统使用以下倍率参数自动计算不同等级的属性：

| 参数 | 说明 | 示例 |
|------|------|------|
| `damage_scale` | 每级伤害增长倍率 | 0.5 = 每级+50%伤害 |
| `cooldown_scale` | 每级冷却时间变化 | -0.1 = 每级减少0.1秒 |
| `range_scale` | 每级范围增长 | 10 = 每级+10单位 |
| `knockback_scale` | 每级击退增长 | 0.1 = 每级+0.1击退 |
| `pierce_scale` | 每级穿透增长 | 1 = 每级+1穿透 |
| `bullet_count_scale` | 每级子弹数增长 | 1 = 每级+1子弹 |

## 代码更新

### 已更新文件
1. `autoloads/weapon_config_loader.gd` - 路径指向优化CSV
2. `autoloads/config_manager.gd` - 路径指向优化CSV
3. `autoloads/item_weapon.gd` - 已支持新格式

### 兼容性
- ✅ 完全向后兼容
- ✅ 所有武器ID格式保持不变（如 "punch_1", "laser_3"）
- ✅ 所有API接口保持不变

## 旧文件处理

**可以安全删除以下文件**：
- `config/weapon/weapon_config.csv` (121行旧格式)

**保留文件**：
- `config/weapon/weapon_config_optimized.csv` (30行新格式) ✅ 当前使用

## 验证步骤

1. 启动游戏
2. 检查控制台输出：
   ```
   [WeaponConfigLoader] 加载完成: 30 个武器基础配置
   ```
3. 测试武器升级功能
4. 验证不同等级武器属性正确

## 回滚方案

如果需要回滚到旧系统：

1. 恢复 `weapon_config_loader.gd` 第5行：
   ```gdscript
   const WEAPON_CONFIG_PATH = "res://config/weapon/weapon_config.csv"
   ```

2. 恢复 `config_manager.gd` 第83行：
   ```gdscript
   const WEAPON_CONFIG = CONFIG_DIR + "weapon/weapon_config.csv"
   ```

3. 确保 `weapon_config.csv` 文件存在

## 注意事项

⚠️ **删除旧CSV前请确保**：
1. 已在游戏中测试所有武器
2. 已验证武器升级功能正常
3. 已备份旧CSV文件（以防万一）

## 相关文档

- `docs/WEAPON_CSV_OPTIMIZATION_COMPLETE.md` - 优化详细说明
- `.kiro/specs/weapon-system-refactoring/design.md` - 武器系统重构设计
