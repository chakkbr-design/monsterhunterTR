"""Vídeo vertical (9:16, Reels/TikTok/Shorts) de uma luta do treino, com o HUD do vídeo por cima.

Entrada: a gravação da luta (com o "No HUD" ligado: tela limpa e o clarão branco de sincronia) e o
arquivo da partida (user://matches/*.json, BattleTelemetry com o "track": a vida dos 12 Pokémon a
cada 0,1 s no relógio do vídeo, vt). O script acha o clarão no vídeo (vt 0), corta do clarão até o
fim da luta e desenha, quadro a quadro:
  - em cima o Time B, embaixo o Time A (como no Game Boy: adversário em cima, você embaixo);
  - o nome do time e as 6 Poké Balls (cheia = de pé, apagada = desmaiado);
  - nome, nível e barra de vida de cada Pokémon em campo (a barra desce aos poucos, verde/amarela/
    vermelha);
  - no fim, o vencedor.

Gravação em retrato (tools/video/record.sh, --portrait=1080x1920): o jogo ocupa a tela toda e a
câmera já deixa livres as faixas do HUD (PORTRAIT_BAND em training_battle.gd). Gravação deitada
(16:9, OBS): o jogo fica numa faixa no meio, com o fundo borrado.

Uso:
  python tools/video/make_vertical.py gravacao.avi partida.json saida.mp4
      [--offset S]   segundo do vídeo em que vt = 0 (sem procurar o clarão)
      [--font F]     fonte .ttf (padrão: original/assets/fonts/PixelifySans.ttf)
      [--tail S]     segundos depois do fim da luta (padrão 2.5)
      [--preview S]  só os primeiros S segundos (teste rápido)
Precisa de numpy, Pillow e ffmpeg (no PATH ou pelo pacote imageio-ffmpeg).
"""

import argparse
import bisect
import json
import os
import re
import shutil
import subprocess
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont

W, H = 1080, 1920
# Faixas do HUD (casam com PORTRAIT_BAND = [0.24, 0.3] do jogo): o Time B em cima, o Time A embaixo,
# dentro da área segura das redes (as de cima e de baixo têm botões e legenda por cima).
TOP_Y = 150
BOT_Y = 1360
PANEL_X = 48
PANEL_W = W - 2 * PANEL_X
INK = (24, 24, 32)
PAPER = (248, 248, 232)
SHADE = (200, 200, 184)
HP_GREEN = (56, 200, 88)
HP_YELLOW = (240, 192, 40)
HP_RED = (232, 56, 48)
HP_EMPTY = (72, 72, 80)
BALL_RED = (224, 64, 58)
# A barra desce/sobe a esta fração da vida máxima por segundo (como a do Game Boy, sem pular).
DRAIN = 0.6
# Desmaiado: a linha dele fica (vazia) este tanto antes de abrir lugar.
FAINT_KEEP = 1.2


def ffmpeg_exe():
    exe = shutil.which("ffmpeg")
    if exe:
        return exe
    try:
        import imageio_ffmpeg

        return imageio_ffmpeg.get_ffmpeg_exe()
    except ImportError:
        sys.exit("ffmpeg not found: install it or `pip install imageio-ffmpeg`")


def probe(ff, path):
    """(largura, altura, fps, duração, tem áudio) pelo texto do ffmpeg -i."""
    err = subprocess.run([ff, "-hide_banner", "-i", path], capture_output=True, text=True).stderr
    m = re.search(r"Video: .*?, (\d{2,5})x(\d{2,5})", err)
    if not m:
        sys.exit("no video stream in " + path)
    w, h = int(m.group(1)), int(m.group(2))
    fps = 30.0
    m = re.search(r"([\d.]+) fps", err) or re.search(r"([\d.]+) tbr", err)
    if m:
        fps = float(m.group(1))
    dur = 0.0
    m = re.search(r"Duration: (\d+):(\d+):([\d.]+)", err)
    if m:
        dur = int(m.group(1)) * 3600 + int(m.group(2)) * 60 + float(m.group(3))
    return w, h, fps, dur, "Audio:" in err


