extends Node
## Cria o input map em código, como o jogo de referência faz.

const KEYS := {
	"move_left": [KEY_A, KEY_LEFT],
	"move_right": [KEY_D, KEY_RIGHT],
	"move_forward": [KEY_W, KEY_UP],
	"move_back": [KEY_S, KEY_DOWN],
	"jump": [KEY_SPACE],  ## só na batalha, como o original (lá é Q; aqui Q joga a bola)
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
	"ally_mode": [KEY_F],
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
