"""Monta original/assets/pokemon/<slug>/ das espécies de Kanto que não vieram do original (arte fora do git):
- pmd/*-Anim.png + pmd/anims.json do PMD SpriteCollab (só as animações que data/pmd_anims.json usa); as âncoras
  saem do *-Shadow.png (centro x, base y) e Idle/Walk/Hop fixam o pé no quadro, igual ao importador antigo;
- front.png/back.png: BW animados (PokeAPI sprites) em tira de quadros quadrados, no máximo 8192 px de largura;
- icon.png: frente HGSS 80x80; party_icon.png: ícone Gen 7 em 2x, 2 quadros (o 2º 2 px acima).
Fora de Kanto (biblioteca para espécies futuras) os mesmos arquivos saem com o que existir: frente/costas
BW animadas até o 649 (depois, as estáticas da PokeAPI), ícone HGSS até o 493 (depois, a frente padrão),
ícone de grupo Gen 7 ou Gen 8; espécie sem pasta no SpriteCollab fica sem pmd/.
Uso: git clone --filter=blob:none --sparse do PMDCollab/SpriteCollab (pastas sprite/NNNN) e
python tools/kanto_sprites.py <SpriteCollab/sprite> <saída> <lista.json [[dex, nome], ...] | 152-1025>
(com um intervalo, os nomes em inglês vêm da PokeAPI).
"""
import json, os, re, sys, io, urllib.request, urllib.error, xml.etree.ElementTree as ET
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
    # o mesmo de PokemonSprites.slug, sem os caracteres que o Windows não aceita em pasta (Type: Null)
    s = name.lower().replace(" ", "_").replace(".", "").replace("'", "")
    return re.sub(r'[<>:"/\\|?*]', "", s)


def get(path):
    """Arquivo do raw do GitHub ou None se não existe (404)."""
    try:
        return fetch(path)
    except urllib.error.HTTPError as e:
        if e.code == 404:
            return None
        raise


def species_list():
    if os.path.exists(LIST):
        return json.load(open(LIST))
    a, b = (int(x) for x in LIST.split("-"))
    out = []
    for no in range(a, b + 1):
        fn = os.path.join(CACHE, "species_%d.json" % no)
        if not os.path.exists(fn):
            url = "https://pokeapi.co/api/v2/pokemon-species/%d/" % no
            open(fn, "wb").write(urllib.request.urlopen(urllib.request.Request(url, headers={"User-Agent": "x"}), timeout=60).read())
        sp = json.load(open(fn, encoding="utf-8"))
        out.append([no, next(n["name"] for n in sp["names"] if n["language"]["name"] == "en").replace("\u2019", "'")])
    return out

def anchors(name, d, w, h, dirs, nfr):
    shp = os.path.join(d, name + "-Shadow.png")
    sh = Image.open(shp if os.path.exists(shp) else os.path.join(d, name + "-Anim.png")).convert("RGBA")
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
    raw = get("PokeAPI/sprites/master/sprites/pokemon/versions/generation-iv/heartgold-soulsilver/%d.png" % no)
    if raw is None:
        raw = get("PokeAPI/sprites/master/sprites/pokemon/%d.png" % no)
    if raw is not None:
        Image.open(io.BytesIO(raw)).convert("RGBA").save(path)


def front_back(no, dst):
    for side, fn in (("", "front.png"), ("back/", "back.png")):
        raw = get("PokeAPI/sprites/master/sprites/pokemon/versions/generation-v/black-white/animated/%s%d.gif" % (side, no))
        if raw is None:
            raw = get("PokeAPI/sprites/master/sprites/pokemon/%s%d.png" % (side, no))
        if raw is not None:
            strip(raw, os.path.join(dst, fn))


def party(no, path):
    raw = None
    for gen in ("vii", "viii"):
        raw = raw or get("PokeAPI/sprites/master/sprites/pokemon/versions/generation-%s/icons/%d.png" % (gen, no))
    if raw is None:
        return
    im = Image.open(io.BytesIO(raw)).convert("RGBA")
    im = im.crop(im.getchannel("A").getbbox())
    k = min(2.0, 60.0 / max(im.size))
    im = im.resize((max(1, round(im.size[0] * k)), max(1, round(im.size[1] * k))), Image.NEAREST)
    out = Image.new("RGBA", (128, 64))
    x = (64 - im.size[0]) // 2
    y = 62 - im.size[1]
    out.paste(im, (x, y), im)
    out.paste(im, (64 + x, y - 2), im)
    out.save(path)


def one(item):
    no, name = item
    dst = os.path.join(OUT, slug(name))
    os.makedirs(dst, exist_ok=True)
    anims = pmd(no, dst) if os.path.exists(os.path.join(SC, "%04d" % no, "AnimData.xml")) else []
    front_back(no, dst)
    icon(no, os.path.join(dst, "icon.png"))
    party(no, os.path.join(dst, "party_icon.png"))
    print(no, name, len(anims), "Idle" in anims, flush=True)


def main():
    from concurrent.futures import ThreadPoolExecutor

    with ThreadPoolExecutor(8) as ex:
        list(ex.map(one, species_list()))


main()
