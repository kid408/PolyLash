# 如何运行武器场景创建工具

## 问题
游戏启动时报错：
```
ERROR: [ItemWeapon] 错误: 武器场景路径不存在: res://scenes/weapons/range/weapon_range_beam.tscn
```

## 原因
武器场景文件还未创建。需要运行 `tools/create_weapon_scenes_tool.gd` 来生成 7 个基础武器场景。

## 解决方案

### 方法 1：在 Godot 编辑器中运行（推荐）

1. **打开 Godot 编辑器**
2. **打开脚本**：
   - 在文件系统面板中找到 `tools/create_weapon_scenes_tool.gd`
   - 双击打开脚本
3. **运行脚本**：
   - 点击菜单 `File → Run`
   - 或按快捷键 `Ctrl+Shift+X` (Windows/Linux) 或 `Cmd+Shift+X` (Mac)
4. **检查输出**：
   - 查看输出面板（Output），应该看到：
     ```
     ========================================
     开始创建武器场景...
     ========================================
     
     --- 创建近战武器场景: weapon_melee_point (拳头类) ---
       ✓ 附加脚本: weapon.gd
       ✓ 添加节点: Sprite2D
       ✓ 附加脚本: hitbox_component.gd
       ✓ 添加节点: HitboxComponent (Area2D)
       ✓ 添加节点: CollisionShape2D (初始禁用)
       ✓ 添加节点: CooldownTimer
       ✓ 附加脚本: melee_behavior.gd
       ✓ 添加节点: WeaponBehavior (MeleeBehavior)
       ✅ 场景已保存: res://scenes/weapons/melee/weapon_melee_point.tscn
     
     ... (更多场景创建信息)
     
     ========================================
     ✅ 场景创建完成！
     ========================================
     ```

5. **验证结果**：
   - 在文件系统面板中检查以下文件是否存在：
     - `scenes/weapons/melee/weapon_melee_point.tscn`
     - `scenes/weapons/melee/weapon_melee_thrust.tscn`
     - `scenes/weapons/melee/weapon_melee_sector.tscn`
     - `scenes/weapons/melee/weapon_melee_circle.tscn`
     - `scenes/weapons/range/weapon_range_physical.tscn`
     - `scenes/weapons/range/weapon_range_beam.tscn` ⭐ 这个是报错的文件
     - `scenes/weapons/range/weapon_range_magic.tscn`

6. **重新运行游戏**：
   - 按 `F5` 或点击 `Play` 按钮
   - 错误应该消失

### 方法 2：手动创建场景（不推荐，仅作备选）

如果方法 1 失败，可以手动创建场景：

1. 在 Godot 编辑器中，右键点击 `scenes/weapons/range/`
2. 选择 `New Scene`
3. 创建节点结构（参考 `tools/create_weapon_scenes_tool.gd` 中的注释）
4. 保存为 `weapon_range_beam.tscn`

但这样需要为每个场景重复操作，非常耗时。

## 创建的场景列表

工具会创建以下 7 个场景：

### 近战武器（4 个）
1. **weapon_melee_point.tscn** - 拳头类（点攻击）
2. **weapon_melee_thrust.tscn** - 长矛类（直线攻击）
3. **weapon_melee_sector.tscn** - 斧头类（扇形攻击）
4. **weapon_melee_circle.tscn** - 弯刀类（圆形攻击）

### 远程武器（3 个）
5. **weapon_range_physical.tscn** - 手枪/霰弹枪类（物理子弹）
6. **weapon_range_beam.tscn** - 激光类（光束） ⭐ 当前缺失
7. **weapon_range_magic.tscn** - 魔法棒类（魔法弹）

## 场景结构

每个场景都有统一的节点结构：

```
Weapon (Node2D, weapon.gd)
├─ Sprite2D (贴图，动态加载)
├─ HitboxComponent (Area2D, hitbox_component.gd)
│  └─ CollisionShape2D (碰撞形状，动态创建)
├─ CooldownTimer (Timer)
└─ WeaponBehavior (MeleeBehavior.gd 或 RangeBehavior.gd)
   └─ Muzzle (Marker2D，仅远程武器)
```

## 常见问题

### Q: 运行脚本后没有输出？
A: 确保在 Godot 编辑器中打开了输出面板（View → Output）

### Q: 提示找不到脚本文件？
A: 检查以下文件是否存在：
- `scenes/weapons/weapon.gd`
- `scenes/components/hitbox_component.gd`
- `scenes/weapons/melee/melee_behavior.gd`
- `scenes/weapons/range/range_behavior.gd`

### Q: 场景创建后游戏还是报错？
A: 
1. 检查 CSV 中的路径是否正确
2. 重启 Godot 编辑器
3. 清理并重新导入项目（Project → Reload Current Project）

## 下一步

创建场景后，继续执行任务列表中的其他任务：
- T6: 清理 .tres 残留
- T7: 创建测试脚本
- T8: 更新文档
- T9: Bug 修复与优化

## 相关文件

- `tools/create_weapon_scenes_tool.gd` - 场景创建工具
- `.kiro/specs/weapon-system-refactoring/tasks.md` - 任务列表
- `config/weapon/weapon_config_optimized.csv` - 武器配置
