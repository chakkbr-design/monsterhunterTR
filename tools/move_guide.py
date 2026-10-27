#!/usr/bin/env python3
"""Gera o guia dos golpes: como cada golpe oficial (Gen 9) foi adaptado ao tempo real.

Le data/moves.json (+ data/species.json para contar quem aprende cada golpe) e escreve
  docs/GOLPES.md              (sempre)
  <caminho.html>              (se um caminho for passado como argumento)

Uso, da raiz do projeto:
    python tools/move_guide.py [saida.html]

Os numeros de energia e cooldown repetem a conta do codigo: battle/battle_energy.gd (custo) e
core/dex.gd (Dex.cooldown). O texto de "Adaptacao" vem dos campos do golpe + dos dicionarios
SPECIAL / BESPOKE abaixo, que explicam em portugues o que battle/battle_move_effects.gd,
battle_moves.gd e battle_physics.gd fazem por chave/flag (BESPOKE: golpes com codigo proprio por id).
Quando o codigo mudar, ajuste esses dicionarios e rode de novo.
"""

import html
import json
import math
import os
import sys

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
MOVES_PATH = os.path.join(ROOT, "data", "moves.json")
SPECIES_PATH = os.path.join(ROOT, "data", "species.json")
MD_PATH = os.path.join(ROOT, "docs", "GOLPES.md")

# ---------------------------------------------------------------- constantes do codigo
# core/dex.gd
PP_POOL_REF = 100.0
COOLDOWN_SCALE = 2.5
MIN_COOLDOWN = 1.6
STATUS_COOLDOWN_MULT = 3.0
MIN_STATUS_COOLDOWN_VIVA = 8.0
STRONG_BP = 70.0
STRONG_BP_SPAN = 80.0
# battle/battle_energy.gd
E_BASE, E_BP, E_MAX_COST, E_STATUS, E_VARIABLE = 12.0, 0.25, 50.0, 28.0, 70.0
E_MEAN_HITS = 3.1
E_PRIORITY_COST, E_PRIORITY_CD = 0.6, 1.8
# battle/battle_moves.gd
MISSABLE = ["dash", "arc", "multi_arc", "whip", "projectile", "beam", "aoe_target", "zone"]
# battle/battle_physics.gd (tabelas por id)
PUSH_IDS = {"whirlwind": 5.0, "roar": 5.0, "dragon_tail": 4.0, "circle_throw": 4.0}
LEAP_IDS = {
    "body_slam": {"secs": 0.42, "h": 1.5},
    "stomp": {"secs": 0.34, "h": 1.0},
    "heavy_slam": {"secs": 0.5, "h": 2.0},
    "heat_crash": {"secs": 0.5, "h": 2.0},
    "high_jump_kick": {"secs": 0.4, "h": 1.6},
    "bounce": {"secs": 1.1, "h": 4.5, "sky": True},
    "fly": {"secs": 1.2, "h": 5.0, "sky": True},
}
BLINK_IDS = ["aerial_ace", "feint_attack", "shadow_sneak"]
TUNNEL_IDS = {"dig": "dig", "dive": "dive"}
# battle/battle_move_effects.gd
BIND_MOVES = ["wrap", "bind", "fire_spin", "whirlpool", "sand_tomb", "clamp", "infestation",
              "magma_storm", "snap_trap", "thunder_cage"]
SOUND_MOVES = ["alluring_voice", "bug_buzz", "disarming_voice", "echoed_voice", "growl", "howl",
               "hyper_voice", "metal_sound", "psychic_noise", "roar", "round", "screech", "sing",
               "snarl", "snore", "supersonic", "uproar"]
QUAKE_MOVES = ["earthquake", "bulldoze", "magnitude"]

TYPES = ["normal", "fire", "water", "electric", "grass", "ice", "fighting", "poison", "ground",
         "flying", "psychic", "bug", "rock", "ghost", "dragon", "dark", "steel", "fairy"]
TYPE_PT = {
    "normal": "Normal", "fire": "Fogo", "water": "Água", "electric": "Elétrico", "grass": "Planta",
    "ice": "Gelo", "fighting": "Lutador", "poison": "Veneno", "ground": "Terra", "flying": "Voador",
    "psychic": "Psíquico", "bug": "Inseto", "rock": "Pedra", "ghost": "Fantasma", "dragon": "Dragão",
    "dark": "Sombrio", "steel": "Aço", "fairy": "Fada",
}
TYPE_HEX = {
    "normal": "#a8a77a", "fire": "#ee8130", "water": "#6390f0", "electric": "#f7d02c",
    "grass": "#7ac74c", "ice": "#96d9d6", "fighting": "#c22e28", "poison": "#a33ea1",
    "ground": "#e2bf65", "flying": "#a98ff3", "psychic": "#f95587", "bug": "#a6b91a",
    "rock": "#b6a136", "ghost": "#735797", "dragon": "#6f35fc", "dark": "#705746",
    "steel": "#b7b7ce", "fairy": "#d685ad",
}
CAT_PT = {"physical": "Físico", "special": "Especial", "status": "Status"}
STAT_PT = {"atk": "Ataque", "def": "Defesa", "spa": "At. Esp.", "spd": "Def. Esp.", "spe": "Speed",
           "acc": "Precisão", "evasion": "Evasão", "crit": "chance de crítico"}
STATUS_PT = {"burn": "Queimadura", "poison": "Veneno", "toxic": "Toxic (veneno grave)",
             "paralysis": "Paralisia", "sleep": "Sono", "freeze": "Congelamento",
             "confusion": "Confusão", "flinch": "Hesitar", "leech": "Semente (Leech Seed)"}
STATUS_NOTE = {
    "burn": "1/16 do HP por rodada e o dano físico dele cai à metade; Fogo é imune",
    "poison": "1/8 do HP por rodada; Veneno e Aço são imunes",
    "toxic": "n/16 do HP no n-ésimo turno; Veneno e Aço são imunes",
    "paralysis": "Speed x0,5 e 20% de chance de o golpe falhar; Elétrico é imune",
    "sleep": "não age por 1 a 3 rodadas; golpe recebido não acorda",
    "freeze": "20% de descongelar a cada tentativa de agir; golpe de Fogo descongela; Gelo é imune",
    "confusion": "2 a 5 rodadas; 33% dos golpes saem em direção aleatória",
    "flinch": "o alvo fica parado 0,5 s",
    "leech": "1/8 do HP por rodada passa para quem plantou; Planta é imune",
}

KIND_PT = {
    "dash": "Investida", "arc": "Arco (contato)", "multi_arc": "Arco em sequência",
    "projectile": "Projétil", "homing": "Teleguiado", "stream": "Jato", "beam": "Raio",
    "aoe_self": "Onda ao redor", "aoe_target": "Área no alvo", "zone": "Zona no chão",
    "self_buff": "Efeito próprio", "debuff_aoe": "Efeito ao redor", "clones": "Cópias",
    "whip": "Chicote",
}
KIND_ORDER = ["dash", "arc", "multi_arc", "whip", "projectile", "homing", "stream", "beam",
              "aoe_self", "aoe_target", "zone", "self_buff", "debuff_aoe", "clones"]
KIND_DESC = {
    "dash": "O Pokémon corre até o alvo e bate no contato (golpe de corpo, mordida, investida). Sai do chão: espera pousar.",
    "arc": "Golpe de contato em cone curto na frente do usuário (garra, soco, rabada). Acerta quem estiver no cone.",
    "multi_arc": "Vários golpes de contato em sequência rápida no mesmo cone (Double Kick, Fury Swipes).",
    "whip": "Chicote: a ponta varre uma linha até o alcance e acerta o primeiro que tocar (Vine Whip).",
    "projectile": "Projétil que voa em linha reta (bola, folha, agulha, jato de água); dá para desviar. Pode sair em leque ou em arco.",
    "homing": "Projétil teleguiado que faz curva atrás do alvo (Swift, Aura Sphere); a curva fraca dos de dreno (Absorb) ainda deixa desviar.",
    "stream": "Jato ou sopro em cone mantido por uma fração de segundo (Flamethrower, Gust); o usuário fica parado e trava no alvo.",
    "beam": "Raio em linha reta com aviso no chão antes de disparar (Hyper Beam, Ice Beam); o usuário fica parado e vulnerável.",
    "aoe_self": "Onda em volta do usuário, com aviso no chão (Earthquake, Surf, Explosion); quem está dentro do raio apanha, dá para pular ou sair.",
    "aoe_target": "Marca uma área no chão sobre o alvo e bate depois do aviso (Thunder, Rock Slide, Psychic); quem sai da marca escapa.",
    "zone": "Área que fica no chão por alguns segundos e bate a cada pulso em quem estiver dentro (Fire Spin, Sand Tomb).",
    "self_buff": "Sem alvo: o efeito cai no próprio usuário ou no campo (Swords Dance, Protect, Rain Dance). Nunca erra.",
    "debuff_aoe": "Efeito de status em quem estiver até um raio do usuário (Growl, Tail Whip); sem multi_target só o mais perto é afetado. Nunca erra.",
    "clones": "Cria cópias ilusórias em volta do usuário que absorvem golpes (Double Team).",
}
KIND_MISS = {k: ("sim" if k in MISSABLE else "não") for k in KIND_PT}

# Quem no oficial tem varios golpes por uso (avisa se faltar hits_range nos dados)
OFFICIAL_MULTI = ["arm_thrust", "barrage", "bone_rush", "bonemerang", "bullet_seed", "comet_punch",
                  "double_hit", "double_iron_bash", "double_kick", "double_slap", "dragon_darts",
                  "dual_chop", "dual_wingbeat", "fury_attack", "fury_swipes", "gear_grind",
                  "icicle_spear", "pin_missile", "population_bomb", "rock_blast", "scale_shot",
                  "spike_cannon", "surging_strikes", "tachyon_cutter", "tail_slap", "triple_axel",
                  "triple_dive", "triple_kick", "twin_beam", "twineedle", "water_shuriken"]


# ---------------------------------------------------------------- numeros em portugues
def num(x, nd=1):
    """12.0 -> '12', 1.5 -> '1,5'."""
    x = float(x)
    if abs(x - round(x)) < 1e-9:
        return str(int(round(x)))
    s = ("%." + str(nd) + "f") % x
    s = s.rstrip("0").rstrip(".")
    return s.replace(".", ",")