def find_flash(ff, path, fps, limit=240.0):
    """Segundo do primeiro quadro quase todo branco (o clarão de sincronia do No HUD)."""
    cmd = [ff, "-v", "error", "-t", str(limit), "-i", path, "-vf", "scale=32:18", "-pix_fmt", "gray"]
    cmd += ["-f", "rawvideo", "-"]
    raw = subprocess.run(cmd, capture_output=True).stdout
    frames = np.frombuffer(raw, np.uint8).reshape(-1, 18 * 32)
    bright = frames.mean(axis=1)
    for i, b in enumerate(bright):
        if b > 235 and frames[i].min() > 200:
            return i / fps
    return None


class Track:
    """Linha do tempo do arquivo da partida."""

    def __init__(self, data):
        self.data = data
        self.track = data.get("track", [])
        self.vts = [s["vt"] for s in self.track]
        self.teams = data["teams"]
        meta = data.get("meta", {})
        self.names = meta.get("names", ["Team A", "Team B"])
        self.size = max(1, int(meta.get("battle_size", 2)))
        res = data.get("result", {})
        self.end_vt = float(res.get("vt", self.vts[-1] if self.vts else 0.0))
        self.outcome = res.get("outcome", "")

    def at(self, vt):
        if not self.track:
            return None
        i = bisect.bisect_right(self.vts, vt) - 1
        return self.track[max(i, 0)]


class Side:
    """Estado desenhado de um lado: linhas fixas (quem entrou fica na mesma linha) e a barra animada."""

    def __init__(self, team, size):
        self.team = team
        self.rows = [None] * size  # índice no time ou None
        self.left_at = [0.0] * size  # vt em que a linha ficou sem ninguém em campo (desmaio)
        self.shown = [1.0] * len(team)  # fração de vida desenhada

    def update(self, snap_hp, on, vt, dt):
        maxes = [max(1, int(m.get("max", 1))) for m in self.team]
        for r, idx in enumerate(self.rows):
            if idx is None or idx in on:
                continue
            # Saiu de campo: desmaiado fica um pouco com a barra vazia; recolhido sai na hora.
            if snap_hp[idx] > 0:
                self.rows[r] = None
            elif self.left_at[r] == 0.0:
                self.left_at[r] = vt
            elif vt - self.left_at[r] > FAINT_KEEP:
                self.rows[r] = None
        for idx in on:
            if idx in self.rows:
                continue
            free = [r for r, v in enumerate(self.rows) if v is None]
            if not free:
                # Linha ainda segurando um desmaiado: o novo toma o lugar.
                free = [r for r, v in enumerate(self.rows) if v not in on]
            if free:
                r = free[0]
                self.rows[r] = idx
                self.left_at[r] = 0.0
                self.shown[idx] = snap_hp[idx] / maxes[idx]
        for i, hp in enumerate(snap_hp):
            want = hp / maxes[i]
            step = DRAIN * dt
            cur = self.shown[i]
            self.shown[i] = min(want, cur + step) if want > cur else max(want, cur - step)


def load_font(path, size):
    for p in [path, "C:/Windows/Fonts/arialbd.ttf", "DejaVuSans-Bold.ttf"]:
        if p and os.path.exists(p) or p == "DejaVuSans-Bold.ttf":
            try:
                return ImageFont.truetype(p, size)
            except OSError:
                continue
    return ImageFont.load_default()


def hp_color(f):
    if f > 0.5:
        return HP_GREEN
    if f > 0.2:
        return HP_YELLOW
    return HP_RED


def draw_ball(d, cx, cy, r, alive, present):
    if not present:
        d.ellipse([cx - r, cy - r, cx + r, cy + r], outline=SHADE, width=4)
        return
    if not alive:
        d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=HP_EMPTY, outline=INK, width=4)
        d.line([cx - r, cy, cx + r, cy], fill=INK, width=4)
        return
    d.pieslice([cx - r, cy - r, cx + r, cy + r], 180, 360, fill=BALL_RED)
    d.pieslice([cx - r, cy - r, cx + r, cy + r], 0, 180, fill=(250, 250, 250))
    d.ellipse([cx - r, cy - r, cx + r, cy + r], outline=INK, width=4)
    d.line([cx - r, cy, cx + r, cy], fill=INK, width=4)
    d.ellipse([cx - r * 0.35, cy - r * 0.35, cx + r * 0.35, cy + r * 0.35], fill=(250, 250, 250), outline=INK, width=3)


