extends Control
## Painel de EXP do fim da batalha, como o de Scarlet/Violet: a party inteira numa coluna à direita,
## cada linha com retrato, nome, Lv, "+EXP" e a barra enchendo ao mesmo tempo. Quem sobe de nível
## mostra "Level up!" e a janela de stats (primeiro os +N, depois os valores novos).
## Sem confirmação: tudo corre sozinho e some; E (ou Enter) pula até o fim.
## API da arena: begin(rows), step(dt, skip) -> true quando acabou.
## row = {mon, xp0, level0, gain, learned: {nível: [nomes de golpe]}}.

const ROW_W := 330.0
const ROW_H := 56.0
const ROW_GAP := 6.0
const MARGIN := 18.0
const TOP := 120.0
const ICON_R := 22.0
const BAR_W := 200.0
## Segundos para a barra andar um nível inteiro.
const LEVEL_SECS := 0.7
## Janela de stats: os +N por STAT_DIFF_SECS, depois os valores novos por STAT_TOTAL_SECS.
const STAT_DIFF_SECS := 1.1
const STAT_TOTAL_SECS := 1.0
const STAT_W := 220.0
const STAT_ROW_H := 22.0
## Tempo com tudo cheio antes de sumir.
const HOLD_SECS := 1.0

var rows: Array = []
## Janelas de stats na fila: {mon, from, to}; a primeira é a que está na tela.
var stat_queue: Array = []
## Linhas de texto que o painel mostrou (para os testes): "X gained N EXP.", "X grew to Lv N!", ...
var lines: Array = []
var _stat_t := 0.0
var _hold := 0.0
## Quantas de `lines` a arena já levou para o log (take_news).
var _taken := 0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	visible = false


func begin(list: Array) -> void:
	rows = []
	stat_queue = []
	lines = []
	_stat_t = 0.0
	_hold = 0.0
	for r in list:
		var row: Dictionary = r.duplicate()
		row["shown"] = float(row.xp0)
		row["level"] = int(row.level0)
		row["flash"] = 0.0
		rows.append(row)
		if int(row.gain) > 0:
			lines.append("%s gained %d EXP." % [row.mon.display_name, int(row.gain)])
	_taken = lines.size()  # "gained" fica só no painel; o log recebe nível e golpe novo
	visible = not rows.is_empty()
	queue_redraw()


## Linhas novas desde a última chamada (nível, golpe aprendido).
func take_news() -> Array:
	var out := lines.slice(_taken)
	_taken = lines.size()
	return out


func active() -> bool:
	return visible


## Um quadro. true quando acabou (o painel já sumiu).
func step(dt: float, skip := false) -> bool:
	if not visible:
		return true
	if skip:
		_finish_all()
		return true
	var filling := false
	for row in rows:
		row.flash = maxf(float(row.flash) - dt, 0.0)
		var m: Mon = row.mon
		var target := float(row.xp0) + float(row.gain)
		if float(row.shown) >= target:
			continue
		filling = true
		var lv := int(row.level)
		var span := float(
			Growth.exp_for_level(m.growth, lv + 1) - Growth.exp_for_level(m.growth, lv)
		)
		row.shown = minf(float(row.shown) + maxf(span, 1.0) / LEVEL_SECS * dt, target)
		while (
			int(row.level) < Growth.MAX_LEVEL
			and float(row.shown) >= float(Growth.exp_for_level(m.growth, int(row.level) + 1))
		):
			_level_up(row)
	if not stat_queue.is_empty():
		_stat_t += dt
		if _stat_t >= STAT_DIFF_SECS + STAT_TOTAL_SECS:
			stat_queue.pop_front()
			_stat_t = 0.0
	elif not filling:
		_hold += dt
		if _hold >= HOLD_SECS:
			visible = false
			return true
	queue_redraw()
	return false


func _level_up(row: Dictionary) -> void:
	var m: Mon = row.mon
	row.level = int(row.level) + 1
	row.flash = 1.2
	stat_queue.append({"mon": m, "from": int(row.level) - 1, "to": int(row.level)})
	lines.append("%s grew to Lv %d!" % [m.display_name, int(row.level)])
	for mv in row.get("learned", {}).get(int(row.level), []):
		lines.append("%s learned %s!" % [m.display_name, mv])
	preload("res://audio/cue.gd").sfx("level_up")


func _finish_all() -> void:
	for row in rows:
		var target := float(row.xp0) + float(row.gain)
		var m: Mon = row.mon
		row.shown = maxf(float(row.shown), target)
		while (
			int(row.level) < Growth.MAX_LEVEL
			and target >= float(Growth.exp_for_level(m.growth, int(row.level) + 1))
		):
			row.level = int(row.level) + 1
			lines.append("%s grew to Lv %d!" % [m.display_name, int(row.level)])
			for mv in row.get("learned", {}).get(int(row.level), []):
				lines.append("%s learned %s!" % [m.display_name, mv])
	stat_queue = []
	visible = false


## Stats do Mon num nível (mesmos IV/EV/natureza de agora): a diferença é só a do nível.
static func stats_at(m: Mon, level: int) -> Dictionary:
	var base: Dictionary = Dex.species(m.species).get("base", {})
	var out := {}
	for s in StatCalc.STATS:
		out[s] = StatCalc.stat(
			s, int(base.get(s, 50)), int(m.ivs.get(s, 0)), int(m.evs.get(s, 0)), level, m.nature
		)
	return out