def godot_round(x):
    return math.floor(x + 0.5) if x >= 0 else -math.floor(-x + 0.5)


def snap(x, step=0.1):
    return godot_round(x / step) * step


# ---------------------------------------------------------------- custo e cooldown
def pp_cost(m):
    if "pp_cost" in m:
        return float(m["pp_cost"])
    if "uses" in m:
        return PP_POOL_REF / max(1.0, float(m["uses"]))
    if m.get("category") == "status":
        return 3.0
    total = float(m.get("power", 0)) * max(1.0, float(m.get("count", 1))) * max(1.0, float(m.get("hits", 1)))
    if m.get("kind") == "stream":
        total *= max(1.0, float(m.get("duration", 1.0)) / float(m.get("tick", 0.15)))
    return min(max(math.ceil(total / 20.0), 1.0), 12.0)


def dex_cooldown(m):
    if "cooldown" in m:
        return max(float(m["cooldown"]), MIN_COOLDOWN)
    weight = float(m["fatigue"]) if "fatigue" in m else pp_cost(m) * 10.0
    cd = (float(m.get("windup", 0.0)) + float(m.get("duration", 0.0)) + weight / 40.0) * COOLDOWN_SCALE
    if m.get("category") == "status":
        cd = max(cd * STATUS_COOLDOWN_MULT, MIN_STATUS_COOLDOWN_VIVA)
    else:
        cd = max(cd, MIN_COOLDOWN)
        bp = float(m.get("bp", 0))
        if bp > STRONG_BP:
            cd *= 1.0 + (bp - STRONG_BP) / STRONG_BP_SPAN
    return snap(cd)


def nominal_bp(m):
    bp = float(m.get("bp", 0))
    if bp <= 0.0:
        return E_VARIABLE
    hr = m.get("hits_range")
    if isinstance(hr, list):
        lo, hi = int(hr[0]), int(hr[1])
        bp *= float(lo) if lo == hi else E_MEAN_HITS
    return bp


def energy_cost(m):
    c = E_STATUS
    if m.get("category") != "status":
        c = min(E_BASE + nominal_bp(m) * E_BP, E_MAX_COST)
    if int(m.get("priority", 0)) > 0:
        c *= E_PRIORITY_COST
    return int(godot_round(c))


def energy_cooldown(m):
    cd = dex_cooldown(m)
    if int(m.get("priority", 0)) > 0:
        cd *= E_PRIORITY_CD
    return cd


# ---------------------------------------------------------------- textos por flag / special
def est(n):
    n = abs(int(n))
    return "%d estágio" % n if n == 1 else "%d estágios" % n


def stage_word(n):
    n = int(n)
    if n > 0:
        return "+%d" % n
    return "%d" % n


def stats_text(d):
    return ", ".join("%s %s" % (STAT_PT.get(k, k), stage_word(v)) for k, v in d.items())


