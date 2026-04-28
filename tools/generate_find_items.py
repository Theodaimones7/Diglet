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

DEPTH_BANDS = ["common", "uncommon", "rare", "epic", "legendary"]

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

NAME_ASPECTS = [
    "Dawn",
    "Dusk",
    "Ash",
    "Embers",
    "Cinders",
    "Frost",
    "Storms",
    "Echoes",
    "Depths",
    "Roots",
    "Crowns",
    "Oaths",
    "Wards",
    "Whispers",
    "Moons",
    "Stars",
    "Dreams",
    "Ruins",
    "Dust",
    "Gold",
    "Glass",
    "Bones",
    "Thorns",
    "Tides",
    "Lanterns",
    "Graves",
    "Kings",
    "Saints",
    "Shadows",
    "Sunlight",
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
    "antidote": "Saint's Antidote",
    "batwing": "Wing of Nightfall",
    "birdsbeak": "Beak of the Windseer",
    "book": "Book of Death",
    "clock": "Clock of Buried Hours",
    "clover": "Clover of Second Chances",
    "eye": "Oracle Eye of the Deep",
    "fabric": "Banner of the Lost Camp",
    "fang": "Fang of the Cave King",
    "fishtail": "Tail of the Blind Fish",
    "foxtail": "Fox Tail of Silent Paths",
    "frogleg": "Frog Leg of Mire Luck",
    "ink": "Ink of Black Oaths",
    "ironball": "Iron Ball of Judgment",
    "leaf": "Leaf of Amber Sleep",
    "map": "Map of Hidden Veins",
    "mirror": "Mirror of Moonlit Lies",
    "rabbitpaw": "Paw of Borrowed Luck",
    "scorpionclaw": "Claw of Desert Venom",
    "telescope": "Telescope of Fallen Stars",
    "tentacle": "Tentacle of the Deep One",
    "water": "Water of First Rain",
    "wolffur": "Fur of the Lone Wolf",
}

FOOD_RELIC_NAMES = {
    "banana": "Banana",
    "bread": "Bread",
    "carrot": "Carrot",
    "cheese": "Cheese",
    "cherry": "Cherry",
    "fish": "Fish",
    "grapes": "Grapes",
    "greengrapes": "Green Grapes",
    "greenpepper": "Green Pepper",
    "lemon": "Lemon",
    "meat": "Meat",
    "mulberry": "Mulberry",
    "mushroom": "Mushroom",
    "nut": "Nut",
    "orange": "Orange",
    "pear": "Pear",
    "pie": "Pie",
    "pineapple": "Pineapple",
    "radish": "Radish",
    "rawfish": "Raw Fish",
    "rawmeat": "Raw Meat",
    "redpepper": "Red Pepper",
    "strawberry": "Strawberry",
    "watermellon": "Watermelon",
    "yellowpepper": "Yellow Pepper",
}

