local flow = require "flow/flow"
local rgba = flow.color.rgba

local Box = flow.ui.cp.Box
local Button = flow.ui.cp.Button
local Markdown = flow.ui.cp.Markdown
local Text = flow.ui.cp.Text


return {
	view = function(params, navigation)
		-- Comprehensive game guide content in markdown
		local guide_content = [[
# Epic Quest: Complete Guide

Welcome to the ultimate guide for Epic Quest! This guide will help you master the game and become a legendary hero.

---

## Getting Started

Before you begin your adventure, here are the essential things you need to know:

- Create your character and choose your class
- Complete the tutorial to learn basic controls
- Collect your starter equipment from the merchant
- Talk to the Elder in the village to start your first quest

![Character Creation Screen](atlas:guide:castle_siege|width=86%|height=220|scale=stretch)

## Character Classes

Epic Quest features four unique character classes, each with their own playstyle:

### 1. Warrior

The Warrior is a melee combat specialist with high defense and powerful attacks.

- High HP and defense stats
- Excels in close-range combat
- Can equip heavy armor and shields
- Special ability: Berserker Rage

![Warrior Class](atlas:guide:sword|width=70%|height=220|scale=fit|aspect=524:768)

### 2. Mage

Masters of arcane magic who deal devastating spell damage from a distance.

- High magic damage output
- Low defense but powerful crowd control
- Can cast elemental spells
- Special ability: Meteor Storm

![Mage Class](atlas:guide:hokusai_dragon|width=78%|height=220|scale=fit|aspect=1:1)

### 3. Ranger

Swift and deadly archers who strike from the shadows.

- High agility and critical hit rate
- Expert with bows and traps
- Can tame animal companions
- Special ability: Arrow Rain

![Ranger Class](atlas:guide:autumn_forest_path_with_tall_trees|height=170|scale=fit|aspect=768:512)

### 4. Cleric

Holy warriors who can heal allies and smite enemies with divine power.

- Balanced stats with healing abilities
- Can support team in multiplayer
- Wields holy magic and maces
- Special ability: Divine Blessing

![Cleric Class](atlas:guide:forest_path_sunset|width=92%|height=170|scale=stretch)

---

## Combat System

> Master the combat system to survive the toughest encounters!

The combat in Epic Quest uses a real-time action system:

1. Use basic attacks with the Attack button
2. Build up your Energy bar through combat
3. Spend Energy to use powerful Special Abilities
4. Dodge enemy attacks by rolling (costs Stamina)
5. Block incoming damage with Shield (Warrior only)

### Combat Tips

- Always keep an eye on your stamina
- Learn enemy attack patterns
- Use the environment to your advantage
- Combo your abilities for maximum damage

![Combat Screenshot](atlas:guide:castle_siege|height=210|scale=stretch)

---

## Leveling and Progression

As you complete quests and defeat enemies, you'll gain experience and level up.

### Experience Points (XP)

- Killing enemies: 10-100 XP
- Completing quests: 500-5000 XP
- Discovering new areas: 200 XP
- Crafting items: 50 XP

### Skill Trees

Each class has three skill trees to invest points in:

1. **Offensive Tree** - Increase damage output
2. **Defensive Tree** - Improve survivability
3. **Utility Tree** - Gain special abilities and bonuses

![Skill Tree](atlas:guide:hokusai_dragon|width=74%|height=220|scale=fit|aspect=1:1)

---

## Equipment and Crafting

### Weapon Tiers

- Common (Gray): Basic starter equipment
- Uncommon (Green): Slightly better stats
- Rare (Blue): Notable stat improvements
- Epic (Purple): Powerful legendary weapons
- Legendary (Gold): The most powerful items

### Crafting System

Gather resources from the world to craft powerful items:

```
Iron Ore + Wood = Iron Sword
Leather + Thread = Leather Armor
Magic Crystal + Staff = Magic Staff
```

Visit the Blacksmith in town to learn crafting recipes.

![Crafting Interface](atlas:guide:sword|width=68%|height=220|scale=fit|aspect=524:768)

---

## Boss Strategies

### Dragon Lord (Level 20)

> One of the toughest bosses in the game!

- **Weakness**: Ice magic
- **Attack Pattern**: Breathes fire every 10 seconds
- **Strategy**: Stay behind him and attack from the rear
- **Reward**: Dragon Scale armor set

### Shadow King (Level 35)

- **Weakness**: Holy magic
- **Attack Pattern**: Summons shadow minions
- **Strategy**: Eliminate minions first, then focus boss
- **Reward**: Shadow Blade legendary weapon

![Boss Battle](atlas:guide:hokusai_dragon|height=210|scale=fit|aspect=1:1)

---

## Multiplayer Co-op

Team up with friends to tackle challenging dungeons:

- Form parties of up to 4 players
- Share quest progress and rewards
- Revive fallen teammates
- Bonus XP for playing in a group

### Recommended Party Composition

1 Tank (Warrior) + 1 Healer (Cleric) + 2 DPS (Mage/Ranger)

---

## Tips and Tricks

Here are some advanced tips for expert players:

- Save your gold for Epic tier equipment
- Complete daily quests for bonus rewards
- Join a guild for exclusive perks
- Explore every corner of the map for hidden treasures
- Upgrade your equipment at the Enchanter
- Stock up on healing potions before boss fights

---

## Conclusion

You now have all the knowledge needed to become a master of Epic Quest! Remember to have fun, explore the world, and forge your own legend.

Good luck, adventurer!

![Epic Quest Logo](atlas:guide:forest_path_sunset|width=94%|height=180|scale=stretch)
]]

		return Box({
			key = "game_guide_root",
			style = { width="100%", height="100%", flex_direction="column", gap=0, padding=0 },
			color = rgba(0.08, 0.08, 0.12, 1),
			children = {
				-- Header
				Box({
					key="header",
					style={ height=60, flex_direction="row", gap=8, align_items="center" },
					color=rgba(0.2, 0.2, 0.2, 0.8),
					children = {
						Button({
							key="btn_back",
							style={ width=80, height=40 },
							color=rgba(0.8, 0.3, 0.3, 1),
							on_click = function()
								navigation.pop("slide_right")
							end,
							children = {
								Text({
									key="btn_back_label",
									text="BACK",
									style={ width="100%", height="100%" }
								})
							}
						}),
						Text({
							key="title",
							text="Epic Quest - Game Guide",
							style={ flex_grow=1, height=40 }
						})
					}
				}),
				-- Markdown viewer with game guide content
				Markdown.viewer(guide_content, "guide_viewer")
			}
		})
	end
}
