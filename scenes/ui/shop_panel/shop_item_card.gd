extends PanelContainer
class_name ShopItemCard

# ============================================================================
# 商店物品卡片 - 显示单个商店物品
# ============================================================================

# 信号
signal purchase_requested(card_index: int)

# 节点引用
@onready var icon_texture: TextureRect = %IconTexture
@onready var name_label: Label = %NameLabel
@onready var effects_label: RichTextLabel = %EffectsLabel
@onready var price_button: Button = %PriceButton
@onready var purchased_label: Label = %PurchasedLabel

# 数据
var card_index: int = -1
var item_data: Dictionary = {}
var is_purchased: bool = false

# ============================================================================
# 设置
# ============================================================================

func setup(index: int, item: Dictionary) -> void:
	"""设置卡片数据
	
	Args:
		index: 卡片索引
		item: 物品数据字典
	"""
	card_index = index
	item_data = item
	
	# 设置物品名称
	var item_name = item.get("item_name", "未知物品")
	name_label.text = item_name
	
	# 加载图标
	var icon_path = item.get("icon_path", "")
	if FileAccess.file_exists(icon_path):
		var texture = load(icon_path) as Texture2D
		if texture:
			icon_texture.texture = texture
	
	# 设置效果描述（带颜色）
	_setup_effects_text(item.get("effects", []))
	
	# 设置价格按钮
	var price = item.get("price", 0)
	price_button.text = "购买 (%d金币)" % price
	
	# 连接按钮信号
	if not price_button.pressed.is_connected(_on_price_button_pressed):
		price_button.pressed.connect(_on_price_button_pressed)
	
	# 重置购买状态
	set_purchased(false)

func _setup_effects_text(effects: Array) -> void:
	"""设置效果描述文本（带颜色）
	
	Args:
		effects: 效果数组
	"""
	var text_parts: Array = []
	
	for effect in effects:
		var description = effect.get("description", "")
		var is_trade_off = effect.get("is_trade_off", false)
		
		if description == "":
			continue
		
		# 根据是否为权衡（负面效果）设置颜色
		if is_trade_off:
			text_parts.append("[color=red]%s[/color]" % description)
		else:
			text_parts.append("[color=green]%s[/color]" % description)
	
	effects_label.text = "\n".join(text_parts)

# ============================================================================
# 购买状态
# ============================================================================

func set_purchased(purchased: bool) -> void:
	"""设置购买状态
	
	Args:
		purchased: 是否已购买
	"""
	is_purchased = purchased
	
	if purchased:
		price_button.visible = false
		purchased_label.visible = true
		modulate = Color(0.7, 0.7, 0.7, 1.0)  # 变灰
	else:
		price_button.visible = true
		purchased_label.visible = false
		modulate = Color(1.0, 1.0, 1.0, 1.0)  # 正常

func set_affordable(affordable: bool) -> void:
	"""设置是否买得起
	
	Args:
		affordable: 是否买得起
	"""
	if is_purchased:
		return
	
	price_button.disabled = not affordable

# ============================================================================
# 信号处理
# ============================================================================

func _on_price_button_pressed() -> void:
	"""购买按钮被点击"""
	if not is_purchased:
		purchase_requested.emit(card_index)
