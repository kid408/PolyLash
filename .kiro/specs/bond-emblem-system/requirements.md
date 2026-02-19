# 需求文档：羁绊与道具系统重构 (Bond & Item System Overhaul)

> 版本: v2.0
> 日期: 2026-02-16
> 优先级: P0 (核心玩法阻断 + UI修复)
> 目标: 修复羁绊UI显示错误，并重构道具系统以支持 Roguelike 构建体验（双轨制）。

## 简介

对 PolyLash 的道具系统和羁绊系统进行全面重构。核心变更包括：修复羁绊 UI 显示不一致问题；采用"双轨制"架构将道具拆分为个人装备 (Equipment) 和团队护符 (Artifacts)；重新定义 Tier 3 装备使其同时提供属性和羁绊标签；引入羁绊徽章 (Emblem) 和通用遗物 (Relic) 作为团队护符；通过商店购买 + 波次奖励三选一的混合模式增强 Roguelike 局内构建体验；合并配置文件消除硬编码映射。

### 核心变更概览

| 模块 | 当前问题 (As-Is) | 重构目标 (To-Be) |
|------|------------------|------------------|
| 羁绊UI | 选择界面显示 3/3，战斗界面显示 Lv.2，用户困惑 | 全链路统一显示 Lv.X (当前/下一级)，支持溢出数值 |
| 道具槽位 | 角色仅1个槽位，T3圣物只给标签不给属性，角色变弱 | 双轨制：个人装备（数值+标签）+ 团队护符（纯标签/全局被动）|
| 羁绊构建 | 3角色限制导致无法凑齐 Lv.3 (6标签) | 引入团队护符，通过商店/波次奖励突破标签限制 |
| 经济循环 | 商店缺乏策略性，金币用途单一 | 商店增加徽章购买，波次增加三选一奖励 |

## 术语表

- **EmblemManager**: 团队护符/徽章管理器 Autoload 节点，负责全局护符的持有、计数和生命周期管理
- **BondManager**: 现有羁绊管理器，负责标签统计、等级激活和效果应用
- **ShopManager**: 现有商店管理器，负责波次间商店物品生成和购买
- **EquipmentManager**: 现有装备管理器，负责角色个人装备的穿戴和持久化
- **WarehouseManager**: 现有仓库管理器，负责道具仓库的存储和管理
- **ConfigManager**: 现有配置管理器，负责 CSV 配置文件的加载和缓存
- **Equipment**: 个人装备，绑定角色、占用唯一装备槽位的道具（Tier 1/2/3）
- **Artifact**: 团队护符，不占用角色装备槽、存放于全局仓库、对全队生效的物品
- **Bond_Emblem**: 羁绊徽章，一种 Artifact，单纯提供特定羁绊标签计数 +1
- **Global_Relic**: 通用遗物，一种 Artifact，提供全局被动机制效果
- **Wildcard_Emblem**: 万能鬼牌徽章，可充当任意一种羁绊标签计数 +1 的特殊徽章
- **Wave_Reward_UI**: 波次奖励界面，在特定波次结束后弹出的三选一选择界面
- **bond_tag**: 羁绊标签，角色、装备或徽章携带的标签（如 inkborn、colossus、nomad 等）
- **BondSummaryItem**: 选择界面中的羁绊摘要组件
- **BondHUD**: 战斗界面中的羁绊显示 HUD

## 需求

### 需求 1：羁绊 UI 显示统一

**用户故事：** 作为玩家，我希望选择界面和战斗界面对羁绊等级的显示格式统一，以便我不会对当前羁绊状态产生误解。

#### 验收标准

1. THE BondSummaryItem（选择界面）和 BondHUD（战斗界面）SHALL 使用相同的格式化逻辑显示羁绊状态
2. WHEN 羁绊未激活时，THE 显示组件 SHALL 显示灰色图标加 "0/N"（N 为 Lv.1 需求数量）
3. WHEN 羁绊已激活但未满级时，THE 显示组件 SHALL 显示亮色图标加 "Lv.X (当前数量/下一级需求)"
4. WHEN 羁绊已满级时，THE 显示组件 SHALL 显示金色图标加 "Lv.MAX"；IF 标签数量溢出，THEN THE 显示组件 SHALL 显示实际数量（如 "Lv.3 (8/6)"）
5. THE BondManager SHALL 公开 get_activated_level(bond_id, count) 方法供 UI 组件调用
6. WHEN BondHUD 显示羁绊标签计数时，THE BondHUD SHALL 在 tooltip 中区分角色贡献、装备贡献和徽章贡献（如 "2角色 + 1装备 + 1徽章 = 4"）

