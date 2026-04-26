from __future__ import annotations

import json
import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
ASSET_DIR = ROOT / "assets" / "496_RPG_icons"
OUTPUT_PATH = ROOT / "data" / "finds" / "items.json"


RARITY_RANK = {
    "common": 0,
    "uncommon": 1,
    "rare": 2,
    "epic": 3,
    "legendary": 4,
}

RELIC_EPITHETS = [
    "Buried",
    "Dusty",
    "Cracked",
    "Weathered",
    "Forgotten",
    "Ancient",
    "Sealed",
    "Runed",
    "Sunken",
    "Hollow",
    "Gilded",
    "Obsidian",
    "Verdant",
    "Moonlit",
    "Starforged",
    "Deepstone",
    "Ember",
    "Frostbound",
    "Stormscarred",
    "Shadowed",
    "Blessed",
    "Cursed",
    "Wayfinder's",
    "Miner's",
]

WEAPON_EPITHETS = [
    "Rustbitten",
    "Ironroot",
    "Cavern",
    "Granite",
    "Coppervein",
    "Basalt",
    "Silvered",
    "Deepcut",
    "Echoing",
    "Nightfall",
    "Suncrack",
    "Oathbound",
    "Stormedge",
    "Ashen",
    "Kingsguard",
    "Graveborn",
    "Starfall",
    "Runebound",
    "Moonsteel",
    "Dawnforged",
    "Voidmarked",
    "Goldcrest",
]

SPELL_EPITHETS = [
    "I",
    "II",
    "III",
    "IV",
    "V",
    "VI",
    "VII",
    "VIII",
    "IX",
    "X",
    "XI",
    "XII",
    "XIII",
    "XIV",
    "XV",
    "XVI",
    "XVII",
    "XVIII",
    "XIX",
    "XX",
    "XXI",
    "XXII",
]

ELEMENT_NAMES = {
    "earth": "Earth",
    "fire": "Fire",
    "holy": "Holy",
    "ice": "Ice",
    "light": "Light",
    "magic": "Arcane",
    "physic": "Mind",
    "poison": "Venom",
    "shadow": "Shadow",
    "thunder": "Thunder",
    "water": "Water",
    "wind": "Wind",
}

ITEM_RELIC_NAMES = {
    "antidote": "Antidote",
    "batwing": "Bat Wing",
    "birdsbeak": "Bird Beak",
    "book": "Old Journal",
    "clock": "Brass Clock",
    "clover": "Lucky Clover",
    "eye": "Oracle Eye",
    "fabric": "Banner Cloth",
    "fang": "Beast Fang",
    "fishtail": "Fish Tail",
    "foxtail": "Fox Tail",
    "frogleg": "Frog Leg",
    "ink": "Black Ink",
    "ironball": "Iron Ball",
    "leaf": "Amber Leaf",
    "map": "Mine Map",
    "mirror": "Moon Mirror",
    "rabbitpaw": "Rabbit Paw",
    "scorpionclaw": "Scorpion Claw",
    "telescope": "Telescope",
    "tentacle": "Tentacle",
    "water": "Spring Water",
    "wolffur": "Wolf Fur",
}

FOOD_RELIC_NAMES = {
    "banana": "Banana Cache",
    "bread": "Old Bread",
    "carrot": "Cellar Carrot",
    "cheese": "Wax Cheese",
    "cherry": "Cherry Jar",
    "fish": "Cave Fish",
    "grapes": "Raisin Pouch",
    "greengrapes": "Sour Grapes",
    "greenpepper": "Green Pepper",
    "lemon": "Lemon Jar",
    "meat": "Meat Ration",
    "mulberry": "Mulberry Jar",
    "mushroom": "Mushroom",
    "nut": "Hard Nut",
    "orange": "Orange Slice",
    "pear": "Honey Pear",
    "pie": "Pocket Pie",
    "pineapple": "Pineapple",
    "radish": "Radish",
    "rawfish": "Raw Fish",
    "rawmeat": "Raw Meat",
    "redpepper": "Red Pepper",
    "strawberry": "Strawberry",
    "watermellon": "Melon Slice",
    "yellowpepper": "Gold Pepper",
}

