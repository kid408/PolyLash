# 需求文档：批量角色技能系统

## 简介

为 PolyLash Roguelike 游戏批量创建新角色技能（分 A-E 五组），每套包含 Q-line（画线）、Q-circle（画圈闭合）、E-key（瞬发）三个技能。同时重构 skill_params.csv 为长表格式，扩展 SkillEffectManager 支持新效果类型，扩展敌人状态系统支持新状态。删除 20 个旧角色，根据技能主题创建 20 个全新角色并绑定对应技能，剩余技能存入技能库供未来使用。

## 术语表

- **SkillDrawingBase**: Q 键画线技能基类，管理规划模式、划线检测、闭合检测、能量消耗
- **SkillBase**: 所有技能的抽象基类，管理冷却、能量消耗、执行状态
- **SkillEffectManager**: 自动加载的技能效果生命周期管理器，独立于角色切换
- **SkillManager**: 角色技能管理器，管理 Q/E/LMB/RMB 四个技能槽位
- **StatusComponent**: 状态组件，管理单位的 Buff/Debuff 效果
- **ConfigManager**: 配置管理器，从 CSV 加载并缓存所有配置数据
- **skill_params.csv**: 技能参数配置文件（当前为宽表，57 列）
- **player_skill_bindings.csv**: 角色技能绑定配置文件
- **StaticBody2D**: Godot 物理节点，用于创建不可移动的碰撞体（墙壁、障碍物）
- **长表格式**: 数据库范式化的 CSV 格式，每行一个参数（skill_id, param_name, param_value）
- **宽表格式**: 当前 CSV 格式，每行一个技能，所有参数为列
- **原始六角色**: butcher、pyro、sapper、herder、weaver、wind，其技能不可修改，不可删除
- **旧角色**: 除原始六角色外的 20 个角色（technology_hurricane、tankman 等），将被删除
- **新角色**: 根据技能主题全新创建的 20 个角色（glacier、tesla 等），替代旧角色
- **队友**: 当前小队中的所有角色成员，切换角色后仍可受益于其他角色的技能效果区域

## 需求

### 需求 1：重构 skill_params.csv 为长表格式

**用户故事：** 作为配置维护人员，我希望将 skill_params.csv 从 57 列宽表重构为长表格式（skill_id, param_name, param_value），以便轻松添加新技能参数而无需修改表结构。

#### 验收标准

1. THE ConfigManager SHALL 支持读取长表格式的 skill_params.csv（skill_id, param_name, param_value, description 四列）
2. WHEN ConfigManager 加载长表格式的 skill_params.csv 时，THE ConfigManager SHALL 将数据转换为与现有 get_skill_params(skill_id) 接口兼容的字典格式
3. WHEN 现有六角色（butcher、pyro、sapper、herder、weaver、wind）的技能参数被迁移到长表格式后，THE ConfigManager SHALL 返回与宽表格式完全相同的参数值
4. THE ConfigManager SHALL 自动将字符串类型的数值参数转换为 float 或 int 类型
5. IF skill_params.csv 中存在重复的 skill_id + param_name 组合，THEN THE ConfigManager SHALL 使用最后出现的值并输出警告日志

### 需求 2：扩展 SkillEffectManager 支持新效果类型

**用户故事：** 作为游戏架构师，我希望 SkillEffectManager 支持 StaticBody2D 墙体、Buff/Debuff 区域和召唤物管理，以便新技能能够创建物理阻挡墙、增益区域和可管理的召唤单位。

#### 验收标准

