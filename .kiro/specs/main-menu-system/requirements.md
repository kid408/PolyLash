# 需求文档：PolyLash 主菜单系统

## 简介

为 PolyLash（Godot 4 Roguelike 游戏）设计完整的游戏启动与主菜单系统，包括 Splash Screen、标题界面、主菜单、存档管理、图鉴系统、设置系统和致谢界面。采用深色极简风格（Dark Minimalist），沿用现有灰/黑/绿配色方案，强调策略感与神秘感。

## 术语表

- **Main_Menu_System**: 主菜单系统，包含标题界面、主菜单、存档管理、图鉴、设置和致谢等所有菜单相关功能的总称
- **Title_Screen**: 标题界面，显示游戏 Logo 和"按任意键继续"提示的启动画面
- **Main_Menu**: 主菜单，提供继续游戏、新游戏、加载存档、图鉴、设置、致谢、退出等选项的核心导航界面
- **Save_System**: 存档系统，负责游戏进度的序列化、反序列化和持久化存储的单例模块
- **Save_Slot**: 存档槽位，用于存储单个游戏进度的数据容器，系统提供3个槽位
- **Save_Data**: 存档数据，包含队长头像、当前层数/波次、队伍羁绊摘要、游戏时长、最后游玩时间等信息的结构化数据
- **Compendium**: 图鉴/档案馆，展示已解锁角色、圣物和怪物信息的收藏系统
- **Settings_Panel**: 设置面板，提供常规、显示、音频和游戏性设置的配置界面
- **Credits_Screen**: 致谢/鸣谢界面，以档案清单风格展示游戏使用的素材、作者和协议信息
- **Credits_Item**: 致谢条目，展示单个素材的名称、作者、协议类型和链接的 UI 组件
- **Splash_Screen**: 启动画面，游戏启动时短暂显示工作室 Logo 的过渡界面
- **Confirm_Dialog**: 二次确认弹窗，在执行不可逆操作（如删除存档、退出游戏）前要求用户确认的对话框
- **ConfigManager**: 现有的配置管理器自动加载单例，负责从 CSV 文件加载和缓存游戏配置数据
- **SoundManager**: 现有的音效管理器自动加载单例，负责播放 UI 音效和游戏音效
- **DataManager**: 现有的数据管理器自动加载单例，负责金币和升级数据的持久化
- **Menu_Button**: 主菜单中的可交互按钮，具有 Default、Hover、Pressed 三种视觉状态

## 需求

### 需求 1：启动画面与标题界面

**用户故事：** 作为玩家，我希望在启动游戏时看到一个有氛围感的标题界面，以便感受到游戏的策略感和神秘感。

#### 验收标准

