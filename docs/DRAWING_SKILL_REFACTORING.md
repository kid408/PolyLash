# 画线技能系统重构文档

## 概述

本文档说明了画线技能（Drawing Skills）的能量消耗系统重构方案。通过创建统一的中间基类 `SkillDrawingBase`，将6个画线技能的重复代码整合到基类中，大幅简化子类实现。

## 问题分析

### 原有问题

1. **代码重复**：6个画线技能（牧羊人、烈焰者、御风者、锯条、蛛网、地雷）的能量消耗逻辑完全相同，但分散在各自的脚本中
2. **维护困难**：修改能量算法需要同时修改6个文件
3. **参数重复**：`energy_per_10px`、`energy_threshold_distance`、`energy_scale_multiplier` 等参数在每个技能中重复定义
4. **逻辑重复**：划线检测、闭合检测、能量返还等逻辑在每个技能中重复实现

### 能量消耗算法

所有画线技能使用相同的动态能量消耗算法：

```gdscript
# 基础阶段（距离 <= 阈值）
energy_cost = energy_per_10px

# 递增阶段（距离 > 阈值）
excess_distance = total_distance - energy_threshold_distance
multiplier = 1.0 + excess_distance * energy_scale_multiplier
energy_cost = energy_per_10px * multiplier
```

**参数说明**：
- `energy_per_10px`: 每10像素消耗的基础能量（通常为1.0）
- `energy_threshold_distance`: 能量递增阈值距离（通常为1800像素）
- `energy_scale_multiplier`: 能量递增系数（0.0005~0.001，不同角色不同）

## 解决方案

### 架构设计

```
SkillBase (基类)
    ↓
SkillDrawingBase (画线技能中间基类) ← 新增
    ↓
    ├── SkillFirePath (烈焰者Q技能)
    ├── SkillWindPath (御风者Q技能)
    ├── SkillHerderLoop (牧羊人Q技能)
    ├── SkillSawPath (锯条Q技能)
    ├── SkillWebWeave (蛛网Q技能)
    └── SkillMinePath (地雷Q技能)
```

### 核心文件

#### 1. `scenes/skills/skill_drawing_base.gd`

**职责**：
- 统一管理能量消耗逻辑（动态递增）
- 统一管理规划模式、划线检测、闭合检测
- 提供虚函数接口供子类实现具体效果

**核心功能**：
```gdscript
# 能量消耗计算
func _calculate_current_energy_cost() -> float
func _calculate_total_consumed_energy() -> float

# 划线逻辑
func _start_drawing() -> void
func _continue_drawing() -> void

# 闭合检测
func _check_intersection_and_closure() -> void
func _perform_final_closure_check() -> void

# 虚函数接口（子类必须实现）
func _spawn_line_effect(start: Vector2, end: Vector2) -> void
func _spawn_area_effect(polygon: PackedVector2Array) -> void
```

**参数管理**：
- 从CSV加载：`energy_per_10px`, `energy_threshold_distance`, `energy_scale_multiplier`
- 子类无需重复定义这些参数

#### 2. 子类实现示例

**烈焰者Q技能** (`skill_fire_path_refactored.gd`)：

```gdscript
extends SkillDrawingBase
class_name SkillFirePathRefactored

# 只需定义火焰特效专属参数
var fire_line_damage: int = 20
var fire_line_duration: float = 5.0
var fire_sea_damage: int = 40

# 实现线段效果
func _spawn_line_effect(start: Vector2, end: Vector2) -> void:
    SkillEffectManager.create_line_effect({
        "start": start,
        "end": end,
        "damage": fire_line_damage,
        "duration": fire_line_duration,
        "color": Color(2.0, 1.2, 0.4, 0.9)
    })

# 实现区域效果
func _spawn_area_effect(polygon: PackedVector2Array) -> void:
    SkillEffectManager.create_area_effect({
        "polygon": polygon,
        "damage": fire_sea_damage,
        "duration": fire_sea_duration,
        "color": Color(1.5, 0.7, 0.2, 0.6)
    })

# 自定义线条颜色
func _get_line_color() -> Color:
    return Color(2.0, 1.0, 0.3, 1.0)  # 金橙色
```

**代码量对比**：
- 原版：~800行（包含重复的能量逻辑）
- 重构版：~100行（只包含特效逻辑）
- **减少85%的代码量**

## 参数配置

### CSV配置 (`config/player/skill_params.csv`)

```csv
skill_id,energy_per_10px,energy_threshold_distance,energy_scale_multiplier,...
skill_fire_path,1,1800,0.0008,...
skill_wind_path,1,1800,0.0006,...
skill_herder_loop,1,1800,0.0005,...
skill_saw_path,1,1800,0.001,...
skill_web_weave,1,1800,0.0006,...
skill_mine_path,1,1800,0.001,...
```

**参数说明**：
- 所有画线技能的 `energy_per_10px` 都是 1.0
- `energy_threshold_distance` 都是 1800 像素
- `energy_scale_multiplier` 根据角色平衡性调整（0.0005~0.001）

## 使用指南

### 创建新的画线技能

1. **继承基类**：
```gdscript
extends SkillDrawingBase
class_name MyNewDrawingSkill
```

