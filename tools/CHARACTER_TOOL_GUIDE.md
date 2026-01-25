# 角色创建工具使用说明

## 🚀 快速开始（30秒）

1. 打开 `tools/create_character_tool.gd`
2. 修改 `CHARACTER_ID` 和 `CHARACTER_NAME`
3. File -> Run
4. 完成！所有文件自动创建

---

## ✨ 新特性

### 🎯 自动化程度更高

- ✅ **自动生成类名**：无需手动填写 `CHARACTER_CLASS_NAME`
- ✅ **自动添加CSV**：无需手动复制粘贴配置
- ✅ **智能检测**：自动跳过已存在的配置

### 🔄 类名自动转换

工具会自动将 `CHARACTER_ID` 转换为大驼峰格式：

| CHARACTER_ID | 自动生成的类名 |
|--------------|---------------|
| `lovely` | `Lovely` |
| `lovely_girl` | `LovelyGirl` |
| `fire_mage` | `FireMage` |
| `ice_warrior` | `IceWarrior` |

---

## 📝 详细步骤

### 1. 打开文件

在 Godot 编辑器中打开：
```
tools/create_character_tool.gd
```

### 2. 修改配置（只需修改这两行）

```gdscript
const CHARACTER_ID = "lovely"      # 角色ID（小写，用下划线）
const CHARACTER_NAME = "小可爱"     # 角色名称（中文）
```

### 3. 可选：调整其他参数

```gdscript
# 基础属性
const MAX_HP = 100.0
const MAX_ENERGY = 100.0
const SPEED = 300.0
const ENERGY_REGEN = 10.0

# 技能绑定
const SKILL_Q = "skill_wind_path"
const SKILL_E = "skill_storm_eye"
const SKILL_LMB = "skill_dash"
const SKILL_RMB = ""

# 视觉配置
const SPRITE_PATH = "res://assets/sprites/Player_13.png"
const SPRITE_SCALE = 1.0
const COLOR_MODULATE = "#ffffff"
```

### 4. 运行脚本

- 方式1: File -> Run (选择 create_character_tool.gd)
- 方式2: 在脚本编辑器中按 Ctrl+Shift+X

### 5. 查看结果

控制台会显示：
```
================================================================================
角色创建工具
================================================================================

角色ID: lovely
角色名称: 小可爱
类名: Lovely

✅ 角色脚本创建成功: res://scenes/unit/players/player_lovely.gd

--------------------------------------------------------------------------------
正在添加到CSV配置文件...
--------------------------------------------------------------------------------

✅ 已添加到 player_config.csv
✅ 已添加到 player_visual.csv
✅ 已添加到 player_skill_bindings.csv
✅ 已添加到 player_weapons.csv
✅ 已添加到 player_weapons.csv (第2行)
✅ 已添加到 player_available_weapons.csv

✅ 所有CSV配置已自动添加

================================================================================
✅ 角色创建完成！
================================================================================

下一步：
1. 在游戏中测试角色：PlayerFactory.create_player("lovely")
2. 根据需要调整CSV配置文件中的参数
```

---

## 📋 工具自动完成的任务

### 1. 创建角色脚本

**文件路径**: `scenes/unit/players/player_{CHARACTER_ID}.gd`

**包含内容**:
- ✅ 完整的 PlayerBase 继承
- ✅ 自动生成的类名（大驼峰格式）
- ✅ SkillManager 集成
- ✅ 输入处理逻辑
- ✅ 技能按键绑定（Q/E/LMB/F）

### 2. 自动添加CSV配置

#### player_config.csv
```csv
lovely,小可爱,100.0,100.0,300.0,10.0,true
```
包含：ID、名称、生命、能量、速度、能量恢复、是否可用

#### player_visual.csv
```csv
lovely,res://assets/sprites/Player_13.png,1.0,#ffffff
```
包含：ID、精灵路径、缩放、颜色

#### player_skill_bindings.csv
```csv
lovely,skill_wind_path,skill_storm_eye,skill_dash,
```
包含：ID、Q技能、E技能、左键技能、右键技能

