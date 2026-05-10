# PolyLash 羁绊系统全量落地开发白皮书 (Final Master V6.0)

> **To Codex**: 本文档为 PolyLash 羁绊系统重构与落地的**唯一技术执行标准**。
> 开发分为四大模块：底层基建、CSV填表、羁绊特判、UI重构。请严格按照本文档中的架构指引、枚举类型和真实数据表头进行开发，严禁产生未定义的平行逻辑。

---

## 模块一：底层架构基建升级 (Phase 1: Plumbing)

在编写具体的 `BondManager` 前，必须先在现有的战斗总线中打通以下 4 个强类型拦截与分类钩子，且**必须兼容现有旁路逻辑**。

### 1. 伤害总线改造 (DamageType)
* **枚举定义**：全局新增 `enum DamageType { DIRECT, AOE, DOT, TRUE_DAMAGE }`，以及标志位 `is_shared_damage: bool = false`。
* **改造节点**：
  - `HitboxComponent.setup()` 新增 `damage_type` 参数，默认向下兼容 `DIRECT`。
  - 所有绕过 Hitbox、直接调用 `health_component.take_damage()` 或 `enemy.apply_modifier_damage()` 的旁路接口，必须同步追加 `damage_type` 传参，确保 DOT/真伤 准确归类。

### 2. 状态双轨统计接口 (Status Aggregation)
* **接口定义**：在敌人基类或状态管理器提供统一查询：
  1. `get_abnormal_state_count() -> int` (获取负面异常总数)
  2. `has_mechanic_mark(mark_name: String) -> bool` (检测机制标记)
* **底层规约**：这两个接口必须**同时轮询合并** `Enemy.active_statuses` 和 `CombatModifierComponent`，严格去重，防止漏算。

### 3. 实体生命周期分组 (Entity Grouping)
* **规约**：确立全局 Node Group: `"player_summoned_entity"`。
* **改造节点**：全面排查 `SkillEffectManager` 托管物及各技能脚本自管实体（如墙体、焦油）。在其 `_ready()` 阶段统一执行 `add_to_group("player_summoned_entity")`。

### 4. 物理击退拦截钩子 (Knockback Hook)
* **规约**：基于现有 Area2D 位移底层，放弃 `external_force` 思路。
* **改造节点**：在真实的击退入口（如 `Enemy.apply_knockback(knockback_dir, knockback_power)`）增加拦截信号/接口。允许系统在此处监听并修改当前的击退方向与力度。

---

## 模块二：核心技能数据表全量映射 (Phase 2: CSV Mapping)

利用已有的 `space_skill_config.csv`、`skill_e_config.csv` 和 `ult_config.csv` 的扩展字段，将 8 名角色的技能属性打上精准标签。

*(注：以下仅列出必须填入的 Tag 与 Type 字段，保留原表的数值/特效等其他字段配置)*

### 1. 缚丝 (Silk)
* **Space-未闭合**: `open_logic_tags`: `"DMG_TRUE, MARK_SOUL_LINK, NO_KNOCKBACK"`
* **Space-闭合**: `closed_logic_tags`: `"DMG_TRUE, APPLY_STUN"`
* **E键**: `damage_type`: `"DMG_TRUE"`, `buff_id_list`: `""` (特判全队回血)
* **F键**: `bonus_bond_tag`: `"no_cost"`

### 2. 坍缩者 (Collapsar)
* **Space-未闭合**: `open_logic_tags`: `"DMG_AOE, PULL_WEAK"`, `open_physics_tags`: `"APPLY_SLOW"`
* **Space-闭合**: `closed_logic_tags`: `"DMG_AOE, PULL_STRONG, MARK_SINGULARITY"`
* **E键**: `damage_type`: `"DMG_AOE"`, `effect_type`: `"EXPLODE_ALL_MARKS"`
* **F键**: `base_damage_type`: `"DMG_TRUE"`

### 3. 斩铁 (Zantetsu)
* **Space-未闭合**: `open_logic_tags`: `"DMG_DIRECT, SHAPE_CUT"`
* **Space-闭合**: `closed_logic_tags`: `"DMG_AOE, APPLY_HITSTOP"`
* **E键**: `damage_type`: `"DMG_DIRECT"`, `effect_type`: `"DASH_AND_DETONATE"`
* **F键**: `bonus_bond_tag`: `"ultra_cut"`

