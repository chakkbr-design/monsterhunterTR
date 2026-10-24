"""Atualiza data/species.json para a geração atual (PokeAPI) nos Pokémon de número 1..N (padrão 51).

Stats base, tipos, habilidades (normais + oculta), learnset por nível da versão mais recente em que a
espécie aparece (SV > SwSh > BDSP > USUM), golpes de evolução (nível 0 da PokeAPI), TMs, egg e tutor.
Só entram golpes que existem em data/moves.json; os que faltam são listados no fim.
Espécies que faltam no jogo são criadas com os campos de jogo (forma, locomoção, pulo) de um modelo.
Rodar da raiz do projeto: python tools/gen9_species.py [cache_pokeapi] [N]
"""

import json, os, sys

P = os.path.join(os.path.dirname(__file__), "..", "..", "pba-referencia", "dados", "pokeapi")
if len(sys.argv) > 1:
    P = sys.argv[1]
LAST = int(sys.argv[2]) if len(sys.argv) > 2 else 51
PREF = ["scarlet-violet", "sword-shield", "brilliant-diamond-shining-pearl", "ultra-sun-ultra-moon"]
GROWTH = {
    "slow": "slow",
    "medium": "medium_fast",
    "fast": "fast",
    "medium-slow": "medium_slow",
    "slow-then-very-fast": "erratic",
    "fast-then-very-slow": "fluctuating",
}
STAT = {
    "hp": "hp",
    "attack": "atk",
    "defense": "def",
    "special-attack": "spa",
    "special-defense": "spd",
    "speed": "spe",
}
# Campos de jogo das espécies novas (não vêm da PokeAPI): copiados do modelo e ajustados.
NEW_TEMPLATE = {
    37: ("Vulpix", {"shape": "quadruped", "locomotion": "ground"}),
    38: ("Ninetales", {"shape": "quadruped", "locomotion": "ground"}),
    48: ("Venonat", {"shape": "upright", "locomotion": "ground"}),
    49: ("Venomoth", {"shape": "bug-wings", "locomotion": "fly", "fly_height": 1.1}),
}
ITEM_EVO = {"fire-stone": "fire_stone", "moon-stone": "moon_stone", "thunder-stone": "thunder_stone",
            "leaf-stone": "leaf_stone", "water-stone": "water_stone"}


def load(name):
    return json.load(open(os.path.join(P, name + ".json"), encoding="utf-8"))


def mid(name):
    return name.replace("-", "_")


def latest_vg(p, method):
    by = {}
    for mv in p["moves"]:
        for d in mv["version_group_details"]:
            if d["move_learn_method"]["name"] == method:
                by.setdefault(d["version_group"]["name"], []).append((d["level_learned_at"], mv["move"]["name"]))
    for vg in PREF:
        if vg in by:
            return vg, by[vg]
    return None, []


def moves_in(p, method, vg):
    out = []
    for mv in p["moves"]:
        for d in mv["version_group_details"]:
            if d["move_learn_method"]["name"] == method and d["version_group"]["name"] == vg:
                out.append(mid(mv["move"]["name"]))
    return sorted(set(out))


def evo_chain_next(species):
    """Próxima evolução da espécie: (dex_no, detalhes) ou None."""
    chain = load_chain(species)

    def walk(node):
        if node["species"]["name"] == species["name"]:
            return node["evolves_to"]
        for n in node["evolves_to"]:
            r = walk(n)
            if r is not None:
                return r
        return None

    return walk(chain["chain"]) or []


_CHAINS = {}


def load_chain(species):
    url = species["evolution_chain"]["url"]
    if url not in _CHAINS:
        fn = os.path.join(P, "evolution-chain_%s.json" % url.rstrip("/").split("/")[-1])
        if not os.path.exists(fn):
            import urllib.request

            d = json.loads(urllib.request.urlopen(urllib.request.Request(url, headers={"User-Agent": "x"})).read())
            json.dump(d, open(fn, "w", encoding="utf-8"))
        _CHAINS[url] = json.load(open(fn, encoding="utf-8"))
    return _CHAINS[url]


