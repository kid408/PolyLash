# Requirements Document - Weaver Q技能重新设计

## Introduction

重新设计织网者（PlayerWeaver）的Q技能，使其玩法流程与牧羊人（PlayerHerder）一致，但功能参考屠夫（PlayerButcher）的冲撞和收网机制。新设计分为两个阶段：编织（Weave）和收割（Recall）。

## Glossary

- **Weaver**: 织网者角色类
- **Q_Skill**: Q键技能系统
- **Bullet_Time**: 子弹时间（时间减慢效果）
- **Web_Line**: 丝线（玩家绘制的路径）
- **Open_Path**: 开放路径（未闭合的线条）
- **Closed_Path**: 闭合路径（形成封闭区域的线条）
- **Cocoon**: 结茧效果（闭合路径触发的特殊效果）
- **Root**: 定身效果（敌人无法移动）
- **Vulnerable_Mark**: 易伤标记（增加受到的伤害）
- **Recall**: 收割（收回丝线并造成伤害）
- **Herder**: 牧羊人角色（参考其Q技能流程）
- **Butcher**: 屠夫角色（参考其冲撞和收网功能）

## Requirements

### Requirement 1: Q技能流程框架

**User Story:** 作为玩家，我希望织网者的Q技能流程与牧羊人一致，这样我可以用熟悉的操作方式使用不同角色。

#### Acceptance Criteria

1. WHEN 玩家按住Q键 THEN 系统SHALL进入子弹时间（Engine.time_scale = 0.1）
2. WHEN 玩家在子弹时间中点击左键 THEN 系统SHALL消耗能量并添加路径点
3. WHEN 玩家在子弹时间中点击右键 THEN 系统SHALL撤销最后一个路径点并返还能量
4. WHEN 玩家松开Q键 THEN 系统SHALL退出子弹时间并实体化丝线
5. WHEN 子弹时间激活时 THEN 系统SHALL防止被顿帧系统重置（保持time_scale = 0.1）

---

### Requirement 2: 阶段一 - 编织（Weave）

**User Story:** 作为玩家，我希望通过鼠标绘制丝线路径，这样我可以创造战术区域。

#### Acceptance Criteria

1. WHEN 玩家按住Q键 THEN 系统SHALL显示从玩家位置到鼠标位置的预览线段
2. WHEN 玩家点击左键添加路径点 THEN 系统SHALL在该位置创建一个固定的路径点
3. WHEN 路径点被创建 THEN 系统SHALL在路径点之间绘制连线
4. WHEN 玩家松开Q键 THEN 丝线SHALL实体化并滞留在场景中
5. WHEN 丝线实体化后 THEN 丝线SHALL持续存在8秒
6. WHEN 丝线实体化后 THEN Q技能图标SHALL变为"收回"状态

---

### Requirement 3: 路径判定 - 开放路径

**User Story:** 作为玩家，当我绘制的路径未闭合时，我希望看到一条发光的丝线，这样我可以知道路径状态。

#### Acceptance Criteria

1. WHEN 路径未形成闭合区域 THEN 系统SHALL判定为开放路径
2. WHEN 路径为开放路径 THEN 系统SHALL在地上留下发光的丝线
3. WHEN 丝线存在时 THEN 丝线SHALL具有视觉效果（发光、颜色）
4. WHEN 丝线存在时 THEN 丝线SHALL不对敌人产生任何效果（仅视觉）

---

### Requirement 4: 路径判定 - 闭合路径（结茧效果）

**User Story:** 作为玩家，当我绘制的路径形成闭合区域时，我希望触发结茧效果，这样我可以控制和增强对敌人的伤害。

#### Acceptance Criteria

1. WHEN 路径形成闭合区域 THEN 系统SHALL判定为闭合路径
2. WHEN 路径为闭合路径 THEN 系统SHALL触发"结茧（Cocoon）"效果
3. WHEN 结茧效果触发 THEN 圈内的所有敌人SHALL立即被定身（Root）
4. WHEN 敌人被定身 THEN 敌人的can_move属性SHALL设置为false
5. WHEN 结茧效果触发 THEN 圈内的所有敌人SHALL挂上[易伤]标记
6. WHEN 敌人有易伤标记 THEN 该敌人受到的收割伤害SHALL提升至250%
7. WHEN 结茧效果触发 THEN 系统SHALL显示视觉反馈（闭合区域高亮）

