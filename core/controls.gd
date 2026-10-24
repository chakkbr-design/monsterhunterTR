extends Node
## Cria o input map em código, como o jogo de referência faz.

const KEYS := {
	"move_left": [KEY_A, KEY_LEFT],
	"move_right": [KEY_D, KEY_RIGHT],
	"move_forward": [KEY_W, KEY_UP],
	"move_back": [KEY_S, KEY_DOWN],
	"jump": [KEY_SPACE],
	"sprint": [KEY_SHIFT],
	"interact": [KEY_E],
	"move_1": [KEY_1],
	"move_2": [KEY_2],
	"move_3": [KEY_3],
	"move_4": [KEY_4],
	"throw_ball": [KEY_Q],
	"swap_mon": [KEY_TAB],
	"run_away": [KEY_R],
	"pause": [KEY_ESCAPE],
	"cam_left": [KEY_Z],
	"cam_right": [KEY_C],
	"ally_mode": [KEY_F],
	# Fora da batalha (controls.gd setup do original): F dá comida ao companheiro; 1-6 mandam e
	# recolhem cada Pokémon da equipe.
	"feed": [KEY_F],
	"party_1": [KEY_1],
	"party_2": [KEY_2],
	"party_3": [KEY_3],
	"party_4": [KEY_4],
	"party_5": [KEY_5],
	"party_6": [KEY_6],
}


func _ready() -> void:
	register()


static func register() -> void:
	for action in KEYS:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for key in KEYS[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			InputMap.action_add_event(action, ev)
