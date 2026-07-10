# Diagnosis — why Unkillables Rebalance is out of date on 0.9.3.9.2

**Build in question:** 24097213 (Hot-Fix 0.9.3.9.2). **Mod version:** 0.9.2.2 (Nexus [#68](https://www.nexusmods.com/theforeverwinter/mods/68)).
Method: decoded the mod's pak vs. the live game with the [`forever-winter-datamine`](https://github.com/dataterminals) CUE4Parse
toolchain (base-only mount = vanilla; `global + mod` mount = the mod's own cooked versions), diffed the two, and
corroborated against the mod's public description.

## What the mod is

A **pure pak mod** — one container, `153_UnkillablesRebalance_P` (`.pak/.ucas/.utoc`), no TFWWorkbench JSON and no
loose files. It ships **11 cooked-asset overrides** of the game's boss/elite AI:

| Asset | Type | What the mod changes |
|---|---|---|
| `BP_AI_Euruska_MeatMan` | boss BP | `DefaultHealth` 1e9 → **330,000** |
| `BP_AI_Euruska_OrgaMech` | boss BP | `DefaultHealth` 1e9 → **286,870** |
| `BP_AI_Euruska_ShieldOfficer` | boss BP | `DefaultHealth` 1e9 → **328,000** |
| `BP_Mech_Toothy` | boss BP | `DefaultHealth` 9e8 → **308,700** |
| `BP_AI_Eurasia_MotherCourage` | boss BP | `DefaultHealth` 1e9 → **372,000** |
| `BP_AI_Eurasia_Opal` | boss BP | `DefaultHealth` 1e9 → **213,000** |
| `AIDEF_Euruska_Stalker` (+`_HK`, `_Pregnant_Quest`, `_Underground`) | AI DataAsset | `DamageToStagger` 20000 → **1000**; `SyncKillMaxPlayerHealth` 2000 → **1000** |
| `BPC_IncomingDamageMod` | shared component BP | 19 armour/body-zone HP constants scaled down (see [`rebalance-values.json`](rebalance-values.json)) |

This matches the author's own description verbatim: *"rebalances most unkillables — OPAL, Mother Courage, Orgamech,
Meatman, Toothy and Shield Officer (non-hunter killer) are now both stunnable and killable by regular weapons"* and
*"Grabber/Stalker (all variants) no longer insta-kill players unless they are below 1000 hp… 600 damage swipes."*
So the whole mod is **scalar-value rebalancing** — no new assets, no bytecode logic added; it de-invincibles the
billion-HP bosses (see [[fw-anti-boss-codex]] for why they normally need the DetPack stun-kill loop) and defangs the
Grabber's sync-kill grab.

## Why it's out of date (root cause = cooked-asset version drift)

The mod's overrides were **cooked against game 0.9.2.2**. On 0.9.3.9.2 the base assets underneath them have drifted,
and a pak override binds to the base package by **FPackageId** (CityHash64 of the package name), so the game loads the
mod's stale 0.9.2.2 cooked class in place of the current one. This is the **same failure class** that crashed
[Heavy Rifle Rebalance](https://www.nexusmods.com/theforeverwinter/mods/76)'s `BP_WPN_HRF05` on this build
(`ObjectSerializationError`) — see the sibling `HeavyRifleRebalanceFix` repo.

**Structural evidence (mod cooked-class exports vs. current base):**

| Asset | mod exports | base exports | drift |
|---|---:|---:|:--|
| MeatMan / OrgaMech / ShieldOfficer / Toothy | 71 / 73 / 122 / 783 | 71 / 73 / 122 / 783 | **none** — only the CDO health scalar differs |
| 4× `AIDEF_Euruska_Stalker*` | (DataAsset) | (DataAsset) | **none** — only 2 scalars differ |
| `BP_AI_Eurasia_MotherCourage` | 141 | **182** | base gained **+41** exports |
| `BP_AI_Eurasia_Opal` | 385 | **417** | base gained **+32** exports |
| `BPC_IncomingDamageMod` | 464 | **497** | base gained **+33** exports |

So the 11 overrides split cleanly into two risk tiers:

- **8 low-risk assets** (4 boss BPs + 4 Stalker DataAssets): the current base class/asset is **structurally identical**
  to what the mod overrides; only the rebalanced scalar differs. A stale override here reverts nothing and is very
  unlikely to fail deserialization.
- **3 drifted assets** (`MotherCourage`, `Opal`, `BPC_IncomingDamageMod`): the base class **grew new exports** since
  0.9.2.2. Shipping the mod's stale version here (a) **reverts** whatever base added (missing new functions/abilities),
  and (b) risks the HeavyRifle-style `ObjectSerializationError` if the stale bytecode references a base symbol that
  changed. `MotherCourage` and `OrgaMech` are also exactly the two the author already flags as freezing on death — a
  behaviour that a further base-drift can only worsen.

## Exact failure mode on this build — **not yet confirmed in-game**

Static analysis proves the drift and the values, but the *runtime* symptom on 0.9.3.9.2 could be any of:

1. **Hard crash** (`ObjectSerializationError`) when a drifted boss spawns — the HeavyRifle outcome.
2. **Silent no-op** — the override fails to bind and bosses stay at 1e9 HP (mod "does nothing").
3. **Loads but reverted** — drifted bosses lose base's post-0.9.2.2 changes.

The low-risk 8 almost certainly still apply their rebalance. The unknown is the drifted 3. Confirming which requires a
launch on build 24097213 (the arbiter, as with HeavyRifle).

## Recommended fix (mirrors HeavyRifleRebalanceFix — minimal fragile surface)

The rebalance is **entirely scalar values**, and TFWWorkbench/JSON can't express boss-BP CDO health or bytecode
constants, so a pak is unavoidable. Two viable build strategies:

- **Option A — rebase the mod's overrides (HeavyRifle method).** retoc `to-legacy` the mod-won assets with the full
  current game mounted → repath the bare extracts to their real `/Game` paths (retoc derives FPackageId from path) →
  `to-zen --version UE5_4`. Refreshes imports against current base. Clean for the 8 low-risk assets; for the drifted 3
  it still ships stale bytecode (reverts base content, residual crash risk).
- **Option B — patch current base (most correct).** retoc `to-legacy` the **current base** version of each asset →
  byte-patch only the changed scalars (float32: e.g. `1e9` `0x4E6E6B28` → `330000` `0x48A11C00`; `DefaultMaxHealth`
  likewise; the 19 ordered `BPC` `EX_FloatConst`s) → `to-zen`. Ships **current** structure with only the rebalanced
  values changed — no reverted content, no stale bytecode. More work (esp. mapping the 19 ordered BPC constants), but
  no drift risk.

A sensible hybrid: Option A for the 8 structurally-identical assets, Option B for the 3 drifted ones. Both paths need
retoc (not yet on this machine) and an in-game test on 24097213.

## Honest caveats

- **Not yet built or tested.** This document is static analysis + author-description corroboration only.
- The `191`-style mesh/texture side that HeavyRifle had does **not** exist here — this mod touches no meshes, so there's
  no cosmetic-regression surface.
- Any future hotfix touching these boss classes will re-break the pak — inherent to cooked-override mods.