POTION_COLORS = {
    "blue": "Azure",
    "green": "Verdant",
    "orange": "Amber",
    "pink": "Rose",
    "red": "Crimson",
    "white": "Pale",
    "yellow": "Golden",
    "medicine": "Medicinal",
}

POTION_EFFECTS = [
    "Stamina",
    "Mending",
    "Focus",
    "Fortune",
    "Clarity",
    "Resolve",
    "Warmth",
    "Echoes",
    "Guarding",
]


def _suffix_number(stem: str) -> int:
    match = re.search(r"(\d+)$", stem)
    if match is None:
        return 1
    return int(match.group(1))


def _choice(values: list[str], number: int) -> str:
    return values[(max(1, number) - 1) % len(values)]


def _base_after_prefix(stem: str) -> str:
    if stem.startswith("Ac_"):
        return stem.removeprefix("Ac_").lower()
    return re.sub(r"^[A-Z]_", "", stem).lower()


def _split_base_number(stem: str) -> tuple[str, int]:
    base = _base_after_prefix(stem)
    base = re.sub(r"^c_", "", base)
    match = re.match(r"([a-z_]+?)(\d+)?$", base)
    if match is None:
        return base, 1
    name = match.group(1).strip("_")
    number = int(match.group(2) or "1")
    return name, number


def semantic_name_for(stem: str, kind: str, index: int) -> str:
    base, number = _split_base_number(stem)
    lower = stem.lower()
    if kind == "magic_relic":
        if base in ELEMENT_NAMES:
            return "%s %s" % (ELEMENT_NAMES[base], _choice(SPELL_EPITHETS, number))
        if base == "buff":
            return "Ward %s" % _choice(SPELL_EPITHETS, number)
        weapon_noun = _weapon_noun(base)
        return "%s Rune %s" % (weapon_noun, _choice(SPELL_EPITHETS, number))
    if kind == "weapon":
        return "%s %s" % (_weapon_noun(base), _choice(SPELL_EPITHETS, number))
    if kind == "gear":
        return "%s %s" % (_gear_noun(base), _choice(SPELL_EPITHETS, number))
    if kind == "accessory":
        return "%s %s" % (_accessory_noun(base), _choice(SPELL_EPITHETS, number))
    if kind == "potion":
        color = POTION_COLORS.get(base, title_from_stem(base))
        effect = _choice(POTION_EFFECTS, number)
        return "%s %s" % (color, effect)
    if kind == "gem":
        return _gem_name(base, number)
    if kind == "currency":
        return _currency_name(base, number)
    if kind == "scrap":
        return "%s %s" % (_scrap_noun(base), _choice(SPELL_EPITHETS, number))
    if lower.startswith("i_c_"):
        return FOOD_RELIC_NAMES.get(base, "%s Provision" % title_from_stem(base))
    if base.startswith("bottle"):
        return "Bottle %s" % _choice(SPELL_EPITHETS, number)
    if base.startswith("cannon"):
        return "Cannon Core %s" % _choice(SPELL_EPITHETS, number)
    if base.startswith("chest"):
        return "Chest %s" % _choice(SPELL_EPITHETS, number)
    if base.startswith("feather"):
        return "Feather %s" % _choice(SPELL_EPITHETS, number)
    if base.startswith("key"):
        return "Vault Key %s" % _choice(SPELL_EPITHETS, number)
    if base.startswith("scroll"):
        return "Scroll %s" % _choice(SPELL_EPITHETS, number)
    if base.startswith("torch"):
        return "Torch %s" % _choice(SPELL_EPITHETS, number)
    return ITEM_RELIC_NAMES.get(base, "%s %s" % (_choice(RELIC_EPITHETS, index), title_from_stem(base)))


