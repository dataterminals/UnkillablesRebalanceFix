# Diagnosis — why Unkillables Rebalance is out of date on 0.9.3.9.2

**Build in question:** 24097213 (Hot-Fix 0.9.3.9.2). **Mod version:** 0.9.2.2 (Nexus [#68](https://www.nexusmods.com/theforeverwinter/mods/68)).
Method: decoded the mod's pak vs. the live game with the [`forever-winter-datamine`](https://github.com/dataterminals) CUE4Parse
toolchain (base-only mount = vanilla; `global + mod` mount = the mod's own cooked versions), diffed the two, and
corroborated against the mod's public description.

> **Update 2026-08-23 (v1.3, built) — the 2026-08-05 diagnosis below is WITHDRAWN. It was wrong.**
> The pak was finally rebuilt on a machine with the game (build `24536482`) and the claim was
> measured instead of reasoned about. **All 4 Stalker AIDEFs build byte-for-byte identical to the
> frozen 0.9.2.2 cook they were already shipping** — same length, same string set, and the only
> bytes that differ from current base are the 4 belonging to the 2 rebalanced scalars
> (`20000→1000` moves 3 bytes, `2000→1000` moves 1):
>
> | AIDEF | uexp len | base vs rebuilt | rebuilt vs previously shipped |
> |---|---|---|---|
> | `AIDEF_Euruska_Stalker` | 206 B | 4 bytes @ 102,103,104,136 | **0 — identical** |
> | `AIDEF_Euruska_Stalker_HK` | 205 B | 4 bytes @ 100,101,102,134 | **0 — identical** |
> | `AIDEF_Euruska_Stalker_Pregnant_Quest` | 202 B | 4 bytes @ 98,99,100,132 | **0 — identical** |
> | `AIDEF_Euruska_Stalker_Underground` | 202 B | 4 bytes @ 98,99,100,132 | **0 — identical** |
>
> The AIDEF class **never drifted** between 0.9.2.2 and 24536482, so the frozen cook was decoding
> correctly all along and the unversioned-property mechanism described below **cannot** have been
> mis-reading these files. `stalker_aidef.structural_drift` is now `false` **as measured**, not as
> assumed. The Option A → Option B migration is kept — it removes the frozen-cook dependency and
> the `upstream/` requirement permanently — but it is a **no-op in shipped bytes**, not a fix.
>
> **The reported "crash when shooting the Grabber" therefore has no established cause.** What *was*
> found, and is real and measured, is that the previously shipped pak drops **9 property shapes**
> from `BPC_IncomingDamageMod` on 24536482 — the patch added `Check if Weapon Silenced`,
> `Clean Up Damaged Foes` and faction-aware AI noise, and the stale copy reverts them. That is a
> genuine regression and a plausible contributor, but it is not the same claim. Get the crash log.
>
> **The lesson, a third time, and it is not the one written below.** 2026-07-10 was "export counts
> match, so the cook is safe." 2026-08-05 was "no bytecode, so the cook is safe." Both were
> reasoning in place of evidence, and both were *wrong in the unsafe direction*. 2026-08-05's
> correction was reasoning too — a mechanism that explained the symptom, adopted without measuring
> whether its precondition (drift) held. It did not. **A mechanism that explains the symptom is not
> evidence that it occurred.**

> **Update 2026-08-05 (v1.3) — SUPERSEDED, see the 2026-08-23 update above. Kept for history.**
> *(original text: "the second 'structurally safe' call was wrong too.")* Players report
> the game **crashing when they shoot the Grabber**. The 4 Stalker AIDEF DataAssets were the last
> overrides still shipping the mod's frozen 0.9.2.2 cook, kept there because *"DataAssets carry no
> Kismet bytecode, so there is no serialization-crash surface."* Bytecode is not the relevant
> property: UE5 cooked assets use **unversioned property serialization**, where a property is
> identified by its **index in the class's property schema** rather than by name. A class that
> gained, removed, or reordered a `UPROPERTY` since 0.9.2.2 makes the frozen bitstream decode into
> the **wrong fields** — object and soft-object pointers included — which crashes when a field is
> *dereferenced* (i.e. when you shoot the thing), not at load. **Fix: all 11 overrides now build
> from current base via Option B; Option A is gone from the pipeline.** The game had also moved
> 24501089 → **24536482**, so the pak was stale regardless — that part explains why other players
> saw problems too. *This root cause is inferred from the symptom and the asset inventory; no crash
> log has been obtained yet (see `WORKLOG.md` Session 5).* Twice now the error has been the same
> shape: reasoning about why a frozen cook *ought* to load, instead of evidence that it does.

> **Update 2026-07-10 (v1.1) — the in-game arbiter fired, and the "low-risk 8" call was wrong.** A
> community member crashed on the current build: `ObjectSerializationError` on `BP_AI_Euruska_MeatMan`
> (`Bad export index 1066192076/32`); removing the pak boots clean. MeatMan was one of the "8 low-risk"
> rebased boss BPs. Its real deserialization export count is **32** (== the runtime `/32`), *not* the
> "71" in the table below — that was a different IoStore metric. A decode-diff shows the mod's 0.9.2.2
> cook is a **stale subset** of current base (base gained a `"Sync Kill in Log"` element; uexp 5931 vs
> 5904 B), so its cooked refs desync at runtime. **Fix: all 6 boss BPs + BPC now use the "patch current
> base" path (Option B); only the 4 Stalker DataAssets stay rebased.** Export-count parity ≠ a safe cook —
> the same HRF05 lesson, now on an asset we'd filed low-risk. The sections below are the original v1.0
> diagnosis, kept for history.

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

> **In plain terms:** This mod is one small file (a "pak" — a game data package) that only turns numbers down. It lowers the huge health of six boss enemies so normal guns can hurt and kill them, and it stops the Grabber enemy from instantly killing you. It adds nothing new to the game.

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
  unlikely to fail deserialization. — **[Corrected v1.1: FALSE for the 4 boss BPs. MeatMan crashed in-game; the
  "identical" claim rested on a misleading export-count metric. All 6 boss BPs are now built via Option B. See the
  update banner at the top.]**
- **3 drifted assets** (`MotherCourage`, `Opal`, `BPC_IncomingDamageMod`): the base class **grew new exports** since
  0.9.2.2. Shipping the mod's stale version here (a) **reverts** whatever base added (missing new functions/abilities),
  and (b) risks the HeavyRifle-style `ObjectSerializationError` if the stale bytecode references a base symbol that
  changed. `MotherCourage` and `OrgaMech` are also exactly the two the author already flags as freezing on death — a
  behaviour that a further base-drift can only worsen.

> **In plain terms:** The mod was built for an older version of the game. Since then the game changed some of these bosses, but the mod still carries its own old copies of them. For a few bosses those old copies no longer match the new game, which can undo the game's recent changes or crash it.

## Exact failure mode on this build — **CONFIRMED 2026-07-10: hard crash (option 1)**

Static analysis proves the drift and the values, but the *runtime* symptom on 0.9.3.9.2 could be any of:

1. **Hard crash** (`ObjectSerializationError`) when a drifted boss spawns — the HeavyRifle outcome.
2. **Silent no-op** — the override fails to bind and bosses stay at 1e9 HP (mod "does nothing").
3. **Loads but reverted** — drifted bosses lose base's post-0.9.2.2 changes.

The low-risk 8 almost certainly still apply their rebalance. The unknown is the drifted 3. Confirming which requires a
launch on build 24097213 (the arbiter, as with HeavyRifle).

> **In plain terms:** We ran the mod on the current game and confirmed the worst outcome: the game hard-crashes when one of the affected bosses shows up. It doesn't quietly do nothing — it actually crashes.

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

> **In plain terms:** The fix rebuilds the boss files from the current game and changes only the health numbers, leaving everything else exactly as the game now has it. That way the bosses load without crashing while still getting the mod's easier health.

## Honest caveats

- **Fix built & statically verified; in-game test still pending.** The hybrid rebuild (Option A for the 8 low-risk,
  Option B for the drifted 3) is done and decode-verifies (`docs/fix-notes.md`): `retoc verify` passes, FPackageIds are
  11/11 identical to the original, all values read back correctly, and the drifted 3 now report current base structure
  (182/417/497 exports). The one remaining unknown — whether the game's runtime linker agrees with the static parse — is
  resolved only by a launch on 24097213, the same arbiter as HeavyRifle. — **[v1.1: that launch happened and it CRASHED
  (MeatMan). Rebuilt with all 6 boss BPs on Option B; the rebuilt boss BPs are byte-identical to current base except
  their health floats. A fresh in-game re-test is the remaining arbiter.]**
- The `191`-style mesh/texture side that HeavyRifle had does **not** exist here — this mod touches no meshes, so there's
  no cosmetic-regression surface.
- Any future hotfix touching these boss classes will re-break the pak — inherent to cooked-override mods.

> **In plain terms:** The fix is built and checked, but it still needs one real in-game test to be certain. It doesn't touch any graphics, so nothing will look wrong. And a future game update could break it again — that's normal for this kind of mod.