# special -> texto (str ou funcao do golpe). Chaves de "special" em data/moves.json.
SPECIAL = {
    "self_confuse": "Depois que o golpe termina, o usuário fica confuso de cansaço (como o oficial, que repete 2-3 turnos e confunde ao fim).",
    "heal_weather": "Cura o usuário em 1/2 do HP máximo; 2/3 sob sol forte, 1/4 sob qualquer outro clima (chuva, areia, neve).",
    "revenge": "Poder x2 se o alvo acertou o usuário nos últimos 1,5 s (o 'virou o jogo' do Revenge/Avalanche/Payback).",
    "pivot": "Depois de bater, o usuário troca de lugar com o próximo Pokémon do banco (sai 0,35 s depois). Sem reserva, só bate.",
    "covet": "Se causar dano, rouba o item do treinador do alvo (só se o usuário estiver sem item).",
    "fixed": lambda m: "Dano fixo de %s HP (não usa a fórmula; imunidade de tipo ainda vale). Só o ritmo x0,75 do jogo vai por cima." % num(m.get("fixed", 20)),
    "flail": "Poder 20 a 200 pela tabela oficial do Flail/Reversal: quanto menos HP o usuário tem, mais forte.",
    "low_kick": "Poder 20 a 120 pelo peso do alvo (tabela oficial: leve bate fraco, pesado bate forte).",
    "chain": lambda m: "Usos seguidos que acertam dobram o poder (até %d dobras, x%d); errar ou esperar demais zera a corrente.%s" % (
        int(m.get("chain", 2)), 2 ** int(m.get("chain", 2)),
        " Enrolado com Defense Curl, dobra de novo." if m.get("id") == "rollout" else ""),
    "level_damage": "Dano fixo igual ao nível do usuário (Seismic Toss / Night Shade). Só o ritmo x0,75 vai por cima.",
    "pluck": "Se houver uma frutinha no chão perto do alvo, o usuário a come (cura 10% do HP) e libera o Belch.",
    "ohko": "Nocaute em um golpe: tira todo o HP do alvo. A precisão sobe 1 ponto por nível do usuário acima do alvo; não afeta alvo de nível maior nem Sturdy.",
    "flatter": lambda m: "Além da confusão, sobe %s do alvo (%s)." % (
        "o Ataque" if m.get("flatter_stat") == "atk" else "o At. Esp.",
        "+2 estágios, como o Swagger" if m.get("flatter_stat") == "atk" else "+1 estágio, como o Flatter"),
    "follow_me": lambda m: "Até o fim da rodada, os golpes de alvo único dos adversários passam a mirar o usuário.%s" % (
        " Pó: não funciona contra Planta." if m.get("powder") else ""),
    "mean_look": "Se acertar, o alvo não pode fugir nem trocar de Pokémon (Fantasma é imune).",
    "jealousy": lambda m: "Além do dano, aplica %s só se o alvo subiu algum atributo na mesma rodada." % STATUS_PT.get(m.get("jealous_status", "burn"), "o status").lower(),
    "regen": lambda m: ("Cria raízes: cura 1/16 do HP no fim de cada rodada, o usuário não é empurrado nem pode trocar (Ingrain)." if m.get("rooted")
                        else "Anel de água: cura 1/16 do HP no fim de cada rodada até sair de campo (Aqua Ring)."),
    "screen_break": "Se o golpe for eficaz, quebra o Reflect e o Light Screen do lado do alvo antes de acertar.",
    "counter": lambda m: "Postura de 1 s parado (prioridade -5): o primeiro golpe %s recebido nela volta com o dobro do dano para quem bateu." % (
        "físico" if m.get("counter_cat", "physical") == "physical" else "especial"),
    "heat_crash": "Poder 40 a 120 pela razão de peso usuário/alvo (>=2x: 60, >=3x: 80, >=4x: 100, >=5x: 120). Salta e cai em cima do alvo.",
    "stomping_tantrum": "Poder x2 se o golpe anterior do usuário falhou (errou, foi bloqueado ou sem efeito).",
    "trick": "Troca o item do treinador entre o usuário e o alvo (falha se nenhum tiver item).",
    "heal_half": lambda m: "Cura %s%% do HP máximo do usuário." % num(float(m.get("heal", 0.5)) * 100),
    "curse": "Fantasma: gasta metade do HP e amaldiçoa o adversário (perde 1/4 do HP a cada rodada até o Curse sair de campo). Outros tipos: Ataque +1, Defesa +1, Speed -1.",
    "defense_curl": "Defesa +1 e marca o usuário como enrolado (o Rollout seguinte dobra de poder).",
    "disable": "Trava o último golpe usado pelo alvo por 4 rodadas.",
    "helping_hand": "Se o parceiro soltar um golpe de dano em até 4 s, ele sai com 1,5x por 2,5 s. Sem parceiro, falha.",
    "rain_dance": "Chuva por 5 rodadas: Água 1,5x, Fogo 0,5x; Thunder e Hurricane não erram.",
    "sunny_day": "Sol por 5 rodadas: Fogo 1,5x, Água 0,5x.",
    "sandstorm": "Tempestade de areia por 5 rodadas: 1/16 do HP por rodada em quem não é Pedra, Terra ou Aço; Def. Esp. dos de Pedra +50%.",
    "rapid_spin": "Depois de acertar, tira do usuário a Semente, o Wrap/Bind e as armadilhas (Spikes, Stealth Rock, Toxic Spikes) armadas pelo adversário.",
    "thunder_wave": "Não afeta Terra (e Elétrico é imune à paralisia). Um alvo sob Substitute bloqueia.",
    "yawn": "O alvo fica sonolento e dorme no fim da rodada seguinte (se estiver sem status). Falha se já tem status ou sonolência.",
    "electro_ball": "Poder 40 a 150 pela razão de Speed usuário/alvo (>=1x: 60, >=2x: 80, >=3x: 120, >=4x: 150).",
    "super_fang": "Dano fixo = metade do HP atual do alvo (mínimo 1). Só o ritmo x0,75 vai por cima.",
    "charge": "At. Esp. +1 e o próximo golpe Elétrico do usuário sai com poder x2 (vale até esse golpe acertar).",
    "encore": "O alvo só pode repetir o último golpe por 3 rodadas (os outros ficam travados).",
    "after_you": "O parceiro age já: zera o GCD dele e o cooldown do golpe mais pronto. Sem parceiro, falha.",
    "aromatherapy": "Cura o status principal de todo o time do usuário (os de campo e os do banco).",
    "assurance": "Poder x2 se o alvo levou dano nos últimos 1,5 s.",
    "snowscape": "Chama o granizo/neve no campo (clima de gelo por alguns turnos).",
    "conversion": "O usuário vira do tipo do primeiro golpe que tem.",
    "conversion_2": "O usuário ganha um tipo que resiste ao último golpe que recebeu.",
    "ignore_stages": "Ignora as mudanças de Defesa e Def. Esp. do alvo.",
    "dream_eater": "Só sai com o alvo dormindo; o usuário recupera metade do dano causado.",
    "entrainment": "A habilidade do alvo vira a do usuário.",
    "first_move": "Só funciona como primeiro golpe do usuário em campo (o primeiro turno do oficial).",
    "freeze_dry": "Água é fraca ao Gelo neste golpe (a resistência vira fraqueza).",
    "split_stats": "Os dois dividem a média dos atributos (Ataque/At. Esp. ou Defesa/Def. Esp.).",
    "swap_stages": "Troca as mudanças de estágio de Defesa/Def. Esp. (ou Ataque/At. Esp.) com o alvo.",
    "magic_coat": "Janela curta em que golpes de status do inimigo voltam contra quem os lançou.",
    "magic_room": "Campo por alguns turnos: itens de treinador ficam sem efeito para todos.",
    "metal_burst": "Devolve 1,5x o último dano recebido (janela de 2,5 s); falha se ninguém acertou.",
    "nature_power": "Vira outro golpe conforme o terreno em que o usuário está (Earth Power, Ice Beam, Hydro Pump...).",
    "perish_song": "Quem estiver no raio (7 m) e ouvir desmaia em 3 rodadas, se não sair do campo.",
    "poltergeist": "Arremessa o item do alvo; sem item, usa um objeto do cenário próximo; sem nenhum, falha.",
    "reflect_type": "O usuário copia os tipos do alvo.",
    "retaliate": "Poder x2 se um aliado desmaiou nos últimos 8 s.",
    "role_play": "O usuário copia a habilidade do alvo.",
    "cure_burn": "Cura a queimadura do alvo.",
    "swap_stats": "Troca a Speed com o alvo.",
    "steel_roller": "Aplaina o terreno de campo; só funciona com terreno ou morro/pico ao alcance.",
    "teleport": "Some e reaparece num ponto livre da quadra, longe dos inimigos; solta de prisões.",
    "terrain_pulse": "Poder x2 e tipo do terreno de campo ativo.",
    "transform": "Vira cópia do alvo: tipos, stats (menos HP), golpes, habilidade e aparência (BattleTransform).",
    "triple_axel": "Três chutes seguidos; o poder cresce a cada acerto (20, 40, 60).",
    "belch": "Só pode ser usado depois de comer uma frutinha na luta (ver Pluck/Bug Bite).",
    "copycat": "Usa o último golpe usado na luta por qualquer um (fora da lista proibida de Metronome/Copycat/Mimic).",
    "echoed_voice": "Poder x(1 + usos seguidos do lado), até x5 (limite 200): cada uso dentro da janela solta mais forte que o anterior.",
    "endeavor": "Reduz o HP do alvo até o HP do usuário (falha se o alvo já tem HP igual ou menor).",
    "feint": "Quebra o Protect/Quick Guard do alvo (a proteção cai) e bate normalmente.",
    "fell_stinger": "Se o golpe nocautear o alvo, Ataque do usuário +3 estágios.",
    "gastro_acid": "Anula a habilidade do alvo pelo resto da luta.",
    "grassy_terrain": "Campo de grama por 5 rodadas: Planta 1,3x para quem está no chão, cura 1/16 do HP por rodada no chão, Earthquake/Bulldoze/Magnitude 0,5x. Um terreno tira o outro.",
    "electric_terrain": "Campo elétrico por 5 rodadas: Elétrico 1,3x para quem está no chão e ninguém no chão dorme. Um terreno tira o outro.",
    "misty_terrain": "Campo de névoa por 5 rodadas: quem está no chão não sofre status nem confusão e Dragão bate 0,5x. Um terreno tira o outro.",
    "psychic_terrain": "Campo psíquico por 5 rodadas: Psíquico 1,3x para quem está no chão e golpes de prioridade não o alcançam. Um terreno tira o outro.",
    "gravity": "Gravidade por 5 rodadas: ninguém pula, Voadores e levitando caem, golpes de Terra acertam Voador, precisão x5/3.",
    "gyro_ball": "Poder = 25 x Speed do alvo / Speed do usuário + 1 (máx. 150): quanto mais lento o usuário, mais forte.",
    "haze": "Zera os estágios de atributo de todos em campo.",
    "healing_wish": "O usuário desmaia; quem entrar no lugar dele volta com HP cheio e sem status. Só com reserva no banco.",
    "imprison": "Os adversários não podem usar os golpes que o usuário também conhece.",
    "incinerate": "Queima as frutinhas do chão perto do alvo.",
    "laser_focus": "O próximo golpe do usuário (neste turno e no seguinte) é crítico garantido.",
    "life_dew": "Cura 1/4 do HP máximo do usuário e do parceiro.",
    "light_screen": "Light Screen por 5 rodadas: o lado do usuário leva 0,5x de golpes especiais (2/3 na dupla). Crítico ignora.",
    "reflect": "Reflect por 5 rodadas: o lado do usuário leva 0,5x de golpes físicos (2/3 na dupla). Crítico ignora.",
    "safeguard": "Safeguard por 5 rodadas: o lado do usuário não recebe status nem confusão de golpes adversários.",
    "mist": "Névoa protetora por 5 rodadas: o lado do usuário não tem atributos baixados pelo adversário.",
    "tailwind": "Vento a favor por 4 rodadas: Speed x2 para o lado do usuário (decide a ordem da fila).",
    "metronome": "Usa um golpe sorteado do jogo (fora da lista proibida: Protect, Counter, Metronome, Copycat...).",
    "mimic": "Troca o próprio Mimic pelo último golpe usado pelo adversário (fora da lista proibida).",
    "no_protect": "Ignora Protect e Substitute do alvo.",
    "protect": "Bloqueia quase tudo até o fim da rodada. Usado em rodadas seguidas: chance 1, 1/3, 1/9... (zera quando uma rodada passa sem usar). Feint quebra.",
    "quick_guard": "Até o fim da rodada, o lado do usuário não é atingido por golpes de prioridade.",
    "wide_guard": "Até o fim da rodada, o lado do usuário não é atingido por golpes de vários alvos.",
    "endure": "Até o fim da rodada, o usuário aguenta qualquer golpe com 1 HP.",
    "rest": "Cura tudo e dorme 2 rodadas (cura o status anterior). Falha com HP cheio ou já dormindo (e com Insomnia/Vital Spirit).",
    "roost": lambda m: "Cura %s%% do HP máximo e, se for Voador, perde o tipo Voador até o fim da rodada (e desce ao chão)." % num(float(m.get("heal", 0.5)) * 100),
    "round": "Poder x2 se o parceiro usou Round há pouco (janela de 2 s).",
    "spit_up": "Poder 100 por Stockpile guardado (100/200/300); gasta os Stockpiles e devolve a Defesa e a Def. Esp. Falha sem Stockpile.",
    "stockpile": "Guarda uma carga (até 3): Defesa +1 e Def. Esp. +1 por carga, usadas por Spit Up e Swallow.",
    "swallow": "Gasta os Stockpiles e cura 1/4, 1/2 ou todo o HP (1, 2 ou 3 cargas). Falha sem Stockpile.",
    "spite": "Corta o PP do último golpe do alvo (no modo de energia, tira energia).",
    "stored_power": "Poder = 20 + 20 por estágio de atributo positivo do usuário.",
    "toxic_spikes": "Espinhos venenosos no chão sob os adversários (duram 20 s): 1 camada envenena, 2 camadas dão Toxic; Veneno que pisa absorve.",
    "venoshock": "Poder x2 se o alvo está envenenado (veneno ou Toxic).",
    "worry_seed": "A habilidade do alvo vira Insomnia (e acorda quem dorme).",
    "acrobatics": "Poder x2 se o usuário não tem item do treinador.",
    "omni_boost": lambda m: "%s%% de chance de subir Ataque, Defesa, At. Esp., Def. Esp. e Speed do usuário em +1 (uma vez por uso)." % num(float(m.get("omni_chance", 0.1)) * 100),
    "attract": "Apaixona o alvo de gênero oposto: metade das vezes o golpe dele não sai. Sem gênero ou mesmo gênero, falha.",
    "baton_pass": "O usuário sai e o próximo do banco entra herdando os estágios de atributo e o crítico. Sem reserva, falha.",
    "beat_up": "Um golpe por Pokémon saudável do time, cada um com poder 5 + (Ataque base / 10).",
    "belly_drum": "Gasta metade do HP e leva o Ataque ao máximo (+12 estágios, limitado a +6). Falha com HP <= 50%.",
    "body_press": "Usa a Defesa do usuário no lugar do Ataque no cálculo do dano.",
    "defog": "Baixa a evasão do alvo e limpa o campo: telas do adversário, armadilhas (Spikes, Stealth Rock, Toxic Spikes) e terrenos.",
    "dragon_cheer": "O parceiro ganha +1 de crítico (+2 se for Dragão). Sem parceiro, falha.",
    "facade": "Poder x2 se o usuário está com queimadura, veneno, Toxic ou paralisia; a queimadura não corta o dano.",
    "fake_out": "Só sai logo depois de entrar em campo (até 1,5 s); acerta primeiro (prioridade +3) e faz o alvo hesitar.",
    "false_swipe": "Nunca nocauteia: deixa o alvo com 1 HP.",
    "final_gambit": "Dano = HP atual do usuário, que desmaia depois.",
    "fling": "Arremessa o item do treinador do usuário (falha sem item) e o consome.",
    "focus_punch": "Concentra primeiro (prioridade -3); se o usuário levar dano antes de bater, perde a concentração e o golpe falha.",
    "foul_play": "Usa o Ataque do alvo no lugar do Ataque do usuário.",
    "future_sight": "Avisa agora e cai no fim da segunda rodada seguinte, na área do alvo da hora. Só cai se quem usou ainda está vivo.",
    "grassy_glide": "Prioridade +1 enquanto houver Grassy Terrain e o usuário estiver no chão.",
    "heal_pulse": "Cura 1/2 do HP máximo do parceiro (do próprio usuário se estiver sozinho).",
    "hex": "Poder x2 se o alvo tem algum status principal.",
    "howl": "Ataque +1 do usuário e do parceiro.",
    "terrain_clear": "Depois de bater, apaga qualquer terreno de campo.",
    "knock_off": "Poder x1,5 se o alvo tem item do treinador; se acertar, o alvo perde o item.",
    "lash_out": "Poder x2 se algum atributo do usuário caiu nesta rodada.",
    "last_resort": "Só sai depois de o usuário já ter usado todos os outros golpes que conhece.",
    "memento": "O usuário desmaia e derruba Ataque e At. Esp. do alvo em 2 estágios.",
    "pain_split": "Soma o HP do usuário e do alvo e divide igual entre os dois.",
    "present": "Poder sorteado 40/80/120; 20% das vezes é um presente que cura o alvo em 1/4 do HP.",
    "psych_up": "Copia os estágios de atributo e o crítico do adversário.",
    "heal_block": "O alvo não pode se curar por 2 rodadas.",
    "psyshock": "Golpe especial calculado contra a Defesa física do alvo.",
    "skill_swap": "Troca a habilidade do usuário com a do alvo.",
    "sleep_talk": "Só dormindo: usa um dos outros golpes do usuário (sorteado) sem acordar.",
    "sleep_only": "Só sai dormindo (a rodada sai mesmo com o usuário em sono).",
    "spikes": "Espinhos no chão sob cada adversário (duram 20 s): 1/8 do HP de quem pisa e não voa.",
    "stealth_rock": "Pedras flutuando em volta de cada adversário (20 s): 1/8 do HP x eficácia de Pedra em quem se aproxima, mesmo voando.",
    "strength_sap": "Cura o usuário pelo valor do Ataque do alvo e baixa o Ataque do alvo em 1.",
    "substitute": "Gasta 1/4 do HP e cria um boneco com esse HP que leva os golpes e status no lugar do usuário (som atravessa). Falha com HP baixo ou se já existe.",
    "taunt": "O alvo não pode usar golpes de status por 3 rodadas.",
    "teeter_dance": "Confunde todos ao redor (inclusive o parceiro, como no oficial, quando o alvo é 'todos').",
    "throat_chop": "Se causar dano, o alvo não pode usar golpes de som por 2 rodadas.",
    "tickle": "Ataque e Defesa dos alvos -1 cada.",
    "upper_hand": "Só sai se o alvo está preparando um golpe de prioridade; acerta primeiro e faz hesitar.",
    "uproar": "Barulho por 3 rodadas: acorda todos e impede qualquer um de dormir.",
    "venom_drench": "Se o alvo está envenenado, baixa Ataque, At. Esp. e Speed dele em 1 cada; senão sem efeito.",
    "water_spout": "Poder proporcional ao HP atual do usuário (poder x HP atual / HP máximo, mínimo 1).",
    "weather_ball": "Com clima ativo o tipo muda (sol: Fogo, chuva: Água, areia: Pedra, neve: Gelo) e o poder dobra.",
    "wish": "Desejo: no fim da rodada seguinte cura 1/2 do HP máximo de quem desejou (ou de quem estiver no lugar dele).",
    "clear_smog": "Se causar dano, zera os estágios de atributo do alvo.",
    "soak": "Muda o tipo do alvo para Água.",
    "magnet_rise": "Levita por 5 rodadas: imune a golpes de Terra e não pisa no chão (Gravity derruba).",
    "wonder_room": "Defesa e Def. Esp. de todos trocadas por 5 rodadas; usar de novo desliga.",
    "trick_room": "Prioridade -7: inverte a ordem da fila de Speed por 5 rodadas; usar de novo desliga.",
    "brine": "Poder x2 se o alvo está com menos da metade do HP.",
    "hard_press": "Poder proporcional ao HP atual do alvo (mínimo 1).",
    "lock_on": "O próximo golpe do usuário (neste turno e no seguinte) não erra.",
    "destiny_bond": "Se o usuário for nocauteado pelo próximo golpe do alvo, o atacante cai junto. Vale até o usuário usar outro golpe.",
    "rage_fist": "Poder +50 por vez que o usuário levou golpe na luta, até 350.",
    "simple_beam": "A habilidade do alvo vira Simple (falha se já for).",
    "coaching": "Ataque +1 e Defesa +1 do parceiro. Sem parceiro, falha.",
    "acupressure": "Sorteia um atributo (Ataque, Defesa, At. Esp., Def. Esp., Speed ou Precisão) e o sobe +2.",
    "recycle": "Devolve o item do treinador que já foi usado.",
    "magnetic_flux": "Defesa +1 e Def. Esp. +1 do usuário e do parceiro que tenham Plus ou Minus. Falha se ninguém tem.",
    "ally_switch": "O usuário e o parceiro trocam de lugar. Sem parceiro, falha.",
}