def _weapon_noun(base: str) -> str:
    nouns = {
        "axe": "Axe",
        "bow": "Bow",
        "dagger": "Dagger",
        "fist": "Gauntlet",
        "gun": "Hand Cannon",
        "mace": "Mace",
        "spear": "Spear",
        "staff": "Staff",
        "sword": "Sword",
        "throw": "Throwing Star",
    }
    return nouns.get(base, title_from_stem(base))


def _gear_noun(base: str) -> str:
    nouns = {
        "armor": "Plate",
        "armour": "Chain",
        "clothing": "Coat",
        "elm": "Helm",
        "hat": "Prospector Hat",
        "shoes": "Boots",
    }
    return nouns.get(base, title_from_stem(base))


def _accessory_noun(base: str) -> str:
    nouns = {
        "medal": "Medal",
        "necklace": "Necklace",
        "ring": "Ring",
    }
    return nouns.get(base, title_from_stem(base))


def _gem_name(base: str, number: int) -> str:
    names = {
        "agate": "Agate",
        "amethist": "Amethyst",
        "crystal": "Crystal %s" % _choice(SPELL_EPITHETS, number),
        "diamond": "Diamond",
        "jade": "Jade",
        "opal": "Opal",
        "ruby": "Ruby",
        "sapphire": "Sapphire",
    }
    return names.get(base, "%s Gem" % title_from_stem(base))


def _currency_name(base: str, number: int) -> str:
    if "gold" in base:
        metal = "Gold"
    elif "silver" in base:
        metal = "Silver"
    elif "bronze" in base:
        metal = "Bronze"
    else:
        metal = title_from_stem(base)
    if "coin" in base:
        return "%s Coin" % metal
    if "bar" in base:
        return "%s Ingot" % metal
    return "%s %s" % (metal, _choice(SPELL_EPITHETS, number))


def _scrap_noun(base: str) -> str:
    nouns = {
        "bones": "Rib Bones",
        "bone": "Ancient Bone",
        "coal": "Coal Chunk",
        "metal": "Metal Plate",
        "rock": "Stone Shard",
        "snailshell": "Snail Shell",
        "solidshell": "Solid Shell",
        "wood": "Timber Fragment",
    }
    return nouns.get(base, title_from_stem(base))


def unique_display_name(name: str, used_names: set[str], index: int) -> str:
    candidate = name
    if candidate not in used_names:
        used_names.add(candidate)
        return candidate
    candidate = "%s of %s" % (name, _choice(RELIC_EPITHETS, index))
    suffix = 2
    while candidate in used_names:
        candidate = "%s %d" % (name, suffix)
        suffix += 1
    used_names.add(candidate)
    return candidate


def title_from_stem(stem: str) -> str:
    cleaned = re.sub(r"^[A-Z]_", "", stem)
    cleaned = cleaned.replace("Ac_", "").replace("I_C_", "")
    cleaned = re.sub(r"([a-z])([A-Z])", r"\1 \2", cleaned)
    cleaned = re.sub(r"(\D)(\d+)$", r"\1 \2", cleaned)
    cleaned = cleaned.replace("_", " ")
    return " ".join(part.capitalize() for part in cleaned.split())


def item_type(stem: str) -> str:
    lower = stem.lower()
    if lower.startswith("ac_"):
        return "accessory"
    if lower.startswith("a_") or lower.startswith("c_"):
        return "gear"
    if lower.startswith("w_"):
        return "weapon"
    if lower.startswith("s_"):
        return "magic_relic"
    if lower.startswith("p_"):
        return "potion"
    if any(token in lower for token in ["coin", "bar", "gold", "silver", "bronze"]):
        return "currency"
    if any(token in lower for token in ["crystal", "diamond", "ruby", "sapphire", "opal", "jade", "agate", "amethist"]):
        return "gem"
    if any(token in lower for token in ["bone", "rock", "wood", "metal", "coal", "shell"]):
        return "scrap"
    if any(token in lower for token in ["key", "scroll", "book", "map", "mirror", "clock", "telescope", "chest"]):
        return "relic"
    return "relic"


