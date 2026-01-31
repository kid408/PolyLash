# Game Over Screen - Quick Reference

## 🚀 Quick Start

### Display Game Over Screen
```gdscript
# In arena.gd or any scene
const GAME_OVER_SCENE = preload("res://scenes/ui/game_over/game_over_screen.tscn")

var game_over = GAME_OVER_SCENE.instantiate()
add_child(game_over)

game_over.set_stats({
    "kills": Global.session_kills,
    "gold": Global.session_gold
})

game_over.show_screen()
```

## 📊 Track Session Data

### In Global.gd
```gdscript
# Track kills
Global.add_session_kill()

# Track gold
Global.add_session_gold(50)

# Reset data
Global.reset_session_data()
```

## ➕ Add New Stats

### Method 1: Dynamic
```gdscript
game_over.add_stat_row("Survival Time:", "5:32", Color.CYAN)
game_over.add_stat_row("Damage Dealt:", "12,450", Color.ORANGE_RED)
```

### Method 2: In set_stats()
```gdscript
func set_stats(data: Dictionary) -> void:
    kills_value.text = str(data.get("kills", 0))
    gold_value.text = str(data.get("gold", 0))
    
    # Add custom stats
    if data.has("time"):
        add_stat_row("Time:", data["time"])
```

## 🎨 UI Customization

### Colors
```gdscript
# Title color
Color(0.9, 0.3, 0.3, 1)  # Red

# Value color
Color(1, 0.9, 0.3, 1)    # Gold

# Label color
Color(0.8, 0.8, 0.8, 1)  # Gray
```

### Sizes
- Panel: 600x500
- Title: 56px
- Stats: 28px
- Button: 70px height

## 🔧 Integration Points

### 1. Enemy Death (enemy.gd)
```gdscript
func destroy_enemy() -> void:
    # ... existing code ...
    Global.add_session_kill()  # Add this
```

### 2. Gold Gain (player_base.gd)
```gdscript
func add_gold(amount: int) -> void:
    # ... existing code ...
    Global.add_session_gold(amount)  # Add this
```

### 3. Player Death (player_base.gd)
```gdscript
func _on_death() -> void:
    # ... existing code ...
    Global.is_game_over = true  # Add this
```

### 4. Arena Check (arena.gd)
```gdscript
func _process(delta: float) -> void:
    if not Global.is_game_over and is_instance_valid(player):
        if player.health_component.current_health <= 0:
            _show_game_over_screen()
```

## 📁 File Structure
```
scenes/ui/game_over/
├── game_over_screen.tscn    # Scene
├── game_over_screen.gd      # Script
├── README.md                # Full docs
└── QUICK_REFERENCE.md       # This file
```

## ⚡ Common Tasks

### Add Survival Time
```gdscript
# In Global.gd
var session_time: float = 0.0

func update_session_time(delta: float) -> void:
    if not is_game_over:
        session_time += delta

# In Arena._process()
Global.update_session_time(delta)

# In game_over_screen
var minutes = int(Global.session_time / 60)
var seconds = int(Global.session_time) % 60
add_stat_row("Time:", "%d:%02d" % [minutes, seconds])
```

### Add Damage Tracking
```gdscript
# In Global.gd
var session_damage: int = 0

func add_session_damage(amount: int) -> void:
    session_damage += amount

# In weapon/hitbox code
Global.add_session_damage(damage_dealt)
```

## 🐛 Troubleshooting

### Screen doesn't show
- Check `Global.is_game_over` flag
- Verify player death detection
- Check CanvasLayer layer value (should be 100)

### Stats show 0
- Verify `Global.add_session_kill()` is called
- Check `Global.add_session_gold()` is called
- Ensure data isn't reset too early

### Can't return to menu
- Check scene path in `_on_return_button_pressed()`
- Verify `get_tree().paused` is reset
- Check `Global.reset_session_data()` is called

## 📚 See Also
- Full documentation: `README.md`
- Implementation guide: `../../../GAME_OVER_SYSTEM_GUIDE.md`
- Summary: `../../../GAME_OVER_IMPLEMENTATION_SUMMARY.md`
