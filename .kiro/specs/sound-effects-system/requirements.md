# 需求文档：PolyLash 音效系统

## 简介

为 PolyLash（Godot 4.5 Roguelike 游戏）设计并实现一套完整的、CSV 驱动的音效管理系统。该系统将替代当前 `Global.gd` 中硬编码的音效播放逻辑，引入新的 `SoundManager` 自动加载节点，支持分类 CSV 配置、音效预加载、冷却防刷、随机变体选择，以及每角色 Q 技能闭合独立音效。

## 术语表

- **SoundManager**: 新建的音效管理自动加载节点（`autoloads/sound_manager.gd`），负责加载 CSV 配置、预加载音频资源、提供分类播放接口
- **Global**: 现有的全局自动加载节点（`autoloads/global.gd`），包含 32 槽 AudioStreamPlayer 对象池
- **ConfigManager**: 现有的配置管理器（`autoloads/config_manager.gd`），负责加载所有 CSV 配置
- **CSV 音效配置**: 存放在 `config/audio/` 目录下的分类 CSV 文件，定义音效 ID、文件路径、音量、音调范围、冷却时间等参数
- **音效组（Sound_Group）**: 一组具有相同 `group` 标识的音效条目，播放时随机选取其中一条，用于增加听感丰富度
- **冷却时间（Cooldown）**: 同一音效两次播放之间的最小间隔（秒），防止高频事件导致音效刷屏
- **占位音频（Placeholder）**: 开发阶段使用的临时音频文件，复制自 `assets/audio/UI Pop.mp3` 并转换为 `.wav` 格式重命名
- **Q 闭合音效**: 每个角色 Q 技能画线闭合时播放的独特音效，通过 `player_config.csv` 的 `q_closure_sfx` 列配置

## 需求

### 需求 1：SoundManager 自动加载节点（独立、低耦合、高复用）

**用户故事：** 作为系统架构师，我希望有一个完全独立的音效管理节点，以便将音效逻辑与游戏逻辑彻底解耦，实现高复用性和可维护性。

#### 验收标准

1. THE SoundManager SHALL 作为 Godot 自动加载节点注册在项目设置中，在游戏启动时自动初始化
2. THE SoundManager SHALL 拥有独立的 AudioStreamPlayer 对象池，不依赖 Global 节点的对象池进行音频播放
3. WHEN SoundManager 初始化时，THE SoundManager SHALL 从 `config/audio/` 目录加载所有分类 CSV 音效配置文件
4. WHEN SoundManager 初始化时，THE SoundManager SHALL 预加载所有 CSV 中引用的音频资源文件到内存缓存
5. THE SoundManager SHALL 仅通过 `sound_id` 字符串作为外部调用接口，调用方无需了解音频文件路径、音量、音调等内部细节
6. THE SoundManager SHALL 不依赖任何游戏业务节点（如 Global、Player、Enemy），仅接收 sound_id 参数即可完成播放
7. IF CSV 中引用的音频文件不存在，THEN THE SoundManager SHALL 在控制台输出警告信息并跳过该条目的预加载

### 需求 2：分类 CSV 音效配置

**用户故事：** 作为音效设计师，我希望通过 CSV 文件配置所有音效参数，以便无需修改代码即可调整音效行为。

#### 验收标准

1. THE ConfigManager SHALL 加载以下四个分类 CSV 配置文件：`config/audio/ui_sounds.csv`、`config/audio/combat_sounds.csv`、`config/audio/skill_sounds.csv`、`config/audio/environment_sounds.csv`
2. THE CSV 配置文件 SHALL 包含以下列：`sound_id`（主键）、`sound_path`（音频文件路径）、`volume_db`（音量）、`min_pitch`（最小音调）、`max_pitch`（最大音调）、`cooldown`（冷却时间）、`group`（音效组标识）、`description`（描述）
3. WHEN 通过 `sound_id` 查询音效配置时，THE SoundManager SHALL 返回该音效的完整配置字典
4. WHEN CSV 文件遵循项目标准格式（首行列名、第二行 `-1` 注释行、后续数据行）时，THE ConfigManager SHALL 正确解析所有数据行

### 需求 3：音效播放核心功能

**用户故事：** 作为游戏设计师，我希望音效播放支持音调随机化、音量控制和冷却防刷，以便获得丰富且不刺耳的听感。

#### 验收标准