1. WHEN create_wall_effect 被调用时，THE SkillEffectManager SHALL 创建一个 StaticBody2D 节点，其碰撞形状沿指定线段生成，阻挡敌人和/或子弹移动
2. WHEN 墙体效果的持续时间到期时，THE SkillEffectManager SHALL 播放淡出动画并移除该 StaticBody2D 节点
3. WHEN create_buff_zone 被调用时，THE SkillEffectManager SHALL 创建一个 Area2D 区域，对进入区域的队友应用指定的 Buff 效果
4. WHEN create_debuff_zone 被调用时，THE SkillEffectManager SHALL 创建一个 Area2D 区域，对进入区域的敌人应用指定的 Debuff 效果
5. WHEN create_summon 被调用时，THE SkillEffectManager SHALL 创建一个可管理的召唤单位，具有独立的生命周期和行为逻辑
6. WHEN 同一技能的召唤物数量超过配置的最大值时，THE SkillEffectManager SHALL 移除最早创建的召唤物
7. THE SkillEffectManager SHALL 在角色切换后继续管理所有已创建的效果，保持效果的独立生命周期

### 需求 3：扩展敌人状态系统

**用户故事：** 作为游戏设计师，我希望敌人状态系统支持冰冻、沉默、恐惧、标记、石化等新状态，以便新技能能够施加多样化的控制效果。

#### 验收标准

1. WHEN apply_status("freeze") 被调用时，THE StatusComponent SHALL 使敌人完全停止移动和攻击，持续指定时间
2. WHEN apply_status("silence") 被调用时，THE StatusComponent SHALL 阻止敌人使用特殊技能，持续指定时间
3. WHEN apply_status("fear") 被调用时，THE StatusComponent SHALL 使敌人向远离施法者的方向逃跑，持续指定时间
4. WHEN apply_status("marked") 被调用时，THE StatusComponent SHALL 标记敌人，使其受到的伤害增加指定百分比
5. WHEN apply_status("petrify") 被调用时，THE StatusComponent SHALL 使敌人变为石化状态（完全不可行动），持续指定时间
6. WHEN 多个控制状态同时存在时，THE StatusComponent SHALL 按优先级处理：石化 > 冰冻 > 恐惧 > 沉默 > 减速
7. WHEN 状态持续时间到期时，THE StatusComponent SHALL 移除状态效果并恢复敌人的原始属性

### 需求 4：A 组技能 - 元素与控制（地形改造）

**用户故事：** 作为玩家，我希望拥有以元素和地形控制为主题的技能组，以便通过创建墙壁、区域和控制效果来改变战场地形。

#### 验收标准

1. WHEN 冰河角色画线时，THE Glacier_Q_Line_Skill SHALL 沿路径创建 StaticBody2D 冰墙，阻挡敌人和子弹移动，持续配置的时间
2. WHEN 冰河角色画圈闭合时，THE Glacier_Q_Circle_Skill SHALL 在闭合区域内对所有敌人施加冰冻状态
3. WHEN 冰河角色按 E 键时，THE Glacier_E_Skill SHALL 在角色周围产生冰爆效果，击退附近敌人并为角色添加临时护盾
4. WHEN 特斯拉角色画线时，THE Tesla_Q_Line_Skill SHALL 沿路径创建电弧线，对接触的敌人造成伤害并施加 0.5 秒眩晕
5. WHEN 特斯拉角色画圈闭合时，THE Tesla_Q_Circle_Skill SHALL 在闭合区域内创建雷电场，每 0.5 秒对区域内敌人造成伤害
6. WHEN 特斯拉角色按 E 键时，THE Tesla_E_Skill SHALL 对范围内敌人施加沉默状态，阻止敌人使用特殊技能
7. WHEN 新火法角色画线时，THE NewPyro_Q_Line_Skill SHALL 沿路径创建 StaticBody2D 火墙，阻挡敌人移动并对接触者造成持续伤害
8. WHEN 新火法角色画圈闭合时，THE NewPyro_Q_Circle_Skill SHALL 在闭合区域内创建火海，对区域内敌人造成持续伤害
9. WHEN 新火法角色按 E 键时，THE NewPyro_E_Skill SHALL 在角色周围产生火焰环，击退附近敌人
10. WHEN 瘟疫角色画线时，THE Plague_Q_Line_Skill SHALL 沿路径创建腐蚀路径，对接触的敌人施加 50% 减速和中毒状态
11. WHEN 瘟疫角色画圈闭合时，THE Plague_Q_Circle_Skill SHALL 在闭合区域内创建瘴气池，使区域内敌人受到的伤害增加 30%
12. WHEN 瘟疫角色按 E 键时，THE Plague_E_Skill SHALL 引爆所有中毒敌人身上的毒素层数，造成基于层数的爆发伤害
13. WHEN 狱警角色画线时，THE Jailer_Q_Line_Skill SHALL 沿路径创建电网（StaticBody2D），对接触的敌人造成碰撞伤害和击退
14. WHEN 狱警角色画圈闭合时，THE Jailer_Q_Circle_Skill SHALL 在闭合区域边界创建封闭的碰撞墙壁
15. WHEN 狱警角色按 E 键时，THE Jailer_E_Skill SHALL 在角色前方扇形范围内产生盾击效果，击退范围内敌人
16. WHEN 新风暴角色画线时，THE NewTempest_Q_Line_Skill SHALL 沿路径创建风带，为经过的队友提供大幅移速加成
17. WHEN 新风暴角色画圈闭合时，THE NewTempest_Q_Circle_Skill SHALL 在闭合区域内创建台风眼效果，将区域内敌人持续拉向中心
18. WHEN 新风暴角色按 E 键时，THE NewTempest_E_Skill SHALL 在角色周围产生龙卷风效果，将附近敌人抛向空中

