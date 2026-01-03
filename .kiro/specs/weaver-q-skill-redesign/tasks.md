# Implementation Plan: Weaver Q技能重新设计

## Overview

本实现计划将织网者的Q技能从当前的"锚点收网"机制重新设计为"编织-收割"两阶段机制。实现将分为多个增量步骤，每个步骤都可以独立测试和验证。

## Tasks

- [x] 1. 设置状态机和基础变量
  - 添加SkillState枚举（IDLE, PLANNING, WEAVE, RECALL）
  - 添加核心状态变量（skill_state, path_points, web_lines等）
  - 添加配置参数（web_duration, close_threshold等）
  - 初始化web_lifetime_timer
  - _Requirements: 1.1, 10.1_

- [x] 2. 实现阶段一：编织模式 - 子弹时间和路径绘制
  - [x] 2.1 实现charge_skill_q（按住Q进入子弹时间）
    - 从PlayerHerder复用enter_planning_mode逻辑
    - 设置Engine.time_scale = 0.1
    - 更新skill_state为PLANNING
    - _Requirements: 1.1, 2.1_
  
  - [x] 2.2 实现try_add_path_point（左键添加路径点）
    - 检查能量是否足够
    - 消耗skill_q_cost能量
    - 添加鼠标位置到path_points数组
    - 显示"No Energy!"提示（能量不足时）
    - _Requirements: 1.2, 2.2, 8.1, 8.3, 8.4_
  
  - [x] 2.3 实现undo_last_point（右键撤销路径点）
    - 从path_points移除最后一个点
    - 返还skill_q_cost能量
    - 更新UI信号
    - _Requirements: 1.3, 8.2_
  
  - [x] 2.4 实现_update_visuals（绘制预览线和路径线）
    - 从PlayerHerder复用视觉更新逻辑
    - 绘制已确认的路径点连线
    - 绘制预览线段（从最后路径点到鼠标）
    - 根据路径状态设置颜色（白色/红色/灰色）
    - _Requirements: 2.3, 9.1, 9.2, 9.3_
  
  - [x] 2.5 实现_process_subclass中的子弹时间保持
    - 检查is_planning状态
    - 防止Engine.time_scale被顿帧系统重置
    - _Requirements: 1.5_

- [x] 3. 实现路径闭合判定
  - [x] 3.1 实现check_path_closed方法
    - 检查路径点数量（至少3个）
    - 实现距离判定（最后点接近第一点）
    - 实现线段相交判定
    - 构建closed_polygon多边形
    - _Requirements: 4.1, 13.1, 13.2, 13.3, 13.4_
  
  - [ ]* 3.2 编写check_path_closed的属性测试
    - **Property 4: 路径闭合判定**
    - **Validates: Requirements 4.1, 13.1, 13.2, 13.3**

- [x] 4. 实现release_skill_q（松开Q实体化丝线）
  - [x] 4.1 实现基础实体化逻辑
    - 检查路径点数量（至少2个）
    - 退出子弹时间（Engine.time_scale = 1.0）
    - 更新skill_state为WEAVE
    - 创建Line2D节点并添加到web_container
    - 启动web_lifetime_timer（8秒）
    - _Requirements: 1.4, 2.4, 2.5, 2.6_
  
  - [x] 4.2 实现闭合路径的结茧效果
    - 调用check_path_closed判定路径类型
    - 如果闭合，调用apply_cocoon_effect
    - 显示闭合区域视觉反馈（Polygon2D填充）
    - _Requirements: 3.1, 3.2, 3.3, 4.2, 9.4_
  
  - [ ]* 4.3 编写release_skill_q的单元测试
    - 测试路径点不足的情况
    - 测试开放路径的实体化
    - 测试闭合路径的实体化
    - _Requirements: 1.4, 2.4_

- [x] 5. 实现结茧效果（Cocoon）
  - [x] 5.1 实现apply_cocoon_effect方法
    - 使用Geometry2D.is_point_in_polygon检测圈内敌人
    - 设置敌人的can_move = false（定身）
    - 添加敌人到cocooned_enemies数组（易伤标记）
    - 添加敌人到rooted_enemies数组
    - 显示定身和易伤标记视觉效果
    - _Requirements: 4.3, 4.4, 4.5, 4.6, 9.6, 9.7_
  
  - [ ]* 5.2 编写apply_cocoon_effect的单元测试
    - 测试圈内敌人被正确定身
    - 测试圈外敌人不受影响
    - 测试易伤标记正确添加
    - _Requirements: 4.3, 4.4, 4.5_
  
  - [ ]* 5.3 编写结茧效果的属性测试
    - **Property 5: 结茧效果完整性**
    - **Validates: Requirements 4.2, 4.3, 4.4, 4.5, 4.6**

