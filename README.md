# Better Boss Health Bar

A lightweight World of Warcraft addon that replaces the default boss frames with customizable health and cast bars for dungeons and raids. Built for the Midnight expansion (interface 120001).

## Features

- Up to 10 customizable boss health bars with health percent and current/max display
- Integrated cast bar per boss with distinct colors for kickable and non-kickable casts
- Major spell timers shown next to each boss with configurable warning threshold
- Multiple profiles (create, copy, delete, switch) with full default reset
- Drag-to-move bars when unlocked, plus a test mode to preview the layout out of combat
- Adjustable size, spacing, colors, fonts, growth direction, and boss-name placement

## Installation

1. Copy the `BetterBossHealthBar` folder into `World of Warcraft/_retail_/Interface/AddOns/`.
2. Restart the game client or reload the UI with `/reload`.
3. Make sure the addon is enabled in the character select AddOns panel.

## Usage

Open the options panel with `/bbhb` or `/betterbosshealthbar`.

### Slash commands

| Command | Description |
|---|---|
| `/bbhb` | Open the options panel |
| `/bbhb lock` | Lock the bars in place |
| `/bbhb unlock` | Unlock the bars so they can be dragged |
| `/bbhb test` | Toggle test mode (shows fake bosses for previewing) |
| `/bbhb reset` | Reset the current profile to defaults |
| `/bbhb cleartimers` | Clear all active major spell timers |
| `/bbhb timer <seconds> <spell name>` | Add a manual major spell timer |

## Configuration

All settings are stored per profile in `BetterBossHealthBarDB`. The options panel covers:

- **Bar**: width, height, spacing, colors, position, font size, growth direction, boss-name placement and alignment
- **Cast**: enable/disable, height, kickable/non-kickable colors, spell name and cast time visibility, big icon option
- **Major spells**: icon size, font size, maximum shown, name/time display, offsets, warning threshold and color

## Files

- `Core.lua` — event handling, profile management, slash commands
- `Bars.lua` — bar frame creation and update logic
- `Options.lua` — options panel UI
- `BetterBossHealthBar.toc` — addon manifest

## Version

1.0.0