#### player_weapons.csv
```csv
lovely,weapon_pistol,1
lovely,weapon_shotgun,5
```
包含：ID、武器ID、解锁等级

#### player_available_weapons.csv
```csv
lovely,true,true,false,false,false,false,false,false,false
```
包含：ID、9种武器的可用状态

### 3. 智能检测

- 🔍 检查角色ID是否已存在
- 🔍 检查脚本文件是否已存在
- 🔍 检查CSV文件是否已有该角色配置
- ⚠️ 如果已存在，会跳过并提示，不会覆盖

---

## 🎨 使用示例

### 示例1: 创建基础角色

```gdscript
const CHARACTER_ID = "warrior"
const CHARACTER_NAME = "战士"
# 其他使用默认值
```

运行后自动生成：
- 脚本: `player_warrior.gd`
- 类名: `PlayerWarrior`
- 所有CSV配置

### 示例2: 创建法师角色

```gdscript
const CHARACTER_ID = "fire_mage"
const CHARACTER_NAME = "火焰法师"

const MAX_HP = 80.0
const MAX_ENERGY = 150.0
const SPEED = 250.0
const ENERGY_REGEN = 15.0

const SKILL_Q = "skill_fire_path"
const SKILL_E = "skill_fire_storm"
const SKILL_LMB = "skill_fire_dash"

const SPRITE_PATH = "res://assets/sprites/Player_5.png"
```

运行后自动生成：
- 脚本: `player_fire_mage.gd`
- 类名: `PlayerFireMage`
- 所有CSV配置（使用自定义参数）

### 示例3: 创建坦克角色

```gdscript
const CHARACTER_ID = "tank_hero"
const CHARACTER_NAME = "坦克英雄"

const MAX_HP = 200.0
const MAX_ENERGY = 80.0
const SPEED = 200.0
const ENERGY_REGEN = 5.0

const SKILL_Q = "skill_shield_bash"
const SKILL_E = "skill_taunt"
const SKILL_LMB = "skill_charge"

const SPRITE_PATH = "res://assets/sprites/Player_7.png"
const SPRITE_SCALE = 1.2
```

运行后自动生成：
- 脚本: `player_tank_hero.gd`
- 类名: `PlayerTankHero`
- 所有CSV配置（高生命、低速度）

---

## ❓ 常见问题

### Q1: 为什么不需要填写 CHARACTER_CLASS_NAME 了？

**A**: 工具会自动将 `CHARACTER_ID` 转换为大驼峰格式。例如：
- `lovely` → `Lovely`
- `fire_mage` → `FireMage`

这样可以避免手动输入错误，保持命名一致性。

### Q2: CSV配置没有自动添加？

**A**: 检查：
1. CSV文件是否存在于 `config/player/` 目录
2. 控制台是否有错误信息
3. 该角色ID是否已存在（会跳过）

### Q3: 提示角色ID已存在？

**A**: 修改 `CHARACTER_ID` 为一个新的唯一ID，或者：
1. 删除现有的角色脚本
2. 从CSV文件中删除该角色的配置行
3. 重新运行工具

### Q4: 如何修改已创建的角色？

**A**: 
1. **修改脚本**: 直接编辑 `player_{CHARACTER_ID}.gd`
2. **修改属性**: 编辑对应的CSV文件
3. **不要重新运行工具**（会跳过已存在的配置）

### Q5: 角色在游戏中不显示？

**A**: 检查：
1. `CHARACTER_ID` 拼写是否正确
2. `SPRITE_PATH` 路径是否存在
3. CSV文件是否正确保存（UTF-8编码）
4. 重启游戏

### Q6: 技能不生效？

**A**: 检查：
1. 技能ID是否正确（在 `config/player/skill_params.csv` 中存在）
2. `player_skill_bindings.csv` 是否正确添加
3. 技能脚本是否存在于 `scenes/skills/players/`
4. 重启游戏

---