1. WHEN 播放一个音效时，THE SoundManager SHALL 在该音效配置的 `min_pitch` 和 `max_pitch` 范围内随机选取音调值
2. WHEN 同一 `sound_id` 的音效在冷却时间内被再次请求播放时，THE SoundManager SHALL 忽略该请求
3. WHEN 播放一个属于某音效组的音效时，THE SoundManager SHALL 从该组的所有音效条目中随机选取一条进行播放
4. THE SoundManager SHALL 提供分类播放方法：`play_ui(sound_id)`、`play_combat(sound_id)`、`play_skill(sound_id)`、`play_environment(sound_id)`

### 需求 4：UI 音效

**用户故事：** 作为玩家，我希望 UI 交互有清晰的音效反馈，以便获得流畅的操作体验。

#### 验收标准

1. WHEN 玩家点击 UI 按钮时，THE SoundManager SHALL 播放按钮点击音效
2. WHEN 商店面板、升级面板或选择面板打开或关闭时，THE SoundManager SHALL 播放对应的面板开关音效
3. WHEN 玩家在商店中购买物品时，THE SoundManager SHALL 播放购买确认音效
4. WHEN 玩家选择升级属性时，THE SoundManager SHALL 播放升级选择确认音效
5. WHEN 玩家执行无效操作（如金币不足）时，THE SoundManager SHALL 播放错误提示音效
6. WHEN 游戏暂停或恢复时，THE SoundManager SHALL 播放暂停/恢复音效

### 需求 5：角色/玩家音效

**用户故事：** 作为玩家，我希望角色动作有对应的音效反馈，以便感知角色状态变化。

#### 验收标准

1. WHEN 玩家角色受到伤害时，THE SoundManager SHALL 播放受击音效
2. WHEN 玩家角色护甲被击破时，THE SoundManager SHALL 播放护甲破碎音效
3. WHEN 玩家角色死亡时，THE SoundManager SHALL 播放死亡音效
4. WHEN 玩家角色冲刺时，THE SoundManager SHALL 播放冲刺音效
5. WHEN 玩家获得能量时，THE SoundManager SHALL 播放能量获取音效
6. WHEN 玩家能量不足无法施放技能时，THE SoundManager SHALL 播放能量不足提示音效
7. WHEN 玩家升级或达到经验里程碑时，THE SoundManager SHALL 播放升级音效
8. WHEN 玩家拾取金币时，THE SoundManager SHALL 播放金币拾取音效
9. WHEN 玩家通过 1-2-3 键成功切换角色时，THE SoundManager SHALL 播放角色切换音效
10. WHEN 玩家尝试切换角色但处于冷却中或目标已死亡时，THE SoundManager SHALL 播放切换失败音效
11. WHEN 超级护甲羁绊触发时，THE SoundManager SHALL 播放超级护甲触发音效

### 需求 6：战斗音效

**用户故事：** 作为玩家，我希望战斗中有丰富的音效反馈，以便获得打击感和战斗节奏感。

#### 验收标准

1. WHEN 敌人被击中时，THE SoundManager SHALL 播放敌人受击音效
2. WHEN 敌人死亡时，THE SoundManager SHALL 播放敌人死亡音效（支持按敌人类型选择变体）
3. WHEN 敌人进入冲锋预警阶段时，THE SoundManager SHALL 播放冲锋预警音效
4. WHEN 敌人开始冲锋时，THE SoundManager SHALL 播放冲锋音效
5. WHEN 暴击触发时，THE SoundManager SHALL 播放暴击音效
6. WHEN 闭环绞杀触发时，THE SoundManager SHALL 播放闭环绞杀音效
7. WHEN 爆炸效果触发时，THE SoundManager SHALL 播放爆炸音效
8. WHEN 敌人被施加异常状态（burn/curse/poison/slow/freeze/stun）时，THE SoundManager SHALL 根据状态类型播放对应的异常状态音效
9. WHEN 地雷怪死亡生成毒池时，THE SoundManager SHALL 播放毒池生成音效

### 需求 7：技能音效

**用户故事：** 作为玩家，我希望技能施放有层次分明的音效反馈，以便感知技能的不同阶段。

#### 验收标准

1. WHEN 玩家按下 Q 键进入规划模式时，THE SoundManager SHALL 播放子弹时间进入音效
2. WHEN 玩家开始画线时，THE SoundManager SHALL 播放画线开始音效
3. WHEN 画线过程中检测到闭合时，THE SoundManager SHALL 播放闭合检测提示音效
4. WHEN Q 技能闭合区域执行时，THE SoundManager SHALL 根据当前角色的 `player_config.csv` 中 `q_closure_sfx` 列配置播放该角色专属的闭合执行音效
5. WHEN Q 技能开放路径执行时，THE SoundManager SHALL 播放开放路径执行音效
6. WHEN 画线过程中能量耗尽时，THE SoundManager SHALL 播放能量耗尽音效
7. WHEN 玩家施放 E 技能时，THE SoundManager SHALL 根据技能类型（瞬发/AOE）播放对应的通用 E 技能音效
8. WHEN 玩家激活 F 技能（终极技能）时，THE SoundManager SHALL 播放终极技能激活音效
9. WHEN 玩家的 F 技能结束时，THE SoundManager SHALL 播放终极技能结束音效