### 需求 2：修复圣物系统断路与标签不匹配（P0）

**用户故事：** 作为玩家，我希望装备的 Tier 3 道具能正确提供羁绊标签和属性加成，以便圣物对羁绊等级和角色战力产生实际影响。

#### 验收标准

1. WHEN BondManager 重新计算羁绊标签时，THE BondManager SHALL 从每个队伍角色的已装备道具中读取 bond_grant 标签并计入 current_bond_counts
2. WHEN PlayerBase 装备 Tier 3 道具时，THE PlayerBase SHALL 同时应用属性加成和将羁绊标签注册到 BondManager 可查询的数据结构中
3. THE item_effect_config.csv SHALL 使用与 bond_config.csv 一致的羁绊标签名（inkborn、colossus、nomad、alchemist、blaster、architect、hexer、geometrist、assist、vanguard、commander）
4. THE PlayerBase._infer_item_id_from_type() SHALL 使用更新后的圣物 ID 映射

### 需求 3：配置文件合并重构

**用户故事：** 作为开发者，我希望废弃 item_effect_config.csv 并将其内容合并入 item_config.csv，以便消除硬编码映射并简化道具数据管理。

#### 验收标准

1. THE 新 item_config.csv SHALL 包含以下字段：id、name、tier、type、slot_type、base_stat、base_value、mod_type、mod_value、bond_grant、icon_path、description
2. THE ConfigManager SHALL 在启动时加载新格式的 item_config.csv 并提供 get_item_config(item_id) 查询接口
3. THE PlayerBase SHALL 通过 ConfigManager 读取道具配置，消除 _infer_item_id_from_type() 中的硬编码映射表
4. THE WarehouseManager SHALL 使用新的统一配置结构替代原有的简化配置加载

### 需求 4：装备系统重构（双轨制 - 个人装备轨道）

**用户故事：** 作为玩家，我希望 Tier 3 装备同时提供属性加成和羁绊标签，以便高级装备成为最强装备而非纯粹的羁绊工具。

#### 验收标准

1. WHEN 角色装备 Tier 1 道具时，THE 装备系统 SHALL 应用纯基础数值加成（HP/ATK/SPD）
2. WHEN 角色装备 Tier 2 道具时，THE 装备系统 SHALL 应用基础数值加成和百分比修正
3. WHEN 角色装备 Tier 3 道具时，THE 装备系统 SHALL 同时应用高数值加成、百分比修正和 bond_grant 羁绊标签
4. WHEN 角色已有装备且装备新道具时，THE EquipmentManager SHALL 自动替换旧装备并将旧装备返回仓库
5. WHEN 玩家获得消耗品（type=consumable）时，THE 装备系统 SHALL 直接调用 PlayerBase.apply_consumable_effect() 立即生效（如回血/回蓝），且 SHALL NOT 将消耗品存入角色装备槽位或仓库

### 需求 5：团队护符系统（双轨制 - 团队护符轨道）

**用户故事：** 作为玩家，我希望获得的徽章和遗物在本局游戏中持续生效且不占用角色装备槽，以便我可以自由收集护符来强化羁绊和全局能力。

#### 验收标准

1. THE EmblemManager SHALL 维护一个当前局内持有的护符列表，区分 Bond_Emblem（羁绊徽章）和 Global_Relic（通用遗物）两种类型
2. WHEN 一个新护符被添加到 EmblemManager 时，THE EmblemManager SHALL 发出 emblem_added 信号并触发 BondManager 重新计算羁绊
3. WHEN 一局游戏结束时，THE EmblemManager SHALL 清空所有持有的护符数据
4. THE EmblemManager SHALL 提供 get_emblem_tags() 方法返回所有羁绊徽章提供的 bond_tag 及其计数
5. THE EmblemManager SHALL 提供 get_emblems_for_bond(bond_id) 方法返回指定羁绊标签的徽章数量

### 需求 6：团队护符配置

**用户故事：** 作为开发者，我希望有一套独立的护符配置文件，以便护符系统与个人装备系统解耦。

#### 验收标准

1. THE emblem_config.csv SHALL 定义每个护符的 emblem_id、display_name、artifact_type（emblem 或 relic）、bond_tag、rarity、shop_price、icon_path 和 description 字段
2. THE ConfigManager SHALL 在启动时加载 emblem_config.csv 并提供 get_emblem_config(emblem_id) 查询接口

### 需求 7：BondManager 三源标签统计