### 需求 5：B 组技能 - 战术支援（小队增益）

**用户故事：** 作为玩家，我希望拥有以小队增益为主题的技能组，以便通过创建增益区域来强化队友的战斗能力。

#### 验收标准

1. WHEN 铁匠角色画线时，THE Blacksmith_Q_Line_Skill SHALL 沿路径创建磨刀石区域，为经过的队友提供 +50% 攻击力加成
2. WHEN 铁匠角色画圈闭合时，THE Blacksmith_Q_Circle_Skill SHALL 在闭合区域内创建锻造炉，为区域内队友提供 +100% 攻击速度加成
3. WHEN 铁匠角色按 E 键时，THE Blacksmith_E_Skill SHALL 重置当前角色的 Q 技能冷却时间
4. WHEN 军医角色画线时，THE Medic_Q_Line_Skill SHALL 沿路径创建消毒带，为经过的队友恢复生命值，对经过的敌人施加减速
5. WHEN 军医角色画圈闭合时，THE Medic_Q_Circle_Skill SHALL 在闭合区域内创建无菌室，为区域内队友每秒恢复生命值并提供无敌状态
6. WHEN 军医角色按 E 键时，THE Medic_E_Skill SHALL 为当前角色提供 5 秒的生命偷取 Buff
7. WHEN 弹药角色画线时，THE Ammo_Q_Line_Skill SHALL 沿路径创建加速轨道，队友的子弹穿过该线段时变大并增加伤害
8. WHEN 弹药角色画圈闭合时，THE Ammo_Q_Circle_Skill SHALL 在闭合区域内创建补给站，减少区域内队友的技能冷却时间
9. WHEN 弹药角色按 E 键时，THE Ammo_E_Skill SHALL 立即将当前角色的能量恢复至满值
10. WHEN 圣骑士角色画线时，THE Paladin_Q_Line_Skill SHALL 沿路径创建光墙，阻挡敌人子弹通过
11. WHEN 圣骑士角色画圈闭合时，THE Paladin_Q_Circle_Skill SHALL 在闭合区域内创建净化场，清除队友的 Debuff 并提供伤害减免
12. WHEN 圣骑士角色按 E 键时，THE Paladin_E_Skill SHALL 施放嘲讽效果，强制范围内敌人攻击当前角色
13. WHEN 血族角色画线时，THE Vampire_Q_Line_Skill SHALL 沿路径创建血路（消耗自身生命值），对接触的敌人造成基于其最大生命值百分比的伤害
14. WHEN 血族角色画圈闭合时，THE Vampire_Q_Circle_Skill SHALL 在闭合区域内创建血池，为区域内队友提供 100% 生命偷取
15. WHEN 血族角色按 E 键时，THE Vampire_E_Skill SHALL 吸取附近敌人的生命值并恢复自身
16. WHEN 旗手角色画线时，THE Banner_Q_Line_Skill SHALL 沿路径创建冲锋线，使经过的队友忽略单位碰撞
17. WHEN 旗手角色画圈闭合时，THE Banner_Q_Circle_Skill SHALL 在闭合区域内创建决斗场，使区域内敌人的防御力降为 0
18. WHEN 旗手角色按 E 键时，THE Banner_E_Skill SHALL 吹响号角，为全队提供短暂的移速爆发加成

