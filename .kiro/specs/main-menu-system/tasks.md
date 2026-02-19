# 实现计划：PolyLash 主菜单系统

## 概述

基于设计文档，将主菜单系统拆分为增量式编码任务。每个任务构建在前一个任务之上，确保无孤立代码。使用 GDScript，目标框架为 Godot 4.5。

## 任务

- [x] 1. 创建 SaveManager 自动加载单例
  - [x] 1.1 创建 `autoloads/save_manager.gd`，实现核心存档数据结构和序列化/反序列化方法
    - 实现 `serialize_save_data(data: Dictionary) -> String` 方法，将字典序列化为格式化 JSON
    - 实现 `deserialize_save_data(json_string: String) -> Dictionary` 方法，将 JSON 反序列化为字典
    - 实现 `validate_save_data(data: Dictionary) -> bool` 方法，验证必要字段（version, slot_index, leader_id, selected_players, current_floor, current_wave, play_time_seconds, last_played_timestamp, bond_summary）
    - 实现 `_ensure_save_dir()` 方法，确保 user://saves/ 目录存在
    - _Requirements: 8.1, 8.2, 8.3, 8.4, 8.5, 3.10, 3.11_

  - [ ]* 1.2 编写存档数据往返一致性属性测试
    - **Property 1: 存档数据往返一致性**
    - 生成随机有效 Save_Data 字典，测试 serialize → deserialize 产生等价对象
    - **Validates: Requirements 8.3, 8.1, 8.2, 3.6, 3.10**

  - [ ]* 1.3 编写存档数据验证属性测试
    - **Property 2: 存档数据验证完整性**
    - 生成随机字典（有效和无效），测试 validate_save_data 的正确性
    - **Validates: Requirements 3.11, 3.12, 8.4, 8.5**

  - [x] 1.4 实现存档槽位管理方法
    - 实现 `_load_all_slots()` 从文件系统加载3个槽位数据
    - 实现 `get_slot_data(slot_index)`, `is_slot_empty(slot_index)`, `is_slot_corrupted(slot_index)`
    - 实现 `create_new_save(slot_index, leader_id, selected_players)` 创建新存档
    - 实现 `save_game_progress(slot_index, data)` 保存游戏进度
    - 实现 `load_game_save(slot_index)` 加载存档
    - 实现 `delete_save(slot_index)` 删除存档
    - 实现 `get_most_recent_slot()` 和 `has_any_save()` 查询方法
    - _Requirements: 3.1, 3.3, 3.5, 3.6, 3.9, 2.2, 2.3, 2.5_

  - [ ]* 1.5 编写存档槽位管理属性测试
    - **Property 3: 存档创建后槽位非空**
    - **Property 4: 存档删除后槽位为空**
    - **Property 5: CONTINUE 可见性与存档状态一致**
    - **Validates: Requirements 3.3, 3.5, 3.9, 2.2, 2.3**

  - [x] 1.6 实现设置管理方法
    - 实现 `get_default_settings()` 返回默认设置字典
    - 实现 `get_setting(key, default_value)`, `set_setting(key, value)`
    - 实现 `save_settings()` 和 `load_settings()` JSON 持久化
    - 实现 `apply_display_settings()` 和 `apply_audio_settings()` 应用设置
    - _Requirements: 5.7, 5.8, 5.9, 5.10_

  - [ ]* 1.7 编写设置数据往返一致性属性测试
    - **Property 6: 设置数据往返一致性**
    - **Validates: Requirements 5.8, 5.9**

  - [x] 1.8 在 project.godot 中注册 SaveManager 为自动加载单例
    - _Requirements: 3.1_

- [x] 2. 检查点 - 确保 SaveManager 所有测试通过
  - 确保所有测试通过，如有问题请询问用户。

- [x] 3. 实现辅助工具函数和 ConfigManager 扩展
  - [x] 3.1 在 SaveManager 中实现时间格式化工具函数
    - 实现 `format_play_time(seconds: int) -> String` 将秒数转为 "HH:MM:SS" 格式
    - 实现 `format_last_played(timestamp: int) -> String` 将 Unix 时间戳转为 "YYYY-MM-DD HH:MM" 格式
    - _Requirements: 3.2_

  - [ ]* 3.2 编写时间格式化属性测试
    - **Property 11: 游戏时长格式化正确性**
    - **Validates: Requirements 3.2**

  - [x] 3.3 扩展 ConfigManager 加载 credits_config.csv
    - 在 ConfigManager 中添加 `credits_configs` 字典和 `_load_credits_configs()` 方法
    - 添加 `get_credits_configs() -> Array[Dictionary]` 访问方法
    - 创建 `config/system/credits_config.csv` 模板文件
    - _Requirements: 6.2_

- [x] 4. 创建 SplashScreen 启动画面场景
  - [x] 4.1 创建 `scenes/ui/main_menu/splash_screen.tscn` 和 `splash_screen.gd`
    - 纯黑背景 + 居中 Logo TextureRect
    - 1.5秒显示后淡出过渡到 MainMenuRoot 场景
    - 更新 project.godot 的 `run/main_scene` 指向 splash_screen.tscn
    - _Requirements: 1.1_