def rarity_for(stem: str, index: int) -> str:
    lower = stem.lower()
    if "gold_" in lower or lower in {"i_diamond", "i_ruby", "i_sapphire"}:
        return "legendary"
    if lower.startswith("s_") or any(token in lower for token in ["opal", "jade", "amethist", "crystal03"]):
        return "epic"
    if lower.startswith("ac_") or any(token in lower for token in ["gold", "silver", "crystal", "key", "scroll", "book", "mirror", "telescope", "chest"]):
        return "rare"
    if lower.startswith("w_") or lower.startswith("p_") or lower.startswith("a_") or lower.startswith("c_"):
        return "uncommon"
    if index % 23 == 0:
        return "uncommon"
    return "common"


def depth_range(rarity: str, stem: str) -> tuple[int, int]:
    lower = stem.lower()
    if any(token in lower for token in ["bone", "rock", "wood", "bronze", "coal", "metal"]):
        return 1, 30
    if rarity == "common":
        return 1, 50
    if rarity == "uncommon":
        return 21, 100
    if rarity == "rare":
        return 51, 200
    if rarity == "epic":
        return 101, -1
    return 201, -1


def spawn_weight(rarity: str, stem: str) -> int:
    base = {
        "common": 100,
        "uncommon": 70,
        "rare": 35,
        "epic": 12,
        "legendary": 4,
    }[rarity]
    lower = stem.lower()
    if any(token in lower for token in ["bone", "rock", "wood", "bronze"]):
        base += 25
    if "gold_" in lower or "diamond" in lower:
        base = max(2, base - 2)
    return base


def value_for(rarity: str, min_depth: int, index: int) -> int:
    base = {
        "common": 6,
        "uncommon": 18,
        "rare": 55,
        "epic": 150,
        "legendary": 420,
    }[rarity]
    depth_bonus = max(0, min_depth - 1) // 4
    rank_bonus = RARITY_RANK[rarity] * 11
    jitter = (index * 7) % max(3, base // 2)
    return base + depth_bonus + rank_bonus + jitter


def set_id_for(stem: str, rarity: str, kind: str) -> str:
    lower = stem.lower()
    if "crystal" in lower or kind == "gem":
        return "crystal_relics"
    if "key" in lower or "scroll" in lower or "medal" in lower:
        return "temple_seals"
    if rarity in {"epic", "legendary"} and kind in {"accessory", "magic_relic"}:
        return "ancient_mask"
    return ""


def make_id(stem: str, index: int, used: set[str]) -> str:
    cleaned = re.sub(r"[^a-z0-9]+", "_", stem.lower()).strip("_")
    cleaned = re.sub(r"^[a-z]_", "", cleaned)
    if not cleaned:
        cleaned = f"item_{index:03d}"
    candidate = cleaned
    suffix = 2
    while candidate in used:
        candidate = f"{cleaned}_{suffix}"
        suffix += 1
    used.add(candidate)
    return candidate


def main() -> None:
    files = sorted(ASSET_DIR.glob("*.png"), key=lambda path: path.name.lower())
    used_ids: set[str] = set()
    used_names: set[str] = set()
    items: list[dict[str, object]] = []
    for index, path in enumerate(files, start=1):
        stem = path.stem
        rarity = rarity_for(stem, index)
        min_depth, max_depth = depth_range(rarity, stem)
        kind = item_type(stem)
        item = {
            "id": make_id(stem, index, used_ids),
            "name": unique_display_name(semantic_name_for(stem, kind, index), used_names, index),
            "assetPath": f"res://assets/496_RPG_icons/{path.name}",
            "rarity": rarity,
            "value": value_for(rarity, min_depth, index),
            "minDepth": min_depth,
            "maxDepth": max_depth,
            "spawnWeight": spawn_weight(rarity, stem),
            "type": kind,
            "setId": set_id_for(stem, rarity, kind),
            "unlockId": "",
            "enabled": True,
        }
        items.append(item)
    OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT_PATH.write_text(json.dumps(items, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"Wrote {len(items)} items to {OUTPUT_PATH}")


if __name__ == "__main__":
    main()