# Golpes com codigo proprio por id em battle_move_effects.gd / battle_physics.gd (sem "special")
BESPOKE = {
    "toxic": "Não erra quando o usuário é do tipo Veneno (regra oficial).",
    "thunder": "Na chuva nunca erra (oficial). Atinge quem está no alto (Fly/Bounce).",
    "hurricane": "Na chuva nunca erra (oficial). Atinge quem está no alto (Fly/Bounce).",
    "solar_beam": "O 'turno de carga' virou o preparo do raio (windup). Sob chuva, areia ou neve o dano cai à metade (x0,5), como no oficial.",
    "scald": "Descongela o alvo congelado, como os golpes de Fogo.",
    "earthquake": "Acerta quem está sob a terra (Dig) em dobro. No Grassy Terrain cai à metade (x0,5). Quem está no ar não é atingido; o parceiro pula ao ver o terremoto.",
    "bulldoze": "No Grassy Terrain cai à metade (x0,5) em quem está no chão.",
    "magnitude": "No Grassy Terrain cai à metade (x0,5). Sorteia a magnitude (4 a 10) e ela define o poder, o pulo e o impacto. Acerta quem está sob a terra em dobro.",
    "fissure": "Alcança quem está sob a terra (Dig), como o oficial.",
    "surf": "Acerta quem está mergulhado (Dive) em dobro.",
    "whirlpool": "Acerta quem está mergulhado (Dive) em dobro.",
    "gust": "Acerta quem está no alto (Fly/Bounce) em dobro.",
    "twister": "Acerta quem está no alto (Fly/Bounce) em dobro.",
    "sky_uppercut": "Alcança quem está no alto (Fly/Bounce).",
    "smack_down": "Alcança quem está no alto (Fly/Bounce).",
    "thousand_arrows": "Alcança quem está no alto (Fly/Bounce).",
    "dig": "Afunda em 0,3 s (invulnerável), anda por baixo da terra até o alvo e sai sob ele. Só Earthquake, Magnitude (dobro) e Fissure o alcançam enquanto está sob a terra.",
    "dive": "Mergulha (invulnerável), anda por baixo d'água até o alvo e sai sob ele. Só Surf e Whirlpool (dobro) o alcançam.",
    "fly": "Salta alto (fica fora de alcance no ar, 1,2 s) e cai sobre o alvo. Só Gust e Twister (dobro), Thunder, Hurricane, Sky Uppercut e Smack Down o alcançam lá em cima.",
    "bounce": "Salta alto (fora de alcance no ar, 1,1 s) e cai sobre o alvo. Só Gust e Twister (dobro), Thunder, Hurricane, Sky Uppercut e Smack Down o alcançam lá em cima.",
    "aerial_ace": "Some e reaparece em cima do alvo (nunca erra no oficial).",
    "shadow_sneak": "Some e reaparece em cima do alvo.",
    "feint_attack": "Some e reaparece em cima do alvo.",
    "whirlwind": "No oficial força a troca; aqui o alvo é arremessado 5 m para longe.",
    "roar": "No oficial força a troca; aqui o alvo é arremessado 5 m para longe.",
    "dragon_tail": "No oficial força a troca; aqui o alvo é arremessado 4 m para longe depois do dano.",
    "circle_throw": "No oficial força a troca; aqui o alvo é arremessado 4 m para longe depois do dano.",
    "rage": "Só dano simples: o aumento de Ataque ao apanhar do oficial não foi implementado.",
    "thief": "Fica fora da lista de Metronome/Copycat/Mimic (como o oficial).",
    "switcheroo": "Fica fora da lista de Metronome/Copycat/Mimic (como o oficial).",
    "sweet_scent": "No jogo sobe a Precisão do usuário em +1 (equivale a baixar a evasão dos adversários).",
    "splash": "Não faz nada (como o oficial).",
    "focus_energy": "Chance de crítico do usuário +2 níveis (limite 4): o crítico passa de 1/24 para 1/2.",
}

# Golpes da Gen 2-9 (tools/moves_more_a.py e moves_more_b.py): GUIDE[id] = texto da adaptação.
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import moves_more_a, moves_more_b  # noqa: E402

for _part in (moves_more_a, moves_more_b):
    BESPOKE.update(getattr(_part, "GUIDE", {}))
    for _k, _v in getattr(_part, "SPECIAL", {}).items():
        SPECIAL.setdefault(_k, _v)  # "" = o texto está no GUIDE do golpe


# ---------------------------------------------------------------- montagem das linhas
def priority_text(p):
    if p > 0:
        return ("Prioridade +%d: sai quase sem preparo (0,04 s) e com GCD 0,6x. "
                "No modo de energia custa 0,6x e o cooldown é 1,8x." % p)
    return ("Prioridade %d: sai depois dos normais; prepara %s s mais devagar (0,1 s por nível) e segura o GCD um pouco mais." %
            (p, num(0.1 * -p)))


def multi_text(m):
    mt = m.get("multi_target", "")
    if mt == "all_opponents":
        return "Golpe de vários alvos (todos os adversários): acerta todos ao alcance; se um uso pega mais de um, dano x0,75 (spread)."
    if mt == "all_other_pokemon":
        return ("Golpe de vários alvos (todos os outros, inclusive o parceiro): acerta todos ao alcance, até o aliado; "
                "se um uso pega mais de um, dano x0,75 (spread).")
    return ""


def hit_rule(m):
    """Linha sobre quantos acertos por uso."""
    hr = m.get("hits_range")
    if isinstance(hr, list):
        lo, hi = int(hr[0]), int(hr[1])
        unit = "projéteis" if m.get("kind") == "projectile" else "golpes"
        if lo == hi:
            return "Multi-hit oficial: %d acertos por uso no mesmo alvo, cada um com o poder oficial (%s)." % (lo, num(m.get("bp", m.get("power", 0))))
        return ("Multi-hit oficial: sorteia %d a %d acertos por uso (35%% / 35%% / 15%% / 15%% para 2/3/4/5), cada um com o poder oficial (%s); "
                "Skill Link sempre dá %d. O visual solta os %s sorteados, todos no mesmo alvo." % (lo, hi, num(m.get("bp", m.get("power", 0))), hi, unit))
    if m.get("special") == "beat_up":
        return ""
    kind = m.get("kind")
    n = max(int(m.get("count", 1)), int(m.get("hits", 1)))
    if m.get("category") != "status" and (n > 1 or kind in ("stream", "zone", "multi_arc")):
        extra = ""
        if n > 1:
            extra = " (o visual solta %d)" % n
        return ("Um acerto por alvo por uso%s: o visual desenha o jato, a área ou os golpes seguidos, mas cada alvo leva dano e efeito uma vez só "
                "(no oficial não é multi-hit)." % extra)
    return ""