- [x] 5. 创建 MainMenuRoot 根场景和 TitleScreen
  - [x] 5.1 创建 `scenes/ui/main_menu/main_menu_root.tscn` 和 `main_menu_root.gd`
    - 作为所有子界面的容器，管理子场景切换
    - 实现 `switch_to(screen, transition)` 方法，支持淡入淡出和滑动过渡（0.3秒）
    - 实现 `go_to_main_menu()`, `go_to_save_slots(mode)`, `go_to_compendium()`, `go_to_credits()`, `open_settings()`, `close_settings()` 导航方法
    - 实现 ESC 键返回主菜单的全局输入处理
    - _Requirements: 2.16, 7.4_

  - [x] 5.2 创建 `scenes/ui/main_menu/title_screen.tscn` 和 `title_screen.gd`
    - 深灰色背景(#1a1a1a) + 中上位置 Logo + 下方闪烁提示文本
    - 实现提示文本1秒周期闪烁动画
    - 实现背景几何线条流动动画（使用 Line2D 或自定义 _draw）
    - 实现任意键/鼠标点击检测，触发 `any_key_pressed` 信号
    - 实现过渡动画：Logo 上移缩小 + 菜单按钮依次淡入
    - _Requirements: 1.2, 1.3, 1.4, 1.5_

- [x] 6. 创建 MainMenu 主菜单界面
  - [x] 6.1 创建 `scenes/ui/main_menu/menu_button.tscn` 和 `menu_button.gd` 按钮预制体
    - 实现三种视觉状态：Default、Hover（Scale 1.05 + 文字变色 #4CAF50）、Pressed（Y+2px 下沉）
    - 集成 SoundManager 播放 "ui_hover" 和 "ui_click" 音效
    - 使用 Tween 实现0.15秒悬停动画和0.1秒按下动画
    - _Requirements: 2.14, 7.2, 7.3_

  - [x] 6.2 创建 `scenes/ui/main_menu/main_menu.tscn` 和 `main_menu.gd`
    - 屏幕左侧垂直排列按钮列表：CONTINUE, NEW GAME, LOAD GAME, COMPENDIUM, SETTINGS, CREDITS, QUIT
    - 根据 SaveManager.has_any_save() 控制 CONTINUE 按钮显示/隐藏
    - CONTINUE 按钮字体1.3倍大小 + #4CAF50 文字颜色
    - 实现 CONTINUE 悬停时右侧浮动信息卡片（队长头像、名称、层数/波次、时长）
    - 实现键盘焦点导航（自动聚焦第一个按钮 + 上下方向键）
    - 发出 `menu_action` 信号供 MainMenuRoot 处理
    - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5, 2.6, 2.7, 2.8, 2.9, 2.10, 2.11, 2.15_

  - [x] 6.3 实现退出确认对话框
    - 复用现有 ExitConfirmDialog 模式或创建通用 ConfirmDialog
    - 支持自定义确认文本和确认/取消回调
    - 支持 ESC 键取消
    - _Requirements: 2.11, 2.12, 2.13_

- [x] 7. 创建 SaveSlotPanel 存档管理界面
  - [x] 7.1 创建 `scenes/ui/main_menu/save_slot_card.tscn` 和 `save_slot_card.gd` 卡片预制体
    - 显示槽位序号、状态标签、队长头像(64x64)、层数/波次、羁绊图标、游戏时长、最后游玩时间
    - 空槽位：虚线边框 + "空" 标签
    - 进行中：实线边框 + 完整信息
    - 损坏：红色边框 + 警告图标
    - 悬停效果：边框变为 #4CAF50
    - 右上角删除按钮（仅非空槽位显示）
    - _Requirements: 3.2, 3.7, 3.12_

  - [x] 7.2 创建 `scenes/ui/main_menu/save_slot_panel.tscn` 和 `save_slot_panel.gd`
    - 顶部标题 + 返回按钮
    - 水平排列3个 SaveSlotCard
    - 支持 "new_game" 和 "load" 两种模式
    - new_game 模式：空槽位直接创建，非空槽位弹出覆盖确认
    - load 模式：仅非空槽位可点击加载
    - 删除操作弹出确认对话框
    - 连接 MainMenuRoot 导航（跳转角色选择或加载游戏）
    - _Requirements: 3.1, 3.3, 3.4, 3.5, 3.6, 3.8, 3.9, 3.13_

- [x] 8. 检查点 - 确保主菜单核心流程可用
  - 确保所有测试通过，如有问题请询问用户。
  - 验证：启动 → Splash → Title → MainMenu → 存档管理 流程完整可用

- [x] 9. 创建 SettingsPanel 设置弹窗
  - [x] 9.1 创建 `scenes/ui/main_menu/settings_panel.tscn` 和 `settings_panel.gd`
    - CanvasLayer 弹窗，半透明黑色遮罩(70%透明度)，面板居中
    - 四个 Tab：常规、显示、音频、游戏性/控制
    - 常规 Tab：语言下拉框 + 云存档开关（置灰"即将推出"）
    - 显示 Tab：分辨率下拉框、显示模式下拉框、垂直同步开关、帧率限制下拉框、屏幕震动滑动条(0-100%)
    - 音频 Tab：主音量/BGM/SFX/UI 四个滑动条(0-100%)，右侧显示百分比数值
    - 游戏性 Tab：画线灵敏度滑动条、智能施法开关、技能释放模式下拉框、伤害数字开关
    - 修改即时生效，关闭时自动保存
    - 支持 ESC 键关闭
    - process_mode = PROCESS_MODE_ALWAYS
    - _Requirements: 5.1, 5.2, 5.3, 5.4, 5.5, 5.6, 5.7, 5.10, 5.11_

- [x] 10. 创建 CompendiumScreen 图鉴界面
  - [x] 10.1 创建 `scenes/ui/main_menu/compendium_screen.tscn` 和 `compendium_screen.gd`
    - 顶部三个 Tab 按钮（Characters/Relics/Monsters），选中 Tab 使用 #4CAF50 下划线
    - 右上角解锁进度标签（"已解锁 X/Y"）
    - 左上角返回按钮
    - ScrollContainer + GridContainer 内容网格
    - Characters Tab：从 ConfigManager.player_configs 读取，未解锁显示黑色剪影+锁+???，已解锁显示头像+名称
    - Relics Tab：从 ConfigManager.item_configs_new 读取，按 tier 分组（Tier 1 白色/Tier 2 蓝色/Tier 3 紫色标题）
    - Monsters Tab：从 ConfigManager.enemy_configs 读取，显示已遭遇敌人
    - _Requirements: 4.1, 4.2, 4.3, 4.4, 4.6, 4.7, 4.8, 4.10, 4.12, 4.13_

  - [x] 10.2 创建 `scenes/ui/main_menu/compendium_detail_panel.tscn` 和 `compendium_detail_panel.gd`
    - 角色详情：全身像、名称、羁绊标签、基础属性、技能描述
    - 圣物详情：名称、Tier、效果描述、修正属性
    - 怪物详情：名称、基础属性、简要描述
    - 点击卡片时在右侧或弹窗中显示
    - _Requirements: 4.5, 4.9, 4.11_

  - [ ]* 10.3 编写图鉴逻辑属性测试
    - **Property 7: 图鉴解锁状态一致性**
    - **Property 8: 圣物按 Tier 分组正确性**
    - **Property 9: 图鉴解锁进度计算**
    - **Validates: Requirements 4.3, 4.4, 4.7, 4.12**

- [x] 11. 创建 CreditsScreen 致谢界面
  - [x] 11.1 创建 `scenes/ui/main_menu/credits_screen.tscn` 和 `credits_screen.gd`
    - 左侧分类筛选按钮（All/Art/Audio/Font/Code/Special）
    - 右侧 ScrollContainer + VBoxContainer 条目列表
    - 从 ConfigManager.get_credits_configs() 读取数据
    - 实现分类筛选逻辑
    - 顶部标题"鸣谢 / Attribution" + 返回按钮
    - 底部版权声明文本
    - _Requirements: 6.1, 6.2, 6.3, 6.7, 6.8_

  - [x] 11.2 创建 `scenes/ui/main_menu/credits_item.tscn` 和 `credits_item.gd` 条目预制体
    - 60px 高长条卡片：左侧分类标签、中间素材名称+作者协议、右侧链接按钮
    - 悬停效果：背景色 #222222 → #2a2a2a + tooltip 显示 description
    - 链接按钮点击调用 OS.shell_open(url)
    - _Requirements: 6.4, 6.5, 6.6_

  - [ ]* 11.3 编写致谢筛选属性测试
    - **Property 10: 致谢分类筛选正确性**
    - **Validates: Requirements 6.3**

- [x] 12. 视觉风格统一和整合
  - [x] 12.1 统一所有界面的配色方案和字体
    - 确保所有界面使用 #1a1a1a 背景、#4CAF50 主色调、#B08D55 次色调
    - 确保所有界面使用 "Bake Soda.otf" 字体
    - 确保所有过渡动画使用0.3秒时长
    - _Requirements: 7.1, 7.4, 7.5_

  - [x] 12.2 将所有子场景集成到 MainMenuRoot 中
    - 在 main_menu_root.tscn 中添加所有子场景实例
    - 连接所有导航信号和回调
    - 测试完整导航流程：Splash → Title → MainMenu → 各子界面 → 返回
    - _Requirements: 2.6, 2.7, 2.8, 2.9, 2.10, 2.16_

- [x] 13. 最终检查点 - 确保所有测试通过，完整流程可用
  - 确保所有测试通过，如有问题请询问用户。
  - 验证完整流程：启动 → Splash → Title → MainMenu → 所有子界面导航 → 返回 → 退出

## 备注

- 标记 `*` 的任务为可选任务，可跳过以加快 MVP 开发
- 每个任务引用具体的需求编号以确保可追溯性
- 检查点任务确保增量验证
- 属性测试验证通用正确性属性，单元测试验证具体示例和边界情况
