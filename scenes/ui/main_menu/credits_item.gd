extends PanelContainer
# ============================================================================
# 致谢条目预制体 - 60px 高长条卡片，显示素材信息和链接
# ============================================================================

# 颜色常量
const COLOR_ITEM_BG := Color("#222222")
const COLOR_ITEM_HOVER := Color("#2a2a2a")

# 链接地址
var _url: String = ""

# 节点引用
@onready var category_label: Label = $HBox/CategoryLabel
@onready var name_label: Label = $HBox/InfoVBox/NameLabel
@onready var author_label: Label = $HBox/InfoVBox/AuthorLabel
@onready var link_button: Button = $HBox/LinkButton

# ============================================================================
# 初始化
# ============================================================================

func _ready() -> void:
	mouse_entered.connect(_on_hover.bind(true))
	mouse_exited.connect(_on_hover.bind(false))
	link_button.pressed.connect(_on_link_pressed)

# ============================================================================
# 数据填充
# ============================================================================

func setup(data: Dictionary) -> void:
	# 分类标签
	category_label.text = "[%s]" % data.get("category", "")
	# 素材名称
	name_label.text = data.get("asset_name", "")
	# 作者 + 协议
	var author: String = data.get("author", "")
	var license_type: String = data.get("license_type", "")
	author_label.text = "by %s • %s" % [author, license_type]
	# 链接
	_url = data.get("url", "")
	link_button.visible = _url != ""
	# tooltip 显示描述
	tooltip_text = data.get("description", "")

# ============================================================================
# 悬停效果：背景色 #222222 → #2a2a2a
# ============================================================================

func _on_hover(hovered: bool) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_ITEM_HOVER if hovered else COLOR_ITEM_BG
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_right = 4
	style.corner_radius_bottom_left = 4
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	add_theme_stylebox_override("panel", style)

# ============================================================================
# 链接按钮点击 → 打开浏览器
# ============================================================================

func _on_link_pressed() -> void:
	if _url != "":
		OS.shell_open(_url)