### 需求 6：C 组技能 - 奇观与召唤（简化版）

**用户故事：** 作为玩家，我希望拥有以召唤和大规模效果为主题的技能组，以便通过召唤单位和触发壮观效果来控制战场。

#### 验收标准

1. WHEN 火车王角色画线时，THE Train_Q_Line_Skill SHALL 沿路径创建幽灵轨道，延迟 1 秒后沿轨道释放冲击波造成大量伤害
2. WHEN 火车王角色画圈闭合时，THE Train_Q_Circle_Skill SHALL 在闭合区域内创建旋转光束，持续对区域内敌人造成伤害
3. WHEN 火车王角色按 E 键时，THE Train_E_Skill SHALL 发出汽笛声，致盲范围内所有敌人
4. WHEN 虫母角色画线时，THE Swarm_Q_Line_Skill SHALL 沿路径创建裂缝，每 1 秒生成一只自爆甲虫
5. WHEN 虫母角色画圈闭合时，THE Swarm_Q_Circle_Skill SHALL 在闭合区域内创建孵化场，生成 3 个远程炮塔并为区域内队友恢复生命
6. WHEN 虫母角色按 E 键时，THE Swarm_E_Skill SHALL 命令所有召唤物集火攻击最近的敌人
7. WHEN 萨满角色画线时，THE Totem_Q_Line_Skill SHALL 在路径起点和终点各放置一个图腾，两个图腾之间以闪电链连接并对经过的敌人造成伤害
8. WHEN 萨满角色画圈闭合时，THE Totem_Q_Circle_Skill SHALL 在闭合区域内创建地震效果，每秒对区域内敌人造成伤害并施加减速
9. WHEN 萨满角色按 E 键时，THE Totem_E_Skill SHALL 引爆场上所有图腾，对图腾周围敌人造成范围伤害
10. WHEN 工程角色画线时，THE Turret_Q_Line_Skill SHALL 沿路径等距放置 3 个自动炮塔，炮塔自动攻击范围内敌人
11. WHEN 工程角色画圈闭合时，THE Turret_Q_Circle_Skill SHALL 在闭合区域内创建维修站，使区域内炮塔获得双倍攻击速度
12. WHEN 工程角色按 E 键时，THE Turret_E_Skill SHALL 引爆所有炮塔，对炮塔周围敌人造成范围伤害
13. WHEN 软泥角色画线时，THE Goo_Q_Line_Skill SHALL 沿路径创建超级胶水区域，对经过的敌人施加 90% 减速
14. WHEN 软泥角色画圈闭合时，THE Goo_Q_Circle_Skill SHALL 在闭合区域内创建分裂池，当区域内敌人受到伤害时生成迷你史莱姆
15. WHEN 软泥角色按 E 键时，THE Goo_E_Skill SHALL 吞噬最近的小型敌人（立即击杀）并恢复自身生命值
16. WHEN 死灵角色画线时，THE Necro_Q_Line_Skill SHALL 沿路径创建骨墙（StaticBody2D），骨墙在受到 3 次攻击后破碎
17. WHEN 死灵角色画圈闭合时，THE Necro_Q_Circle_Skill SHALL 在闭合区域内创建尸爆场，区域内敌人死亡时会爆炸对周围敌人造成伤害
18. WHEN 死灵角色按 E 键时，THE Necro_E_Skill SHALL 发出恐惧尖啸，对范围内敌人施加恐惧状态

### 需求 7：D 组技能 - 经济与收割（价值流）

**用户故事：** 作为玩家，我希望拥有以经济收益和处决为主题的技能组，以便通过击杀敌人获得额外金币和资源。

