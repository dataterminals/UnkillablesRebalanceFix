# Unkillables Rebalance — Fix

A compatibility repair of the community mod **Unkillables Rebalance** for
*The Forever Winter* (Nexus mod [#68](https://www.nexusmods.com/theforeverwinter/mods/68)),
so it works again on the current game build.

> **Status:** **rebuilt & statically verified on build `24501089`** (2026-08-01) — awaiting the in-game test.
> The mod ships for game **0.9.2.2**; root cause is cooked-asset version drift (same failure class as
> `HeavyRifleRebalanceFix`). The rebuilt pak is in [`dist/UnkillablesRebalanceFix/`](dist/UnkillablesRebalanceFix).
> See [`docs/fix-notes.md`](docs/fix-notes.md), [`docs/diagnosis.md`](docs/diagnosis.md) and [`WORKLOG.md`](WORKLOG.md).

## What the mod does

Unkillables Rebalance makes *The Forever Winter*'s "unkillable" bosses actually killable, and defangs the Grabber:

- **6 bosses get finite HP** (removing the 1-billion / 900-million invincibility pool) so they're killable by regular
  weapons instead of only the stun → 3× DetPack anti-boss loop: MeatMan 330k, OrgaMech 286,870, ShieldOfficer 328k,
  Toothy 308,700, Mother Courage 372k, Opal 213k.
- **Grabber / Stalker (all 4 variants)** — `DamageToStagger` 20000 → 1000 (20× easier to stun) and
  `SyncKillMaxPlayerHealth` 2000 → 1000 (no more insta-kill grab unless you're already under 1000 HP; it does a 600-dmg
  swipe and disengages instead).
- **`BPC_IncomingDamageMod`** — 19 armour/body-zone HP constants scaled down so armoured zones are destroyable.

It is a **pure pak mod**: one container, `153_UnkillablesRebalance_P`, overriding 11 cooked boss/AI assets. No
TFWWorkbench JSON, no loose files, no meshes. Full value map: [`docs/rebalance-values.json`](docs/rebalance-values.json).

## The problem

The mod's assets were cooked against game **0.9.2.2**. On **0.9.3.9.2** the base boss classes underneath 3 of the 11
overrides (`MotherCourage`, `Opal`, `BPC_IncomingDamageMod`) have **drifted** (gained exports), so the game loads the
mod's stale 0.9.2.2 classes — reverting base changes and risking the same `ObjectSerializationError` that broke
Heavy Rifle Rebalance. The other 8 overrides are structurally identical to current base (only a rebalanced scalar
differs) and are low-risk. See [`docs/diagnosis.md`](docs/diagnosis.md).

## Layout

| Path | Contents |
|------|----------|
| `upstream/` | Pristine extracted original (`153_` pak). Reference only; cooked binaries are gitignored. |
| `docs/` | Diagnosis, the datamined rebalance value map, fix notes. |
| `tools/` | `build_fix.sh` (reproducible rebuild) + `patch_drifted.py` (self-verifying scalar patcher). retoc is gitignored. |
| `dist/` | **Built fixed mod** — tracked; ships the repaired `153` pak + player `readme.txt`. |
| `WORKLOG.md` | Running log. |

## Dependencies (unchanged from upstream)

Whatever the current community build for 0.9.3.x uses to load pak mods — Signature Bypass + UE4SS. (This mod has **no**
TFWWorkbench dependency; it's a plain pak.)

## Credit

Original mod **Unkillables Rebalance** by its Nexus author (mod #68). This repository is a community **compatibility
fix**; any redistributed build remains subject to the original author's permission.