def main():
    path = "data/species.json"
    doc = json.load(open(path, encoding="utf-8"))
    known = {m["id"] for m in json.load(open("data/moves.json", encoding="utf-8"))["moves"]}
    by_no = {v["dex_no"]: k for k, v in doc.items() if k != "_doc"}
    names = {}
    for no in range(1, 152):
        sp = load("pokemon-species_%d" % no)
        names[sp["name"]] = by_no.get(no) or next(
            n["name"] for n in sp["names"] if n["language"]["name"] == "en"
        )
    missing = {}
    for no in range(1, LAST + 1):
        p = load("pokemon_%d" % no)
        sp = load("pokemon-species_%d" % no)
        key = by_no.get(no)
        if key is None:
            key, extra = NEW_TEMPLATE[no]
            doc[key] = dict(extra)
            doc[key]["dex_no"] = no
            names[sp["name"]] = key
        e = doc[key]
        e["types"] = [t["type"]["name"] for t in sorted(p["types"], key=lambda t: t["slot"])]
        e["base"] = {STAT[s["stat"]["name"]]: s["base_stat"] for s in p["stats"]}
        e["ev_yield"] = {STAT[s["stat"]["name"]]: s["effort"] for s in p["stats"] if s["effort"]}
        ab = sorted(p["abilities"], key=lambda a: a["slot"])
        e["abilities"] = [mid(a["ability"]["name"]) for a in ab]
        hid = [mid(a["ability"]["name"]) for a in ab if a["is_hidden"]]
        if hid:
            e["hidden_ability"] = hid[0]
        else:
            e.pop("hidden_ability", None)
        vg, lv = latest_vg(p, "level-up")
        evo, learn = [], []
        for lvl, name in sorted(lv):
            m = mid(name)
            if m not in known:
                missing.setdefault(m, []).append(key)
                continue
            if lvl == 0:
                evo.append(m)
            else:
                learn.append([lvl, m])
        e["learnset"] = learn
        if evo:
            e["evo_moves"] = evo
        else:
            e.pop("evo_moves", None)
        e["learnset_version"] = vg
        for method, field in (("machine", "tm"), ("egg", "egg"), ("tutor", "tutor")):
            ids = [m for m in moves_in(p, method, vg) if m in known]
            if ids or field == "tm":
                e[field] = ids
            else:
                e.pop(field, None)
        e["moves"] = [m for m in e.get("moves", []) if m in known and m in {x[1] for x in learn} | set(evo) | set(e["tm"])]
        if len(e["moves"]) < 4:
            for _, m in reversed(learn):
                if m not in e["moves"] and len(e["moves"]) < 4:
                    e["moves"].append(m)
        e["catch_rate"] = sp["capture_rate"]
        e["base_exp"] = p["base_experience"]
        e["growth"] = GROWTH[sp["growth_rate"]["name"]]
        e["gender_ratio"] = -1 if sp["gender_rate"] < 0 else sp["gender_rate"] / 8.0
        e["height_m"] = p["height"] / 10.0
        e["weight_kg"] = p["weight"] / 10.0
        e["category"] = next(g["genus"] for g in sp["genera"] if g["language"]["name"] == "en")
        if "flavor" not in e:
            fl = [f for f in sp["flavor_text_entries"] if f["language"]["name"] == "en"]
            e["flavor"] = " ".join(fl[-1]["flavor_text"].split()) if fl else ""
        nxt = evo_chain_next(sp)
        if nxt:
            n = nxt[0]
            d = n["evolution_details"][0] if n["evolution_details"] else {}
            into = names.get(n["species"]["name"])
            if d.get("trigger", {}).get("name") == "level-up" and d.get("min_level"):
                e["evolution"] = {"level": d["min_level"], "into": into}
            elif d.get("trigger", {}).get("name") == "use-item":
                e["evolution"] = {"method": "item", "item": ITEM_EVO.get(d["item"]["name"], mid(d["item"]["name"])), "into": into}
            elif "evolution" not in e:
                e["evolution"] = {"method": d.get("trigger", {}).get("name", "level-up"), "into": into}
        e.setdefault("pp", 100)
        e.setdefault("jump_height", 0.35)
        e.setdefault("sprite", "res://assets/sprites/critter_purple.png")
    json.dump(doc, open(path, "w", encoding="utf-8", newline="\n"), ensure_ascii=False, indent=2)
    open(path, "a", encoding="utf-8").write("\n")
    print("golpes que faltam em moves.json (%d):" % len(missing))
    for m, who in sorted(missing.items()):
        print("  %s: %s" % (m, ", ".join(who)))


main()