#### 验收标准

1. WHEN 商人角色画线时，THE Merchant_Q_Line_Skill SHALL 沿路径创建赏金线，接触该线的敌人死亡时掉落双倍金币
2. WHEN 商人角色画圈闭合时，THE Merchant_Q_Circle_Skill SHALL 在闭合区域内创建黑市，区域内敌人每秒掉落 1 金币并进入逃跑状态
3. WHEN 商人角色按 E 键时，THE Merchant_E_Skill SHALL 投掷金币炸弹，对范围内敌人造成伤害
4. WHEN 炼金角色画线时，THE Midas_Q_Line_Skill SHALL 沿路径创建金光射线，对接触的敌人施加 1 秒石化状态
5. WHEN 炼金角色画圈闭合时，THE Midas_Q_Circle_Skill SHALL 在闭合区域内创建转化阵，区域内敌人死亡时变为金堆障碍物（StaticBody2D）
6. WHEN 炼金角色按 E 键时，THE Midas_E_Skill SHALL 投掷药水瓶，对命中区域的敌人施加随机 Debuff
7. WHEN 吸尘器角色画线时，THE Vacuum_Q_Line_Skill SHALL 沿路径创建传送带，每 1 秒将最远的掉落物传送到玩家位置
8. WHEN 吸尘器角色画圈闭合时，THE Vacuum_Q_Circle_Skill SHALL 在闭合区域内创建磁场，将拾取范围扩大 5 倍
9. WHEN 吸尘器角色按 E 键时，THE Vacuum_E_Skill SHALL 立即吸取屏幕内所有掉落物
10. WHEN 处刑角色画线时，THE Executioner_Q_Line_Skill SHALL 沿路径创建红线，接触红线的生命值低于 30% 的敌人立即死亡
11. WHEN 处刑角色画圈闭合时，THE Executioner_Q_Circle_Skill SHALL 在闭合区域内创建断头台效果，区域内敌人受到伤害时有概率被立即击杀
12. WHEN 处刑角色按 E 键时，THE Executioner_E_Skill SHALL 使角色瞬移到最近敌人位置并造成伤害
13. WHEN 赌徒角色画线时，THE Gambler_Q_Line_Skill SHALL 沿路径创建随机变色带（红色=伤害、绿色=治疗、蓝色=加速），颜色随机变化
14. WHEN 赌徒角色画圈闭合时，THE Gambler_Q_Circle_Skill SHALL 在闭合区域内创建轮盘效果，随机给予强力 Buff 或弱 Debuff
15. WHEN 赌徒角色按 E 键时，THE Gambler_E_Skill SHALL 掷骰子，根据结果产生随机效果
16. WHEN 猎人角色画线时，THE Hunter_Q_Line_Skill SHALL 沿路径标记所有接触的敌人，被标记敌人受到的自动攻击伤害增加 50%
17. WHEN 猎人角色画圈闭合时，THE Hunter_Q_Circle_Skill SHALL 在闭合区域内创建猎场，区域内被标记的敌人被自动攻击优先选择
18. WHEN 猎人角色按 E 键时，THE Hunter_E_Skill SHALL 使角色执行翻滚闪避，获得短暂无敌帧

### 需求 8：E 组技能 - 特殊机制

**用户故事：** 作为玩家，我希望拥有具有独特机制的技能组，以便体验反射、诅咒链接等创新玩法。

#### 验收标准

1. WHEN 魔术师角色画线时，THE Illusionist_Q_Line_Skill SHALL 沿路径创建镜面（StaticBody2D），反射敌人子弹
2. WHEN 魔术师角色画圈闭合时，THE Illusionist_Q_Circle_Skill SHALL 在闭合区域中心创建幻影分身，吸引敌人仇恨
3. WHEN 魔术师角色按 E 键时，THE Illusionist_E_Skill SHALL 使角色与幻影分身交换位置
4. WHEN 巫毒角色画线时，THE Voodoo_Q_Line_Skill SHALL 沿路径创建诅咒线，对接触的敌人施加诅咒状态
5. WHEN 巫毒角色画圈闭合时，THE Voodoo_Q_Circle_Skill SHALL 在闭合区域内创建钉刺坑，攻击区域内任意单位时对所有带诅咒状态的敌人造成等量伤害
6. WHEN 巫毒角色按 E 键时，THE Voodoo_E_Skill SHALL 自伤触发全屏诅咒伤害，对所有带诅咒状态的敌人造成伤害