---

### Requirement 5: 阶段二 - 收割（Recall）

**User Story:** 作为玩家，我希望通过再次按Q键收回丝线并造成伤害，这样我可以清理敌人。

#### Acceptance Criteria

1. WHEN 玩家再次短按Q键 THEN 系统SHALL触发收割效果
2. WHEN 丝线存在8秒后 THEN 系统SHALL自动触发收割效果
3. WHEN 收割触发 THEN 所有滞留的丝线SHALL瞬间向玩家当前位置弹回/收缩
4. WHEN 丝线收缩时 THEN 系统SHALL播放视觉动画（线条收缩）
5. WHEN 收割完成 THEN Q技能图标SHALL恢复为"编织"状态
6. WHEN 收割完成 THEN 所有丝线SHALL被清除

---

### Requirement 6: 收割伤害 - 普通收割

**User Story:** 作为玩家，我希望收割时对路径上的敌人造成伤害，这样我可以清理杂兵。

#### Acceptance Criteria

1. WHEN 收割触发 THEN 系统SHALL检测丝线路径上的所有敌人
2. WHEN 敌人在丝线路径上 THEN 系统SHALL对该敌人造成100%物理伤害
3. WHEN 敌人距离丝线路径小于判定宽度 THEN 该敌人SHALL被视为在路径上
4. WHEN 敌人受到普通收割伤害 THEN 系统SHALL显示伤害数字
5. WHEN 敌人受到普通收割伤害 THEN 系统SHALL播放打击音效

---

### Requirement 7: 收割伤害 - 破茧一击

**User Story:** 作为玩家，我希望对被结茧的敌人造成更高伤害，这样我可以快速击杀精英敌人。

#### Acceptance Criteria

1. WHEN 收割触发且敌人有易伤标记 THEN 系统SHALL对该敌人造成250%暴击伤害
2. WHEN 敌人受到破茧一击 THEN 系统SHALL显示特殊伤害数字（不同颜色）
3. WHEN 敌人受到破茧一击 THEN 系统SHALL播放特殊音效
4. WHEN 敌人受到破茧一击 THEN 系统SHALL播放特殊视觉效果
5. WHEN 破茧一击造成伤害后 THEN 易伤标记SHALL被移除

---

### Requirement 8: 能量消耗

**User Story:** 作为玩家，我希望Q技能有合理的能量消耗，这样我需要管理资源。

#### Acceptance Criteria

1. WHEN 玩家添加路径点 THEN 系统SHALL消耗skill_q_cost能量
2. WHEN 玩家撤销路径点 THEN 系统SHALL返还skill_q_cost能量
3. WHEN 玩家能量不足 THEN 系统SHALL阻止添加路径点
4. WHEN 玩家能量不足 THEN 系统SHALL显示"No Energy!"提示
5. WHEN 收割触发 THEN 系统SHALL不消耗额外能量

---

### Requirement 9: 视觉反馈

**User Story:** 作为玩家，我希望看到清晰的视觉反馈，这样我可以理解技能状态。

#### Acceptance Criteria

1. WHEN 玩家按住Q键 THEN 系统SHALL显示预览线段（从最后路径点到鼠标）
2. WHEN 路径为开放路径 THEN 丝线SHALL显示为白色
3. WHEN 路径为闭合路径 THEN 丝线SHALL显示为红色
4. WHEN 结茧效果触发 THEN 闭合区域SHALL显示半透明填充
5. WHEN 收割触发 THEN 丝线SHALL播放收缩动画
6. WHEN 敌人被定身 THEN 敌人SHALL显示定身标记
7. WHEN 敌人有易伤标记 THEN 敌人SHALL显示易伤标记（不同颜色）

---

### Requirement 10: 技能状态管理

**User Story:** 作为玩家，我希望技能状态清晰，这样我可以知道何时可以使用技能。

#### Acceptance Criteria

1. WHEN 丝线不存在 THEN Q技能SHALL处于"编织"模式
2. WHEN 丝线存在 THEN Q技能SHALL处于"收割"模式
3. WHEN 处于编织模式 THEN 按住Q键SHALL进入子弹时间
4. WHEN 处于收割模式 THEN 短按Q键SHALL触发收割
5. WHEN 处于收割模式 THEN 按住Q键SHALL不进入子弹时间
6. WHEN 收割完成 THEN 技能SHALL自动切换回编织模式

