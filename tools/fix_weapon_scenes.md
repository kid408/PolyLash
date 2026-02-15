# 修复武器场景问题

## 问题
错误：`Script inherits from native type 'Node2D', so it can't be assigned to an object of type: 'Node'`

## 原因
旧的武器场景文件（`weapon_laser.tscn`, `weapon_pistol.tscn`）中的 `WeaponBehavior` 节点类型是 `Node`，但脚本继承自 `Node2D`。

## 解决方案

### 方法 1：删除旧场景文件（推荐）

在 Godot 编辑器的文件系统面板中：

1. **删除以下旧文件**：
   - `scenes/weapons/range/weapon_laser.tscn`
   - `scenes/weapons/range/weapon_pistol.tscn`
   - `scenes/weapons/melee/weapon_punch.tscn` (如果存在)

2. **右键点击文件 → Delete**

3. **确认删除**

这些旧文件已经被新的基础场景替代：
- `weapon_laser.tscn` → `weapon_range_beam.tscn`
- `weapon_pistol.tscn` → `weapon_range_physical.tscn`
- `weapon_punch.tscn` → `weapon_melee_point.tscn`

### 方法 2：手动修复场景（不推荐）

如果你想保留这些文件：

1. 在 Godot 编辑器中打开 `weapon_laser.tscn`
2. 选择 `WeaponBehavior` 节点
3. 在检查器中，点击节点类型旁边的图标
4. 将类型从 `Node` 改为 `Node2D`
5. 保存场景
6. 对 `weapon_pistol.tscn` 重复相同操作

但这样做没有意义，因为新的基础场景已经包含了所有功能。

## 验证

删除旧文件后：

1. **按 F5 启动游戏**
2. **检查控制台**，应该看到：
   ```
   [WeaponConfigLoader] 加载完成: 30 个武器基础配置
   [WeaponConfigLoader] 创建武器 Stats: punch_1 (punch Lv.1)
   ```
3. **游戏正常运行**，无错误

## 当前场景文件列表

### 应该存在的文件（新系统）

**近战武器**：
- ✅ `scenes/weapons/melee/weapon_melee_point.tscn` (拳头类)
- ✅ `scenes/weapons/melee/weapon_melee_thrust.tscn` (长矛类)
- ✅ `scenes/weapons/melee/weapon_melee_sector.tscn` (斧头类)
- ✅ `scenes/weapons/melee/weapon_melee_circle.tscn` (弯刀类)

**远程武器**：
- ✅ `scenes/weapons/range/weapon_range_physical.tscn` (手枪/霰弹枪类)
- ✅ `scenes/weapons/range/weapon_range_beam.tscn` (激光类)
- ✅ `scenes/weapons/range/weapon_range_magic.tscn` (魔法棒类)

### 应该删除的文件（旧系统）

**近战武器**：
- ❌ `scenes/weapons/melee/weapon_punch.tscn` (已被 weapon_melee_point.tscn 替代)

**远程武器**：
- ❌ `scenes/weapons/range/weapon_laser.tscn` (已被 weapon_range_beam.tscn 替代)
- ❌ `scenes/weapons/range/weapon_pistol.tscn` (已被 weapon_range_physical.tscn 替代)

## 为什么会有这个问题？

1. **旧场景创建时**，`WeaponBehavior` 基类还没有确定继承关系
2. **后来修改**，`WeaponBehavior` 改为继承 `Node2D`
3. **旧场景没有更新**，导致类型不匹配
4. **新工具创建的场景**已经使用正确的 `Node2D` 类型

## 总结

**删除旧场景文件即可解决问题。新系统已经完全替代了旧系统。**
