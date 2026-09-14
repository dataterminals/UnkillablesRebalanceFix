# Fix notes — what changed and how to test

Target build: **`25071553`**. Original mod: **Unkillables Rebalance 0.9.2.2** (Nexus #68).
This mod ships whole copies of game files, so it must be rebuilt after every patch.

> **Update 2026-09-11 (v1.4, built & verified on `25071553`) — the mechanism above is no longer
> theoretical; it was measured, with a control.** Build 25071553 (2026-09-10) moved the **AI character
> class schema**. The v1.3 pak is not rejected on it, it is **mis-read**: decoded inside a live
> 25071553 mount, every one of the 6 boss CDOs diverges at the same property (`FarDistance` /
> `CloseDistanceRadiusScalar`), values land under neighbouring names — MeatMan's `FarDistance` reads
> 150 where base has 750, and the 750 reappears as `CloseDistanceRadiusScalar` — and the stream then
> desynchronises, losing 19 properties including `RootComponent`, `Mesh`, `CapsuleComponent`,
> `CharacterMovement`, `AIControllerClass` and `HealthComponentPrivate` (MeatMan 35 → 19 decoded).
>
> The control: the **same v1.3 bytes** read under the archived `24536482` usmap decode all 35,
> coherently. The pak is not corrupt — the schema moved underneath it. This is the first direct
> observation of index-shift in this repo; 2026-08-05 asserted it without evidence and 2026-08-23
> had to retract that, for a class that turned out not to have moved.
>
> **Toothy is the counter-example to count-based triage**, again: its CDO property *count* is
> unchanged (17 → 17) while 8 of those 17 values sit under the wrong name. Neither export counts nor
> property counts can see this; only a value-level decode against the live schema can.
>
> `BPC_IncomingDamageMod` dropped **nothing** this patch (285 shapes in base, v1.3 and v1.4 alike),
> and the 4 Stalker AIDEFs are byte-identical to v1.3. The damage is confined to the 6 boss
> Blueprints — and there it is total. See `WORKLOG.md` Session 7.

> **Update 2026-08-23 (v1.3, built & verified on `24536482`).** Two results, one of them a
> retraction.
>
> **What the rebuild fixes, measured:** the previously shipped pak drops **9 property shapes** from
> `BPC_IncomingDamageMod` when decoded against the live build (285 base → 276 shipped). The patch
> added `Check if Weapon Silenced` and `Clean Up Damaged Foes` and swapped `MakeAINoise` for
> `MakeAINoiseForFactions`; the stale copy reverts all of it. `BPC_IncomingDamageMod` is the **only**
> one of the 11 packages whose payload moved between 24501089 and 24536482 — the other ten rebuild
> byte-identical.
>
> **The 2026-08-05 Grabber diagnosis is WITHDRAWN.** All 4 Stalker AIDEFs rebuild **byte-identical**
> to the frozen 0.9.2.2 cook (206/205/202/202 B; the only bytes differing from current base are the
> 4 belonging to the 2 rebalanced scalars). The class never drifted, so the unversioned-property
> mechanism below could not have applied to it. Option B is kept for these — it removes the
> frozen-cook dependency permanently — but it is a **no-op in shipped bytes, not a fix**, and the
> reported crash is unexplained. See `docs/diagnosis.md` and `WORKLOG.md` Session 6.

> **Update 2026-08-05 (v1.3) — SUPERSEDED by the entry above; kept for history.** The 4 Stalker
> AIDEF DataAssets were the only overrides still shipping the mod's 0.9.2.2 cook, kept there on the
> reasoning that *"DataAssets carry no Kismet bytecode, so there is no serialization-crash surface."*
> That premise is wrong in general — UE5 cooked assets use **unversioned property serialization**, so
> a property is identified by its **index** in the class schema, not its name, and a class that
> gained/removed/reordered a `UPROPERTY` makes a frozen bitstream decode into the *wrong fields*.
> The reasoning is sound; it simply did not apply here, because these classes did not change. **All
> 11 overrides now build from current base. There is no Option A left.**

> **Update 2026-07-10 (v1.1):** the pending in-game test fired and it **crashed** — a community
> member hit `ObjectSerializationError` on `BP_AI_Euruska_MeatMan` (a boss we'd filed "low-risk").
> Fix: **all 6 boss BPs now build via the "patch current base" path** (v1.0 did only 3); just the 4
> Stalker DataAssets are still rebased. Removing the pak boots clean; each rebuilt boss is now
> byte-identical to the current base cook except its 2 health floats. *(Superseded by the 2026-08-05
> update above — the Stalker DataAssets are no longer rebased either.)*

## The change (hybrid rebuild of one pak)

The mod is a pure pak mod (`153_UnkillablesRebalance_P`) overriding 11 cooked boss/AI assets with **scalar
rebalancing** only. It was cooked for 0.9.2.2; on 0.9.3.9.2 three of the eleven base classes had drifted (gained
exports), so the stale overrides risked the HeavyRifle-style `ObjectSerializationError` and/or reverting base content.
The rebuild reproduces the **identical rebalance** on the current build, per-asset by risk tier:

| Assets | Action | Why |
|---|---|---|
| **All 6 boss BPs** — `MeatMan`, `OrgaMech`, `ShieldOfficer`, `Toothy`, `MotherCourage`, `Opal` — + `BPC_IncomingDamageMod` | **patched current base** — extract the **current** base class, change only the rebalanced scalars (`tools/patch_drifted.py`), repack | ships the current structure with only the rebalanced numbers — no stale bytecode. Each boss BP ends up **byte-identical to current base except its 2 health floats**. v1.0 shipped 4 of these as mod-rebases (the "low-risk" call) and one — MeatMan — crashed in-game; export-count parity did not guarantee the stale cook loads. |
| 4× `AIDEF_Euruska_Stalker*` (`_HK` / `_Pregnant_Quest` / `_Underground`) | **patched current base** — same treatment, via `tools/patch_stalker_aidef.py` (`DamageToStagger` and `SyncKillMaxPlayerHealth`) | *Changed in v1.3.* These were rebased until 2026-08-05 because "DataAssets carry no Kismet bytecode". Moved to Option B on the theory that a drifted schema was mis-decoding and causing the shooting-the-Grabber crash — **measured false on 2026-08-23**: they rebuild byte-identical to the frozen cook, so this class never drifted. Kept on Option B anyway, because nothing frozen should remain in the pipeline; the shipped bytes are unchanged. |

The rebalanced values (identical to the original mod) are in [`rebalance-values.json`](rebalance-values.json):

- **Boss HP** (`FWHealthComponent.DefaultHealth`/`DefaultMaxHealth`, float32): MeatMan 330k, OrgaMech 286,870,
  ShieldOfficer 328k, Toothy 308,700, MotherCourage 372k, Opal 213k (all from 1e9 / 9e8).
- **Stalkers** (all 4 AIDEF DataAssets): `DamageToStagger` 20000→1000, `SyncKillMaxPlayerHealth` 2000→1000.
- **`BPC_IncomingDamageMod`**: 19 ordered Kismet **double** constants (armour/body-zone HP). The patcher is
  self-verifying — it asserts the current base double sequence equals the datamined order before writing, so a wrong
  split can't ship.

> **In plain terms:** This mod only changes some numbers — mainly how much health each boss has — so
> the bosses can be hurt and killed instead of being invincible. We rebuilt every boss using files from
> the current version of the game and touched nothing but those numbers, so nothing else about them changes.

## How it was verified (without launching the game)

- `retoc verify` on the rebuilt container → **verified**.
- **FPackageIds 11/11 byte-identical** to the original working mod (`retoc manifest` diff) → the rebuilt overrides bind
  to the same base packages the working 0.9.2.2 mod did.
- Decoded in a full game + rebuilt-pak mount → **ok=11 fail=0** (imports resolve; no data loss):
  - Boss HP reads 330000 / 286870 / 328000 / 308700 / 372000 / 213000.
  - All 4 Stalkers read `DamageToStagger` 1000, `SyncKillMaxPlayerHealth` 1000.
  - `BPC` reads the 19 constants in exact order: 61870×4, 108700 (with 72000 at position 7), … 43000.
  - **Drifted 3 now report current base export counts** (MotherCourage **182**, Opal **417**, BPC **497**) — i.e. current
    structure, not the stale 0.9.2.2 subset.
- **v1.1 re-verify (2026-07-10):** each of the **6 boss BPs** is now byte-identical to the current base cook except its
  2 health floats (8-byte diff); the isolated `global + mod` decode reads all HP/scalars correct. (Read mod values via
  an **isolated** mount — a full base+mod mount's `dump` clobbers same-basename base entries, so it shows base values.)
  MeatMan is back to the full 5931 B base uexp with its `"Sync Kill in Log"` element — the crash source is gone.

> **In plain terms:** Before releasing this, we double-checked the rebuilt files against the current
> game's own files without ever launching the game. Everything matches except the health numbers we meant
> to change, and the boss that used to crash the game (the "Meatman") now loads normally.

## Install

Contents of `dist/UnkillablesRebalanceFix/` (the three `153_…` files) go where the original mod's pak went:
`…\The Forever Winter\Windows\ForeverWinter\Content\Paks\Mods\`. Remove the **original** mod's `153_` files first (don't
run both). Keep your pak-mod loader (Signature Bypass + UE4SS) current for 0.9.3.x; after a hotfix, clean-reinstall the
loader + pak (remove, don't just toggle). No TFWWorkbench dependency — this is a plain pak. Full player-facing notes in
`dist/readme.txt`.

> **In plain terms:** Copy the three files into your game's mods folder and delete the old version of this
> mod first — don't run both at once. Keep your mod loader up to date, and after any game update, fully
> remove and re-add the loader and this mod rather than just toggling it off and on.

## Test checklist (build 25071553)

1. **Baseline (optional):** original mod → watch for a crash / no-effect on a rebalanced boss. Fixed mod → neither.
2. Reaches main menu and loads a mission without crashing.
3. Each boss (MeatMan, OrgaMech, ShieldOfficer, Toothy, Mother Courage, Opal — non-HK) is staggerable and killable by
   weapons; no `ObjectSerializationError` for any `BP_AI_*` / `BP_Mech_Toothy` / `BPC_IncomingDamageMod`.
4. **Shoot a Grabber/Stalker repeatedly until it staggers — no crash.** This is the reported v1.3
   repro, and the item that matters most: item 5 only covers *being grabbed*, which is a different
   code path, and that gap is why the report went unnoticed. Try the variants you can reach
   (regular, Underground). Note the suspected cause was **ruled out by measurement** on 2026-08-23
   (the Stalker AIDEFs never drifted), so this is now an open question rather than a fix being
   confirmed — if it still crashes, capture `…\Saved\Crashes\` and
   `…\Saved\Logs\ForeverWinter.log`; that log is the thing the diagnosis is missing.
5. Grabber/Stalker: ~600-dmg swipe + disengage instead of an insta-kill grab (while you're above 1000 HP).
6. `…\Saved\Crashes\` stays empty — and if it does not, keep the crash log, it is the thing this
   diagnosis is still missing.

> **In plain terms:** To check it's working: start the game, load a mission, and confirm each boss can be
> staggered and killed by your weapons without the game crashing. If the game's crash-report folder stays
> empty afterward, you're good.

## Known minor issues / caveats (not introduced by this fix)

- **Mother Courage / OrgaMech death freeze:** they sometimes freeze to an idle pose on death before despawning — a
  pre-existing behaviour the original author documents, not a crash and not from this rebuild.
- **Rebuild after future patches:** any hotfix that changes these boss classes can re-break the pak. Re-run
  `tools/build_fix.sh` (re-extracts/rebases onto the new build; the patcher aborts if base values moved).
- **Attribution:** original mod by its Nexus #68 author. This is a community compatibility fix; confirm the author's
  permission before any public redistribution.

> **In plain terms:** A couple of bosses may briefly freeze in place when they die — that's an old quirk
> of the original mod, not this fix, and it's harmless. Future game updates could break this mod and need
> a rebuild, and since someone else made the original mod, ask their permission before sharing it anywhere.