NUMBERED_RELIC_NAMES = {
    "bottle": ["Empty Bottle", "Old Bottle", "Sealed Bottle", "Glow Bottle"],
    "cannon": ["Cannonball", "Powder Keg", "Brass Shell", "Broken Mortar", "Fuse Coil"],
    "chest": ["Wooden Chest", "Iron Chest"],
    "feather": ["White Feather", "Black Feather"],
    "key": ["Copper Key", "Iron Key", "Brass Key", "Silver Key", "Gold Key", "Bone Key", "Glass Key"],
    "scroll": ["Rolled Scroll", "Sealed Scroll"],
    "torch": ["Burned Torch", "Miner's Torch"],
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
            return "%s Sigil of %s" % (ELEMENT_NAMES[base], _choice(NAME_ASPECTS, number))
        if base == "buff":
            return "Ward of %s" % _choice(NAME_ASPECTS, number)
        weapon_noun = _weapon_noun(base)
        return "%s Rune of %s" % (weapon_noun, _choice(NAME_ASPECTS, number))
    if kind == "weapon":
        return "%s of %s" % (_weapon_noun(base), _choice(NAME_ASPECTS, number))
    if kind == "gear":
        return "%s of %s" % (_gear_noun(base), _choice(NAME_ASPECTS, number))
    if kind == "accessory":
        return "%s of %s" % (_accessory_noun(base), _choice(NAME_ASPECTS, number))
    if kind == "potion":
        color = POTION_COLORS.get(base, title_from_stem(base))
        effect = _choice(POTION_EFFECTS, number)
        return "%s Draught of %s" % (color, effect)
    if kind == "gem":
        return _gem_name(base, number)
    if kind == "currency":
        return _currency_name(base, number)
    if kind == "scrap":
        return "%s of %s" % (_scrap_noun(base), _choice(NAME_ASPECTS, number))
    if lower.startswith("i_c_"):
        return FOOD_RELIC_NAMES.get(base, "%s Provision" % title_from_stem(base))
    numbered_relic_name = _numbered_relic_name(base, number)
    if numbered_relic_name != "":
        return numbered_relic_name
    return ITEM_RELIC_NAMES.get(base, "%s %s" % (_choice(RELIC_EPITHETS, index), title_from_stem(base)))


def _numbered_relic_name(base: str, number: int) -> str:
    names = NUMBERED_RELIC_NAMES.get(base)
    if names is None:
        return ""
    if number < 1 or number > len(names):
        return "%s %d" % (title_from_stem(base), number)
    return names[number - 1]


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
        "agate": "Agate of Layered Time",
        "amethist": "Amethyst of Violet Sleep",
        "crystal": "Crystal of %s" % _choice(NAME_ASPECTS, number),
        "diamond": "Diamond of Unbroken Light",
        "jade": "Jade of Quiet Breath",
        "opal": "Opal of Shifting Color",
        "ruby": "Ruby of Heartfire",
        "sapphire": "Sapphire of Deep Water",
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
        return "%s Coin of Lost Wages" % metal
    if "bar" in base:
        return "%s Ingot of Old Forges" % metal
    return "%s of %s" % (metal, _choice(NAME_ASPECTS, number))


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


def depth_band_for_index(index: int) -> str:
    return DEPTH_BANDS[(index - 1) % len(DEPTH_BANDS)]


def depth_range(depth_band: str, stem: str) -> tuple[int, int]:
    if depth_band == "common":
        return 1, 20
    if depth_band == "uncommon":
        return 21, 50
    if depth_band == "rare":
        return 51, 100
    if depth_band == "epic":
        return 101, 200
    if depth_band == "legendary":
        return 201, -1
    return 1, -1


def spawn_weight(depth_band: str, stem: str) -> int:
    return 100


def value_for(depth_band: str, min_depth: int, index: int) -> int:
    base = {
        "common": 8,
        "uncommon": 12,
        "rare": 18,
        "epic": 28,
        "legendary": 42,
    }[depth_band]
    depth_bonus = max(0, min_depth - 1) // 4
    rank_bonus = RARITY_RANK[depth_band] * 4
    jitter = (index * 7) % max(3, base // 2)
    return base + depth_bonus + rank_bonus + jitter


def set_id_for(stem: str, depth_band: str, kind: str) -> str:
    lower = stem.lower()
    if "crystal" in lower or kind == "gem":
        return "crystal_relics"
    if "key" in lower or "scroll" in lower or "medal" in lower:
        return "temple_seals"
    if depth_band in {"epic", "legendary"} and kind in {"accessory", "magic_relic"}:
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
        depth_band = depth_band_for_index(index)
        min_depth, max_depth = depth_range(depth_band, stem)
        kind = item_type(stem)
        item = {
            "id": make_id(stem, index, used_ids),
            "name": unique_display_name(semantic_name_for(stem, kind, index), used_names, index),
            "assetPath": f"res://assets/496_RPG_icons/{path.name}",
            "rarity": "common",
            "value": value_for(depth_band, min_depth, index),
            "minDepth": min_depth,
            "maxDepth": max_depth,
            "spawnWeight": spawn_weight(depth_band, stem),
            "type": kind,
            "setId": set_id_for(stem, depth_band, kind),
            "unlockId": "",
            "enabled": True,
        }
        items.append(item)
    OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT_PATH.write_text(json.dumps(items, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"Wrote {len(items)} items to {OUTPUT_PATH}")


if __name__ == "__main__":
    main()
