"""Atualiza os golpes de data/moves.json para os valores atuais (PokeAPI, Gen 9).

Poder: o valor do jogo é escalado pela razão atual/Gen 3 (golpes adaptados, como streams por tique,
mantêm a adaptação). Precisão, PP (uses), categoria e chance de efeito vêm direto da geração atual.
Cache da PokeAPI em ../pba-referencia/dados/pokeapi (tools/gen9_fetch.py). Rodar da raiz do projeto.
"""

import json, os, sys

P = os.path.join(os.path.dirname(__file__), "..", "..", "pba-referencia", "dados", "pokeapi")
if len(sys.argv) > 1:
    P = sys.argv[1]
VG = [
    v["name"]
    for v in json.load(open(os.path.join(P, "version-group_limit_100.json"), encoding="utf-8"))[
        "results"
    ]
]
FRLG = VG.index("firered-leafgreen")


_IDX = {}


def api(mid):
    if not _IDX:
        for f in os.listdir(P):
            if f.startswith("move_"):
                d = json.load(open(os.path.join(P, f), encoding="utf-8"))
                _IDX[d["name"]] = d
    return _IDX.get(mid)


def dump_moves(doc, path):
    """Mesmo layout do arquivo: um golpe por linha."""
    lines = ['{', '  "_doc": %s,' % json.dumps(doc["_doc"], ensure_ascii=False), '  "moves": [']
    body = ["    " + json.dumps(m, ensure_ascii=False) for m in doc["moves"]]
    lines.append(",\n".join(body))
    lines += ["  ]", "}"]
    open(path, "w", encoding="utf-8", newline="\n").write("\n".join(lines) + "\n")


def gen3(d, field):
    """Valor do campo na Gen 3: o primeiro past_value cuja versão é >= FRLG, senão o atual."""
    best = None
    for pv in d.get("past_values", []):
        i = VG.index(pv["version_group"]["name"])
        if i >= FRLG and pv.get(field) is not None and (best is None or i < best[0]):
            best = (i, pv[field])
    return best[1] if best else d.get(field)


def main():
    path = "data/moves.json"
    doc = json.load(open(path, encoding="utf-8"))
    log = []
    for mv in doc["moves"]:
        d = api(mv["id"].replace("_", "-"))
        if d is None:
            log.append("sem dados: " + mv["id"])
            continue
        p9, p3 = d.get("power"), gen3(d, "power")
        if p9 and p3 and p9 != p3 and mv.get("power", 0) > 0 and mv["power"] != p9:
            old = mv["power"]
            mv["power"] = round(old * p9 / p3, 1) if old != p3 else p9
            if mv["power"] == int(mv["power"]):
                mv["power"] = int(mv["power"])
            log.append("%s poder %s -> %s (Gen3 %s, Gen9 %s)" % (mv["id"], old, mv["power"], p3, p9))
        if p9:
            mv["bp"] = p9  # poder de verdade (Gen 9): base do cooldown dos golpes fortes
        tgt = d.get("target", {}).get("name", "")
        if tgt in ("all-opponents", "all-other-pokemon", "all-pokemon"):
            mv["multi_target"] = tgt.replace("-", "_")
        else:
            mv.pop("multi_target", None)
        acc = d.get("accuracy")
        if acc is None:
            if "accuracy" in mv:
                log.append("%s precisão %s -> nunca erra" % (mv["id"], mv["accuracy"]))
                mv.pop("accuracy")
        elif mv.get("accuracy") != acc and "accuracy" in mv:
            log.append("%s precisão %s -> %s" % (mv["id"], mv.get("accuracy"), acc))
            mv["accuracy"] = acc
        if d.get("pp") and mv.get("uses") != d["pp"]:
            log.append("%s PP %s -> %s" % (mv["id"], mv.get("uses"), d["pp"]))
            mv["uses"] = d["pp"]
        cat = d["damage_class"]["name"]
        if mv.get("category") != cat:
            log.append("%s categoria %s -> %s" % (mv["id"], mv.get("category"), cat))
            mv["category"] = cat
        if d.get("type", {}).get("name") and mv.get("type") != d["type"]["name"]:
            log.append("%s tipo %s -> %s" % (mv["id"], mv.get("type"), d["type"]["name"]))
            mv["type"] = d["type"]["name"]
        pri = d.get("priority", 0)
        if pri != mv.get("priority", 0):
            log.append("%s prioridade %s -> %s" % (mv["id"], mv.get("priority", 0), pri))
            if pri:
                mv["priority"] = pri
            else:
                mv.pop("priority", None)
        ch = d.get("effect_chance")
        ef = mv.get("effect")
        if ch and isinstance(ef, dict) and "chance" in ef:
            want = ch / 100.0
            c3 = gen3(d, "effect_chance")
            # chance adaptada (por tique) escala como o poder
            new = want if abs(ef["chance"] - want) < 1e-6 else round(ef["chance"] * want / (c3 / 100.0), 3) if c3 and abs(ef["chance"] - c3 / 100.0) > 1e-6 else want
            if abs(new - ef["chance"]) > 1e-6:
                log.append("%s chance de efeito %s -> %s" % (mv["id"], ef["chance"], new))
                ef["chance"] = new
        mv["name"] = next(
            (n["name"] for n in d.get("names", []) if n["language"]["name"] == "en"), mv["name"]
        )
    dump_moves(doc, path)
    print("\n".join(log))


main()
