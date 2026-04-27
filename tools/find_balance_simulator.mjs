import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const ITEMS_PATH = path.join(ROOT, "data", "finds", "items.json");
const CONFIG_PATH = path.join(ROOT, "data", "finds", "drop_config.json");
const DEFAULT_SEED = 12345;
const DEFAULT_HOURS = 10;
const FLOORS_PER_HOUR = 36;
const DEFAULT_RARITY_WEIGHTS = {
  common: 750,
  uncommon: 187,
  rare: 32,
  epic: 30,
  legendary: 1,
};
const RARITY_VALUE_MULTIPLIERS = {
  common: 1,
  uncommon: 1.35,
  rare: 2.1,
  epic: 3.4,
  legendary: 6,
};

class SeededRandom {
  constructor(seed) {
    this.state = seed >>> 0;
  }

  next() {
    this.state = (1664525 * this.state + 1013904223) >>> 0;
    return this.state / 0x100000000;
  }

  int(min, max) {
    return min + Math.floor(this.next() * (max - min + 1));
  }
}

function readJson(filePath) {
  return JSON.parse(fs.readFileSync(filePath, "utf8"));
}

function inDepth(item, depth) {
  if (!item.enabled) return false;
  if (depth < item.minDepth) return false;
  return item.maxDepth < 0 || depth <= item.maxDepth;
}

function spawnChance(config, depth) {
  for (const band of config.spawnChanceByDepth ?? []) {
    if (depth < band.minDepth) continue;
    if (band.maxDepth >= 0 && depth > band.maxDepth) continue;
    return Math.max(0, Math.min(1, Number(band.chance) || 0));
  }
  return 0;
}

function pickWeightedObject(weights, rng) {
  const entries = Object.entries(weights).filter(([, value]) => Number(value) > 0);
  const total = entries.reduce((sum, [, value]) => sum + Number(value), 0);
  if (total <= 0) return entries[0]?.[0] ?? "";
  let roll = rng.next() * total;
  for (const [key, value] of entries) {
    roll -= Number(value);
    if (roll <= 0) return key;
  }
  return entries.at(-1)[0];
}

function rarityMultiplier(config, rarity, levelType, pityBonus) {
  let multiplier = 1;
  if (levelType === "rare") {
    if (rarity === "rare") multiplier *= Number(config.rareWeightMultiplier ?? 3);
    if (rarity === "epic") multiplier *= Number(config.epicWeightMultiplier ?? 2);
    if (rarity === "legendary") multiplier *= Number(config.legendaryWeightMultiplier ?? 1.5);
  }
  const valuable = new Set(config.valuableRarities ?? ["rare", "epic", "legendary"]);
  if (valuable.has(rarity)) multiplier *= 1 + pityBonus;
  return multiplier;
}

function pickItem(items, rng) {
  const weighted = items.map((item) => ({
    item,
    weight: Math.max(0, Number(item.spawnWeight) || 0),
  })).filter((entry) => entry.weight > 0);
  const total = weighted.reduce((sum, entry) => sum + entry.weight, 0);
  if (total <= 0) return null;
  let roll = rng.next() * total;
  for (const entry of weighted) {
    roll -= entry.weight;
    if (roll <= 0) return entry.item;
  }
  return weighted.at(-1).item;
}

function pickRarity(config, levelType, pityBonus, rng) {
  const rarityWeights = config.rarityWeights ?? DEFAULT_RARITY_WEIGHTS;
  const weighted = Object.keys(DEFAULT_RARITY_WEIGHTS).map((rarity) => ({
    rarity,
    weight: Math.max(0, Number(rarityWeights[rarity] ?? DEFAULT_RARITY_WEIGHTS[rarity]) || 0)
      * rarityMultiplier(config, rarity, levelType, pityBonus),
  })).filter((entry) => entry.weight > 0);
  const total = weighted.reduce((sum, entry) => sum + entry.weight, 0);
  if (total <= 0) return "common";
  let roll = rng.next() * total;
  for (const entry of weighted) {
    roll -= entry.weight;
    if (roll <= 0) return entry.rarity;
  }
  return weighted.at(-1).rarity;
}

function resolveDrop(items, config, depth, pityBonus, rng) {
  if (rng.next() > spawnChance(config, depth)) return { type: "empty", items: [] };
  const pool = items.filter((item) => inDepth(item, depth));
  if (pool.length === 0) return { type: "empty", items: [] };

  const levelType = pickWeightedObject(config.levelTypeWeights ?? { normal: 1 }, rng) || "normal";
  const count = levelType === "rich"
    ? rng.int(Math.max(1, config.richItemMin ?? 2), Math.max(config.richItemMin ?? 2, config.richItemMax ?? 4))
    : 1;
  const picked = [];
  for (let i = 0; i < count; i += 1) {
    const item = pickItem(pool, rng);
    if (item) picked.push({ item, rarity: pickRarity(config, levelType, pityBonus, rng) });
  }
  return { type: levelType, items: picked };
}

function validate(items) {
  let ok = true;
  for (const depth of [1, 20, 21, 50, 51, 100, 101, 200, 201, 300]) {
    if (!items.some((item) => inDepth(item, depth))) {
      console.error(`No enabled item pool for depth ${depth}`);
      ok = false;
    }
  }
  for (const item of items) {
    const assetPath = path.join(ROOT, item.assetPath.replace("res://", "").replaceAll("/", path.sep));
    if (!fs.existsSync(assetPath)) {
      console.error(`Missing asset for ${item.id}: ${item.assetPath}`);
      ok = false;
    }
  }
  return ok;
}

function simulate() {
  const items = readJson(ITEMS_PATH);
  const config = readJson(CONFIG_PATH);
  const rng = new SeededRandom(DEFAULT_SEED);
  const stats = {
    floors: Math.round(DEFAULT_HOURS * FLOORS_PER_HOUR),
    empty: 0,
    normal: 0,
    rich: 0,
    rare: 0,
    items_found: 0,
    sell_value: 0,
    rarity: { common: 0, uncommon: 0, rare: 0, epic: 0, legendary: 0 },
  };
  let pityBonus = 0;
  const pityStep = Number(config.pityStep ?? 0.05);
  const pityMax = Number(config.pityMaxBonus ?? 0.35);
  for (let depth = 1; depth <= stats.floors; depth += 1) {
    const drop = resolveDrop(items, config, depth, pityBonus, rng);
    stats[drop.type] = (stats[drop.type] ?? 0) + 1;
    if (drop.items.length === 0) {
      pityBonus = Math.min(pityMax, pityBonus + pityStep);
      continue;
    }
    let valuable = false;
    for (const dropItem of drop.items) {
      const item = dropItem.item;
      const rarity = dropItem.rarity;
      stats.items_found += 1;
      stats.sell_value += Math.max(0, Math.round((Number(item.value) || 0) * (RARITY_VALUE_MULTIPLIERS[rarity] ?? 1)));
      stats.rarity[rarity] = (stats.rarity[rarity] ?? 0) + 1;
      if (["rare", "epic", "legendary"].includes(rarity)) valuable = true;
    }
    pityBonus = valuable ? 0 : Math.min(pityMax, pityBonus + pityStep);
  }
  return { seed: DEFAULT_SEED, hours: DEFAULT_HOURS, validation_ok: validate(items), stats };
}

const result = simulate();
console.log(JSON.stringify(result, null, 2));
if (!result.validation_ok) process.exitCode = 1;
