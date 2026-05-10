# PolyLash 羁绊系统具体逻辑实装白皮书 (Phase 3/4/5)

> **To Codex**: 本文档为 3x3x3 羁绊矩阵的具体代码实装标准。
> **前提条件**：假设 Phase 1 的底层钩子（DamageType, 状态双轨统计, 击退拦截等）与 Phase 2 的 CSV 打标签已全部完工。
> **架构要求**：请在 `BondManager` 中实现统一的信号监听分发，或采用注入式 Modifier，严禁在角色/敌人基础脚本中硬编码羁绊特判。

---

## 模块一：【身世 Origin】逻辑实装规范 (生存与底盘)

### 1. 军工 (Military)
* **Lv1 (扩容弹夹)**：
  * **拦截点**：`HitboxComponent` 或 AOE 生成节点。
  * **逻辑**：检测到伤害类型为 `DMG_AOE` 时，将其 `CollisionShape2D` 的 `scale` 或 `radius` 乘以 `1.25`。
* **Lv2 (穿甲破片)**：
  * **拦截点**：敌人受击结算后。
  * **逻辑**：若受到的伤害类型为 `DMG_AOE`，向该敌人挂载 `vulnerable` 状态，持续 4.0s。
* **Lv3 (饱和打击 - 特判)**：
  * **拦截点**：敌人受到 `DMG_AOE` 伤害时。
  * **逻辑**：在受击坐标处，瞬间实例化 3 个微型物理投射物向随机方向发射。投射物属性为 `DMG_DIRECT`，基础伤害 = `1.0 * Player_ATK`。

### 2. 赛博 (Cyber)
* **Lv1 (义体过载)**：
  * **逻辑**：直接修改 `PlayerStats`，`max_energy += 40`, `current_energy += 20` (入场时触发)。
* **Lv2 (动能回收)**：
  * **拦截点**：监听全局 `on_enemy_death` 信号。
  * **逻辑**：判断死亡敌人的 `is_elite` 或 `is_boss` 为 `true`，且击杀来源为技能，立刻调用前台角色的 `reset_skill_cooldown("dash")` 和 `reset_skill_cooldown("skill_e")`。
* **Lv3 (量子备份 - 特判)**：
  * **拦截点**：`HealthComponent.take_damage()` 中血量扣至 $\le 0$ 时。
  * **逻辑**：阻断死亡流程。恢复 `max_health` 与 `max_energy`，向玩家挂载 `invincible` 状态，持续 3.0s。设置全局标志位 `cyber_lv3_used = true`（每局限 1 次）。

### 3. 异能 (Esper)
* **Lv1 (细胞重组)**：
  * **拦截点**：玩家造成伤害结算后。
  * **逻辑**：调用 `Player.heal(damage_amount * 0.15)`。**注意**：若伤害为 `DMG_DOT`，吸血系数强制衰减至 `0.05`。
* **Lv2 (鲜血护盾)**：
  * **拦截点**：监听 `Player.heal()` 返回的 `overflow_amount`。
  * **逻辑**：调用 `ShieldComponent.add_shield(overflow_amount)`，护盾上限 Clamp 为 `max_health * 0.5`。
* **Lv3 (沸血献祭 - 特判)**：
  * **拦截点 A**：玩家造成伤害前，检测 `ShieldComponent.current_shield > 0`。若成立，将该次伤害类型强转为 `DMG_TRUE` 并 `damage *= 2.0`。
  * **拦截点 B**：重写能量消耗逻辑，画线时优先扣除 `ShieldComponent` 的数值，护盾不足时再扣除真实 Energy。

### 4. 机械 (Mech)
* **Lv1 (反应装甲)**：
  * **拦截点**：全局基础属性加成 `armor += 20`。监听玩家受击信号。
  * **逻辑**：每次受击添加 1 层临时 Armor Modifier (+2 护甲，持续 5.0s)，最高限制 10 层。
* **Lv2 (刺猬引擎)**：
  * **拦截点**：`_process` 中开设定时器，检测临时 Armor 层数 $\ge 10$。
  * **逻辑**：触发 1.0s 循环定时器，实例化环形伤害区 (`DMG_AOE`, 伤害 = `total_armor * 1.5`)。
* **Lv3 (移动要塞 - 特判)**：
  * **逻辑 A**：赋予全队常驻的 `super_armor` 与 `immune_knockback` 标签。
  * **逻辑 B**：检索 `Group: "player_summoned_entity"`，将其内部的 `CollisionShape` 物理质量/掩码修改为最高优先级，禁止被 `CharacterBody2D` 推动；且附带耐久度属性的实体（如方阵的墙），`max_hp *= 2`。

---

## 模块二：【职能 Mastery】逻辑实装规范 (机制变异)

### 1. 锋芒 (Vanguard)
* **Lv1 (残心)**：
  * **拦截点**：`space_skill` 结算 (Release) 瞬间。
  * **逻辑**：挂载移速 `+30%` Buff 与 `super_armor` Buff，持续 2.0s。
* **Lv2 (燕返)**：
  * **拦截点**：Dash 动作状态结束帧。
  * **逻辑**：获取鼠标向量，实例化剑气投射物 (`DMG_DIRECT`, 1.5倍 ATK, 射程 250px)。
* **Lv3 (无极光轨 - 特判)**：
  * **拦截点**：`space_skill` 画线采样循环。
  * **逻辑**：取消画线时对 Dash 的锁定位。若 `is_dashing == true`，将玩家位移路径强制转换并 `append` 到 `Line2D` 和逻辑采样数组中。

### 2. 术理 (Anomaly)
* **Lv1 (侵蚀)**：
  * **拦截点**：系统向敌人添加 Modifier 时。
  * **逻辑**：若该 Modifier 的 ID 存在于异常字典 `["poison", "vulnerable", "slow", "bleed", "tar_debuff"]` 中，将其 `duration *= 1.5`。