1. WHEN 游戏启动时, THE Splash_Screen SHALL 在纯黑背景上居中显示工作室 Logo，持续1.5秒后以淡出动画过渡到 Title_Screen
2. WHEN Title_Screen 加载完成时, THE Title_Screen SHALL 在深灰色背景(#1a1a1a)上的中上位置显示游戏 Logo，并在屏幕下方三分之一处显示以1秒周期闪烁的"PRESS ANY KEY TO START"提示文本（字体颜色 #AAAAAA）
3. WHEN 玩家在 Title_Screen 按下任意键或点击鼠标时, THE Title_Screen SHALL 播放过渡动画（Logo 在0.5秒内上移至屏幕顶部并缩小至原始尺寸的40%，菜单按钮从屏幕左侧以0.3秒延迟依次淡入滑入）并切换到 Main_Menu
4. WHEN Title_Screen 显示时, THE Title_Screen SHALL 在背景上以每秒10-20像素的速度渲染缓慢流动的几何线条动画，线条颜色使用主色调 #4CAF50 的20%透明度
5. WHEN Title_Screen 处于空闲状态超过30秒未收到任何输入时, THE Title_Screen SHALL 保持当前动画循环播放而不触发任何超时行为

### 需求 2：主菜单导航

**用户故事：** 作为玩家，我希望通过主菜单快速访问游戏的各项功能，以便高效地开始或继续游戏。

#### 验收标准

1. THE Main_Menu SHALL 在屏幕左侧垂直排列显示以下按钮列表：CONTINUE、NEW GAME、LOAD GAME、COMPENDIUM、SETTINGS、CREDITS、QUIT
2. WHEN 存在未结束的存档时, THE Main_Menu SHALL 显示 CONTINUE 按钮作为列表第一项，其字体大小为其他按钮的1.3倍，并使用主色调 #4CAF50 作为文字颜色
3. WHEN 不存在未结束的存档时, THE Main_Menu SHALL 隐藏 CONTINUE 按钮并将 NEW GAME 作为列表第一项
4. WHEN 玩家悬停在 CONTINUE 按钮上时, THE Main_Menu SHALL 在按钮右侧显示一个浮动信息卡片，包含该存档的队长头像、队长名称、当前层数/波次、队伍羁绊摘要和游戏时长
5. WHEN 玩家点击 CONTINUE 按钮时, THE Main_Menu SHALL 直接加载最近一次游玩的存档并跳转至游戏场景
6. WHEN 玩家点击 NEW GAME 按钮时, THE Main_Menu SHALL 以滑动过渡动画跳转至存档槽位选择界面
7. WHEN 玩家点击 LOAD GAME 按钮时, THE Main_Menu SHALL 以滑动过渡动画跳转至存档管理界面
8. WHEN 玩家点击 COMPENDIUM 按钮时, THE Main_Menu SHALL 以滑动过渡动画跳转至图鉴界面
9. WHEN 玩家点击 SETTINGS 按钮时, THE Main_Menu SHALL 以淡入动画打开设置弹窗覆盖层
10. WHEN 玩家点击 CREDITS 按钮时, THE Main_Menu SHALL 以滑动过渡动画跳转至致谢界面
11. WHEN 玩家点击 QUIT 按钮时, THE Main_Menu SHALL 显示 Confirm_Dialog 进行二次确认，对话框包含"确认退出游戏？"文本和"确认"/"取消"两个按钮
12. WHEN 玩家在退出 Confirm_Dialog 中点击确认时, THE Main_Menu_System SHALL 关闭游戏应用程序
13. WHEN 玩家在退出 Confirm_Dialog 中点击取消或按下 ESC 键时, THE Main_Menu_System SHALL 关闭 Confirm_Dialog 并返回主菜单
14. THE Main_Menu SHALL 为每个 Menu_Button 提供三种视觉状态：Default（正常显示）、Hover（Scale 1.05 放大 + 文字颜色变为 #4CAF50 + 播放悬停音效）和 Pressed（Y 方向下沉 2px + 播放点击音效）
15. WHEN 主菜单显示时, THE Main_Menu SHALL 自动将键盘焦点设置在第一个可见按钮上，并支持上下方向键在按钮之间导航
16. WHEN 玩家按下 ESC 键且当前处于子界面（存档管理、图鉴、设置、致谢）时, THE Main_Menu_System SHALL 返回主菜单

### 需求 3：存档管理系统

**用户故事：** 作为玩家，我希望管理多个存档槽位，以便同时维护不同的游戏进度。

#### 验收标准

1. THE Save_System SHALL 提供3个独立的 Save_Slot 用于存储游戏进度
2. WHEN 存档槽位界面显示时, THE Save_System SHALL 为每个 Save_Slot 以卡片形式水平排列显示以下信息：槽位序号（"SLOT 1/2/3"）、状态标签（"空"显示为虚线边框卡片/"进行中"显示为实线边框卡片）、队长头像（64x64像素）、当前层数和波次（格式"第X层 - 波次Y"）、队伍羁绊摘要（最多显示3个羁绊图标）、游戏时长（格式"HH:MM:SS"）和最后游玩时间（格式"YYYY-MM-DD HH:MM"）
3. WHEN 玩家在新游戏流程中选择一个空的 Save_Slot 时, THE Save_System SHALL 在该槽位创建新存档并跳转至角色选择界面（现有的 SelectionPanel）
4. WHEN 玩家在新游戏流程中选择一个已有存档的 Save_Slot 时, THE Save_System SHALL 显示 Confirm_Dialog 确认是否覆盖该存档，对话框包含"该槽位已有存档，是否覆盖？"文本
5. WHEN 玩家确认覆盖存档时, THE Save_System SHALL 清除该槽位的旧数据、创建新存档并跳转至角色选择界面
6. WHEN 玩家在加载存档流程中选择一个有数据的 Save_Slot 时, THE Save_System SHALL 加载该存档数据并跳转至对应的游戏场景
7. WHEN 玩家悬停在有数据的 Save_Slot 卡片上时, THE Save_System SHALL 将卡片边框颜色变为主色调 #4CAF50 并显示"点击加载"或"点击选择"的提示文本
8. WHEN 玩家点击 Save_Slot 卡片右上角的删除图标时, THE Save_System SHALL 显示 Confirm_Dialog 确认是否删除该存档，对话框包含"确认删除该存档？此操作不可撤销。"文本
9. WHEN 玩家确认删除存档时, THE Save_System SHALL 永久删除该 Save_Slot 的数据文件并将卡片更新为空槽位状态
10. THE Save_System SHALL 使用 JSON 格式将 Save_Data 序列化后存储到 user://saves/ 目录，文件命名格式为 save_slot_N.json（N 为槽位序号1-3）
11. WHEN Save_System 读取存档文件时, THE Save_System SHALL 对 JSON 数据进行反序列化并验证必要字段（版本号、队长ID、层数、波次、时间戳）的存在性和类型正确性
12. IF 存档文件损坏或格式无效, THEN THE Save_System SHALL 将该 Save_Slot 卡片标记为"存档损坏"状态（显示警告图标和红色边框），同时保留原始文件不做删除
13. WHEN 存档槽位界面显示时, THE Save_System SHALL 在界面顶部显示"选择存档槽位"标题和返回按钮，返回按钮点击后回到主菜单

### 需求 4：图鉴系统

**用户故事：** 作为玩家，我希望查看已解锁的角色、圣物和怪物信息，以便了解游戏内容和制定策略。

#### 验收标准

1. THE Compendium SHALL 在界面顶部提供三个一级导航 Tab 按钮：Characters（英灵/角色）、Relics（圣物/遗物）、Monsters（怪谈），当前选中的 Tab 使用主色调 #4CAF50 下划线高亮
2. WHEN 玩家切换 Tab 时, THE Compendium SHALL 以淡入动画显示对应分类的内容网格列表
3. WHEN 角色未解锁时, THE Compendium SHALL 将该角色的网格卡片显示为黑色剪影（对原始头像应用纯黑色调制）并在卡片中心叠加锁图标，卡片下方显示"???"代替角色名称
4. WHEN 角色已解锁时, THE Compendium SHALL 显示该角色的完整头像卡片，卡片下方显示角色名称，悬停时卡片边框发光
5. WHEN 玩家点击已解锁的角色卡片时, THE Compendium SHALL 在右侧或弹窗中显示该角色的详细信息面板，包含：全身像、名称、羁绊标签、基础属性（生命值、护甲、速度、能量）和技能描述
6. THE Compendium SHALL 从 ConfigManager 读取角色、圣物和怪物的配置数据来填充内容
7. WHEN 显示 Relics 分类时, THE Compendium SHALL 按 Tier 等级（Tier 1/2/3）对圣物进行分组展示，每组使用对应稀有度颜色的分隔标题（Tier 1 白色、Tier 2 蓝色、Tier 3 紫色）
8. WHEN 圣物未解锁时, THE Compendium SHALL 将该圣物显示为暗色轮廓并附加锁图标
9. WHEN 玩家点击已解锁的圣物卡片时, THE Compendium SHALL 显示该圣物的名称、Tier 等级、效果描述和修正属性
10. WHEN 显示 Monsters 分类时, THE Compendium SHALL 以网格形式展示玩家已遭遇过的敌人，每个卡片显示敌人头像和名称
11. WHEN 玩家点击已遭遇的怪物卡片时, THE Compendium SHALL 显示该怪物的名称、基础属性（生命值、攻击力、移动速度）和简要描述
12. THE Compendium SHALL 在界面右上角显示各分类的解锁进度（格式"已解锁 X/Y"）
13. WHEN Compendium 界面显示时, THE Compendium SHALL 在界面顶部左侧显示返回按钮，点击后回到主菜单

### 需求 5：设置系统

**用户故事：** 作为玩家，我希望自定义游戏的显示、音频和操控设置，以便获得最佳的游戏体验。

#### 验收标准

1. THE Settings_Panel SHALL 以弹窗覆盖层形式显示，背景使用半透明黑色遮罩（透明度70%），面板居中显示并提供四个设置分类 Tab：常规、显示、音频、游戏性/控制
2. WHEN 显示常规设置时, THE Settings_Panel SHALL 提供语言选择下拉框（默认中文）和云存档开关（标注"即将推出"并置灰不可交互）
3. WHEN 显示显示设置时, THE Settings_Panel SHALL 提供以下配置项：分辨率下拉框（包含1280x720、1600x900、1920x1080、2560x1440选项）、显示模式下拉框（窗口/全屏/无边框窗口）、垂直同步开关、帧率限制下拉框（30/60/120/不限制）和屏幕震动强度滑动条（0-100%，步进1%，显示当前数值）
4. WHEN 显示音频设置时, THE Settings_Panel SHALL 提供以下滑动条配置项：主音量（0-100%）、BGM 音量（0-100%）、SFX 音量（0-100%）和 UI 音效音量（0-100%），每个滑动条左侧显示标签名称、右侧显示当前百分比数值
5. WHEN 显示游戏性设置时, THE Settings_Panel SHALL 提供以下配置项：画线灵敏度滑动条（低/中/高三档）、智能施法/辅助画线开关、技能释放模式下拉框（按下释放/点击释放）和伤害数字显示开关
6. WHEN 玩家修改音量滑动条时, THE Settings_Panel SHALL 立即应用音量变更，使玩家能实时听到调整效果
7. WHEN 玩家修改显示设置时, THE Settings_Panel SHALL 立即应用显示变更（分辨率、全屏模式等）
8. THE Settings_Panel SHALL 将所有设置数据序列化为 JSON 格式并持久化存储到 user://settings.json 文件
9. WHEN Settings_Panel 加载时, THE Settings_Panel SHALL 从 user://settings.json 读取并反序列化已保存的设置，将所有 UI 控件恢复到上次保存的状态
10. IF 设置文件不存在或损坏, THEN THE Settings_Panel SHALL 使用预定义的默认值初始化所有设置项（主音量100%、分辨率1920x1080、全屏模式、垂直同步开启、帧率不限制、屏幕震动100%）
11. WHEN 玩家点击设置面板右上角的关闭按钮或按下 ESC 键时, THE Settings_Panel SHALL 自动保存当前设置并以淡出动画关闭面板

### 需求 6：致谢界面

**用户故事：** 作为玩家，我希望查看游戏使用的素材和贡献者信息，以便了解游戏的创作背景并尊重原作者的版权。

#### 验收标准

1. THE Credits_Screen SHALL 以档案清单风格显示，左侧提供分类筛选按钮（All、Art、Audio、Font、Code、Special），右侧为可滚动的条目列表
2. THE Credits_Screen SHALL 从 config/system/credits_config.csv 文件读取致谢数据，CSV 包含以下字段：id、category、asset_name、author、license_type、url、description
3. WHEN 玩家选择分类筛选按钮时, THE Credits_Screen SHALL 仅显示该分类下的 Credits_Item 条目
4. THE Credits_Screen SHALL 为每个 Credits_Item 显示一个60像素高的长条卡片，包含：左侧分类标签（如"[Art]"）、中间上方素材名称（白色 #FFFFFF）、中间下方作者和协议信息（灰色 #AAAAAA，格式"by [Author] • [License_Type]"）、右侧链接图标按钮
5. WHEN 玩家点击 Credits_Item 的链接图标按钮时, THE Credits_Screen SHALL 调用系统浏览器打开该条目的 URL 链接
6. WHEN 玩家悬停在 Credits_Item 卡片上时, THE Credits_Screen SHALL 将卡片背景色从 #222222 变为 #2a2a2a 并显示 description 字段内容作为 tooltip
7. THE Credits_Screen SHALL 在列表底部显示一行版权声明文本："本游戏使用的部分素材遵循 CC-BY 等开源协议，版权归原作者所有。"
8. WHEN Credits_Screen 界面显示时, THE Credits_Screen SHALL 在界面顶部显示"鸣谢 / Attribution"标题和返回按钮，返回按钮点击后回到主菜单

### 需求 7：视觉与交互规范

**用户故事：** 作为玩家，我希望主菜单的视觉风格和交互反馈保持一致且流畅，以便获得沉浸式的菜单体验。

#### 验收标准

1. THE Main_Menu_System SHALL 使用以下配色方案：背景色 #1a1a1a、主色调 #4CAF50（绿色）、次色调 #B08D55（金色/棕色）、主文本色 #FFFFFF、次文本色 #AAAAAA
2. WHEN 玩家悬停在可交互按钮上时, THE Main_Menu_System SHALL 通过 SoundManager 播放 "ui_hover" 悬停音效并显示视觉反馈（Scale 1.05 放大或边缘发光效果），动画时长0.15秒
3. WHEN 玩家点击可交互按钮时, THE Main_Menu_System SHALL 通过 SoundManager 播放 "ui_click" 点击音效并显示按下反馈（Y 方向下沉 2px），动画时长0.1秒
4. WHEN 界面之间发生切换时, THE Main_Menu_System SHALL 使用0.3秒的淡入淡出或滑动过渡动画效果
5. THE Main_Menu_System SHALL 使用项目现有的 "Bake Soda.otf" 字体作为菜单标题和按钮的显示字体

### 需求 8：存档数据序列化

**用户故事：** 作为开发者，我希望存档数据能够可靠地序列化和反序列化，以便确保玩家进度不会丢失。

#### 验收标准

1. THE Save_System SHALL 将 Save_Data 对象序列化为格式化的 JSON 字符串（使用制表符缩进）并写入 user://saves/save_slot_N.json 文件
2. WHEN 读取存档文件时, THE Save_System SHALL 将 JSON 字符串反序列化为 Save_Data 字典对象
3. FOR ALL 有效的 Save_Data 对象, 序列化后再反序列化 SHALL 产生与原始对象等价的 Save_Data（往返一致性）
4. THE Save_System SHALL 在 Save_Data 中包含 "version" 整数字段（初始值为1），用于未来的存档格式迁移
5. THE Save_System SHALL 在 Save_Data 中包含以下必要字段：version（版本号）、slot_index（槽位序号）、leader_id（队长角色ID）、selected_players（已选角色列表）、current_floor（当前层数）、current_wave（当前波次）、play_time_seconds（游戏时长秒数）、last_played_timestamp（最后游玩的 Unix 时间戳）、bond_summary（队伍羁绊摘要列表）