def effect_lines(m):
    out = []
    ef = m.get("effect")
    cat = m.get("category")
    if isinstance(ef, dict):
        ch = float(ef.get("chance", 0))
        pct = "%s%%" % num(ch * 100)
        if "status" in ef:
            st = ef["status"]
            nm = STATUS_PT.get(st, st)
            note = STATUS_NOTE.get(st, "")
            if cat == "status":
                t = "Causa %s no alvo se acertar%s" % (nm, "" if ch >= 1 else " (%s de chance)" % pct)
            elif ch >= 1:
                t = "Sempre causa %s no alvo (depois do dano)" % nm
            else:
                t = "%s de chance de causar %s no alvo" % (pct, nm)
            out.append(t + "." + (" %s: %s." % (nm.split(" (")[0], note) if note else ""))
        elif "stat" in ef:
            who = "do usuário" if ef.get("self") else "do alvo"
            stg = int(ef.get("stages", 0))
            verb = "sobe" if stg > 0 else "baixa"
            lead = "Sempre " if ch >= 1 and cat != "status" else ("" if cat == "status" else "%s de chance: " % pct)
            if cat == "status" and ch < 1:
                lead = "%s de chance: " % pct
            t = "%s%s %s %s em %s." % (lead, verb, STAT_PT.get(ef["stat"], ef["stat"]), who, est(stg))
            out.append(t[0].upper() + t[1:])
    return out


def physics_lines(m):
    out = []
    i = m["id"]
    kind = m["kind"]
    if "tri" in m:
        out.append("%s%% de chance de causar, sorteado igual, Queimadura, Paralisia ou Congelamento (Tri Attack)." % num(float(m["tri"]) * 100))
    if "flinch" in m:
        out.append("%s%% de chance extra de o alvo hesitar (0,5 s parado)." % num(float(m["flinch"]) * 100))
    if "drain" in m:
        out.append("Dreno: orbe verde que, ao acertar, cura o usuário em %s%% do dano causado." % num(float(m["drain"]) * 100))
    if "recoil" in m:
        out.append("Recuo: o usuário perde %s%% do dano causado (Rock Head anula)." % num(float(m["recoil"]) * 100))
    if "crash" in m:
        out.append("Se errar ou for parado, o usuário se machuca em %s%% do HP máximo (golpe de risco)." % num(float(m["crash"]) * 100))
    if "max_recoil" in m:
        out.append("O usuário perde %s%% do HP máximo ao atirar, acertando ou não." % num(float(m["max_recoil"]) * 100))
    if "self_stats" in m:
        out.append("Depois de acertar, muda os atributos do usuário (uma vez por uso): %s." % stats_text(m["self_stats"]))
    if "charge_stats" in m:
        out.append("Ao começar a usar, muda os atributos do usuário: %s (o turno de carga do oficial)." % stats_text(m["charge_stats"]))
    if "recharge" in m:
        out.append("Precisa recarregar: depois do golpe o usuário fica parado e vulnerável por %s s." % num(m["recharge"]))
    if "trap" in m and kind in ("zone", "stream", "aoe_target"):
        out.append("Prende o alvo no lugar por %s s (parado dentro da área)." % num(m["trap"]))
    if m.get("powder"):
        out.append("Golpe de pó: não afeta Planta nem quem tem Overcoat.")
    if m.get("crit"):
        out.append("Alta chance de crítico (+%d no estágio: 1/8 em vez de 1/24)." % int(m["crit"]) if int(m["crit"]) == 1 else "Estágio de crítico +%d." % int(m["crit"]))
    if m.get("self_destruct"):
        out.append("O usuário desmaia depois da explosão (0,3 s depois do impacto).")
    if m.get("category") != "status" and m.get("type") == "fire":
        out.append("Se acertar um alvo congelado, descongela.")
    if (m.get("category") == "physical" and kind in ("dash", "arc", "multi_arc")
            and float(m.get("bp", m.get("power", 0))) >= 80):
        pw = float(m.get("bp", m.get("power", 0)))
        out.append("Contato forte (poder >= 80): além do empurrão, arremessa o alvo %s m; se ele bater na cerca, caixa ou pedra perde até 8%% do HP." % num(0.6 + 1.2 * (pw - 80) / 40.0))
    return out


def stat_move_lines(m):
    out = []
    kind = m["kind"]
    if kind == "self_buff" and not m.get("special"):
        if isinstance(m.get("stats"), dict):
            out.append("Atributos do usuário: %s." % stats_text(m["stats"]))
        elif m.get("stat") == "evasion":
            out.append("Evasão: por %s s o usuário esquiva de golpes mirados nele com %s%% de chance." % (num(m.get("duration", 5.0)), num(float(m.get("evasion", 0.4)) * 100)))
        elif m.get("stat") == "crit":
            pass  # BESPOKE (focus_energy)
        elif m.get("stat") and int(m.get("stages", 0)) != 0:
            stg = int(m["stages"])
            out.append("%s do usuário %s em %s (multiplicador (2+n)/2, limite de -6 a +6)." % (
                STAT_PT.get(m["stat"], m["stat"]), "sobe" if stg > 0 else "baixa", est(stg)))
    if kind == "debuff_aoe" and m.get("stat") and not m.get("special"):
        stg = int(m.get("stages", -1))
        who = "de todos os adversários" if m.get("multi_target") else "do adversário mais perto"
        out.append("%s %s %s em %s, alcance %s m." % (
            STAT_PT.get(m["stat"], m["stat"]), who, "sobe" if stg > 0 else "cai", est(stg), num(m.get("radius", 6.0))))
    if kind == "clones":
        out.append("Cria %d cópias ilusórias por %s s; o usuário esquiva de golpes com %s%% de chance e as cópias absorvem golpes." % (
            int(m.get("count", 2)), num(m.get("duration", 5.0)), num(float(m.get("evasion", 0.4)) * 100)))
    return out


def delivery(m):
    """(rotulo, frase em palavras com os numeros)."""
    k = m["kind"]
    g = m.get
    if k == "dash":
        s = "Investida: o Pokémon corre até o alvo (até %s m, %s m/s) e bate no contato." % (num(g("range", 3.0)), num(g("speed", 12)))
        leap = g("leap") or LEAP_IDS.get(m["id"])
        if g("tunnel") or m["id"] in TUNNEL_IDS:
            s = "Investida por baixo: %s por baixo do chão até %s m, a %s m/s, e sai sob o alvo." % (
                "afunda e anda" if (g("tunnel") or TUNNEL_IDS[m["id"]]) == "dig" else "mergulha e anda",
                num(g("range", 7.0)), num(g("speed", 12)))
        elif g("blink") or m["id"] in BLINK_IDS:
            s = "Teleporte: o Pokémon some e reaparece em cima do alvo (alcance %s m)." % num(g("range", 3.0))
        elif leap:
            if leap is True:
                leap = {"secs": 0.4, "h": 1.5}
            s = "Salto: o Pokémon pula (%s s no ar, %s m de altura) e cai em cima do alvo (alcance %s m)%s." % (
                num(leap.get("secs", 0.4)), num(leap.get("h", 1.5)), num(g("range", 3.0)),
                "; fica fora de alcance lá no alto" if leap.get("sky") else "")
        if g("allowed_midair") is False:
            s += " Só sai no chão (no ar espera pousar)."
        return s
    if k == "arc":
        return "Golpe de contato em cone: acerta quem está até %s m à frente, num arco de %s°." % (num(g("range", 1.8)), num(g("angle", 90)))
    if k == "multi_arc" and m.get("special") == "beat_up":
        return "Golpes de contato em sequência: um golpe por Pokémon saudável do time (cone de %s m, %s°)." % (num(g("range", 1.8)), num(g("angle", 90)))
    if k == "multi_arc":
        return "Golpes de contato em sequência: %d golpes no cone (%s m, %s°), um a cada %s s." % (
            int(g("hits", 3)), num(g("range", 1.8)), num(g("angle", 90)), num(g("interval", 0.2)))
    if k == "whip":
        return "Chicote: %d ponta(s) varrem uma linha de até %s m e acertam o primeiro que tocar." % (int(g("tips", 1)), num(g("range", 3.5)))
    if k == "projectile":
        s = "Projétil: voa em linha reta até %s m a %s m/s; dá para desviar." % (num(g("range", 10)), num(g("speed", 12)))
        if g("fx") == "lob":
            s = "Projétil lançado em arco (altura %s m): até %s m a %s m/s; dá para desviar." % (num(g("lob_height", 2.0)), num(g("range", 10)), num(g("speed", 12)))
        if "drain" in m:
            s = "Orbe de dreno: teleguiado de curva suave (%s), até %s m a %s m/s; dá para desviar." % (num(g("turn", 2.0)), num(g("range", 9)), num(g("speed", 12)))
        n = int(g("count", 1))
        if n > 1 and not isinstance(g("hits_range"), list):
            s += " Sai uma leva de %d em leque de %s°." % (n, num(g("spread", 0)))
        elif n > 1:
            s += " Sai uma leva em leque de %s° (quantidade sorteada, ver multi-hit)." % num(g("spread", 0))
        return s
    if k == "homing":
        n = int(g("count", 1))
        s = "Projétil teleguiado: faz curva atrás do alvo (curva %s), até %s m a %s m/s. Não erra." % (num(g("turn", 5)), num(g("range", 10)), num(g("speed", 12)))
        if n > 1:
            s += " Solta %d, um a cada 0,08 s." % n
        return s
    if k == "stream":
        return "Jato em cone: %s m de alcance, %s° de abertura, durante %s s (um pulso a cada %s s); o usuário fica parado e trava no alvo. Não erra por precisão." % (
            num(g("range", 5.0)), num(g("angle", 35)), num(g("duration", 1.0)), num(g("tick", 0.15)))
    if k == "beam":
        return "Raio em linha: %s m de alcance, %s m de largura; avisa no chão por %s s e dispara; o usuário fica parado %s s depois." % (
            num(g("range", 14)), num(g("width", 0.8)), num(g("windup", 0.6)), num(g("root", 1.0)))
    if k == "aoe_self":
        s = "Onda ao redor do usuário: raio %s m, aviso de %s s e depois bate em todo mundo dentro do raio. Não erra por precisão (pular ou sair da área desvia)." % (
            num(g("radius", 4.0)), num(g("windup", 0.4)))
        if g("slam"):
            s += " O usuário agacha, salta e bate no chão; o dano sai no pouso."
        return s
    if k == "aoe_target":
        return "Área no alvo: marca um círculo de %s m de raio sobre ele (alcance %s m) e cai depois de %s s; quem sair da marca escapa." % (
            num(g("radius", 2.0)), num(g("range", 8.0)), num(g("windup", 1.0)))
    if k == "zone":
        return "Zona no chão: círculo de %s m de raio (alcance %s m) que dura %s s e bate a cada %s s em quem estiver dentro." % (
            num(g("radius", 2.0)), num(g("range", 8.0)), num(g("duration", 4.0)), num(g("tick", 0.5)))
    if k == "self_buff":
        return "Efeito próprio: sem alvo, o efeito cai no usuário ou no campo. Nunca erra."
    if k == "debuff_aoe":
        return "Efeito ao redor: atinge quem estiver até %s m do usuário%s. Nunca erra." % (
            num(g("radius", 6.0)), "" if g("multi_target") else " (só o mais perto)")
    if k == "clones":
        return "Cópias: cria %d ilusões em volta do usuário. Nunca erra." % int(g("count", 2))
    return ""