* **Lv2 (反应釜)**：
  * **拦截点**：敌人受击结算时。
  * **逻辑**：调用 `get_abnormal_state_count()`，若返回 $\ge 1$，触发全队回蓝 +2 点（添加全局 0.2s ICD 防溢出）。
* **Lv3 (薛定谔的弦 - 特判)**：
  * **拦截点**：`space_skill` 释放瞬间的开闭合判定逻辑。
  * **逻辑**：提取 `Point[0]` (起点), `Point[mid]` (中点), `Point[n]` (终点)。若计算夹角 $\le 90^\circ$ 且曲线总长 $L \ge 150px$，跳过距离差判定，强制标记为 `is_closed = true`，并在首尾两点间注入连线数据。

### 3. 御阵 (Sentinel)
* **Lv1 (坚壁)**：
  * **拦截点**：检索 `Group: "player_summoned_entity"`。
  * **逻辑**：将其内部托管生命周期的 Timer 或变量 `lifespan *= 1.5`。
* **Lv2 (几何折射)**：
  * **拦截点**：`space_skill` 允许自我相交时，获取交点坐标 (Intersection Point)。
  * **逻辑**：在交点处实例化 `prism_stun` 实体（持续 2.0s，敌人触碰触发 `APPLY_STUN` 1.0s）。
* **Lv3 (绝对领域 - 特判)**：
  * **拦截点**：闭合圈结算生成遮罩时。
  * **逻辑**：沿闭合多边形的轮廓（Outline），实例化带有 `StaticBody2D` 的碰撞体，物理层设置为阻挡所有敌人（Mask/Layer）。

### 4. 协律 (Harmony)
* **Lv1 (同频)**：
  * **拦截点**：监听 `E` 键与 `F` 键的释放信号。
  * **逻辑**：遍历后台非激活态角色，`energy += 20`。
* **Lv2 (回声)**：
  * **拦截点**：监听 `Tab` 切人信号。
  * **逻辑**：读取上一个角色最后一次成功结算的 `space_skill` 数据缓存。在切人坐标处生成静态残影，并无消耗重播该画线判定。
* **Lv3 (万物互联 - 特判)**：
  * **拦截点**：鼠标输入坐标采集阶段。
  * **逻辑**：获取当前 `mouse_pos`，以 `player_pos` 为原点计算中心对称坐标。在视觉渲染与数据结构中，同步双开两条轨迹（Mirrored Line），并触发两次独立的碰撞结算。

---

## 模块三：【战术 Tactic】逻辑实装规范 (底层篡改警告)

> **极度高危提醒**：本模块涉及 Godot 物理引擎层与递归传导的直接干预。必须严格遵守文档中的防宕机死锁规约。

### 1. 击退 (Knockback)
* **Lv1 (弹性系数)**：
  * **拦截点**：Phase 1 预留的 `apply_knockback` 拦截钩子。
  * **逻辑**：将传入的 `knockback_power *= 1.4`。
* **Lv2 (动能激波)**：
  * **拦截点**：敌人处于击退飞行状态时，监听其与 StaticBody (墙壁) 的碰撞信号。
  * **逻辑**：触发爆炸特效并实例化单次 `DMG_AOE`（伤害 = 2.0 * ATK）。
* **Lv3 (核裂变弹球 - 高危特判)**：
  * **拦截点**：上述碰撞发生瞬间。
  * **防卡死规约**：
    1. 弹体必须携带 `generation = 0` 属性。
    2. 当 `generation < 2` 时，实例化 3 个向不同角度击退的新弹体，且新弹体 `generation = current_generation + 1`。
    3. 加入全局 ICD `0.05s`，即同一帧内最多只处理一次分裂。

### 2. 连携 (Link)
* **Lv1 (导电体质)**：
  * **拦截点**：敌人受击阶段。
  * **逻辑**：若 `damage_type == DMG_AOE`，调用 `get_abnormal_state_count() > 0` 或 `has_mechanic_mark("soul_link")`，若成立则 `damage *= 1.2`。
* **Lv2 (瘟疫蔓延)**：
  * **拦截点**：带有指定 Mark 的敌人死亡信号。
  * **逻辑**：检索以自身为圆心 300px 内的存活 Enemy，取最近的 2 个调用 `add_modifier("soul_link")`。
* **Lv3 (命运交织 - 高危特判)**：
  * **逻辑实现**：覆写场上所有的伤害传递逻辑。只要有 1 只怪受到伤害，立即获取全局所有 Enemy。
  * **防死锁规约**：发出的分摊伤害必须携带 `is_shared_damage = true` 属性。受击接口如果检测到 `is_shared_damage == true`，绝对禁止再次触发传染事件（Return）。

### 3. 穿梭 (Shuttle)
* **Lv1 (低摩擦力)**：
  * **拦截点**：Dash 状态。
  * **逻辑**：`dash_distance *= 1.3`，暂时关闭与 Enemy 的物理碰撞掩码（无视体积阻挡）。
* **Lv2 (动能留存)**：
  * **拦截点**：Dash 结束状态。
  * **逻辑**：原地实例化一个视觉残影实体，开启 1.0s Timer。Timer 结束后释放 `DMG_AOE` 并 `queue_free()`。
* **Lv3 (创战纪光轮 - 特判)**：
  * **拦截点**：Dash 过程中的每一帧。
  * **逻辑**：记录路径坐标，实例化带有红色发光材质的持续性 `CollisionPolygon2D`（激光墙）。任何触碰该墙体的 Enemy 每 0.2s 受到一次高频 `DMG_DIRECT` 切割伤害（不可摧毁，直至战斗波次结束）。