2. **定义专属参数**：
```gdscript
var my_line_damage: int = 30
var my_area_damage: int = 60
```

3. **实现虚函数**：
```gdscript
func _spawn_line_effect(start: Vector2, end: Vector2) -> void:
    # 生成线段效果

func _spawn_area_effect(polygon: PackedVector2Array) -> void:
    # 生成区域效果
```

4. **可选：自定义颜色**：
```gdscript
func _get_line_color() -> Color:
    return Color.BLUE  # 自定义规划线颜色

func _get_closure_color() -> Color:
    return Color.RED  # 自定义闭合提示颜色
```

### 修改能量算法

如果需要修改能量消耗算法，只需修改 `SkillDrawingBase` 中的两个函数：

```gdscript
# 修改当前能量消耗计算
func _calculate_current_energy_cost() -> float:
    # 新的算法

# 修改总能量计算（用于返还）
func _calculate_total_consumed_energy() -> float:
    # 新的算法
```

所有6个画线技能会自动使用新算法。

## 兼容性保证

### 不影响非画线技能

- 其他Q技能（如 `skill_dash`、`skill_stun_bomb`）继续使用 `SkillBase` 的固定能量消耗
- 不需要修改任何非画线技能的代码

### 角色切换兼容

- 技能效果由 `SkillEffectManager` 统一管理
- 切换角色时，已生成的效果（火海、风墙等）继续存在
- `cleanup()` 只清理规划线，不清理已生成的效果

### CSV参数兼容

- 所有参数仍从 `skill_params.csv` 加载
- 基类自动读取 `energy_per_10px`、`energy_threshold_distance`、`energy_scale_multiplier`
- 子类读取自己的专属参数（如 `fire_line_damage`）

## 测试清单

### 功能测试

- [ ] 能量消耗：每10像素消耗1点能量
- [ ] 能量递增：超过1800像素后能量消耗递增
- [ ] 能量返还：右键清除路径时正确返还能量
- [ ] 能量不足：能量不足时停止划线并提示
- [ ] 闭合检测：线段交叉时正确检测闭合
- [ ] 距离闭合：终点接近起点时正确检测闭合
- [ ] 视觉反馈：闭合时线条变红色
- [ ] 颜色渐变：超过阈值时线条颜色渐变

### 技能特效测试

- [ ] 火线：未闭合时生成火线伤害
- [ ] 火海：闭合时生成火海区域
- [ ] 风墙：未闭合时生成风墙吸附
- [ ] 暴风区：闭合时生成暴风区域
- [ ] 牧群线段：未闭合时生成线段伤害
- [ ] 几何击杀：闭合时秒杀圈内敌人

### 兼容性测试

- [ ] 角色切换：切换角色时效果继续存在
- [ ] 多区域：8字形等多闭合区域正确检测
- [ ] CSV加载：参数正确从CSV加载
- [ ] 非画线技能：其他技能不受影响

## 迁移步骤

### 逐步迁移方案

1. **创建基类**：
   - 创建 `skill_drawing_base.gd`
   - 测试基类功能

2. **创建重构版本**：
   - 创建 `skill_fire_path_refactored.gd`
   - 创建 `skill_wind_path_refactored.gd`
   - 创建 `skill_herder_loop_refactored.gd`
   - 保留原版文件作为备份

3. **测试重构版本**：
   - 在测试场景中验证功能
   - 对比原版和重构版的行为

4. **替换原版**：
   - 确认重构版本无问题后
   - 删除原版文件
   - 将重构版重命名为原版文件名

5. **迁移其他技能**：
   - 按相同方式迁移锯条、蛛网、地雷技能

### 回滚方案

如果重构版本出现问题：
1. 保留原版文件作为备份
2. 可以随时切换回原版
3. 逐个技能迁移，降低风险

## 性能优化

### 内存优化

- 基类只创建一个 `Line2D` 节点
- 效果节点由 `SkillEffectManager` 统一管理
- 避免重复创建相同的逻辑对象

### 代码优化

- 减少85%的重复代码
- 统一的算法实现，避免不一致
- 更容易维护和调试

## 未来扩展

### 可能的扩展方向

1. **更多画线技能**：
   - 雷电路径（闪电链）
   - 冰霜路径（冰墙+冰封区域）
   - 毒素路径（毒雾+毒池）

2. **能量算法变体**：
   - 线性递增
   - 指数递增
   - 分段递增

3. **闭合检测增强**：
   - 支持更复杂的形状
   - 优化8字形等多区域检测
   - 支持自定义闭合条件

## 总结

### 优势

✅ **代码量减少85%**：从~800行减少到~100行  
✅ **维护成本降低**：修改算法只需改一处  
✅ **参数统一管理**：从CSV加载，避免重复  
✅ **扩展性强**：新增画线技能只需实现2个函数  
✅ **兼容性好**：不影响现有技能和系统  

### 注意事项

⚠️ **测试充分**：确保所有画线技能功能正常  
⚠️ **保留备份**：迁移前保留原版文件  
⚠️ **逐步迁移**：一次迁移一个技能，降低风险  

---

**文档版本**: 1.0  
**创建日期**: 2026-01-25  
**作者**: Kiro AI Assistant
