# 羁绊配置重构 - Bond Config Refactor

## 🎯 重构目标

将羁绊系统从通用的 RPG 属性加成，重构为与**画图玩法深度结合**的机制系统。

## 📊 数据对比

### 之前的设计 ❌
- 通用 RPG 属性（暴击、生命、护甲等）
- 与画图玩法关联度低
- 测试数据（martial, noble 等）
- 缺乏游戏特色

### 新的设计 ✅
- 围绕画图机制设计
- 深度结合闭合图形、线条、切换等核心玩法
- 独特的游戏体验
- 清晰的职业定位

## 🗂️ 新羁绊分类

### 身世羁绊 (Origin) - 4个

#### 1. 墨灵 (Inkborn)
- **定位**: 能量管理
- **Lv.1 (2人)**: 魔法自然回复速度+30%
- **Lv.2 (3人)**: 击杀敌人回复5点魔法
- **图标索引**: 1

#### 2. 巨擘 (Colossus)
- **定位**: 坦克/防御
- **Lv.1 (2人)**: 全队生命上限+25%
- **Lv.2 (3人)**: 画闭合图形时霸体(无法被打断)
- **图标索引**: 2

#### 3. 风行者 (Nomad)
- **定位**: 速度/机动
- **Lv.1 (2人)**: 移动速度+15%
- **Lv.2 (3人)**: 移动速度加成转化为攻击力
- **图标索引**: 3

#### 4. 炼金术士 (Alchemist)
- **定位**: 资源/收集
- **Lv.1 (2人)**: 拾取范围+50%
- **Lv.2 (3人)**: 线条持续产出金币
- **图标索引**: 4

### 职能羁绊 (Mastery) - 4个

#### 1. 爆破师 (Blaster)
- **定位**: 爆发伤害
- **Lv.1 (1人)**: 闭合图形伤害+20%
- **Lv.2 (2人)**: 闭合引爆产生二次余波
- **Lv.3 (3人)**: 引爆图形触发全屏连锁反应
- **图标索引**: 1

#### 2. 筑墙者 (Architect)
- **定位**: 控制/防御
- **Lv.1 (1人)**: 线条持续时间+3秒
- **Lv.2 (2人)**: 线条附带反伤效果
- **Lv.3 (3人)**: 闭合图形转化为存在10秒的牢笼
- **图标索引**: 2

#### 3. 咒术师 (Hexer)
- **定位**: Debuff/持续伤害
- **Lv.1 (1人)**: 图形内敌人Debuff时间延长
- **Lv.2 (2人)**: 图形内敌人每秒叠加诅咒
- **Lv.3 (3人)**: 画笔划过造成5%最大生命真伤
- **图标索引**: 3

#### 4. 几何学家 (Geometrist)
- **定位**: 技巧/精准
- **Lv.1 (1人)**: 图形闭合容错率提升
- **Lv.2 (2人)**: 小面积图形必定暴击
- **Lv.3 (3人)**: 多边形触发特殊特效(流血/眩晕)
- **图标索引**: 4

### 战术羁绊 (Tactic) - 3个

#### 1. 支援型 (Assist)
- **定位**: 后台增强
- **Lv.1 (2人)**: 后台技能冷却减少30%
- **Lv.2 (3人)**: 激活后台角色镜像作画
- **图标索引**: 1

#### 2. 突击型 (Vanguard)
- **定位**: 切换流
- **Lv.1 (2人)**: 切换冷却减少50%
- **Lv.2 (3人)**: 切换时保留地面图形并增伤
- **图标索引**: 2

#### 3. 指挥型 (Commander)
- **定位**: 属性共享
- **Lv.1 (2人)**: 后台角色30%属性共享给前台
- **Lv.2 (3人)**: 前台攻击附带后台角色特效
- **图标索引**: 3

## 🔧 效果类型说明

### stat_mod (属性修改)
直接修改角色属性，立即生效。

**新增的百分比属性**:
- `energy_regen_pct`: 能量回复速度百分比
- `max_health_pct`: 生命上限百分比
- `movement_speed_pct`: 移动速度百分比
- `pickup_range_pct`: 拾取范围百分比
- `stat_share`: 属性共享比例

### mechanic (机制效果)
需要代码实现的特殊机制，存储为字符串标识。

**画图相关机制**:
- `closed_shape_dmg`: 闭合图形伤害加成
- `secondary_explode`: 二次爆炸
- `chain_reaction`: 连锁反应
- `line_duration`: 线条持续时间
- `thorns_wall`: 反伤墙
- `permanent_cage`: 永久牢笼
- `debuff_duration`: Debuff 延长
- `curse_stack`: 诅咒叠加
- `death_brush`: 画笔真伤
- `shape_tolerance`: 闭合容错
- `small_shape_crit`: 小图形暴击
- `polygon_effect`: 多边形特效

