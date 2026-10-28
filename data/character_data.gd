class_name CharacterData
extends Resource
## Designer-editable description of one playable fighter.
##
## Create one .tres per fighter in res://data/characters/ and add it to the
## roster of the character-select scene. Adding a fighter needs no code change.

## Stable identifier. This is the string written to GameSettings, so keep it
## identical to what the rest of the game already expects ("KAAL", "NEX").
@export var id: String = ""
@export var display_name: String = ""
@export var tagline: String = ""
@export var portrait: Texture2D
## Used for the underline on the portrait panel and the card's name bar.
@export var accent_color: Color = Color.WHITE

@export_group("Attributes")
@export var archetype: String = "Brawler"
@export var max_health: float = 100.0
@export var move_speed: float = 350.0
@export var jump_velocity: float = -650.0

@export_group("Combat Tuning")
@export var light_damage: float = 8.0
@export var heavy_damage: float = 16.0
@export var special_damage: float = 24.0
@export var ultimate_damage: float = 48.0
@export var attack_speed_scale: float = 1.0