class Hud:
    def __init__(self, track, font_path):
        self.t = track
        self.f_team = load_font(font_path, 40)
        self.f_name = load_font(font_path, 42)
        self.f_lv = load_font(None, 34)  # números legíveis (o 5 da Pixelify parece S)
        self.f_big = load_font(font_path, 96)
        self.sides = [Side(track.teams[0], track.size), Side(track.teams[1], track.size)]
        self.row_h = 100

    def panel_h(self):
        return 84 + self.row_h * self.t.size

    def step(self, vt, dt):
        snap = self.t.at(vt)
        if snap is None:
            return
        for s in range(2):
            # Na abertura os cartões esperam o "Fight!" (os titulares ainda estão saindo da bola).
            on = [] if snap.get("st") == "opening" else [int(i) for i in snap["on"][s]]
            self.sides[s].update(snap["hp"][s], on, vt, dt)
        self.snap = snap

    def draw(self, img, vt):
        d = ImageDraw.Draw(img)
        snap = getattr(self, "snap", None)
        if snap is None:
            return
        self._side(d, 1, TOP_Y, snap)
        self._side(d, 0, BOT_Y, snap)
        if vt >= self.t.end_vt + 0.3 and self.t.outcome in ("win", "lose"):
            win = self.t.names[0 if self.t.outcome == "win" else 1]
            self._banner(d, "%s WINS!" % win.upper())

    def _side(self, d, s, y, snap):
        side = self.sides[s]
        team = side.team
        x0, x1 = PANEL_X, PANEL_X + PANEL_W
        h = 84 + self.row_h * sum(1 for r in side.rows if r is not None)
        # Sombra, papel e borda grossa (caixa do Game Boy).
        d.rounded_rectangle([x0 + 8, y + 8, x1 + 8, y + h + 8], 22, fill=(0, 0, 0))
        d.rounded_rectangle([x0, y, x1, y + h], 22, fill=PAPER, outline=INK, width=7)
        d.text((x0 + 34, y + 20), self.t.names[s].upper(), font=self.f_team, fill=INK)
        # 6 Poké Balls: de pé, desmaiado, vaga vazia.
        r = 21
        bx = x1 - 34 - r
        for i in reversed(range(6)):
            present = i < len(team)
            alive = present and snap["hp"][s][i] > 0
            draw_ball(d, bx, y + 42, r, alive, present)
            bx -= 2 * r + 12
        ry = y + 84
        for idx in side.rows:
            if idx is None:
                continue
            m = team[idx]
            name = str(m.get("name") or m.get("sp", "")).upper()
            d.text((x0 + 34, ry), name, font=self.f_name, fill=INK)
            lv = "Lv%d" % int(m.get("lv", 50))
            nw = d.textlength(name, font=self.f_name)
            d.text((x0 + 34 + nw + 18, ry + 10), lv, font=self.f_lv, fill=INK)
            # "HP:" e a barra com moldura preta.
            by = ry + 58
            d.text((x0 + 34, by - 6), "HP", font=self.f_lv, fill=INK)
            bx0, bx1 = x0 + 110, x1 - 40
            d.rounded_rectangle([bx0, by, bx1, by + 30], 10, fill=INK)
            frac = max(0.0, min(1.0, side.shown[idx]))
            ix0, ix1 = bx0 + 6, bx1 - 6
            d.rectangle([ix0, by + 6, ix1, by + 24], fill=HP_EMPTY)
            if frac > 0:
                fx = ix0 + (ix1 - ix0) * frac
                d.rectangle([ix0, by + 6, fx, by + 24], fill=hp_color(frac))
                d.rectangle([ix0, by + 6, fx, by + 11], fill=tuple(min(255, c + 60) for c in hp_color(frac)))
            ry += self.row_h

    def _banner(self, d, text):
        tw = d.textlength(text, font=self.f_big)
        cx, cy = W / 2, H * 0.47
        pad = 44
        d.rounded_rectangle([cx - tw / 2 - pad + 10, cy - 80 + 10, cx + tw / 2 + pad + 10, cy + 80 + 10], 26, fill=(0, 0, 0))
        d.rounded_rectangle([cx - tw / 2 - pad, cy - 80, cx + tw / 2 + pad, cy + 80], 26, fill=PAPER, outline=INK, width=8)
        d.text((cx - tw / 2, cy - 58), text, font=self.f_big, fill=INK)


