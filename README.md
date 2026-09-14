# Unkillables Rebalance — Fix

A compatibility repair of the community mod **Unkillables Rebalance** for
*The Forever Winter* (Nexus mod [#68](https://www.nexusmods.com/theforeverwinter/mods/68)),
so it works again on the current game build.

> **Status:** **rebuilt & statically verified on build `25071553`** (2026-09-11) — awaiting the
> in-game test. The mod ships for game **0.9.2.2**; root cause is cooked-asset version drift (same
> failure class as `HeavyRifleRebalanceFix`). The rebuilt pak is in
> [`dist/UnkillablesRebalanceFix/`](dist/UnkillablesRebalanceFix).
>
> **What this rebuild fixes — and this one is severe.** Build `25071553` (2026-09-10) **moved the AI
> character class schema**. Because UE5 cooks properties unversioned — identified by index, not by
> name — the v1.3 cook is not rejected on the new build, it is **mis-read**: on all 6 boss BPs the
> CDO property stream slides onto neighbouring properties (`FarDistance` decodes 150 where base has
> 750; the 750 lands on `CloseDistanceRadiusScalar`) and then desynchronises: **19 properties never
> decode at all** — `RootComponent`, `Mesh`, `CapsuleComponent`, `CharacterMovement`,
> `AIControllerClass`, `HealthComponentPrivate`, `Tags` among them — for a net 35 → 19 on MeatMan's
> CDO. Same failure class as the v1.1 MeatMan startup crash. Toothy is the warning about count-based
> gates: its property count is unchanged at 17, with 8 of the 17 sitting under the wrong name.
>
> **This is the first direct measurement of the index-shift mechanism in this repo**, with a
> control: the same v1.3 pak read under the archived `24536482` usmap decodes all 35 CDO properties
> coherently, and under the live `25071553` usmap only 19. The `BPC_IncomingDamageMod` and the 4
> Stalker AIDEFs did **not** move this patch. See [`WORKLOG.md`](WORKLOG.md) Session 7.
>
> **The 2026-08-05 Grabber-crash diagnosis remains withdrawn** (Session 6): rebuilding the 4
> Stalker/Grabber DataAssets from current base produced **byte-identical** payloads to the frozen
> 0.9.2.2 cook, so that class never drifted and cannot have been mis-decoding. They are byte-
> identical again on `25071553`. The reported crash is still unexplained and needs a crash log. See
> [`docs/diagnosis.md`](docs/diagnosis.md), [`docs/fix-notes.md`](docs/fix-notes.md) and
> [`WORKLOG.md`](WORKLOG.md).

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

The mod's assets were cooked against game **0.9.2.2**. A pak override binds to the base package by
`FPackageId`, so the game loads the mod's stale cook in place of the current one — reverting whatever the
devs have since changed, and risking the `ObjectSerializationError` that broke Heavy Rifle Rebalance.

The repo originally split the 11 overrides into "drifted" and "low-risk" tiers by export count, and
rebuilt only the drifted ones from current base. **That triage was wrong twice**, in the same shape both
times — reasoning about why a frozen cook *ought* to load, rather than evidence that it does:

- **2026-07-10** — MeatMan was "low-risk" on matching export counts, and crashed in-game. All 6 boss BPs
  moved to the rebuild-from-current-base path.
- **2026-08-05** — the 4 Stalker/Grabber DataAssets were "no Kismet bytecode, so no crash surface", and
  players report crashing when they **shoot** the Grabber. Bytecode was never the relevant property: UE5
  cooked assets use **unversioned property serialization**, which identifies a property by its *index* in
  the class schema, so a reordered or added `UPROPERTY` makes a frozen cook decode into the wrong fields —
  crashing when one is *used*, not at load, and without moving a single export count.

So **all 11 overrides now build from the current base cook** with only the rebalanced scalars patched in.
There is no frozen content left in the pipeline. See [`docs/diagnosis.md`](docs/diagnosis.md).

## Layout

| Path | Contents |
|------|----------|
| `upstream/` | Pristine extracted original (`153_` pak). Reference only; cooked binaries are gitignored. |
| `docs/` | Diagnosis, the datamined rebalance value map, fix notes. |
| `tools/` | `build_fix.sh` (reproducible rebuild) + `patch_drifted.py` / `patch_stalker_aidef.py` (self-verifying scalar patchers) + `verify_build.sh` / `verify_softrefs.py`. retoc is gitignored. |
| `dist/` | **Built fixed mod** — tracked; ships the repaired `153` pak + player `readme.txt`. |
| `WORKLOG.md` | Running log. |

## Dependencies (unchanged from upstream)

Whatever the current community build for 0.9.3.x uses to load pak mods — Signature Bypass + UE4SS. (This mod has **no**
TFWWorkbench dependency; it's a plain pak.)

## Credit

Original mod **Unkillables Rebalance** by its Nexus author (mod #68). This repository is a community **compatibility
fix**; any redistributed build remains subject to the original author's permission.