def range_chips(m):
    parts = []
    g = m.get
    if "range" in m and m["kind"] not in ("self_buff", "debuff_aoe"):
        parts.append("alcance %s m" % num(m["range"]))
    if "radius" in m:
        parts.append("raio %s m" % num(m["radius"]))
    if "angle" in m and m["kind"] in ("arc", "multi_arc", "stream"):
        parts.append("%s°" % num(m["angle"]))
    if "width" in m:
        parts.append("largura %s m" % num(m["width"]))
    if "duration" in m and m["kind"] in ("stream", "zone", "clones", "self_buff"):
        parts.append("%s s" % num(m["duration"]))
    if "windup" in m:
        parts.append("preparo %s s" % num(m["windup"], 2))
    if "speed" in m and m["kind"] in ("dash", "projectile", "homing"):
        parts.append("%s m/s" % num(m["speed"]))
    return parts


def adaptation(m, warns):
    """Lista de frases (pt-BR) com a adaptacao deste golpe."""
    lines = []
    cat = m["category"]
    bp = m.get("bp")
    sp = m.get("special", "")
    i = m["id"]
    # 1. regra de dano
    if cat != "status":
        if sp in ("fixed", "level_damage", "super_fang", "ohko", "endeavor", "final_gambit", "counter"):
            pass  # texto proprio abaixo
        else:
            pw = num(bp) if bp else None
            base = "Dano pela fórmula oficial (Gen 5+, %s%s), STAB, eficácia, crítico e sorteio de 85-100%%, depois x0,75 do ritmo do jogo." % (
                "físico" if cat == "physical" else "especial",
                (", poder %s" % pw) if pw else ", poder variável (ver abaixo)")
            lines.append(base)
    else:
        if not (m.get("effect") or m.get("stat") or m.get("stats") or sp or m.get("kind") == "clones"):
            lines.append("Golpe de status sem efeito de batalha implementado.")
    # 2. special
    if sp:
        t = SPECIAL.get(sp)
        if t is None:
            warns.append("special sem texto: %s (%s)" % (sp, i))
        else:
            if t:
                lines.append(t(m) if callable(t) else t)
    if i in BESPOKE:
        lines.append(BESPOKE[i])
    if i in BIND_MOVES:
        lines.append("Se causar dano, prende o alvo por 4-5 rodadas: 1/8 do HP no fim de cada rodada, sem fugir nem trocar (acaba se quem prendeu sair; Rapid Spin solta).")
    if i in SOUND_MOVES and sp not in ("uproar", "round", "sleep_only"):
        lines.append("Golpe de som: atravessa o Substitute e Throat Chop o bloqueia por 2 rodadas.")
    if (i in PUSH_IDS) and i not in BESPOKE:
        lines.append("Arremessa o alvo %s m (no oficial força a troca)." % num(PUSH_IDS[i]))
    # 3. acertos
    hr = hit_rule(m)
    if hr:
        lines.append(hr)
    # 4. efeitos e flags
    lines += effect_lines(m)
    if i not in BESPOKE:
        lines += stat_move_lines(m)
    lines += physics_lines(m)
    # 5. prioridade e alvos
    p = int(m.get("priority", 0))
    if p != 0:
        lines.append(priority_text(p))
    mt = multi_text(m)
    if mt:
        lines.append(mt)
    # 6. precisao que nao e rolada
    if "accuracy" in m and m["kind"] not in MISSABLE and m["kind"] not in ("self_buff", "debuff_aoe", "clones"):
        lines.append("Precisão oficial %s%%: esta entrega (%s) nunca erra, então a precisão não é rolada." % (num(m["accuracy"]), KIND_PT[m["kind"]].lower()))
    # remove vazios e duplicatas
    seen, out = set(), []
    for x in lines:
        if x and x not in seen:
            seen.add(x)
            out.append(x)
    return out


# ---------------------------------------------------------------- carga dos dados
def load():
    with open(MOVES_PATH, encoding="utf-8") as f:
        moves = json.load(f)["moves"]
    learners = {}
    try:
        with open(SPECIES_PATH, encoding="utf-8") as f:
            sp = json.load(f)
        for name, s in sp.items():
            if name.startswith("_") or not isinstance(s, dict):
                continue
            got = set()
            for row in s.get("learnset", []):
                got.add(row[1])
            for x in s.get("evo_moves", []) or []:
                got.add(x)
            for x in s.get("tm", []) or []:
                got.add(x)
            for x in got:
                learners[x] = learners.get(x, 0) + 1
    except OSError:
        pass
    return moves, learners


def build(moves, learners):
    warns = []
    rows = []
    for m in moves:
        r = {
            "id": m["id"],
            "name": m["name"],
            "type": m["type"],
            "category": m["category"],
            "kind": m["kind"],
            "bp": m.get("bp"),
            "accuracy": m.get("accuracy"),
            "uses": m.get("uses"),
            "priority": int(m.get("priority", 0)),
            "delivery": delivery(m),
            "chips": range_chips(m),
            "cost": energy_cost(m),
            "cd": energy_cooldown(m),
            "learners": learners.get(m["id"], 0),
            "lines": adaptation(m, warns),
            "special": m.get("special", ""),
        }
        if m["category"] != "status":
            if m.get("bp"):
                bp = num(m["bp"])
                if isinstance(m.get("hits_range"), list):
                    lo, hi = m["hits_range"]
                    bp += " x %s" % (str(lo) if lo == hi else "%d-%d" % (lo, hi))
                r["power"] = bp
            else:
                r["power"] = "variável"
        else:
            r["power"] = "—"
        r["acc"] = ("%s%%" % num(m["accuracy"])) if m.get("accuracy") else "nunca erra"
        rows.append(r)
        if m["id"] in OFFICIAL_MULTI and not isinstance(m.get("hits_range"), list):
            warns.append("golpe de vários acertos no oficial SEM hits_range nos dados: %s (1 acerto por alvo por uso)" % m["id"])
    rows.sort(key=lambda r: (TYPES.index(r["type"]) if r["type"] in TYPES else 99, r["name"].lower()))
    return rows, warns