**用户故事：** 作为玩家，我希望羁绊标签从角色自带、装备 bond_grant 和团队徽章三个来源统一计算，以便所有来源的标签都能帮助激活羁绊。

#### 验收标准

1. WHEN BondManager 执行 recalculate_active_bonds 时，THE BondManager SHALL 依次统计三个来源的标签：角色自带标签（origin_tag + mastery_tag + tactic_tag）、角色装备的 bond_grant 标签（通过 EquipmentManager 查询）、EmblemManager 中的全局徽章标签
2. WHEN Wildcard_Emblem 被持有时，THE BondManager SHALL 将万能徽章的计数加到玩家指定的目标羁绊标签上
3. WHEN 任意来源的标签发生变化时，THE BondManager SHALL 重新计算所有羁绊的激活状态

### 需求 8：商店系统集成护符

**用户故事：** 作为玩家，我希望在波次间商店中有机会购买羁绊徽章和遗物，以便我可以通过经济投资来强化构建。

#### 验收标准

1. WHEN ShopManager 生成商店物品时，THE ShopManager SHALL 以 20%-30% 的概率在商品列表中包含一个 Artifact 类型商品
2. WHEN 生成徽章商品时，THE ShopManager SHALL 优先选择当前队伍已拥有但未满级的羁绊对应的徽章（智能刷新）
3. WHEN 玩家购买护符商品时，THE ShopManager SHALL 调用 EmblemManager.add_emblem() 将护符添加到当前局内
4. THE 护符商品的价格 SHALL 高于消耗品和 T2 装备，与 T3 装备价格相当

### 需求 9：波次奖励三选一系统

**用户故事：** 作为玩家，我希望在特定波次结束后获得三选一的奖励，以便我可以根据当前局势做出策略选择。

#### 验收标准

1. WHEN 配置指定的波次（如第 5、10、15 波，可配置）结束时，THE Wave_Reward_UI SHALL 弹出三选一奖励界面
2. THE 三选一选项 SHALL 包含：选项 A 为随机团队徽章或遗物、选项 B 为随机 T3 装备、选项 C 为大量金币或恢复或属性提升
3. WHEN 玩家选择一个奖励选项时，THE Wave_Reward_UI SHALL 将对应物品添加到 EmblemManager 或 EquipmentManager 或将金币添加到 DataManager
4. WHILE Wave_Reward_UI 显示时，THE 游戏 SHALL 暂停战斗逻辑

### 需求 10：万能鬼牌徽章

**用户故事：** 作为玩家，我希望在极少数情况下获得万能徽章，以便我可以灵活地补充任意羁绊的计数。

#### 验收标准

1. WHEN 万能徽章被添加到 EmblemManager 时，THE EmblemManager SHALL 将其标记为 is_wildcard 并提示玩家选择目标羁绊
2. WHEN 玩家为万能徽章选择目标羁绊后，THE EmblemManager SHALL 将该徽章的 bond_tag 设置为玩家选择的羁绊标签
3. THE 万能徽章 SHALL 仅在最终 Boss 波或隐藏房间中以低概率掉落
4. WHEN 万能鬼牌从"波次奖励三选一"或"商店"界面获得时，THE UI 管理器 SHALL 先关闭当前界面（商店/奖励面板），THEN 弹出万能鬼牌选择界面（WildcardUI），THEN 在选择完毕后才恢复游戏/解除暂停。THE UI 管理器 SHALL 使用队列/栈机制确保多个弹窗不会重叠显示

### 需求 11：羁绊阈值调整

**用户故事：** 作为玩家，我希望 Lv.3 羁绊在6人队伍加徽章辅助下可以合理达到，以便高级羁绊成为有意义的构建目标。

#### 验收标准

1. THE bond_config.csv SHALL 将 Origin 和 Mastery 类羁绊的 Lv.2 需求从 4 调整为 3
2. THE bond_config.csv SHALL 将 Origin 和 Mastery 类羁绊的 Lv.3 需求从 6 调整为 5

### 需求 12：羁绊激活视觉反馈

**用户故事：** 作为玩家，我希望羁绊等级提升时有明显的视觉和音效反馈，以便我能直观感受到羁绊系统的变化。

#### 验收标准

1. WHEN 一个羁绊的等级提升时，THE BondHUD SHALL 播放对应图标的放大弹跳动画
2. WHEN 一个羁绊的等级提升时，THE 游戏 SHALL 在屏幕中央显示羁绊名称和等级的飘字提示
3. WHEN 一个羁绊的等级提升时，THE SoundManager SHALL 播放对应的羁绊激活音效（bond_generic.wav）
