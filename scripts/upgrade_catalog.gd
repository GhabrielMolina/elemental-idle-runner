extends RefCounted

# Catalogo das melhorias da loja. Cada lista em "costs" e "values" tem um valor por nivel (Nv1, Nv2, Nv3).
# Percentuais ficam em "*_pct" (50 = 50%). O texto usa os valores do nivel via String.format().

const MAX_LEVEL := 3
const GENERAL := "Geral"

const UPGRADES := {
	"fogo_multiplo": {
		"element": "Fogo",
		"name": "Disparo multiplo",
		"costs": [60, 120, 200],
		"values": {"projectiles": [2, 3, 4]},
		"text": "Lanca {projectiles} projeteis por ataque",
	},
	"fogo_queimadura": {
		"element": "Fogo",
		"name": "Queimadura",
		"costs": [40, 80, 140],
		"values": {"duration": [2.0, 3.5, 5.0], "tick_damage": [4, 4, 4]},
		"text": "Queima por {duration}s ({tick_damage} de dano a cada 0.5s)",
	},
	"fogo_explosao": {
		"element": "Fogo",
		"name": "Explosao",
		"costs": [60, 120, 200],
		"values": {"damage_pct": [40, 50, 60], "radius": [70, 90, 110]},
		"text": "Impacto causa {damage_pct}% do dano a ate {radius}px",
	},
	"agua_afogamento": {
		"element": "Agua",
		"name": "Afogamento",
		"costs": [40, 80, 140],
		"values": {"duration": [3.0, 3.0, 3.0], "tick_damage": [2, 3, 4], "execute_pct": [10, 15, 20]},
		"text": "Afoga por {duration}s ({tick_damage} a cada 0.5s) e executa abaixo de {execute_pct}% da vida",
	},
	"agua_onda": {
		"element": "Agua",
		"name": "Onda",
		"costs": [60, 120, 200],
		"values": {"length": [120, 160, 200], "damage_pct": [50, 60, 70]},
		"text": "Onda atinge ate {length}px atras do alvo com {damage_pct}% do dano",
	},
	"agua_congelamento": {
		"element": "Agua",
		"name": "Congelamento",
		"costs": [50, 100, 170],
		"values": {"duration": [0.6, 0.9, 1.2]},
		"text": "Acertar um inimigo ja lento o congela por {duration}s",
	},
	"terra_lamacal": {
		"element": "Terra",
		"name": "Lamacal",
		"costs": [40, 80, 140],
		"values": {"duration": [3.0, 4.0, 5.0], "speed_pct": [50, 40, 30], "radius": [70, 70, 70]},
		"text": "Deixa lama por {duration}s; quem passa anda a {speed_pct}% da velocidade",
	},
	"terra_tremor": {
		"element": "Terra",
		"name": "Tremor",
		"costs": [60, 120, 200],
		"values": {"damage_pct": [40, 50, 60], "radius": [80, 100, 120]},
		"text": "Atordoa e causa {damage_pct}% do dano a ate {radius}px",
	},
	"terra_rachadura": {
		"element": "Terra",
		"name": "Rachadura",
		"costs": [50, 100, 170],
		"values": {"bonus_pct": [25, 40, 60]},
		"text": "Atordoados ou congelados recebem +{bonus_pct}% de dano de qualquer fonte",
	},
	"ar_tufao": {
		"element": "Ar",
		"name": "Tufao",
		"costs": [60, 120, 200],
		"values": {"every": [6, 5, 4], "damage_pct": [150, 200, 250]},
		"text": "A cada {every} ataques lanca um tufao com {damage_pct}% do dano que atravessa a fileira",
	},
	"ar_ricochete": {
		"element": "Ar",
		"name": "Ricochete",
		"costs": [40, 80, 140],
		"values": {"bounces": [1, 2, 3], "damage_pct": [70, 70, 70], "radius": [140, 140, 140]},
		"text": "O golpe salta para {bounces} inimigo(s) proximo(s) com {damage_pct}% do dano",
	},
	"ar_ventania": {
		"element": "Ar",
		"name": "Ventania",
		"costs": [50, 100, 170],
		"values": {"radius": [70, 100, 130]},
		"text": "Espalha queimadura, afogamento e lentidao do alvo a ate {radius}px",
	},
	"geral_alcance": {
		"element": GENERAL,
		"name": "Alcance",
		"costs": [100, 200, 300],
		"values": {"range_pct": [10, 20, 30]},
		"text": "+{range_pct}% de alcance em todos os elementos",
	},
	"geral_recarga": {
		"element": GENERAL,
		"name": "Recarga",
		"costs": [150, 300, 450],
		"values": {"cooldown_pct": [20, 35, 50]},
		"text": "-{cooldown_pct}% no tempo de recarga",
	},
	"geral_ressonancia": {
		"element": GENERAL,
		"name": "Ressonancia",
		"costs": [120, 240, 360],
		"values": {"bonus_pct": [15, 25, 35]},
		"text": "+{bonus_pct}% de dano em inimigos sob qualquer efeito",
	},
}

static func get_upgrade(id: String) -> Dictionary:
	return UPGRADES.get(id, {})

static func get_for_element(element: String) -> Array[String]:
	var ids: Array[String] = []
	for id in UPGRADES:
		if UPGRADES[id]["element"] == element:
			ids.append(id)
	return ids

static func get_element(id: String) -> String:
	return get_upgrade(id).get("element", "")

static func get_upgrade_name(id: String) -> String:
	return get_upgrade(id).get("name", id)

# Custo para comprar o nivel informado (1 a MAX_LEVEL); -1 quando nao existe.
static func get_cost(id: String, target_level: int) -> int:
	var costs: Array = get_upgrade(id).get("costs", [])
	if target_level < 1 or target_level > costs.size():
		return -1
	return costs[target_level - 1]

static func get_value(id: String, key: String, level: int, default: Variant = 0) -> Variant:
	var values: Dictionary = get_upgrade(id).get("values", {})
	if level < 1 or not values.has(key):
		return default
	var by_level: Array = values[key]
	return by_level[mini(level, by_level.size()) - 1]

static func describe(id: String, level: int) -> String:
	var upgrade := get_upgrade(id)
	if upgrade.is_empty() or level < 1 or level > MAX_LEVEL:
		return ""
	var level_values := {}
	for key in upgrade["values"]:
		level_values[key] = get_value(id, key, level)
	return String(upgrade["text"]).format(level_values)