# ---------------------------------------------------------------- introducao (blocos)
def intro_blocks(n_moves, n_species):
    kinds_rows = [[("`%s`" % k), KIND_PT[k], KIND_DESC[k], KIND_MISS[k]] for k in KIND_ORDER]
    return [
        ("h2", "Como ler este guia"),
        ("p", "Este guia explica, golpe por golpe, como cada golpe oficial (dados da Gen 9) foi adaptado ao combate em tempo real do PokmemonLike. "
              "São %d golpes. Ele é gerado por `tools/move_guide.py` a partir de `data/moves.json` (e `data/species.json` para contar quem aprende cada golpe); "
              "para atualizar, rode `python tools/move_guide.py caminho/da/pagina.html` da raiz do projeto. Os textos de adaptação vêm dos campos de cada golpe "
              "e dos dicionários do script, que seguem `battle/battle_move_effects.gd`, `battle/battle_moves.gd` e `battle/battle_physics.gd`." % n_moves),
        ("p", "Em cada golpe: tipo, categoria, poder oficial (`bp`), precisão, PP oficial, o tipo de entrega no jogo, alcance/área/duração quando há, "
              "o custo de energia e o cooldown no modo de energia, quantas espécies do jogo aprendem o golpe (%d espécies) e o texto de Adaptação." % n_species),
        ("h2", "Do turno ao tempo real"),
        ("ul", [
            "**Dano.** A fórmula é a oficial Gen 5+ (`core/damage.gd`), com os arredondamentos oficiais: base com nível, poder e Ataque/Defesa já com estágios, depois spread, clima, crítico (1,5x), "
            "sorteio inteiro de 85 a 100%, STAB (1,5x), eficácia da tabela de 18 tipos, queimadura (0,5x no físico) e os 'outros' (telas, habilidades, combos). "
            "No fim, o ritmo do jogo multiplica o dano final por **0,75** (`damage_pace`): vale só sobre o dano dos golpes; veneno, queimadura, clima, dreno e cura usam o valor oficial.",
            "**Precisão = erro físico.** O golpe rola a precisão (com estágios de Precisão, (3+n)/3) ao sair. Se falhar, ele sai desviado do alvo mirado (projétil, raio e investida passam ao lado; área cai 2-3 m longe) e pode acertar outro. "
            "Só erram as entregas `dash`, `arc`, `multi_arc`, `whip`, `projectile`, `beam`, `aoe_target` e `zone`; `homing`, `stream`, `aoe_self` e golpes de status sem projétil nunca erram. "
            "Golpe sem precisão (Swift) nunca erra. Evasão (Double Team, Minimize) é uma chance de esquiva por alguns segundos. Fora isso, o jogo é físico: dá para pular a investida e sair da área avisada.",
            "**PP e energia.** A barra de energia (0 a 100, enche 5/s) substitui o PP: "
            "o custo é `12 + 0,25 x poder` (teto 50), status custa 28, golpe de poder variável conta como 70, multi-hit conta pelos acertos (2-5 = 3,1 de média) e prioridade custa 0,6x.",
            "**Cooldown.** Cada golpe tem o seu: `(preparo + duração + peso/40) x 2,5`, com `peso` = 10 x custo de PP, mínimo 1,6 s. Golpe forte (poder > 70) alonga por `1 + (poder - 70)/80`. Status espera x3, mínimo 8 s. "
            "Prioridade multiplica o cooldown por 1,8 no modo de energia. Os números das tabelas são antes do fator de Speed e do GCD (1 s entre golpes).",
            "**Prioridade e Speed.** Prioridade positiva sai quase sem preparo e com GCD 0,6x; negativa prepara 0,1 s a mais por nível.",
            "**Efeitos secundários e status.** A chance é rolada a cada acerto (Serene Grace dobra, Sheer Force tira o efeito e dá 1,3x). Os status seguem o oficial em rodadas e dano de fim de turno (queimadura 1/16, veneno 1/8, Toxic n/16, sono 1-3 rodadas...). Imunidades de tipo valem.",
            "**Campo e dupla.** Clima e terrenos duram 5 rodadas, telas 5, Tailwind 4, Gravity 5; Protect, Endure, Quick/Wide Guard e Follow Me valem até o fim da rodada. Golpes de vários alvos (`all_opponents`, `all_other_pokemon`) acertam todos e dão 0,75x se pegam mais de um.",
        ]),
        ("h2", "Tipos de entrega (`kind`)"),
        ("p", "A entrega diz como o golpe sai do corpo do Pokémon e como acerta. Ela define o que 'acertar' significa em tempo real."),
        ("table", ["kind", "Nome neste guia", "Em palavras", "Erra por precisão?"], kinds_rows),
        ("h2", "Multi-hit: um acerto por alvo, exceto o multi-hit oficial"),
        ("p", "Regra do jogo: **um uso acerta cada alvo uma vez**. Jatos, nuvens, folhas em leque e socos em sequência desenham vários golpes, mas só o primeiro que alcança cada alvo dá dano e efeito (`BattleMoves.hits_of`, `_spend_hit`). "
              "Um golpe de alvo único acerta um alvo só por uso (o primeiro alcançado), mesmo que o cone pegue os dois."),
        ("p", "A exceção são os golpes que no oficial batem várias vezes (`hits_range` nos dados). Double Kick e Twineedle fazem 2 acertos; Fury Swipes, Fury Attack, Double Slap, Pin Missile, Bullet Seed, Icicle Spear, Rock Blast e Scale Shot sorteiam de 2 a 5 com 35/35/15/15% "
              "(Skill Link sempre dá o máximo). Cada acerto usa o poder oficial inteiro e todos caem no mesmo alvo. Beat Up dá um acerto por Pokémon saudável do time. Nos golpes de projétil o sorteio vira o número de projéteis."),
        ("h2", "Custo de energia e cooldown (modo de energia)"),
        ("table", ["Regra", "Valor"], [
            ["Custo de golpe de dano", "`12 + 0,25 x poder`, teto 50 (arredonda)"],
            ["Custo de status", "28"],
            ["Poder variável / dano fixo", "conta como poder 70 (custo 30)"],
            ["Multi-hit", "poder x acertos (fixo) ou x3,1 (2-5)"],
            ["Prioridade positiva", "custo x0,6 e cooldown x1,8"],
            ["Barra", "máximo 100, enche 5/s (Speed 0,85x-1,2x; descansando longe do inimigo 1,8x), começa em 40%"],
        ]),
        ("h2", "Convenções do texto"),
        ("ul", [
            "**Poder** é o oficial (`bp`); o jogo usa o mesmo número em cada acerto. 'variável' = a mecânica calcula o poder na hora (Adaptação explica).",
            "**Precisão** é a oficial; 'nunca erra' = o golpe não tem precisão nos dados.",
            "**PP oficial** é o `uses` dos dados (PP de série principal).",
            "**Alcance, raio, ângulo, preparo (windup)** são metros e segundos do jogo; a Adaptação traduz o que cada um significa na entrega.",
            "'Rodada' = turno do oficial (4 s); efeitos que duram 'N rodadas' contam no fim de turno.",
        ]),
    ]


# ---------------------------------------------------------------- Markdown
def fmt_inline_md(s):
    return s


def md_table(head, rows):
    out = ["| " + " | ".join(head) + " |", "|" + "|".join(["---"] * len(head)) + "|"]
    for r in rows:
        out.append("| " + " | ".join(str(c).replace("|", "\\|") for c in r) + " |")
    return "\n".join(out)


def write_md(rows, blocks, path):
    L = ["# Guia dos golpes", ""]
    L.append("Gerado por `tools/move_guide.py` (não editar à mão): %d golpes, agrupados por tipo e em ordem alfabética." % len(rows))
    L.append("")
    for b in blocks:
        if b[0] == "h2":
            L += ["## " + b[1], ""]
        elif b[0] == "p":
            L += [b[1], ""]
        elif b[0] == "ul":
            L += ["- " + x for x in b[1]] + [""]
        elif b[0] == "table":
            L += [md_table(b[1], b[2]), ""]
    # indice
    L += ["## Golpes por tipo", ""]
    by_type = {}
    for r in rows:
        by_type.setdefault(r["type"], []).append(r)
    L.append(" · ".join("[%s (%d)](#tipo-%s)" % (TYPE_PT[t], len(by_type[t]), t) for t in TYPES if t in by_type))
    L.append("")
    for t in TYPES:
        if t not in by_type:
            continue
        L += ['<a id="tipo-%s"></a>' % t, "", "## %s (%d)" % (TYPE_PT[t], len(by_type[t])), ""]
        for r in by_type[t]:
            L.append("### %s" % r["name"])
            L.append("")
            head = "`%s` · %s · %s · poder %s · precisão %s · PP oficial %s" % (
                r["id"], TYPE_PT[r["type"]], CAT_PT[r["category"]], r["power"], r["acc"], r["uses"])
            L.append(head)
            L.append("")
            L.append("- **Entrega:** `%s` (%s). %s%s" % (r["kind"], KIND_PT[r["kind"]], r["delivery"],
                                                      (" [%s]" % ", ".join(r["chips"])) if r["chips"] else ""))
            L.append("- **Energia:** custo %d · cooldown %s s%s" % (r["cost"], num(r["cd"]), " · prioridade %+d" % r["priority"] if r["priority"] else ""))
            L.append("- **Aprendem:** %d espécie(s) do jogo" % r["learners"])
            if r["lines"]:
                L.append("- **Adaptação:**")
                for x in r["lines"]:
                    L.append("  - " + x)
            L.append("")
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(L).rstrip() + "\n")


# ---------------------------------------------------------------- HTML
def inline_html(s):
    """Escapa e converte **negrito** e `codigo`."""
    s = html.escape(s, quote=False)
    out, i, bold, code = [], 0, False, False
    while i < len(s):
        if s.startswith("**", i):
            out.append("</strong>" if bold else "<strong>")
            bold = not bold
            i += 2
        elif s[i] == "`":
            out.append("</code>" if code else "<code>")
            code = not code
            i += 1
        else:
            out.append(s[i])
            i += 1
    return "".join(out)


def shade(hexcol, f):
    h = hexcol.lstrip("#")
    r, g, b = (int(h[i:i + 2], 16) for i in (0, 2, 4))
    return "#%02x%02x%02x" % (int(r * f), int(g * f), int(b * f))


def ink_for(hexcol):
    h = hexcol.lstrip("#")
    r, g, b = (int(h[i:i + 2], 16) for i in (0, 2, 4))
    lum = (0.299 * r + 0.587 * g + 0.114 * b) / 255.0
    return "#1b1b1f" if lum > 0.6 else "#ffffff"


CSS = """
:root {
  --bg: #f6f5f1; --surface: #ffffff; --surface-2: #efede6; --border: #d9d6cb;
  --text: #1d1d20; --muted: #5d5d66; --accent: #2b59c3; --accent-ink: #ffffff;
  --code-bg: #ecebe4; --shadow: 0 1px 2px rgba(0,0,0,.08);
%(light_tokens)s}
@media (prefers-color-scheme: dark) {
  :root:not([data-theme="light"]) {
    --bg: #14151a; --surface: #1d1f26; --surface-2: #262932; --border: #343846;
    --text: #ececf1; --muted: #a2a5b3; --accent: #8fb0ff; --accent-ink: #10131c;
    --code-bg: #2a2d38; --shadow: none;
%(dark_tokens)s  }
}
:root[data-theme="dark"] {
  --bg: #14151a; --surface: #1d1f26; --surface-2: #262932; --border: #343846;
  --text: #ececf1; --muted: #a2a5b3; --accent: #8fb0ff; --accent-ink: #10131c;
  --code-bg: #2a2d38; --shadow: none;
%(dark_tokens)s}
* { box-sizing: border-box; }
html { -webkit-text-size-adjust: 100%%; }
body { margin: 0; background: var(--bg); color: var(--text); font: 16px/1.5 system-ui, -apple-system, "Segoe UI", Roboto, sans-serif; }
.wrap { max-width: 1040px; margin: 0 auto; padding: 16px; }
h1 { font-size: 1.7rem; margin: .2em 0 .1em; }
h2 { font-size: 1.25rem; margin: 1.6em 0 .5em; }
p, li { max-width: 78ch; }
.sub { color: var(--muted); margin: 0 0 1em; }
code { background: var(--code-bg); padding: .08em .35em; border-radius: 4px; font-size: .9em; overflow-wrap: anywhere; }
.tablewrap { overflow-x: auto; border: 1px solid var(--border); border-radius: 8px; background: var(--surface); margin: .6em 0 1em; }
table { border-collapse: collapse; width: 100%%; min-width: 560px; font-size: .92rem; }
th, td { text-align: left; padding: 8px 10px; border-bottom: 1px solid var(--border); vertical-align: top; }
th { background: var(--surface-2); font-weight: 600; }
tr:last-child td { border-bottom: 0; }
.topbar { display: flex; justify-content: space-between; align-items: center; gap: 12px; }
button.theme { background: var(--surface); color: var(--text); border: 1px solid var(--border); border-radius: 8px; padding: 6px 10px; font: inherit; cursor: pointer; }
.filters { position: sticky; top: 0; z-index: 5; background: var(--bg); padding: 10px 0; display: grid; gap: 8px; grid-template-columns: 1fr; border-bottom: 1px solid var(--border); }
@media (min-width: 720px) { .filters { grid-template-columns: 2fr 1fr 1fr 1fr; } }
.filters input, .filters select { width: 100%%; min-height: 42px; padding: 8px 10px; border: 1px solid var(--border); border-radius: 8px; background: var(--surface); color: var(--text); font: inherit; }
.count { color: var(--muted); font-size: .9rem; margin: .6em 0; }
.typehead { margin: 1.4em 0 .5em; display: flex; align-items: center; gap: 8px; }
.cards { display: grid; gap: 10px; grid-template-columns: 1fr; }
@media (min-width: 820px) { .cards { grid-template-columns: 1fr 1fr; } }
.card { background: var(--surface); border: 1px solid var(--border); border-radius: 10px; padding: 12px; box-shadow: var(--shadow); min-width: 0; }
.card h3 { margin: 0 0 6px; font-size: 1.05rem; display: flex; flex-wrap: wrap; align-items: center; gap: 6px; }
.card h3 small { color: var(--muted); font-weight: 400; font-size: .75rem; }
.badge { display: inline-block; padding: 1px 9px; border-radius: 999px; font-size: .74rem; font-weight: 600; line-height: 1.6; white-space: nowrap; }
.badge.cat { background: var(--surface-2); color: var(--text); border: 1px solid var(--border); }
.badge.kind { background: transparent; color: var(--muted); border: 1px dashed var(--border); }
.stats { display: flex; flex-wrap: wrap; gap: 4px 12px; color: var(--muted); font-size: .85rem; margin: 4px 0 6px; }
.stats b { color: var(--text); font-weight: 600; }
.deliv { font-size: .88rem; margin: 4px 0; }
.energy { font-size: .85rem; color: var(--muted); margin: 4px 0; }
.adapt { margin: 6px 0 0; padding-left: 1.1em; font-size: .9rem; }
.adapt li { margin: 3px 0; overflow-wrap: anywhere; }
.hidden { display: none !important; }
a { color: var(--accent); }
.toc { display: flex; flex-wrap: wrap; gap: 6px; margin: .6em 0 1em; }
.toc a { text-decoration: none; }
details.intro > summary { cursor: pointer; font-weight: 600; margin: .8em 0; }
"""

