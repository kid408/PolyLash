#!/usr/bin/env python3
"""
Script to expand weapon_config.csv from 36 rows to 120 rows
Adds 21 new weapon variants (11 melee + 10 range) × 4 levels = 84 rows
"""

import csv

# Read existing CSV
with open('config/weapon/weapon_config.csv', 'r', encoding='utf-8') as f:
    reader = csv.DictReader(f)
    existing_rows = list(reader)
    fieldnames = reader.fieldnames

# Define new melee weapons (11 variants × 4 levels)
new_melee_weapons = [
    # thrust_charged - 蓄力突刺
    {
        'base': 'thrust_charged',
        'display_base': '蓄力突刺',
        'shape_type': 'line',
        'base_scene': 'res://scenes/weapons/melee/weapon_melee_thrust.tscn',
        'sector_angle': 0,
        'param1_values': [0.5, 0.6, 0.7, 0.8],  # 蓄力时间
        'param2_values': [30, 35, 40, 45],  # 线宽
        'effect_type': 'stun',
        'max_range_values': [280, 300, 320, 340]
    },