## 🔧 高级用法

### 命名规范

#### CHARACTER_ID 规范
- ✅ 使用小写字母
- ✅ 使用下划线分隔单词
- ✅ 使用英文
- ❌ 不要使用空格
- ❌ 不要使用特殊字符

**正确示例**:
```gdscript
const CHARACTER_ID = "fire_mage"
const CHARACTER_ID = "ice_warrior"
const CHARACTER_ID = "shadow_assassin"
```

**错误示例**:
```gdscript
const CHARACTER_ID = "FireMage"      # ❌ 不要用大驼峰
const CHARACTER_ID = "fire mage"     # ❌ 不要用空格
const CHARACTER_ID = "fire-mage"     # ❌ 不要用连字符
const CHARACTER_ID = "火焰法师"       # ❌ 不要用中文
```

### 技能ID规范

技能ID必须在 `config/player/skill_params.csv` 中存在：

```gdscript
# 正确：使用已存在的技能
const SKILL_Q = "skill_wind_path"
const SKILL_E = "skill_storm_eye"

# 如果技能不存在，留空
const SKILL_RMB = ""
```

### 精灵路径规范

确保精灵文件存在：

```gdscript
# 正确：使用存在的精灵
const SPRITE_PATH = "res://assets/sprites/Player_13.png"

# 如果文件不存在，工具会警告但继续执行
```

---

## 📚 相关文档

- `docs/角色创建完整指南_中文.md` - 完整的角色创建指南
- `docs/角色创建快速参考.md` - 快速参考手册
- `docs/CHARACTER_CREATION_GUIDE.md` - 英文指南
- `CHARACTER_CREATION_IMPROVEMENT_SUMMARY.md` - 改进说明

---

## 🆚 与旧版本的区别

### 旧版本（手动）
1. 运行工具
2. 复制控制台输出的CSV配置
3. 手动粘贴到5个CSV文件
4. 手动填写 `CHARACTER_CLASS_NAME`

### 新版本（自动）
1. 修改 `CHARACTER_ID` 和 `CHARACTER_NAME`
2. 运行工具
3. ✅ 完成！

**节省时间**: 从5分钟减少到30秒

---

## 💡 最佳实践

### 1. 创建前规划

在运行工具前，先规划好：
- 角色定位（近战/远程/法师/坦克）
- 基础属性（生命/能量/速度）
- 技能配置（Q/E/LMB）
- 视觉风格（精灵/颜色）

### 2. 使用有意义的ID

```gdscript
# ✅ 好的命名
const CHARACTER_ID = "fire_mage"
const CHARACTER_ID = "ice_warrior"
const CHARACTER_ID = "shadow_assassin"

# ❌ 不好的命名
const CHARACTER_ID = "char1"
const CHARACTER_ID = "test"
const CHARACTER_ID = "aaa"
```

### 3. 先测试默认配置

第一次创建角色时，使用默认配置：
1. 只修改 `CHARACTER_ID` 和 `CHARACTER_NAME`
2. 运行工具
3. 在游戏中测试
4. 然后再调整CSV中的参数

### 4. 版本控制

如果使用Git：
```bash
# 创建角色后提交
git add scenes/unit/players/player_lovely.gd
git add config/player/*.csv
git commit -m "Add new character: lovely"
```

---

## 🎯 下一步

创建角色后：

1. **测试角色**
   ```gdscript
   # 在游戏中
   PlayerFactory.create_player("lovely")
   ```

2. **调整属性**
   - 编辑 `config/player/player_config.csv`
   - 修改生命、能量、速度等

3. **配置技能**
   - 编辑 `config/player/player_skill_bindings.csv`
   - 绑定不同的技能

4. **添加武器**
   - 编辑 `config/player/player_weapons.csv`
   - 添加更多武器

5. **自定义逻辑**
   - 编辑 `player_{CHARACTER_ID}.gd`
   - 添加角色特定的方法和属性

---

**最后更新**: 2026-01-25
**工具版本**: 2.0（自动化版本）

