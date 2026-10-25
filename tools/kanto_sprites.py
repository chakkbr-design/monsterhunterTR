"""Monta original/assets/pokemon/<slug>/ das espécies de Kanto que não vieram do original (arte fora do git):
- pmd/*-Anim.png + pmd/anims.json do PMD SpriteCollab (só as animações que data/pmd_anims.json usa); as âncoras
  saem do *-Shadow.png (centro x, base y) e Idle/Walk/Hop fixam o pé no quadro, igual ao importador antigo;
- front.png/back.png: BW animados (PokeAPI sprites) em tira de quadros quadrados, no máximo 8192 px de largura;
- icon.png: frente HGSS 80x80; party_icon.png: ícone Gen 7 em 2x, 2 quadros (o 2º 2 px acima).
Uso: git clone --filter=blob:none --sparse do PMDCollab/SpriteCollab (pastas sprite/NNNN) e
python tools/kanto_sprites.py <SpriteCollab/sprite> <saída> <lista.json [[dex, nome], ...]>
"""
import json, os, re, sys, io, urllib.request, xml.etree.ElementTree as ET
from PIL import Image, ImageSequence
SC = sys.argv[1]
OUT = sys.argv[2]
LIST = sys.argv[3]
RAW = "https://raw.githubusercontent.com/"
PIN = {"Idle", "Walk", "Hop"}
CACHE = os.path.join(OUT, "..", "_cache")
os.makedirs(CACHE, exist_ok=True)

def fetch(path):
    fn = os.path.join(CACHE, path.replace("/", "_"))
    if not os.path.exists(fn):
        data = urllib.request.urlopen(urllib.request.Request(RAW + path, headers={"User-Agent": "x"}), timeout=60).read()
        open(fn, "wb").write(data)
    return open(fn, "rb").read()

def slug(name):
    return name.lower().replace(" ", "_").replace(".", "").replace("'", "")

def anchors(name, d, w, h, dirs, nfr):
    sh = Image.open(os.path.join(d, name + "-Shadow.png")).convert("RGBA")
    an = Image.open(os.path.join(d, name + "-Anim.png")).convert("RGBA")
    out = []
    for di in range(dirs):
        row = []
        for f in range(nfr):
            box = (f * w, di * h, (f + 1) * w, (di + 1) * h)
            s = sh.crop(box)
            bb = s.getchannel("A").getbbox()
            if bb:
                x = (bb[0] + bb[2] - 1 + 1) // 2
                y = bb[3] - 1
            else:
                x, y = w // 2, h // 2
            if name in PIN:
                fb = an.crop(box).getchannel("A").getbbox()
                if fb:
                    y = fb[3]
            row.append([x, y])
        out.append(row)
    return out

def pmd(no, dst):
    d = os.path.join(SC, "%04d" % no)
    root = ET.parse(os.path.join(d, "AnimData.xml")).getroot()
    raw = {a.findtext("Name"): a for a in root.iter("Anim")}
    res = {}
    os.makedirs(os.path.join(dst, "pmd"), exist_ok=True)
    def build(name, src):
        a = raw[src]
        if a.findtext("CopyOf"):
            return build(name, a.findtext("CopyOf"))
        w, h = int(a.findtext("FrameWidth")), int(a.findtext("FrameHeight"))
        durs = [int(x.text) for x in a.find("Durations")]
        img = Image.open(os.path.join(d, src + "-Anim.png"))
        dirs = img.size[1] // h
        e = {"anchor": anchors(src, d, w, h, dirs, len(durs)), "dirs": dirs, "durations": durs,
             "file": src + "-Anim.png", "h": h, "w": w,
             "hit": int(a.findtext("HitFrame") or -1), "return": int(a.findtext("ReturnFrame") or -1),
             "rush": int(a.findtext("RushFrame") or -1)}
        img.save(os.path.join(dst, "pmd", src + "-Anim.png"))
        return e
    used = set(re.findall(r'"([A-Z][A-Za-z]+)"', open("data/pmd_anims.json", encoding="utf-8").read()))
    for name in raw:
        if name not in used:
            continue
        if not os.path.exists(os.path.join(d, (raw[name].findtext("CopyOf") or name) + "-Anim.png")):
            continue
        res[name] = build(name, name)
    json.dump({k: res[k] for k in sorted(res)}, open(os.path.join(dst, "pmd", "anims.json"), "w"), separators=(",", ":"))
    return sorted(res)

MAX_W = 8192  # textura mais larga que o limite da placa de vídeo some (16384 em muitas, 8192 por segurança)


def strip(gif_bytes, path):
    seq = [f.convert("RGBA") for f in ImageSequence.Iterator(Image.open(io.BytesIO(gif_bytes)))]
    s = max(max(f.size) for f in seq)
    # quadros demais para caber em MAX_W: pula quadros por igual (a animação fica um pouco mais curta)
    if s * len(seq) > MAX_W:
        n = MAX_W // s
        seq = [seq[int(i * len(seq) / n)] for i in range(n)]
    out = Image.new("RGBA", (s * len(seq), s))
    for i, fr in enumerate(seq):
        out.paste(fr, (i * s + (s - fr.size[0]) // 2, s - fr.size[1]))
    out.save(path)


def icon(no, path):
    im = Image.open(io.BytesIO(fetch("PokeAPI/sprites/master/sprites/pokemon/versions/generation-iv/heartgold-soulsilver/%d.png" % no))).convert("RGBA")
    im.save(path)

def party(name, path):
    no = [n for n, nm in json.load(open(LIST)) if nm == name][0]
    im = Image.open(io.BytesIO(fetch("PokeAPI/sprites/master/sprites/pokemon/versions/generation-vii/icons/%d.png" % no))).convert("RGBA")
    im = im.crop(im.getchannel("A").getbbox())
    k = min(2.0, 60.0 / max(im.size))
    im = im.resize((max(1, round(im.size[0] * k)), max(1, round(im.size[1] * k))), Image.NEAREST)
    out = Image.new("RGBA", (128, 64))
    x = (64 - im.size[0]) // 2
    y = 62 - im.size[1]
    out.paste(im, (x, y), im)
    out.paste(im, (64 + x, y - 2), im)
    out.save(path)


def main():
    new = json.load(open(LIST))
    rep = {}
    for no, name in new:
        dst = os.path.join(OUT, slug(name))
        os.makedirs(dst, exist_ok=True)
        rep[name] = pmd(no, dst)
        strip(fetch("PokeAPI/sprites/master/sprites/pokemon/versions/generation-v/black-white/animated/%d.gif" % no), os.path.join(dst, "front.png"))
        strip(fetch("PokeAPI/sprites/master/sprites/pokemon/versions/generation-v/black-white/animated/back/%d.gif" % no), os.path.join(dst, "back.png"))
        icon(no, os.path.join(dst, "icon.png"))
        party(name, os.path.join(dst, "party_icon.png"))
        print(no, name, len(rep[name]), "Idle" in rep[name], flush=True)

main()
