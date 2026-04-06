# 焦耳（Joule）角色技能实现规格 (Pixel-Level V2)

## 1. 角色定位与设计灵魂

- **一句话签名**：“只要沾上我的火药，你跑到天涯海角也是个死人。”
- **体验目标**：极致的“标记与处决”连招。玩家在逃跑中用开线大面积“泼洒”炸药，随后用圈引发毁灭性的连锁反应。
- **土豆兄弟法则（极致偏科与代价）**：**极度依赖 Combo**。他的闭合圈（起爆）基础伤害极其刮痧，如果怪身上没有 Debuff，他连杂兵都炸不死；但只要触发了 Debuff 联动，伤害直接呈指数级爆炸。

## 1. 角色基础定义与 V2 字典
- **player_id**: `joule`
- **display_name**: 焦耳
- **origin_tag**: `军工`
- **mastery_tag**: `御阵`
- **tactic_tag**: `连携`
- **基础属性要求**: `max_energy` = 100, `base_speed` = 280

## 2. CSV 数据表配置 (正式表参数注入)
*(注：表名保留已建好的 `space_skill_config.csv` 结构，但其实际输入绑定已全面转移至鼠标右键 RMB)*

1. **`player_runtime_bindings.csv`**:
   - `player_script_path`: `player_joule.gd`
   - `space_skill_id`: `draw_joule` (此处 id 改为 draw_joule 避免歧义)
   - `e_skill_id`: `e_joule`
   - `f_skill_id`: `f_joule`
   - `assist_id`: `assist_joule`
2. **`space_skill_config.csv` (右键画线基础参数)**:
   - `space_skill_id`: `draw_joule`
   - `draw_mode`: `hold_and_trace` (右键按住拖拽)
   - `allow_self_intersection`: **TRUE**
   - `energy_mode`: `per_unit` (每 20px 扣除 0.5 能量)
   - `release_shape_mode`: `dynamic_polygon`
3. **`skill_e_config.csv`**:
   - `cast_mode`: `target_point`, `targeting_mode`: `cursor_world`
   - `energy_cost`: `30`, `cooldown`: `8.0`
4. **`skill_f_config.csv`**:
   - `energy_cost_mode`: `percent`, `energy_cost`: `40` (消耗 40% 当前能量)

---

## 3. 右键技能：双态引爆 (Binary Explosive)

### 3.1 状态 A：开线（不闭合）结算 -> `[化危焦油]` 挂载
- **判定条件**：右键松开时，画线首尾未相交闭合。
- **几何与视觉表现**：生成一条不可见的线型 Area2D，存活 0.2s（即闪即逝），播放贴地喷洒凝胶的 VFX。
- **核心逻辑**：Area2D 碰撞到的所有 `Enemy` 实体，通过 `CombatModifierComponent` 强制注入 `[tar_debuff]` 状态。
- **`[tar_debuff]` 具体参数（必须严格执行）**：
  - `duration` (持续时间): **8.0** 秒。
  - `move_speed_multiplier` (移速系数): **0.7** (即降低 30%)。
  - `skill_damage_taken_multiplier` (技能易伤系数): **1.2** (受到非武器普攻的技能伤害时，最终伤害 * 1.2)。
  - `damage_over_time` (DOT): 每 **0.5** 秒触发一次 tick，每次 tick 造成 **0.15 * PlayerBase_ATK** 的真实伤害。

### 3.2 状态 B：闭合圈结算 -> 处决引爆
- **判定条件**：右键松开时，画线首尾相交（闭合多边形）。
- **几何与视觉表现**：填充闭合多边形区域，闪烁红光，延迟 **0.5s** 后触发 Area2D 伤害判定。
- **核心逻辑 (Target 遍历分类结算)**：
  遍历 Area2D 内的所有 `Enemy`，读取其 `CombatModifierComponent`：
  - **分支 1 (无 `tar_debuff`)**：造成基础刮痧伤害 = **0.5 * PlayerBase_ATK**。
  - **分支 2 (有 `tar_debuff`)**：
    1. 造成巨额连锁爆破伤害 = **4.0 * PlayerBase_ATK**。
    2. 对其施加冲量引力：向外推开 **150px** 的距离（Knockback）。
    3. **立刻调用 `remove_modifier("tar_debuff")`**，清空该怪物身上的焦油状态（消耗型印记）。

---

## 4. E 技能：电磁诱饵 (Magnetic Decoy)

- **施法定位**：获取调用时刻的 `get_global_mouse_position()` 绝对坐标作为中心点 `Target_Pos`。
- **执行逻辑**：
  1. 瞬间检索全局 (Global) 存活的所有 `Enemy` 实体。
  2. 过滤条件：仅筛选出 `CombatModifierComponent` 中包含 `tar_debuff` 的敌人。
  3. **牵引位移 (Pull)**：对过滤出的敌人，强制覆盖其速度向量。将其在 **0.25** 秒内，以匀速直线平移到 `Target_Pos` 的极小随机偏移范围内 (Radius = 20px，防止模型完全重叠导致物理引擎鬼畜)。
  4. 牵引过程中附加硬直（Stun/Interrupt），无任何直接伤害。

---

## 5. F 技能：白磷火雨 (Phosphorus Rain)

- **执行逻辑**：
  1. 没有任何直接爆发伤害。释放时播放全屏降下火雨的 VFX。
  2. 瞬间检索当前场景内所有的 `Enemy` 实体（无视距离和当前状态）。
  3. 强制为其 `CombatModifierComponent` 注入/刷新强化版印记：`[tar_debuff_max]`。
- **`[tar_debuff_max]` 具体参数**：
  - 与普通焦油属性完全一致（减速 0.7，技能易伤 1.2，DOT 0.15A）。
  - **差异点 1**：`duration` 锁定为 **10.0** 秒。
  - **差异点 2 (特权)**：在持续时间内，闭合圈引爆对其造成 `4.0 * PlayerBase_ATK` 伤害时，**禁止调用 `remove_modifier`**。这意味着在这 10 秒内，玩家可以无限画圈连续触发 4.0A 的核爆处决。

---

## 6. 后台 Assist 被动：挥发性毒气 (Volatile Fumes)

- **触发条件**：当前台角色使用右键完成任意一次画线（开线或闭合）并松开时触发。
- **内置冷却 (ICD)**：**5.0** 秒。
- **执行逻辑**：
  1. 获取前台画线轨迹的几何中心点（Centroid）。
  2. 在该点生成一个静止的 `[毒气云]` 实体 (Area2D)，存活时间 **2.0** 秒，碰撞半径 **80px**。
  3. 任何进入 `[毒气云]` 半径的 `Enemy`，强制注入基础版 `[tar_debuff]` 状态（持续 8.0s）。
  4. 无爆发直伤，严守后台不喧宾夺主的原则。