func _draw() -> void:
	if not visible:
		return
	var x := size.x - MARGIN - ROW_W
	var y := TOP
	for row in rows:
		_draw_row(Rect2(x, y, ROW_W, ROW_H), row)
		y += ROW_H + ROW_GAP
	if not stat_queue.is_empty():
		_draw_stats(Vector2(x - STAT_W - 12.0, TOP), stat_queue[0])


func _draw_row(r: Rect2, row: Dictionary) -> void:
	var m: Mon = row.mon
	var down := m.is_fainted()
	var accent: Color = Dex.type_color(String(m.types[0]) if not m.types.is_empty() else "normal")
	UiDraw.rounded(self, Rect2(r.position + Vector2(0, 3), r.size), Color(0, 0, 0, 0.3), 12)
	UiDraw.glass(self, r, 0.78, 12)
	if float(row.flash) > 0.0:
		UiDraw.rounded(self, r, Color(UiDraw.AMBER, 0.25 * minf(float(row.flash), 1.0)), 12)
	UiDraw.rounded(self, Rect2(r.position.x, r.position.y + 8, 5, r.size.y - 16), accent, 3)
	var pc := r.position + Vector2(14.0 + ICON_R, r.size.y * 0.5)
	draw_circle(pc, ICON_R, accent.darkened(0.55))
	var icon := PokemonSprites.disc_icon(m.species, int(ICON_R * 2.0))
	if icon:
		var t := PokemonSprites.tint(m.species) if not down else Color(0.35, 0.35, 0.35)
		draw_texture_rect(
			icon, Rect2(pc - Vector2(ICON_R, ICON_R), Vector2(ICON_R, ICON_R) * 2.0), false, t
		)
	var tx := r.position.x + 14.0 + ICON_R * 2.0 + 10.0
	var tf := UiDraw.title_font()
	var name_col := UiDraw.COL_WHITE if not down else Color(1, 1, 1, 0.5)
	UiDraw.text(
		self,
		Vector2(tx, r.position.y + 22.0),
		m.display_name,
		16,
		name_col,
		4,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		tf
	)
	var lv := "Lv %d" % int(row.level)
	UiDraw.text(
		self,
		Vector2(r.end.x - 12.0 - UiDraw.text_width(lv, 14, tf), r.position.y + 22.0),
		lv,
		14,
		UiDraw.AMBER,
		4,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		tf
	)
	if float(row.flash) > 0.0:
		var up := "Level up!"
		UiDraw.text(
			self,
			Vector2(r.end.x - 12.0 - UiDraw.text_width(up, 12, tf), r.position.y + 40.0),
			up,
			12,
			UiDraw.AMBER,
			4,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1.0,
			tf
		)
	elif int(row.gain) > 0:
		var g := "+%d" % int(row.gain)
		UiDraw.text(
			self,
			Vector2(r.end.x - 12.0 - UiDraw.text_width(g, 12), r.position.y + 40.0),
			g,
			12,
			Color(1, 1, 1, 0.85),
			3
		)
	UiDraw.bar(
		self,
		Rect2(tx, r.position.y + 34.0, BAR_W - 40.0, 7),
		_ratio(row),
		UiDraw.AMBER,
		-1.0,
		Color(1, 1, 1, 0.75),
		false,
		UiDraw.EXP_TRACK
	)


func _ratio(row: Dictionary) -> float:
	var m: Mon = row.mon
	var lv := int(row.level)
	if lv >= Growth.MAX_LEVEL:
		return 1.0
	var lo := float(Growth.exp_for_level(m.growth, lv))
	var hi := float(Growth.exp_for_level(m.growth, lv + 1))
	return clampf((float(row.shown) - lo) / maxf(hi - lo, 1.0), 0.0, 1.0)


func _draw_stats(at: Vector2, w: Dictionary) -> void:
	var m: Mon = w.mon
	var before := stats_at(m, int(w.from))
	var after := stats_at(m, int(w.to))
	var totals := _stat_t >= STAT_DIFF_SECS
	var h := 34.0 + STAT_ROW_H * StatCalc.STATS.size() + 8.0
	var r := Rect2(at, Vector2(STAT_W, h))
	UiDraw.rounded(self, Rect2(r.position + Vector2(0, 3), r.size), Color(0, 0, 0, 0.3), 12)
	UiDraw.glass(self, r, 0.86, 12)
	var tf := UiDraw.title_font()
	UiDraw.text(
		self,
		at + Vector2(12, 22),
		"%s  Lv %d" % [m.display_name, int(w.to)],
		14,
		UiDraw.AMBER,
		4,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		tf
	)
	var y := at.y + 34.0 + 16.0
	for s in StatCalc.STATS:
		UiDraw.text(
			self, Vector2(at.x + 12, y), String(StatCalc.STAT_NAMES[s]), 13, UiDraw.COL_WHITE, 3
		)
		var v := (str(int(after[s]))) if totals else ("+%d" % (int(after[s]) - int(before[s])))
		var col := UiDraw.COL_WHITE if totals else Color(0.55, 1.0, 0.6)
		UiDraw.text(self, Vector2(at.x + STAT_W - 12 - UiDraw.text_width(v, 13), y), v, 13, col, 3)
		y += STAT_ROW_H