### 4. 血役师 (Hemomancer)
* **Space-未闭合**: `open_logic_tags`: `"DMG_DOT"`, `open_physics_tags`: `"APPLY_POISON"`
* **Space-闭合**: `closed_logic_tags`: `"DMG_AOE, APPLY_ROOT, SPAWN_HEAL_ORB"`
* **E键**: `damage_type`: `"DMG_TRUE"`, `effect_type`: `"DETONATE_ALL_DEBUFFS"`
* **F键**: `base_damage_type`: `"DMG_AOE"`, `bonus_bond_tag`: `"dash_poison_cloud"`

### 5. 焦耳 (Joule)
* **Space-未闭合**: `open_logic_tags`: `"DMG_DOT"`, `open_physics_tags`: `"APPLY_TAR"` (挂载 `tar_debuff`与`vulnerable`)
* **Space-闭合**: `closed_logic_tags`: `"DMG_AOE, DETONATE_TAR"`
* **E键**: `damage_type`: `"DMG_AOE"`, `effect_type`: `"IGNITE_ALL_MINES"`
* **F键**: `base_damage_type`: `"DMG_AOE"`, `bonus_bond_tag`: `"missile_mode"`

### 6. 弧光 (Arc)
* **Space-未闭合**: `open_logic_tags`: `"DMG_DIRECT, PLAYER_DASH_PATH"`, `open_physics_tags`: `"APPLY_INVINCIBLE"`
* **Space-闭合**: `closed_logic_tags`: `"DMG_AOE, CENTRIFUGE_PULL"`
* **E键**: `damage_type`: `"DMG_AOE"`, `effect_type`: `"DRIFT_EXPLOSION"`
* **F键**: `bonus_bond_tag`: `"ghost, no_cost"`

### 7. 泛音 (Overtone)
* **Space-未闭合**: `open_logic_tags`: `"DMG_AOE, TRIGGER_ON_DASH"`
* **Space-闭合**: `closed_logic_tags`: `"DMG_AOE, APPLY_STUN, REGEN_ENERGY"`
* **E键**: `damage_type`: `"DMG_AOE"`, `effect_type`: `"CONTRACT_ALL_STRINGS"`
* **F键**: `base_damage_type`: `"DMG_AOE"`, `bonus_bond_tag`: `"auto_fire_strings"`

### 8. 方阵 (Phalanx)
* **Space-未闭合**: `open_logic_tags`: `"DMG_DIRECT, BOUNCE_ENEMY"`
* **Space-闭合**: `closed_logic_tags`: `"DMG_AOE, PINBALL_ARENA"`
* **E键**: `damage_type`: `"DMG_DIRECT"`, `effect_type`: `"BOWLING_PUSH"`
* **F键**: `bonus_bond_tag`: `"infinite_hp"`

---

## 模块三：3x3x3 羁绊判定规约 (Phase 3: Bond Logic)

> **极度重要：基于真实字典的过滤标准**
> * **异常统计 (`get_abnormal_state_count`) 仅限**：`["poison", "vulnerable", "slow", "bleed", "tar_debuff"]`
> * **连携统计 (`has_mechanic_mark`) 仅限**：`["soul_link", "mark"]`

### 1. 【维度 X：身世 Origin】 (底层面板修改)
* **军工**: 监听 `DMG_AOE`。Lv3 特判：任何 `DMG_AOE` 伤害均触发 3 发微型物理弹片溅射。
* **赛博**: Lv3 特判：监听 `HealthComponent` 死亡信号，执行单局一次的满血/满蓝/无敌锁血。
* **异能**: 监听 `DMG_DOT` 给予独立吸血衰减。Lv3 特判：若存在鲜血护盾，将 `DMG_DIRECT` 转为 `DMG_TRUE` 并翻倍。
* **机械**: Lv3 特判：强制修改 `Group: "player_summoned_entity"` 的质量属性，实现不可推挤。