### 需求 8：每角色 Q 闭合独立音效配置

**用户故事：** 作为游戏设计师，我希望每个角色的 Q 技能闭合效果有独特的音效，以便增强角色辨识度。

#### 验收标准

1. THE `player_config.csv` SHALL 新增 `q_closure_sfx` 列，存储每个角色专属的 Q 闭合音效文件路径
2. WHEN SoundManager 需要播放 Q 闭合音效时，THE SoundManager SHALL 从 ConfigManager 获取当前角色的 `q_closure_sfx` 配置并播放对应音频
3. IF 角色的 `q_closure_sfx` 列为空或文件不存在，THEN THE SoundManager SHALL 回退到通用的 Q 闭合音效

### 需求 9：羁绊机制音效

**用户故事：** 作为玩家，我希望羁绊机制触发时有音效反馈，以便感知羁绊效果的激活。

#### 验收标准

1. WHEN 羁绊机制触发时，THE SoundManager SHALL 播放对应的羁绊触发音效
2. THE SoundManager SHALL 为以下高辨识度羁绊提供独立音效：chain_reaction（连锁反应）、permanent_cage（永久牢笼）、soul_attach（灵魂附着计数）、gold_trail（金币轨迹）、thorns_wall（反伤墙）、small_shape_crit（小图形暴击）
3. WHEN 未配置独立音效的羁绊触发时，THE SoundManager SHALL 播放通用羁绊触发音效

### 需求 10：环境/游戏状态音效

**用户故事：** 作为玩家，我希望游戏状态变化有音效提示，以便感知游戏进程。

#### 验收标准

1. WHEN 新波次开始时，THE SoundManager SHALL 播放波次开始音效
2. WHEN 波次完成时，THE SoundManager SHALL 播放波次完成音效
3. WHEN 商店界面打开时，THE SoundManager SHALL 播放商店开启音效
4. WHEN 商店界面关闭并进入下一波时，THE SoundManager SHALL 播放商店关闭音效
5. WHEN 宝箱出现时，THE SoundManager SHALL 播放宝箱出现音效
6. WHEN 宝箱被打开时，THE SoundManager SHALL 播放宝箱打开音效
7. WHEN 游戏结束时，THE SoundManager SHALL 播放游戏结束音效

### 需求 11：现有硬编码音效迁移

**用户故事：** 作为系统架构师，我希望将 `Global.gd` 中现有的硬编码音效调用迁移到 SoundManager 的 CSV 配置驱动模式，以便统一管理所有音效并消除 Global 节点中的音效职责。

#### 验收标准

1. WHEN 迁移完成后，THE SoundManager SHALL 接管以下现有音效的播放：`play_enemy_death`、`play_loop_kill_impact`、`play_player_death`、`play_player_dash`、`play_player_explosion`
2. WHEN 迁移完成后，THE Global 节点 SHALL 移除所有音效相关的 preload 变量（`sfx_enemy_pop`、`sfx_player_shatter` 等）和专用播放方法（`play_enemy_death` 等），仅保留对象池供 SoundManager 内部使用或完全由 SoundManager 自建对象池替代
3. WHEN 迁移完成后，所有调用旧 `Global.play_*` 方法的代码 SHALL 改为调用 SoundManager 的对应方法
4. THE 迁移过程 SHALL 保持所有现有音效的播放行为（音量、音调范围）与迁移前一致

### 需求 12：音频资源文件组织

**用户故事：** 作为音效设计师，我希望音频文件按类别组织在子目录中，以便快速定位和管理音频资源。

#### 验收标准

1. THE 音频资源 SHALL 按以下目录结构组织：`assets/audio/ui/`、`assets/audio/player/`、`assets/audio/combat/`、`assets/audio/skill/`、`assets/audio/enemy/`、`assets/audio/environment/`
2. WHEN 新增音效条目时，THE 占位音频文件 SHALL 被创建在对应的子目录中
3. THE 现有根目录下的音频文件（如 `dash.wav`、`pop_squish.wav` 等）SHALL 保留在原位置，CSV 配置中引用其原始路径
