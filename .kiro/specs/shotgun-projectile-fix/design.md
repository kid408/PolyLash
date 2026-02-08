# 霰弹枪子弹场景文件名修复 - 设计文档

## 设计目标

1. **消除文件名冲突**：删除拼写错误的文件
2. **确保引用正确**：所有引用指向正确的文件名
3. **验证功能正常**：霰弹枪武器正常工作

## 问题分析

### 当前状态

```
项目文件结构：
scenes/projectiles/
├── projectile_shotgun.tscn   ✓ 正确拼写
├── projectile_shootgun.tscn  ✗ 错误拼写（多了 "o"）
├── projectile_pistol.tscn
├── projectile_laser.tscn
└── ...

CSV 配置 (weapon_config_optimized.csv)：
shotgun 行 → projectile_scene = "res://scenes/projectiles/projectile_shotgun.tscn" ✓
```

### 问题根源

1. **历史遗留**：最初创建文件时拼写错误
2. **后续修正**：创建了正确拼写的文件，但没有删除旧文件
3. **引用混乱**：可能有场景文件仍然引用旧文件

### 为什么会出错

```gdscript
// weapon_config_loader.gd 中的逻辑
var projectile_path = "res://scenes/projectiles/projectile_shotgun.tscn"  // 从 CSV 读取

if ResourceLoader.exists(projectile_path):  // 检查文件是否存在
    stats.projectile_scene = load(projectile_path)  // 加载场景
else:
    // 文件不存在，projectile_scene 为 null
```

**可能的原因**：
1. Godot 资源缓存问题
2. 两个文件的 UID 冲突
3. 某些场景文件内部引用了错误的文件名

## 解决方案

### 方案 1：删除错误文件（推荐）

**步骤**：
1. 检查 `projectile_shootgun.tscn` 是否被任何场景引用
2. 如果没有引用，直接删除
3. 清理 Godot 编辑器缓存
4. 重新导入资源

**优点**：
- 彻底解决问题
- 避免未来混淆
- 符合正确的英文拼写

**缺点**：
- 如果有场景引用了旧文件，需要手动修复

### 方案 2：使用错误文件（不推荐）

**步骤**：
1. 修改 CSV 配置，使用 `projectile_shootgun.tscn`
2. 删除 `projectile_shotgun.tscn`

**优点**：
- 快速修复

**缺点**：
- 保留了错误的拼写
- 不符合英文规范
- 未来维护困难

### 最终选择：方案 1

## 实施计划

### 阶段 1：检查引用

**目标**：确认哪些文件引用了 `projectile_shootgun.tscn`

**方法**：
```bash
# 在项目根目录搜索
grep -r "projectile_shootgun" scenes/
grep -r "projectile_shootgun" config/
```

**预期结果**：
- 如果没有引用：可以安全删除
- 如果有引用：需要先修复引用

### 阶段 2：删除错误文件

**操作**：
1. 在 Godot 编辑器中删除 `scenes/projectiles/projectile_shootgun.tscn`
2. 或使用文件系统删除（同时删除 `.uid` 文件）

**文件清单**：
- `scenes/projectiles/projectile_shootgun.tscn`
- `scenes/projectiles/projectile_shootgun.tscn.uid`（如果存在）

### 阶段 3：清理缓存

**操作**：
1. 关闭 Godot 编辑器
2. 删除 `.godot/editor/` 中的相关缓存文件：
   - `projectile_shootgun.tscn-folding-*.cfg`
   - `projectile_shootgun.tscn-editstate-*.cfg`
3. 重新打开项目

### 阶段 4：验证修复

**测试步骤**：

1. **加载测试**
   ```
   - 启动 Godot 编辑器
   - 打开 scenes/projectiles/projectile_shotgun.tscn
   - 确认场景正常加载
   - 检查控制台无错误
   ```

2. **配置测试**
   ```
   - 运行游戏
   - 查看控制台输出：
     [WeaponConfigLoader] DEBUG shotgun projectile:
       - projectile_path: res://scenes/projectiles/projectile_shotgun.tscn
       - is_empty: false
       - ResourceLoader.exists: true
       - projectile_scene loaded: <PackedScene#...>
   ```

3. **游戏测试**
   ```
   - 选择屠夫角色（默认霰弹枪）
   - 进入游戏
   - 攻击敌人
   - 验证：
     ✓ 发射 7 颗子弹
     ✓ 45° 扇形散射
     ✓ 子弹造成伤害
     ✓ 控制台无错误
   ```

