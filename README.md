# AutoMarker

A World of Warcraft addon that automatically marks mobs in combat with mana or cast bars.

## Features

- Automatically detects and marks mobs that have mana bars
- Automatically detects and marks mobs that are actively casting or channeling
- Smart mark prioritization (Skull for casters/mana users first)
- Only marks during combat when in a group/raid
- Respects raid permissions (requires raid lead or assist)

## Installation

1. Download or clone this repository
2. Copy the `AutoMarker` folder to your `World of Warcraft\_retail_\Interface\AddOns\` directory
3. Restart WoW or type `/reload` in-game

## Commands

- `/automarker` or `/am` - Toggle addon on/off
- `/automarker debug` - Toggle debug messages
- `/automarker group` - Toggle group requirement
- `/automarker help` - Show all commands

## Requirements

- World of Warcraft 12.0 or 12.0.1
- Raid lead or raid assist permissions when in a raid group

## How It Works

The addon scans nameplates during combat and automatically assigns raid target markers to eligible enemies. Priority is given to enemies with mana bars or those actively casting spells.

## License

MIT License