- [ ] 6. Checkpoint - 测试编织阶段
  - 确保所有编织阶段的测试通过
  - 手动测试子弹时间、路径绘制、结茧效果
  - 询问用户是否有问题

- [x] 7. 实现阶段二：收割模式 - 触发逻辑
  - [x] 7.1 修改release_skill_q支持收割触发
    - 检查当前skill_state
    - 如果在WEAVE模式，调用trigger_recall
    - 如果在IDLE模式，执行编织逻辑
    - _Requirements: 5.1, 10.4_
  
  - [x] 7.2 实现_on_web_lifetime_timeout（8秒自动收割）
    - 检查skill_state是否为WEAVE
    - 调用trigger_recall
    - _Requirements: 5.2_
  
  - [x] 7.3 实现trigger_recall方法框架
    - 更新skill_state为RECALL
    - 播放收缩动画（使用Tween）
    - 调用apply_recall_damage
    - 调用cleanup_webs
    - 恢复skill_state为IDLE
    - _Requirements: 5.3, 5.4, 5.5, 5.6, 9.5_

- [x] 8. 实现收割伤害系统
  - [x] 8.1 实现apply_recall_damage方法
    - 从PlayerButcher复用scan_enemies_on_path逻辑
    - 遍历所有丝线路径段
    - 检测路径上的敌人
    - 调用apply_recall_damage_to_enemy
    - _Requirements: 6.1, 6.2, 6.3_
  
  - [x] 8.2 实现apply_recall_damage_to_enemy方法
    - 检查敌人是否在cocooned_enemies中
    - 计算伤害（普通100% vs 破茧250%）
    - 应用伤害到敌人的HealthComponent
    - 显示伤害数字和音效
    - 移除易伤标记
    - _Requirements: 6.4, 6.5, 7.1, 7.2, 7.3, 7.4, 7.5_
  
  - [ ]* 8.3 编写收割伤害的单元测试
    - 测试普通敌人受到100%伤害
    - 测试结茧敌人受到250%伤害
    - 测试易伤标记被正确移除
    - _Requirements: 6.2, 7.1_
  
  - [ ]* 8.4 编写收割伤害的属性测试
    - **Property 6: 收割伤害计算**
    - **Validates: Requirements 6.1, 6.2, 6.3, 7.1**

- [x] 9. 实现资源清理系统
  - [x] 9.1 实现cleanup_webs方法
    - 清除所有web_lines节点
    - 清空path_points数组
    - 清空cocooned_enemies数组
    - 恢复所有rooted_enemies的can_move
    - 清空rooted_enemies数组
    - 停止web_lifetime_timer
    - _Requirements: 5.6, 12.1, 12.3, 12.4, 12.5_
  
  - [x] 9.2 实现_clean_invalid_enemies方法
    - 过滤cocooned_enemies中的无效引用
    - 过滤rooted_enemies中的无效引用
    - _Requirements: 12.3_
  
  - [x] 9.3 在_process_subclass中调用_clean_invalid_enemies
    - 每帧清理无效敌人引用
    - _Requirements: 12.3_
  
  - [ ]* 9.4 编写资源清理的属性测试
    - **Property 9: 资源清理**
    - **Validates: Requirements 12.2, 12.3, 12.4, 12.5**

- [ ] 10. Checkpoint - 测试收割阶段
  - 确保所有收割阶段的测试通过
  - 手动测试收割触发、伤害计算、资源清理
  - 询问用户是否有问题

- [x] 11. 实现技能交互和状态管理
  - [x] 11.1 修改use_skill_e支持子弹时间退出
    - 检查is_planning状态
    - 如果在规划模式，先退出子弹时间
    - 然后执行E技能逻辑
    - _Requirements: 11.2_
  
  - [x] 11.2 修改use_dash防止规划模式冲突
    - 检查is_planning状态
    - 如果在规划模式，忽略冲刺输入
    - _Requirements: 11.3, 11.4_
  
  - [x] 11.3 实现Q技能图标状态切换
    - 根据skill_state更新UI图标
    - IDLE/PLANNING显示"编织"图标
    - WEAVE显示"收割"图标
    - _Requirements: 2.6, 5.5_
  
  - [ ]* 11.4 编写技能交互的集成测试
    - 测试E键优先级
    - 测试规划模式中的左键行为
    - 测试冲刺不受丝线影响
    - _Requirements: 11.1, 11.2, 11.3, 11.4_

- [ ] 12. 实现视觉反馈和动画
  - [ ] 12.1 实现丝线收缩动画
    - 使用Tween动画化Line2D的points
    - 从丝线位置向玩家位置收缩
    - 动画时长0.3-0.5秒
    - _Requirements: 5.4, 9.5_
  
  - [ ] 12.2 实现定身和易伤标记视觉
    - 在敌人身上添加Polygon2D标记
    - 定身标记：黄色圆圈
    - 易伤标记：红色三角形
    - _Requirements: 9.6, 9.7_
  
  - [ ] 12.3 实现闭合区域填充视觉
    - 创建Polygon2D节点
    - 使用半透明红色填充
    - 添加到web_container
    - _Requirements: 4.7, 9.4_
  
  - [ ] 12.4 优化Line2D渲染
    - 设置合适的width（3.0）
    - 启用antialiased
    - 根据状态设置颜色
    - _Requirements: 3.3, 9.2, 9.3_