---

### Requirement 11: 与其他技能的交互

**User Story:** 作为玩家，我希望Q技能不干扰其他技能，这样我可以流畅地使用所有技能。

#### Acceptance Criteria

1. WHEN 玩家按E键 THEN E技能SHALL正常触发（不受Q技能影响）
2. WHEN 玩家在子弹时间中按E键 THEN E技能SHALL优先触发并退出子弹时间
3. WHEN 玩家在子弹时间中点击左键 THEN 左键SHALL只用于添加路径点（不触发冲刺）
4. WHEN 玩家未按Q键时点击左键 THEN 左键SHALL触发普通冲刺
5. WHEN 玩家冲刺时 THEN 冲刺SHALL不受丝线影响

---

### Requirement 12: 性能和清理

**User Story:** 作为开发者，我希望技能不造成性能问题，这样游戏可以流畅运行。

#### Acceptance Criteria

1. WHEN 丝线存在8秒后 THEN 丝线SHALL自动清除
2. WHEN 角色切换时 THEN 所有丝线SHALL被清除
3. WHEN 敌人死亡时 THEN 该敌人的标记SHALL被清除
4. WHEN 丝线清除时 THEN 相关的视觉节点SHALL被释放
5. WHEN 定身效果结束时 THEN 敌人的can_move SHALL恢复为true

---

### Requirement 13: 闭合路径判定算法

**User Story:** 作为开发者，我需要准确判定路径是否闭合，这样结茧效果可以正确触发。

#### Acceptance Criteria

1. WHEN 最后一个路径点接近第一个路径点 THEN 系统SHALL判定为闭合路径
2. WHEN 路径点之间的距离小于close_threshold THEN 系统SHALL判定为接近
3. WHEN 路径线段相交 THEN 系统SHALL判定为闭合路径
4. WHEN 路径形成多边形 THEN 系统SHALL使用Geometry2D.is_point_in_polygon判定敌人位置
5. WHEN 路径判定完成 THEN 系统SHALL缓存多边形点集（避免重复计算）

---

### Requirement 14: 参考实现

**User Story:** 作为开发者，我需要参考现有代码，这样可以保持代码风格一致。

#### Acceptance Criteria

1. WHEN 实现Q技能流程 THEN 代码SHALL参考PlayerHerder的charge_skill_q和release_skill_q
2. WHEN 实现子弹时间 THEN 代码SHALL参考PlayerHerder的enter_planning_mode和exit_planning_mode
3. WHEN 实现路径点添加 THEN 代码SHALL参考PlayerHerder的add_path_point
4. WHEN 实现路径撤销 THEN 代码SHALL参考PlayerHerder的undo_last_point
5. WHEN 实现冲撞扫描 THEN 代码SHALL参考PlayerButcher的_scan_enemies_along_path
6. WHEN 实现收网伤害 THEN 代码SHALL参考PlayerButcher的_apply_cutting_damage
7. WHEN 实现辅助线绘制 THEN 代码SHALL参考PlayerButcher的_update_chains

---

## Notes

### 关键设计要点

1. **流程一致性**: Q技能的按住/松开/左键/右键逻辑必须与PlayerHerder完全一致
2. **功能差异性**: 虽然流程一致，但效果不同：
   - Herder: 冲刺移动 + 闭环击杀
   - Weaver: 静态绘制 + 定身 + 收割
3. **两阶段设计**: 编织和收割是两个独立阶段，不能同时进行
4. **易伤机制**: 只有闭合路径中的敌人才有易伤标记，这是核心战术要素
5. **自动触发**: 8秒后自动收割，防止玩家忘记收割

### 技术实现要点

1. 使用状态变量区分"编织模式"和"收割模式"
2. 复用Herder的子弹时间逻辑（防止被顿帧重置）
3. 复用Butcher的路径扫描逻辑（检测路径上的敌人）
4. 使用Geometry2D进行闭合路径判定
5. 使用Tween实现丝线收缩动画
6. 使用Timer实现8秒自动收割

### 平衡性考虑

1. 能量消耗应与Herder相当（每段路径消耗skill_q_cost）
2. 普通收割伤害应适中（100%物理伤害）
3. 破茧一击伤害应显著（250%暴击伤害）
4. 定身时间应合理（与丝线存在时间一致，最多8秒）
5. 闭合路径判定应宽松（close_threshold = 60.0）
