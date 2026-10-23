class_name Growth
extends RefCounted

const MAX_LEVEL := 100


static func exp_for_level(rate: String, n: int) -> int:
	if n <= 1:
		return 0
	var n3 := float(n * n * n)
	match rate:
		"fast":
			return int(4.0 * n3 / 5.0)
		"medium_slow":
			return maxi(int(6.0 * n3 / 5.0 - 15.0 * n * n + 100.0 * n - 140.0), 0)
		"slow":
			return int(5.0 * n3 / 4.0)
		"erratic":
			if n < 50:
				return int(n3 * (100 - n) / 50.0)
			if n < 68:
				return int(n3 * (150 - n) / 100.0)
			if n < 98:
				return int(n3 * floorf((1911 - 10 * n) / 3.0) / 500.0)
			return int(n3 * (160 - n) / 100.0)
		"fluctuating":
			if n < 15:
				return int(n3 * (floorf((n + 1) / 3.0) + 24.0) / 50.0)
			if n < 36:
				return int(n3 * (n + 14) / 50.0)
			return int(n3 * (floorf(n / 2.0) + 32.0) / 50.0)
		_:
			return int(n3)


static func level_for_exp(rate: String, total: int) -> int:
	var n := 1
	while n < MAX_LEVEL and total >= exp_for_level(rate, n + 1):
		n += 1
	return n


static func exp_gain(base_exp: int, level: int, winner_level: int, trainer := false) -> int:
	var a := 1.5 if trainer else 1.0
	var l := float(level)
	var scale := pow((2.0 * l + 10.0) / (l + float(winner_level) + 10.0), 2.5)
	return maxi(int(a * base_exp * l / 5.0 * scale) + 1, 1)