**能量/资源机制**:
- `kill_regen`: 击杀回能
- `gold_trail`: 金币轨迹

**战斗机制**:
- `super_armor`: 霸体
- `speed_to_damage`: 速度转伤害

**战术机制**:
- `bench_cd_reduce`: 后台冷却减少
- `mirror_draw`: 镜像作画
- `switch_cd_reduce`: 切换冷却减少
- `ink_inherit`: 图形继承
- `soul_attach`: 灵魂附着

## 📝 CSV 格式说明

```csv
bond_id,type,level,required_count,effect_type,effect_param,effect_value,icon_path_index,display_name,description
```

### 字段说明
- `bond_id`: 羁绊唯一标识符（英文）
- `type`: 羁绊类型（origin/mastery/tactic）
- `level`: 羁绊等级（1-3）
- `required_count`: 激活所需角色数量
- `effect_type`: 效果类型（stat_mod/mechanic）
- `effect_param`: 效果参数（属性名或机制名）
- `effect_value`: 效果数值
- `icon_path_index`: 图标索引（1-7）
- `display_name`: 显示名称（中文）
- `description`: 效果描述（中文）

## 🎮 设计理念

### 1. 画图核心
所有羁绊都围绕画图玩法设计，强化核心机制。

### 2. 职业定位
每个羁绊有明确的职业定位和玩法风格。

### 3. 渐进式强化
- Origin: 2人激活，基础增强
- Mastery: 1-3人，三级递进
- Tactic: 2人激活，战术配合

### 4. 协同效应
不同羁绊可以组合出独特的玩法：
- 爆破师 + 几何学家 = 精准爆破流
- 筑墙者 + 巨擘 = 坦克控制流
- 风行者 + 突击型 = 高速切换流
- 咒术师 + 支援型 = 持续伤害流

## 🚀 后续实现步骤

### Phase 1: 属性系统 ✅
- [x] 更新 bond_config.csv
- [x] 更新 BondManager 解析逻辑
- [x] 支持百分比属性（_pct 后缀）
- [x] 更新 player_config.csv 角色羁绊标签

### Phase 2: 机制实现 🔄
- [ ] 实现画图相关机制
- [ ] 实现能量/资源机制
- [ ] 实现战斗机制
- [ ] 实现战术机制

### Phase 3: 测试验证 ⏳
- [ ] 测试羁绊组合
- [ ] 测试百分比属性计算
- [ ] 测试羁绊激活逻辑

### Phase 4: UI 更新 ⏳
- [ ] 更新羁绊图标
- [ ] 更新 Tooltip 显示
- [ ] 添加机制说明

### Phase 5: 平衡调整 ⏳
- [ ] 数值平衡测试
- [ ] 组合效果测试
- [ ] 玩家反馈收集

## 📚 相关文件

### 配置文件
- `config/player/bond_config.csv` - 羁绊配置（已更新）
- `config/player/player_config.csv` - 角色配置（待更新）

### 代码文件
- `autoloads/bond_manager.gd` - 羁绊管理器
- `scenes/ui/bond_hud/bond_hud.gd` - 羁绊 HUD
- `scenes/ui/selection_panel/selection_panel.gd` - 选择界面

### 文档文件
- `BOND_CONFIG_REFACTOR.md` - 本文档
- `docs/GAME_DESIGN_BIBLE.md` - 游戏设计文档

## ⚠️ 注意事项

### 废弃的羁绊
以下羁绊已被移除，不再使用：
- martial（武道世家）
- arcane（秘术行者）
- survivor（幸存者）
- noble（贵族血统）
- shadow（暗影刺客）
- nature（自然守护）
- tech（科技先锋）
- destruction（毁灭打击）
- velocity（极速）
- control（控制大师）
- defense（坚韧防御）
- support（辅助专家）
- summon（召唤大师）
- stealth（隐匿）
- assault（突击战术）
- captain（指挥官）
- defense_tactic（防御战术）
- guerrilla（游击战术）
- siege（攻城战术）
- ambush（伏击战术）

### 兼容性
- 旧的存档可能包含废弃的羁绊ID
- 需要添加兼容性处理或清除旧存档
- UI 需要更新以支持新的羁绊显示

### 测试重点
- 百分比属性计算是否正确
- 机制效果是否按预期触发
- 羁绊组合是否平衡
- UI 显示是否正确

## 🎯 设计目标达成

- ✅ 与画图玩法深度结合
- ✅ 独特的游戏体验
- ✅ 清晰的职业定位
- ✅ 丰富的组合可能性
- ✅ 渐进式的强化体验
- ✅ 易于理解和记忆

---

**重构日期**: 2026-01-31  
**重构者**: Kiro AI Assistant  
**状态**: ✅ CSV 已更新，等待代码实现
