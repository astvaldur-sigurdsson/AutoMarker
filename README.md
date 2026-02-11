# AutoMarker

A World of Warcraft addon that automatically marks mobs in combat based on their properties.

## Features

- **Elite Marking**: Automatically marks elite mobs with Skull (8) and Cross (7)
- **Caster Detection**: Marks mobs that are actively casting or channeling spells
- **Mana User Detection**: Marks mobs that have mana bars
- **Smart Prioritization**: Elites get Skull/Cross, other mobs get remaining marks
- **Flexible Configuration**: Enable/disable marking for solo, party, or raid scenarios
- **Permissions Aware**: Respects raid lead/assist requirements

## ⚠️ Known Limitations

**Delves with NPC Companions**: Due to Blizzard API restrictions, automatic marking does NOT work in delves when grouped with NPC companions (like Brann Bronzebeard). The `SetRaidTarget` API is protected in these scenarios and can only be invoked through manual player interaction. 

**The addon works normally in:**
- Regular 5-player dungeons with real players
- Raids with real players  
- Solo play (if enabled in settings)

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
