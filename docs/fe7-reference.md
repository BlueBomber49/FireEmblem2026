# FE7 reference data

This game uses *Fire Emblem: The Blazing Blade* (FE7, GBA) mechanics and numbers as its baseline. This page records where the starting values in `data/` came from, so they can be checked. Once a value is in a `.tres` file, that file is the source of truth: tune it there, not here.

Sources (Serenes Forest, retrieved 2026-10-09; terrain re-checked 2026-10-14):
- [Calculations](https://serenesforest.net/blazing-sword/miscellaneous/calculations/)
- [Terrain data](https://serenesforest.net/blazing-sword/classes/terrain-data/)
- [Class base stats](https://serenesforest.net/blazing-sword/classes/base-stats/), [growth rates](https://serenesforest.net/blazing-sword/classes/growth-rates/), [maximum stats](https://serenesforest.net/blazing-sword/classes/maximum-stats/)
- [Swords](https://serenesforest.net/blazing-sword/inventory/swords/), [lances](https://serenesforest.net/blazing-sword/inventory/lances/), [axes](https://serenesforest.net/blazing-sword/inventory/axes/), [bows](https://serenesforest.net/blazing-sword/inventory/bows/), [anima tomes](https://serenesforest.net/blazing-sword/inventory/anima-tomes/), [items](https://serenesforest.net/blazing-sword/inventory/items/)
- Level cap: [Fire Emblem Wiki, "Level"](https://fireemblemwiki.org/wiki/Level)

Serenes Forest's `/blazing-sword/weapons/...` URLs redirect to *Shadow Dragon* (FE1) data. Use the `/inventory/` pages above.

## Intended differences from FE7

| FE7 | This game | Why |
|---|---|---|
| One combined Str/Mag stat | Separate `strength` and `magic` | Team decision. FE7's number goes in `strength` for physical classes and `magic` for magic classes, and the other is 0. |
| 11 movement groups | 5: foot, armored, mounted, flier, mage | Simpler. **Nomads use mounted costs** (FE7 Nomads differ from Cavaliers in forest and desert), and **Fighters use foot costs** (FE7 Fighters pay 3 on mountains, where foot units pay 4). |
| Character data stored as offsets from class bases | `UnitData.starting_stats` holds **total** stats | Teammates can paste numbers straight from character pages. Movement always comes from the class. |
| Male and female class variants | Male values only | Simpler; can be added as separate classes later. |

## Combat formulas
All results round down unless noted.

- **Attack speed (AS)** = Spd − max(0, weapon weight − Con)
- **Doubling:** a unit strikes twice if its AS − the enemy's AS ≥ 4
- **Attack** = Str (physical) or Mag (magic) + (Might + triangle bonus) × effectiveness
  - Effectiveness is ×2 when the weapon is effective against the target (English FE7), otherwise ×1
  - Triangle bonus: +1 with advantage, −1 with disadvantage (doubled and reversed for reaver weapons)
- **Defense** = Def (against physical) or Res (against magic) + terrain defense
- **Damage** = max(0, Attack − Defense), ×3 on a critical
- **Accuracy** = weapon Hit + 2 × Skl + Lck ÷ 2 + triangle hit (±15)
- **Avoid** = 2 × AS + Lck + terrain avoid
- **Displayed hit** = clamp(Accuracy − enemy Avoid, 0, 100)
- **Critical** = weapon Crit + Skl ÷ 2 + class critical bonus (+15 for Swordmaster and Berserker)
- **Critical avoid** = Lck; **displayed crit** = clamp(Critical − enemy critical avoid, 0, 100)
- **Hit roll (FE7 "true hit")**: hits when the average of two rolls from 0–99 is below the displayed hit. Crits use a single roll.
- Fliers get no terrain avoid or defense bonus, only HP recovery.
- Weapon triangle: Sword beats Axe, Axe beats Lance, Lance beats Sword. Anima beats Light, Light beats Dark, Dark beats Anima.
- Staff accuracy = 30 + 5 × Mag + Skl; staff avoid = 5 × Res + 2 × distance (later)

## Experience and levels
- **100 EXP per level. Level cap 20**, and EXP gain stops at the cap. Each level-up, every stat has a (growth %) chance to gain 1, and stats can't exceed the class caps.
- Characters use their personal growth rates. Class growth rates are for generic units.
- **EXP for dealing damage** = (31 + enemy level + enemy bonus A − level − bonus A) ÷ class power, minimum 1. A miss or no damage gives 1.
- **EXP for a kill** = damage EXP + max(0, kill base + 20 + boss bonus (40) + thief bonus (20)), where kill base = (enemy level × enemy class power + enemy bonus B) − (level × class power + bonus B)
- Class power: 3 for most classes; 2 for Cleric, Soldier, Troubadour, Bard, Thief and Dancer
- Bonus A: 0 unpromoted, 20 promoted. Bonus B: 0 unpromoted, 60 promoted (40 for Assassin, female Bishop and Valkyrie)

## Terrain
Movement costs by our movement group. A dash means impassable. FE7's other groups are omitted; see the intended differences above.

| Terrain | Avoid | Def | Heal | Foot | Armored | Mounted | Flier | Mage |
|---|---|---|---|---|---|---|---|---|
| Plain | 0 | 0 | | 1 | 1 | 1 | 1 | 1 |
| Forest | 20 | 1 | | 2 | 2 | 3 | 1 | 2 |
| Mountain | 30 | 1 | | 4 | – | – | 1 | 4 |
| Desert (sand) | 5 | 0 | | 2 | 3 | 2 | 1 | 1 |
| Fort | 20 | 2 | 20% | 2 | 2 | 2 | 1 | 2 |
| Gate | 20 | 3 | 10% | 1 | 1 | 1 | 1 | 1 |
| Village/House | 10 | 0 | | 1 | 1 | 1 | 1 | 1 |
| River | 0 | 0 | | 5 | – | – | 1 | – |
| Sea/Lake | 10 | 0 | | – | – | – | 1 | – |
| Cliff | 0 | 0 | | – | – | – | 1 | – |
| Wall | 0 | 0 | | – | – | – | – | – |

"Mounted" is FE7's Knights 1 group (Cavalier). FE7's full table also has Nomad, Fighter, Bandit and Pirate columns.

## Classes (male, unpromoted)
Stats in order HP / Str / Mag / Skl / Spd / Lck / Def / Res / Con / Mov. Growth rates in order HP / Str / Mag / Skl / Spd / Lck / Def / Res (%).

| Class | Bases | Growths | Group | Weapons | Class power |
|---|---|---|---|---|---|
| Myrmidon | 16/4/0/9/9/0/2/0/8/5 | 70/35/0/40/40/30/15/20 | Foot | Sword | 3 |
| Mercenary | 18/4/0/8/8/0/4/0/9/5 | 80/40/0/40/32/30/18/20 | Foot | Sword | 3 |
| Thief | 16/3/0/1/9/0/2/0/6/6 | 50/5/0/45/40/40/5/20 | Foot | Sword | 2 |
| Soldier | 20/3/0/0/1/0/0/0/6/5 | 80/50/0/30/20/25/12/15 | Foot | Lance | 2 |
| Fighter | 20/5/0/2/4/0/2/0/11/5 | 85/55/0/35/30/15/15/15 | Foot | Axe | 3 |
| Archer | 18/4/0/3/3/0/3/0/7/5 | 70/35/0/40/32/35/15/15 | Foot | Bow | 3 |
| Knight | 17/5/0/2/0/0/9/0/13/4 | 80/40/0/30/15/25/28/20 | Armored | Lance | 3 |
| Cavalier | 20/5/0/2/5/0/6/0/9/7 | 75/35/0/40/28/30/15/15 | Mounted | Sword, Lance | 3 |
| Nomad | 16/5/0/4/5/0/4/0/7/7 | 65/30/0/40/45/30/12/15 | Mounted | Bow | 3 |
| Pegasus Knight | 14/4/0/5/5/0/3/2/5/7 | 65/35/0/40/40/35/12/35 | Flier | Lance | 3 |
| Mage | 16/0/1/2/3/0/3/3/6/5 | 55/0/55/40/35/20/5/30 | Mage | Anima | 3 |

Unpromoted caps for every class: HP 60, Str 20, Mag 20, Skl 20, Spd 20, Lck 30, Def 20, Res 20, Con 20, Mov 15. FE7 bases give every class Lck 0.

## Weapons
Rank / range / weight / might / hit / crit / uses. Uses aren't modeled yet (no durability).

| Weapon | Rank | Rng | Wt | Mt | Hit | Crt | Uses | Notes |
|---|---|---|---|---|---|---|---|---|
| Iron Sword | E | 1 | 5 | 5 | 90 | 0 | 46 | |
| Slim Sword | E | 1 | 2 | 3 | 100 | 5 | 30 | |
| Steel Sword | D | 1 | 10 | 8 | 75 | 0 | 30 | |
| Iron Lance | E | 1 | 8 | 7 | 80 | 0 | 45 | |
| Slim Lance | E | 1 | 4 | 4 | 85 | 5 | 30 | |
| Javelin | E | 1–2 | 11 | 6 | 65 | 0 | 20 | |
| Steel Lance | D | 1 | 13 | 10 | 70 | 0 | 30 | |
| Iron Axe | E | 1 | 10 | 8 | 75 | 0 | 45 | |
| Hand Axe | E | 1–2 | 12 | 7 | 60 | 0 | 20 | |
| Steel Axe | E | 1 | 15 | 11 | 65 | 0 | 30 | |
| Iron Bow | E | 2 | 5 | 6 | 85 | 0 | 45 | Effective vs. fliers |
| Steel Bow | D | 2 | 9 | 9 | 70 | 0 | 30 | Effective vs. fliers |
| Fire | E | 1–2 | 4 | 5 | 90 | 0 | 40 | Anima |
| Thunder | D | 1–2 | 6 | 8 | 80 | 5 | 35 | Anima |

All bows are effective against fliers in FE7 (except the Emblem Bow).

## Consumables
| Item | Uses | Effect |
|---|---|---|
| Vulnerary | 3 | Restores 10 HP |
| Elixir | 3 | Restores all HP |