### 2. 【维度 Y：职能 Mastery】 (机制变异)
* **锋芒**: Lv3 特判：`space_skill` 脚本监听 `is_dashing`，允许 Dash 轨迹直接并入画线 Polygon。
* **术理**: 依赖上方定义的“异常统计”回蓝。Lv3 特判：画线首尾距离虽远，但夹角 < 90度且总长达标，强制执行闭合逻辑。
* **御阵**: 延长 `Group: "player_summoned_entity"` 的 lifespan。Lv3 特判：赋予闭合圈 StaticBody2D 物理碰撞。
* **协律**: Lv3 特判：输入层拦截鼠标坐标，以角色为圆心生成对称点，双线程同步调用画线渲染与结算。

### 3. 【维度 Z：战术 Tactic】 (物理规律篡改)
* **击退**: 调用第一模块的拦截钩子放大 `knockback_power`。Lv3 (核裂变弹球) 特判：撞墙瞬间实例化 3 个 `DMG_AOE` 微型弹体。**强制要求：附带 `generation_limit=2`，全局碰撞 ICD=0.05s 防死机。**
* **连携**: Lv3 (全屏伤害共享) 特判：提取全局所有的 Enemy，强制派发伤害。**强制要求：发出的载体 `is_shared_damage = true`，接收方遇此标识立即 Return，防无限递归崩溃。**
* **穿梭**: Lv3 特判：Dash 状态结束不立刻清空轨迹，生成延迟销毁且附带 `DMG_DOT` 的 CollisionPolygon2D。

---

## 模块四：UI 视觉红线与本地化注入 (Phase 4: UI & Text)

### 4.1 数据解耦与文案录入
新建 `player_intro_cn.csv` 供 UI 读取。*(请将下列结构录入)*

| player_id | signature | experience_goal |
| :--- | :--- | :--- |
| `silk` | “不要挣扎，痛苦是会传染的。” | 极致的伤害传导与团队资源循环。不需要直伤，通过走位给怪海“打结”，牵一发而动全身。 |
| `collapsar` | “连光都无法逃逸的深渊，就是我为你画下的坟墓。” | 高风险高回报重狙体验。最高压下完成微雕般极限闭合圈，一击蒸发最高危目标。 |
| `zantetsu` | “花哨的轨迹留给弱者，杀人，一条直线就够了。” | 极致的居合瞬杀快感。将笔直轨迹转化为极速斩击，在怪海中不断穿插一击脱离。 |
| `hemomancer`| “你的每一次绝望挣扎，都在为我的毒沼提供养料。” | 极致的 DOT 折磨流。化身残忍牧羊人铺设毒沼风筝，耐心等待满屏敌人化为血水。 |
| `joule` | “他们管这叫艺术，我管这叫物理超度。” | 极致阵地战与连锁爆破。通过焦油线改变寻路引入雷区，按下按钮观赏最绚丽烟花。 |
| `arc` | “当你看到我画出的光轨时，我已经在那条轨道的尽头了。”| 极速飙车与肉身开团。把画线与冲刺完美结合，在怪海缝隙中规划极限路线刀尖起舞。 |
| `overtone` | “战场是我的指板，光束是我的琴弦。” | 走位与节奏的正反馈。将高压逃生过程，变成一场疯狂拨动琴弦的重金属动作音游。 |
| `phalanx` | “你冲得越猛，你的骨头砸在同伴身上时就越碎。” | 爽感保龄球物理连击。通过不同几何角度的偏导墙，把冲锋的怪海变成互相撞击的炮弹。 |

### 4.2 像素级界面规范 (UI Redline Spec)
* **配色方案**: 纯暗底色 `#0D1117` | 模块半透底板 `#161B22` | 主高亮/选中色 `#00F0FF` | 警告色 `#FF4655` | 文本色 `#E6EDF3` | 分割线 `#30363D`。
* **排版结构**: HBox 划分为 25%(左导航) : 40%(中视觉) : 35%(右文本)。
* **属性雷达图排版（强制）**: 废除旧版纯数字列表。中栏顶部为人物立绘（底部带渐变透明遮罩）。立绘下方**直接重叠/悬浮**一个 `280x280px` 的六边形雷达图（展示生命、速度、能量、回蓝、爆发、控制），利用图层 Z-index 制造全息纵深感。