def base_filter(w, h):
    """Filtro do ffmpeg que põe a gravação no quadro 1080x1920."""
    if w / h <= 0.75:
        # Retrato: cobre a tela (corta o que sobrar).
        return "scale=%d:%d:force_original_aspect_ratio=increase,crop=%d:%d,setsar=1" % (W, H, W, H)
    # Deitada: faixa no meio com o próprio vídeo borrado atrás.
    fh = int(round(W * h / w / 2)) * 2
    return (
        "split[a][b];[a]scale=-2:%d,crop=%d:%d,boxblur=30:3,eq=brightness=-0.12[bg];"
        "[b]scale=%d:%d[fg];[bg][fg]overlay=0:(H-h)/2,setsar=1" % (H, W, H, W, fh)
    )


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("video")
    ap.add_argument("match")
    ap.add_argument("out")
    ap.add_argument("--offset", type=float, default=None)
    ap.add_argument("--font", default=None)
    ap.add_argument("--tail", type=float, default=2.5)
    ap.add_argument("--preview", type=float, default=0.0)
    a = ap.parse_args()

    ff = ffmpeg_exe()
    with open(a.match, encoding="utf-8") as fh:
        track = Track(json.load(fh))
    w, h, fps, dur, has_audio = probe(ff, a.video)
    fps = min(fps, 60.0)
    offset = a.offset
    if offset is None:
        offset = find_flash(ff, a.video, fps)
        if offset is None:
            sys.exit("sync flash not found: record with No HUD on, or pass --offset")
    # Começa logo depois do clarão e acaba um pouco depois do fim da luta.
    start = offset + 4.0 / fps
    end = offset + track.end_vt + a.tail
    if dur > 0:
        end = min(end, dur)
    if a.preview > 0:
        end = min(end, start + a.preview)
    length = end - start
    print("video %dx%d %.2f fps, flash at %.3f s, cutting %.2f..%.2f s" % (w, h, fps, offset, start, end))

    font = a.font
    if font is None:
        here = os.path.dirname(os.path.abspath(__file__))
        font = os.path.join(here, "..", "..", "original", "assets", "fonts", "PixelifySans.ttf")
    hud = Hud(track, font)

    dec = [ff, "-v", "error", "-ss", "%.3f" % start, "-t", "%.3f" % length, "-i", a.video]
    dec += ["-filter_complex", base_filter(w, h), "-r", "%g" % fps, "-pix_fmt", "rgb24", "-f", "rawvideo", "-"]
    enc = [ff, "-y", "-v", "error", "-f", "rawvideo", "-pix_fmt", "rgb24", "-s", "%dx%d" % (W, H)]
    enc += ["-r", "%g" % fps, "-i", "-"]
    if has_audio:
        enc += ["-ss", "%.3f" % start, "-t", "%.3f" % length, "-i", a.video, "-map", "0:v", "-map", "1:a"]
        enc += ["-c:a", "aac", "-b:a", "160k"]
    enc += ["-c:v", "libx264", "-preset", "medium", "-crf", "21", "-maxrate", "8M", "-bufsize", "16M", "-pix_fmt", "yuv420p"]
    enc += ["-movflags", "+faststart", "-shortest", a.out]
    pd = subprocess.Popen(dec, stdout=subprocess.PIPE)
    pe = subprocess.Popen(enc, stdin=subprocess.PIPE)
    size = W * H * 3
    n = 0
    dt = 1.0 / fps
    while True:
        buf = pd.stdout.read(size)
        if len(buf) < size:
            break
        img = Image.frombuffer("RGB", (W, H), buf, "raw", "RGB", 0, 1).copy()
        vt = (start - offset) + n * dt
        hud.step(vt, dt)
        hud.draw(img, vt)
        pe.stdin.write(img.tobytes())
        n += 1
        if n % int(fps * 10) == 0:
            print("  %d s" % (n / fps), flush=True)
    pe.stdin.close()
    pe.wait()
    pd.wait()
    print("wrote %s (%d frames, %.1f s)" % (a.out, n, n / fps))


if __name__ == "__main__":
    main()