### 需求 9：技能脚本架构与代码组织

**用户故事：** 作为游戏架构师，我希望新技能脚本遵循统一的架构模式，以便代码可维护、可扩展且与现有系统兼容。

#### 验收标准

1. THE 所有新 Q 技能 SHALL 继承 SkillDrawingBase，实现 _spawn_line_effect() 和 _spawn_area_effect() 方法
2. THE 所有新 E 技能 SHALL 继承 SkillBase，实现 execute() 方法
3. THE 所有新技能脚本 SHALL 存放在 scenes/skills/players/ 目录下，文件名遵循 skill_{character}_{type}.gd 命名规范
4. THE 所有新技能 SHALL 通过 SkillEffectManager 创建效果，确保效果在角色切换后继续存在
5. THE 所有新技能的参数 SHALL 从 skill_params.csv 长表中读取，不在代码中硬编码数值
6. THE 所有新技能 SHALL 使用临时占位视觉效果（彩色几何形状），不依赖美术资源

### 需求 10：删除旧角色、创建新角色与技能绑定

**用户故事：** 作为游戏设计师，我希望删除 20 个非原始角色，然后根据新技能主题创建 20 个全新角色，并将 20 套新技能分配给这些新角色，剩余技能存入技能库。

#### 验收标准

1. THE 20 个非原始角色（technology_hurricane、tankman、heavy_support、warrior、electric_shock、wizard、fortune_teller、tarot_reader、necromancer、magician、witch_doctor、lovely、camouflage、the_flash、information_Support、technical_support、light_support、dryad、doctor、nurse）SHALL 从所有配置文件和脚本中完全删除
2. WHEN 旧角色被删除后，THE 对应的 player_xxx.gd 脚本文件和 .uid 文件 SHALL 被删除
3. THE 20 个新角色 SHALL 被创建，其 player_id 与新技能主题匹配（如 glacier、tesla、new_pyro 等）
4. WHEN 新角色被创建后，THE 所有相关 CSV 文件（player_config、player_visual、player_weapons、player_skill_bindings、ult_config、player_available_weapons）SHALL 包含新角色的配置行
5. WHEN 新角色被创建后，THE 对应的 player_xxx.gd 脚本文件 SHALL 使用模板化结构创建，包含正确的 class_name 和 load_skills_from_config 参数
6. WHEN player_skill_bindings.csv 被更新后，THE 20 个新角色 SHALL 各自绑定一套独特的新技能（Q-line + Q-circle + E-key）
7. THE 原始六角色（butcher、pyro、sapper、herder、weaver、wind）的 player_id 和技能绑定 SHALL 保持不变
8. THE 剩余未分配的技能 SHALL 在 skill_params.csv 中保留完整参数配置，可通过修改 player_skill_bindings.csv 分配给未来角色
9. WHEN SkillManager 加载新技能绑定时，THE SkillManager SHALL 正确实例化对应的技能脚本并设置参数

### 需求 11：技能效果持久性与角色切换兼容

**用户故事：** 作为玩家，我希望角色 A 创建的技能效果在切换到角色 B 后仍然有效，以便角色 B 能够受益于角色 A 的增益区域。

#### 验收标准

1. WHEN 角色 A 创建了一个 Buff 区域后切换到角色 B 时，THE SkillEffectManager SHALL 继续维护该 Buff 区域的生命周期
2. WHEN 角色 B 进入角色 A 创建的 Buff 区域时，THE Buff 区域 SHALL 对角色 B 应用相应的增益效果
3. WHEN 角色 A 创建了 StaticBody2D 墙体后切换到角色 B 时，THE 墙体 SHALL 继续阻挡敌人移动直到持续时间到期
