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
