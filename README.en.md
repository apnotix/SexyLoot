<div align="center">

# 🎲 SexyLoot

**Loot, rolls and drops at a glance.**
A roll window that shows every player's roll right on the item, an XLoot-style loot window, a group loot feed and a list of your recent finds. Everything is adjustable in Edit Mode.

![WoW Forever](https://img.shields.io/badge/WoW-Forever-e8c26a?style=for-the-badge)
![Interface](https://img.shields.io/badge/Interface-120100%20%7C%2016001-3b2b12?style=for-the-badge)
![Edit Mode](https://img.shields.io/badge/Edit%20Mode-yes-4fc16a?style=for-the-badge)

[🇩🇪 Deutsche Version](README.md)

</div>

---

## ✨ What SexyLoot does

### 🎲 Roll window: Need, Greed, Pass
No more guessing who rolled what.

- 🎯 **Rolls on the item:** each player's choice and roll appear directly under the item, in class colors.
- 🏆 **Winner at a glance:** the winner gets a check mark, Need beats Greed.
- ⏱️ **Timer bar:** it turns red when time is running out.
- 🔍 **Tooltips:** hover the item to see the game's normal item tooltip.
- 🔒 **Honest buttons:** they only lock once your choice has actually gone through. If you cancel the confirmation on a Bind-on-Pickup item, you can still choose again.
- ⬆️ **Growth direction** up or down, with adjustable spacing.
- 📋 **Rolls one below the other:** every player gets their own line, best result on top, font size adjustable.
- ⏳ **Stays after the roll:** the window only disappears after an adjustable time (3 to 30 seconds).
- 🔄 **Survives a reload:** a running roll is restored afterwards.

### 🏆 Winner announcement
Whoever wins a roll appears large in the middle of the screen.

- 🖼️ **Item with icon and quality color**, plus name, need/greed and roll.
- 🙋 **"Du gewinnst!"** when it is you.
- 📏 **Font size** and **display time** adjustable.

### 🎁 Loot window
Replaces the default loot window.

- 🌈 **Quality colors** for border and name, stack count on the icon.
- 🖱️ **Click to loot**, Shift-click links the item in chat.
- ✅ **"Loot all"** with one click.
- 🪙 **Auto loot** is supported.
- 🩶 **Auto-loot grey items** (optional).
- 🏷️ **Group loot label:** you choose from which quality an item is labeled as group loot.
- 🔎 **Icon size** from 24 to 48 pixels.

### 📜 Group feed
Who got what?

- 👥 **Everything the group looted**, with item link and the player's class color.
- 🎲 **Roll details in the tooltip:** hover the item link of a line to see every choice and roll, sorted by result or by player order.
- 🕐 **Timestamps** (optional), **mouse wheel** to scroll.
- 🌫️ **Fades out:** messages disappear after an adjustable time (5 to 120 seconds, can be turned off). Scrolling brings them back.
- 🔤 **Width**, **height** and **font size** adjustable (the line count follows from them).

### 🎒 My loot
Perfect while leveling: a small list of your latest finds.

- 🧵 **Stacking:** linen cloth, ore and the like are added up ("x5").
- 🕒 **Age** per entry ("now", "40s", "2m").
- 💰 **Vendor value** of the whole list in gold, silver and copper.
- 🔢 **3 to 10 entries**, everything can be turned off.

---

## 🛠️ Everything adjustable in Edit Mode

Open **Edit Mode**, click a SexyLoot window and adjust it. SexyLoot uses the [EditModeExpanded](https://github.com/teelolws/EditModeExpanded) library for this.

**Every one of the five windows offers:**

| Option | Effect |
| --- | --- |
| 📍 Position | Drag freely, clamped to the screen edge |
| 🔍 Scale | 50 to 200 % |
| 👁️ Hide | Window permanently off |
| ⚔️ Hide in combat | Only visible outside of combat |
| 🖱️ Hide until mouseover | Appears when you move the mouse over it |
| 🧭 Coordinates | Screen position by number entry |
| 🎨 Background and border color | Both with a color picker and opacity, plus "Reset colors" |

**Plus each window's own options:**

| Window | Options |
| --- | --- |
| 🎲 Roll window | Hide rolls on the item · Let new windows grow upward · Spacing between windows · Font size of rolls · Show window after the roll (seconds) · Start test roll |
| 🏆 Winner announcement | Font size · Display time · Show test winner |
| 🎁 Loot window | Auto-loot grey items · Group loot label from quality · Icon size · Open test loot |
| 📜 Group feed | Hide timestamps · Sort roll details by player order · Width · Height · Font size · Clear feed |
| 🎒 My loot | Hide vendor value · Hide age · Do not stack identical items · Number of entries · Clear list |

### 👀 Demo data in Edit Mode
While Edit Mode is open, every window shows sample content: two rolls, a test loot, feed lines and looted items. That way you see right away how scale, icon size and line count look. The samples disappear when you leave Edit Mode.

---

## 📥 Installation

1. Copy the `SexyLoot` folder into your `Interface/AddOns` directory of the Forever client.
2. Start the game or `/reload`.
3. Open Edit Mode and place the windows as you like.

## ⌨️ Commands

| Command | Effect |
| --- | --- |
| `/sexyloot test` | Test data in all windows |
| `/sexyloot roll` | Test roll |
| `/sexyloot loot` | Test loot |
| `/sexyloot feed` | Sample lines in the feed |
| `/sexyloot mine` | Samples in "My loot" |

Short form: `/sl`

---

## ⚠️ Good to know

- 🧪 **Early version.** Roll detection reads the game's loot chat messages. If your client uses different texts, rolls will not show up on the item. In that case, get in touch with a screenshot and the chat text.
- 👑 **Master Loot** is not supported by the loot window.
- ⏳ The **roll time** is set by the game and cannot be changed.
- 🏷️ The **group loot label** only changes the caption in the loot window. The group leader decides from which quality items are rolled for.
- 📋 There are deliberately **no drop-down lists**, because addon frames using `UIDropDownMenuTemplate` are blocked in the Forever client. Sliders, checkboxes and buttons are used instead.

## 🐞 Reporting bugs

Please report bugs and requests as an [issue on GitHub](https://github.com/apnotix/SexyLoot/issues). Enable `/console scriptErrors 1` first and include the Lua error message.

## 🙏 Credits

- [EditModeExpanded](https://github.com/teelolws/EditModeExpanded) by **Teelo** (library `EditModeExpanded-1.0`, embedded, author credited as its license requires)
- **LibStub** (public domain)
- Inspired by **XLoot**

---

<div align="center">

Made by **apnotix** · Also by me: **SexyInterrupter**

</div>
