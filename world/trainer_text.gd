class_name TrainerText
extends RefCounted
## English lines for the trainers placed up to Pewter (override data/trainers.json when present).
## lines(id, key, fallback): key = intro | defeat | after | lose | badge_speech | gift_speech.

const CLASS_PT := {
	"bug_catcher": "Bug Catcher",
	"camper": "Camper",
	"gym_leader": "Leader",
	"rival": "Rival",
	"youngster": "Youngster",
	"lass": "Lass",
	"picnicker": "Picnicker",
	"hiker": "Hiker",
}

const TEXT := {
	"bug_catcher_rick":
	{
		"intro": ["Hey! You have Pokémon!", "Come on, let's battle!"],
		"defeat": ["No!", "Caterpie couldn't take it!"],
		"after": ["Shh! You'll scare the bugs away.", "Maybe another time, okay?"],
	},
	"bug_catcher_doug":
	{
		"intro": ["Hey!", "Pokémon Trainers never run from a battle!"],
		"defeat": ["Huh?", "I'm out of Pokémon!"],
		"after": ["Darn! I'm going to go catch some stronger ones!"],
	},
	"bug_catcher_anthony":
	{
		"intro": ["I may be small, but don't go easy on me!"],
		"defeat": ["Aw, shoot.", "Nothing went right."],
		"after": ["There goes part of my allowance..."],
	},
	"bug_catcher_charlie":
	{
		"intro": ["Did you know that Pokémon evolve?"],
		"defeat": ["Aah!", "I lost!"],
		"after": ["Bug Pokémon evolve quickly.", "They're a lot of fun!"],
	},
	"bug_catcher_sammy":
	{
		"intro": ["Hey, wait up!", "What's the hurry?"],
		"defeat": ["I give up!", "You're good at this!"],
		"after":
		[
			"Sometimes you can find things on the ground.",
			"I'm looking for something I dropped. Can you help?"
		],
	},
	"camper_liam":
	{
		"intro": ["Stop right there, kid!", "You're light-years away from challenging Brock!"],
		"defeat": ["Darn!", "A light-year isn't a measure of time... it measures distance!"],
		"after": ["You're good...", "But not as good as Brock!"],
	},
	"brock":
	{
		"intro":
		[
			"So, you're here. I'm Brock, the Pewter Gym Leader.",
			"My willpower is rock hard, and so are my Pokémon.",
			"That's right: my Pokémon are all the Rock type!",
			"You'll challenge me even though you know you'll lose?",
			"Very well! Show me your best!"
		],
		"defeat":
		[
			"I took you for granted, and so I lost.",
			"As proof of your victory, accept the official Pokémon League BOULDERBADGE."
		],
		"after":
		[
			"There are all kinds of trainers in this huge world.",
			"You appear to be very talented.",
			"A suggestion: go to the Cerulean Gym and test your skills."
		],
		"badge_speech":
		[
			"Just having the BOULDERBADGE makes your Pokémon stronger.",
			"It also lets you use the move FLASH outside of battle."
		],
		"gift_speech":
		[
			"Wait! Take this with you.",
			"A TM, or Technical Machine, contains a technique for Pokémon.",
			"TM39 contains ROCK TOMB.",
			"It hurls rocks at the foe and lowers its SPEED."
		],
	},
	"rival_blue_route22":
	{
		"intro":
		[
			"Hey! {PLAYER}!",
			"Heading to the Pokémon League? Forget it!",
			"I bet you don't even have any Badges.",
			"The guard won't let you through without them.",
			"By the way, have your Pokémon gotten any stronger?"
		],
		"defeat": ["Aah!", "You just got lucky!"],
		"lose": ["Yeah! Am I great or what?"],
		"after":
		[
			"I hear the Pokémon League is full of strong trainers.",
			"I have to figure out how to get past them.",
			"And you, quit stalling and move along!"
		],
	},
}


static func lines(id: String, key: String, def: Dictionary) -> PackedStringArray:
	var t: Dictionary = TEXT.get(id, {})
	if t.has(key):
		return PackedStringArray(t[key])
	return PackedStringArray(def.get(key, []))


## "Caçador de Insetos Rick", "Líder Brock"; the rival uses Game.rival_name.
static func display_name(id: String, def: Dictionary) -> String:
	var cls := String(def.get("class", ""))
	if cls == "rival":
		return "{RIVAL}"
	if String(def.get("display_name", "")) != "":
		return String(def.display_name)
	return (
		("%s %s" % [CLASS_PT.get(cls, cls.replace("_", " ").capitalize()), def.get("name", "")])
		. strip_edges()
	)
