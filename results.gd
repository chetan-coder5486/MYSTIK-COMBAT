
extends Control

@onready var winner_name: Label = $WinnerName
@onready var winner_portrait: TextureRect = $WinnerPortrait
@onready var final_score: Label = $FinalScore
@onready var rematch_button: Button = $RematchButton
@onready var main_menu_button: Button = $MainMenuButton

const KAAL_PORTRAIT: Texture2D = preload(
	"res://assets/characters/kaal/kaal_portrait.png"
)
const NEX_PORTRAIT: Texture2D = preload(
	"res://assets/characters/nex/nex_portrait.png"
)

func _ready() -> void:
	rematch_button.pressed.connect(_on_rematch_pressed)
	main_menu_button.pressed.connect(_on_main_menu_pressed)

	var winner: String = GameSettings.winner_character
	winner_name.text = winner + " WINS!"

	if winner == "KAAL":
		winner_portrait.texture = KAAL_PORTRAIT
	else:
		winner_portrait.texture = NEX_PORTRAIT

	final_score.text = "FINAL SCORE  |  P1  %d - %d  P2" % [
		GameSettings.player1_round_wins,
		GameSettings.player2_round_wins
	]

func _on_rematch_pressed() -> void:
	GameSettings.player1_round_wins = 0
	GameSettings.player2_round_wins = 0
	get_tree().change_scene_to_file("res://Main.tscn")

func _on_main_menu_pressed() -> void:
	get_tree().change_scene_to_file("res://MainMenu.tscn")