- [ ] 13. 性能优化和调试
  - [ ] 13.1 实现对象池管理Line2D节点
    - 创建Line2D对象池
    - 复用Line2D节点而不是每次创建
    - _Requirements: 12.4_
  
  - [ ] 13.2 缓存闭合多边形
    - 在check_path_closed中缓存closed_polygon
    - 避免重复计算Geometry2D.is_point_in_polygon
    - _Requirements: 13.5_
  
  - [ ] 13.3 添加调试信息输出
    - 实现_print_debug_info方法
    - 输出状态、路径点数、丝线数、结茧敌人数
    - 仅在调试模式下启用
    - _Requirements: N/A_

- [ ] 14. 完整流程集成测试
  - [ ]* 14.1 编写完整技能流程的集成测试
    - 测试从编织到收割的完整流程
    - 测试开放路径和闭合路径的不同行为
    - 测试8秒自动收割
    - _Requirements: 1.1-1.5, 2.1-2.6, 4.1-4.7, 5.1-5.6_
  
  - [ ]* 14.2 编写状态转换的属性测试
    - **Property 1: 状态转换一致性**
    - **Validates: Requirements 1.1, 10.1, 10.2, 10.3, 10.4, 10.5, 10.6**
  
  - [ ]* 14.3 编写能量守恒的属性测试
    - **Property 3: 能量守恒**
    - **Validates: Requirements 8.1, 8.2, 8.3**
  
  - [ ]* 14.4 编写丝线生命周期的属性测试
    - **Property 7: 丝线生命周期**
    - **Validates: Requirements 2.5, 5.2, 12.1**

- [ ] 15. Final Checkpoint - 完整测试和验证
  - 运行所有单元测试和属性测试
  - 手动测试所有技能流程
  - 验证性能表现
  - 确认所有需求都已实现
  - 询问用户是否满意

- [x] 16. 清理和文档更新
  - [x] 16.1 移除旧的Q技能代码
    - 删除active_anchors相关代码
    - 删除_add_anchor, _apply_anchor_effect等方法
    - 删除web_line_container的旧逻辑
    - _Requirements: N/A_
  
  - [x] 16.2 更新代码注释
    - 为所有新方法添加详细注释
    - 更新类文档说明
    - 添加使用示例
    - _Requirements: N/A_
  
  - [x] 16.3 更新PLAYERS.md文档
    - 更新Weaver的Q技能描述
    - 添加编织-收割机制说明
    - 更新技能组合建议
    - _Requirements: N/A_

## Notes

### 实现顺序说明

1. **任务1-6**: 实现编织阶段（子弹时间、路径绘制、结茧效果）
2. **任务7-10**: 实现收割阶段（触发逻辑、伤害计算、资源清理）
3. **任务11-12**: 完善交互和视觉反馈
4. **任务13-15**: 优化性能和完整测试
5. **任务16**: 清理和文档更新

### 测试策略

- 标记为`*`的任务是可选的测试任务，可以根据开发进度决定是否实现
- 每个Checkpoint任务都是强制的，确保阶段性验证
- 属性测试使用GDScript的assert和随机输入生成
- 集成测试需要创建测试场景和测试敌人

### 参考代码位置

- **PlayerHerder**: `scenes/unit/players/player_herder.gd`
  - charge_skill_q, release_skill_q
  - enter_planning_mode, exit_planning_mode
  - add_path_point, undo_last_point
  - _update_visuals

- **PlayerButcher**: `scenes/unit/players/player_butcher.gd`
  - _scan_enemies_along_path
  - _apply_cutting_damage
  - _update_chains

### 配置参数建议值

```gdscript
var web_duration: float = 8.0          # 丝线存活时间
var close_threshold: float = 60.0      # 闭合判定距离
var path_check_width: float = 30.0     # 路径判定宽度
var normal_recall_damage: int = 50     # 普通收割伤害
var cocoon_recall_damage_mult: float = 2.5  # 破茧伤害倍率
```

### 关键技术点

1. **状态机**: 使用枚举管理四个状态，确保状态转换合法
2. **子弹时间**: 复用Herder的逻辑，防止被顿帧重置
3. **路径判定**: 使用Geometry2D进行闭合判定和点在多边形内判定
4. **动画**: 使用Tween实现丝线收缩动画
5. **性能**: 使用对象池、缓存多边形、及时清理无效引用