4. **回归测试**
   ```
   - 测试其他远程武器：
     ✓ 手枪 (pistol)
     ✓ 激光 (laser)
     ✓ 左轮 (revolver)
     ✓ 冲锋枪 (smg)
   - 确保没有引入新问题
   ```

## 技术细节

### 文件结构

**正确的文件**：
```
scenes/projectiles/projectile_shotgun.tscn
```

**内容**：
```gdscript
[gd_scene load_steps=3 format=3 uid="uid://nvi5ivklpxnn"]

[ext_resource type="PackedScene" uid="uid://cs4y516rwuuxm" 
             path="res://scenes/projectiles/projectile_pistol.tscn" id="1_jyw81"]
[ext_resource type="Texture2D" uid="uid://cmr4xxqrthts7" 
             path="res://assets/sprites/Projectiles/Projectile_1.png" id="2_57jjv"]

[node name="ProjectileShootgun" instance=ExtResource("1_jyw81")]

[node name="Sprite2D" parent="." index="0"]
texture = ExtResource("2_57jjv")
```

**注意**：场景内部节点名仍然是 `ProjectileShootgun`（保持不变，避免破坏引用）

### CSV 配置

**weapon_config_optimized.csv** 中 shotgun 行：
```csv
shotgun,霰弹枪%d级,range,4,10,0.5,1.0,-0.1,0.05,1.5,150,10,100,0.1,0,0,15,0.1,0.2,0.15,1600,
res://scenes/weapons/range/weapon_range_physical.tscn,
res://assets/sprites/Weapons/WeaponShotgun.png,
weapon_shotgun_%d.png,
res://scenes/projectiles/projectile_shotgun.tscn,  ← 正确路径
...
```

### 代码流程（修复后）

```
1. 玩家选择屠夫角色
   ↓
2. player_factory.gd 创建角色
   ↓
3. 读取 player_available_weapons.csv
   → butcher 的武器：shotgun
   ↓
4. weapon_config_loader.gd 加载武器配置
   → get_weapon_stats("shotgun_1")
   ↓
5. 解析 CSV，读取 projectile_scene 列
   → projectile_path = "res://scenes/projectiles/projectile_shotgun.tscn"
   ↓
6. ResourceLoader.exists(projectile_path)
   → 返回 TRUE ✓
   ↓
7. stats.projectile_scene = load(projectile_path)
   → 成功加载 PackedScene ✓
   ↓
8. range_behavior.gd 创建子弹
   → spawn_spread_bullets()
   → 生成 7 颗子弹，45° 散射 ✓
```

## 风险评估

### 风险等级：低

**理由**：
- 简单的文件删除操作
- CSV 已经使用正确的文件名
- 不需要修改代码

### 潜在风险

1. **场景引用丢失**
   - **可能性**：低
   - **影响**：如果有场景引用了旧文件，会出现"missing resource"警告
   - **缓解措施**：先搜索引用，确认无引用后再删除

2. **UID 冲突**
   - **可能性**：极低
   - **影响**：资源加载混乱
   - **缓解措施**：删除后重新导入资源

## 回滚计划

如果修复后出现问题：

1. **恢复旧文件**
   ```
   - 从版本控制恢复 projectile_shootgun.tscn
   - 或从回收站恢复
   ```

2. **修改 CSV**
   ```
   - 将 shotgun 行的 projectile_scene 改回旧文件名
   ```

3. **重新测试**

## 相关文件

### 需要修改的文件
- `scenes/projectiles/projectile_shootgun.tscn` - **删除**
- `.godot/editor/projectile_shootgun.tscn-*.cfg` - **删除**（缓存）

### 需要验证的文件
- `scenes/projectiles/projectile_shotgun.tscn` - 确认存在且正常
- `config/weapon/weapon_config_optimized.csv` - 确认配置正确
- `autoloads/weapon_config_loader.gd` - 无需修改（已有调试日志）

### 测试文件
- `config/player/player_available_weapons.csv` - 查看哪些角色使用霰弹枪

## 成功标准

修复完成后，必须满足：

1. ✅ 项目中只存在 `projectile_shotgun.tscn`
2. ✅ 不存在 `projectile_shootgun.tscn`
3. ✅ 霰弹枪武器正常发射子弹
4. ✅ 控制台无错误信息
5. ✅ 其他武器不受影响
6. ✅ 调试日志显示资源加载成功

---

**设计完成时间**：2026-02-09  
**设计者**：Kiro AI  
**审核状态**：待审核