JS = """
(function () {
  var q = document.getElementById('q'), ft = document.getElementById('ft'), fc = document.getElementById('fc'), fk = document.getElementById('fk');
  var cards = Array.prototype.slice.call(document.querySelectorAll('.card'));
  var heads = Array.prototype.slice.call(document.querySelectorAll('.typegroup'));
  var cnt = document.getElementById('cnt');
  function norm(s) { return (s || '').toLowerCase().normalize('NFD').replace(/[\\u0300-\\u036f]/g, ''); }
  function apply() {
    var t = norm(q.value.trim()), n = 0;
    cards.forEach(function (c) {
      var ok = (!ft.value || c.dataset.type === ft.value) && (!fc.value || c.dataset.cat === fc.value) &&
               (!fk.value || c.dataset.kind === fk.value) && (!t || c.dataset.text.indexOf(t) >= 0);
      c.classList.toggle('hidden', !ok);
      if (ok) n++;
    });
    heads.forEach(function (h) { h.classList.toggle('hidden', !h.querySelector('.card:not(.hidden)')); });
    cnt.textContent = 'Mostrando ' + n + ' de ' + cards.length + ' golpes';
  }
  [q, ft, fc, fk].forEach(function (e) { e.addEventListener('input', apply); e.addEventListener('change', apply); });
  var tb = document.getElementById('theme');
  tb.addEventListener('click', function () {
    var r = document.documentElement, dark = r.getAttribute('data-theme') === 'dark' ||
      (!r.getAttribute('data-theme') && window.matchMedia('(prefers-color-scheme: dark)').matches);
    r.setAttribute('data-theme', dark ? 'light' : 'dark');
  });
  apply();
})();
"""


def block_html(b):
    if b[0] == "h2":
        return "<h2>%s</h2>" % inline_html(b[1])
    if b[0] == "p":
        return "<p>%s</p>" % inline_html(b[1])
    if b[0] == "ul":
        return "<ul>%s</ul>" % "".join("<li>%s</li>" % inline_html(x) for x in b[1])
    if b[0] == "table":
        head = "".join("<th>%s</th>" % inline_html(h) for h in b[1])
        body = "".join("<tr>%s</tr>" % "".join("<td>%s</td>" % inline_html(str(c)) for c in r) for r in b[2])
        return '<div class="tablewrap"><table><thead><tr>%s</tr></thead><tbody>%s</tbody></table></div>' % (head, body)
    return ""


def norm_text(s):
    import unicodedata
    s = unicodedata.normalize("NFD", s.lower())
    return "".join(c for c in s if unicodedata.category(c) != "Mn")


def write_html(rows, blocks, path):
    light_tokens = "".join("  --t-%s: %s; --ti-%s: %s;\n" % (t, TYPE_HEX[t], t, ink_for(TYPE_HEX[t])) for t in TYPES)
    dark_tokens = "".join("    --t-%s: %s; --ti-%s: %s;\n" % (t, shade(TYPE_HEX[t], 0.82), t, "#ffffff" if ink_for(TYPE_HEX[t]) == "#ffffff" else "#14151a") for t in TYPES)
    css = CSS % {"light_tokens": light_tokens, "dark_tokens": dark_tokens}
    by_type = {}
    for r in rows:
        by_type.setdefault(r["type"], []).append(r)
    P = []
    P.append("<!doctype html>\n<html lang=\"pt-BR\">\n<head>\n<meta charset=\"utf-8\">\n"
             "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">\n"
             "<title>Guia dos Golpes</title>\n<style>%s</style>\n</head>\n<body>\n<div class=\"wrap\">" % css)
    P.append('<div class="topbar"><h1>Guia dos Golpes</h1><button class="theme" id="theme" type="button">Claro/Escuro</button></div>')
    P.append('<p class="sub">Como cada golpe oficial (Gen 9) foi adaptado ao tempo real do PokmemonLike. %d golpes. Gerado por tools/move_guide.py.</p>' % len(rows))
    P.append('<details class="intro" open><summary>Introdução: regras, entregas, multi-hit e energia</summary>')
    for b in blocks:
        P.append(block_html(b))
    P.append("</details>")
    P.append("<h2>Todos os golpes</h2>")
    opts_t = "".join('<option value="%s">%s</option>' % (t, TYPE_PT[t]) for t in TYPES if t in by_type)
    opts_c = "".join('<option value="%s">%s</option>' % (c, CAT_PT[c]) for c in ("physical", "special", "status"))
    kinds_used = [k for k in KIND_ORDER if any(r["kind"] == k for r in rows)]
    opts_k = "".join('<option value="%s">%s (%s)</option>' % (k, KIND_PT[k], k) for k in kinds_used)
    P.append('<div class="filters">'
             '<input id="q" type="search" placeholder="Buscar por nome ou texto (ex.: dreno, prioridade, Protect)" aria-label="Buscar golpe">'
             '<select id="ft" aria-label="Tipo"><option value="">Todos os tipos</option>%s</select>'
             '<select id="fc" aria-label="Categoria"><option value="">Todas as categorias</option>%s</select>'
             '<select id="fk" aria-label="Entrega"><option value="">Todas as entregas</option>%s</select></div>' % (opts_t, opts_c, opts_k))
    P.append('<div class="count" id="cnt"></div>')
    for t in TYPES:
        if t not in by_type:
            continue
        P.append('<section class="typegroup" id="tipo-%s"><div class="typehead"><span class="badge" style="background:var(--t-%s);color:var(--ti-%s)">%s</span><span class="count">%d golpes</span></div><div class="cards">' % (t, t, t, TYPE_PT[t], len(by_type[t])))
        for r in by_type[t]:
            text = norm_text(" ".join([r["name"], r["id"], r["delivery"], KIND_PT[r["kind"]], r["kind"], CAT_PT[r["category"]]] + r["lines"]))
            chips = (" · ".join(r["chips"])) if r["chips"] else ""
            P.append('<article class="card" data-type="%s" data-cat="%s" data-kind="%s" data-text="%s">' % (t, r["category"], r["kind"], html.escape(text, quote=True)))
            P.append('<h3>%s <span class="badge" style="background:var(--t-%s);color:var(--ti-%s)">%s</span><span class="badge cat">%s</span><span class="badge kind">%s</span><small>%s</small></h3>' % (
                html.escape(r["name"]), t, t, TYPE_PT[t], CAT_PT[r["category"]], KIND_PT[r["kind"]], html.escape(r["id"])))
            P.append('<div class="stats"><span>Poder <b>%s</b></span><span>Precisão <b>%s</b></span><span>PP oficial <b>%s</b></span><span>Aprendem <b>%d</b></span></div>' % (
                html.escape(str(r["power"])), html.escape(r["acc"]), r["uses"], r["learners"]))
            P.append('<div class="deliv"><b>Entrega:</b> %s%s</div>' % (html.escape(r["delivery"]), (" <span class=\"count\">[%s]</span>" % html.escape(chips)) if chips else ""))
            P.append('<div class="energy"><b>Energia:</b> custo %d · cooldown %s s%s</div>' % (r["cost"], num(r["cd"]), (" · prioridade %+d" % r["priority"]) if r["priority"] else ""))
            if r["lines"]:
                P.append('<ul class="adapt">%s</ul>' % "".join("<li>%s</li>" % html.escape(x) for x in r["lines"]))
            P.append("</article>")
        P.append("</div></section>")
    P.append("</div>\n<script>%s</script>\n</body>\n</html>\n" % JS)
    os.makedirs(os.path.dirname(os.path.abspath(path)), exist_ok=True)
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(P))


def main():
    moves, learners = load()
    rows, warns = build(moves, learners)
    n_species = 0
    try:
        with open(SPECIES_PATH, encoding="utf-8") as f:
            n_species = len([k for k in json.load(f) if not k.startswith("_")])
    except OSError:
        pass
    blocks = intro_blocks(len(rows), n_species)
    write_md(rows, blocks, MD_PATH)
    print("docs/GOLPES.md: %d golpes" % len(rows))
    if len(sys.argv) > 1:
        write_html(rows, blocks, sys.argv[1])
        print("html: %s" % sys.argv[1])
    for w in warns:
        print("AVISO:", w)


if __name__ == "__main__":
    main()
